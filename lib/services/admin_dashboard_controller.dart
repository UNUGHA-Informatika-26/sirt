import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'citizen_request_service.dart';
import 'equipment_loan_service.dart';
import 'poll_service.dart';

/// Owns live dashboard summary state for the admin home screen.
class AdminDashboardController extends ChangeNotifier {
  int? _profileResidentCount;
  int? _directoryResidentCount;
  int? _pendingLetterCount;
  int? _pendingLoanCount;
  int? _pendingGuestCount;
  int? _guestReportCount;
  int? _activePollCount;
  Object? _lastError;
  bool _disposed = false;
  List<CommunityPoll> _latestPolls = const [];
  Timer? _pollExpiryTimer;

  late final StreamSubscription<List<Map<String, dynamic>>> _profilesSub;
  late final StreamSubscription<List<Map<String, dynamic>>> _directorySub;
  late final StreamSubscription<List<CitizenRequest>> _requestsSub;
  late final StreamSubscription<List<EquipmentLoanRequest>> _loansSub;
  late final StreamSubscription<List<CommunityPoll>> _pollsSub;

  AdminDashboardController() {
    _profilesSub = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('role', 'warga')
        .listen(
          (rows) => _update(() => _profileResidentCount = rows.length),
          onError: _handleError,
        );

    _directorySub = Supabase.instance.client
        .from('resident_directory')
        .stream(primaryKey: ['id'])
        .listen(
          (rows) => _update(() => _directoryResidentCount = rows.length),
          onError: _handleError,
        );

    _requestsSub = CitizenRequestService.watchAll().listen(
      (requests) => _update(() {
        _pendingLetterCount = requests
            .where((request) =>
                request.kind == 'letter' && request.status == 'pending')
            .length;
        _pendingGuestCount = requests
            .where((request) =>
                request.kind == 'guest' && request.status == 'pending')
            .length;
        _guestReportCount =
            requests.where((request) => request.kind == 'guest').length;
      }),
      onError: _handleError,
    );

    _loansSub = EquipmentLoanService.watchAllRequests().listen(
      (requests) => _update(() => _pendingLoanCount =
          requests.where((request) => request.status == 'pending').length),
      onError: _handleError,
    );

    _pollsSub = PollService.watchPolls().listen(
      _setPolls,
      onError: _handleError,
    );
  }

  void _setPolls(List<CommunityPoll> polls) {
    _latestPolls = polls;
    _update(() => _activePollCount =
        _latestPolls.where((poll) => !poll.isExpired).length);
    _schedulePollExpiry();
  }

  void _schedulePollExpiry() {
    _pollExpiryTimer?.cancel();
    final now = DateTime.now();
    DateTime? nextExpiry;
    for (final poll in _latestPolls) {
      if (!poll.isExpired && (nextExpiry == null || poll.expiresAt.isBefore(nextExpiry))) {
        nextExpiry = poll.expiresAt;
      }
    }
    if (nextExpiry == null) return;
    _pollExpiryTimer = Timer(nextExpiry.difference(now), () {
      if (_disposed) return;
      _update(() => _activePollCount =
          _latestPolls.where((poll) => !poll.isExpired).length);
      _schedulePollExpiry();
    });
  }

  int? get residentCount => _profileResidentCount == null ||
          _directoryResidentCount == null
      ? null
      : _profileResidentCount! + _directoryResidentCount!;
  int? get pendingLetterCount => _pendingLetterCount;
  int? get pendingLoanCount => _pendingLoanCount;
  int? get pendingGuestCount => _pendingGuestCount;
  int? get guestReportCount => _guestReportCount;
  int? get activePollCount => _activePollCount;

  bool get isLoading =>
      residentCount == null ||
      _pendingLetterCount == null ||
      _pendingLoanCount == null ||
      _pendingGuestCount == null ||
      _guestReportCount == null ||
      _activePollCount == null;

  Object? get lastError => _lastError;

  void _update(VoidCallback change) {
    if (_disposed) return;
    change();
    _lastError = null;
    notifyListeners();
  }

  void _handleError(Object error, StackTrace stackTrace) {
    if (_disposed) return;
    _lastError = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _profilesSub.cancel();
    _directorySub.cancel();
    _requestsSub.cancel();
    _loansSub.cancel();
    _pollsSub.cancel();
    _pollExpiryTimer?.cancel();
    super.dispose();
  }
}
