import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/sirt_logo.dart';
import '../app_colors.dart';
import '../services/profile_service.dart';
import 'citizen_polling_screen.dart';
import 'citizen_inventory_screen.dart';
import 'citizen_service_requests_screen.dart';
import '../services/duty_schedule_service.dart';

class CitizenHomeScreen extends StatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  State<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends State<CitizenHomeScreen> {
  int _selectedTab = 0;
  late final Stream<List<DutySchedule>> _dutyScheduleStream;
  String? _profilePhotoUrl;
  bool _uploadingProfilePhoto = false;
  StreamSubscription<String?>? _profilePhotoSubscription;

  @override
  void initState() {
    super.initState();
    dashboardNavigationSignal.addListener(_goToDashboard);
    _dutyScheduleStream = DutyScheduleService.watchAll();
    _profilePhotoUrl = Supabase.instance.client.auth.currentUser
        ?.userMetadata?['avatar_url']
        ?.toString();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      _profilePhotoSubscription = ProfileService.watchMyAvatar(userId).listen(
        (photoUrl) {
          if (mounted) setState(() => _profilePhotoUrl = photoUrl);
        },
      );
    }
  }

  void _goToDashboard() {
    if (mounted) setState(() => _selectedTab = 0);
  }

  @override
  void dispose() {
    dashboardNavigationSignal.removeListener(_goToDashboard);
    _profilePhotoSubscription?.cancel();
    super.dispose();
  }

  static const _services = <_ServiceItem>[
    _ServiceItem('Surat', Icons.article_outlined),
    _ServiceItem('Inventaris', Icons.inventory_2_outlined),
    _ServiceItem('Lapor Tamu', Icons.schedule_outlined),
    _ServiceItem('Jadwal Jaga', Icons.fingerprint_outlined),
    _ServiceItem('Musyawarah', Icons.check_circle_outline),
  ];

  String get _firstName {
    final user = Supabase.instance.client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name']?.toString().trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName.split(RegExp(r'\s+')).first;
    }
    final emailName = user?.email?.split('@').first;
    if (emailName != null && emailName.isNotEmpty) return emailName;
    return 'Warga';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: appBackground,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          titleSpacing: 20,
          title: SirtLogo(onTap: () => setState(() => _selectedTab = 0)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: InkWell(
                onTap: () => setState(() => _selectedTab = 3),
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFFE5F3EF),
                  backgroundImage: _profilePhotoUrl == null
                      ? null
                      : NetworkImage(_profilePhotoUrl!),
                  child: _profilePhotoUrl == null
                      ? Text(
                          _firstName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: appGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: _selectedTab == 0
              ? _buildHome()
              : _buildOtherTab(_selectedTab),
        ),
        bottomNavigationBar: NavigationBar(
          height: 66,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFE5F3EF),
          selectedIndex: _selectedTab,
          onDestinationSelected: (index) => setState(() => _selectedTab = index),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined), label: 'Beranda'),
            NavigationDestination(
                icon: Icon(Icons.grid_view_outlined), label: 'Layanan'),
            NavigationDestination(
                icon: Icon(Icons.access_time_outlined), label: 'Jadwal'),
            NavigationDestination(
                icon: Icon(Icons.account_circle_outlined), label: 'Profil'),
          ],
        ),
      );

  Widget _buildHome() => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            children: [
              Text(
                'Beranda\nHalo, $_firstName 👋',
                style: const TextStyle(
                  color: appInk,
                  fontSize: 21,
                  height: 1.02,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 17),
              const _WelcomeBanner(),
              const SizedBox(height: 17),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Layanan warga',
                      style: TextStyle(
                          color: appInk,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedTab = 1),
                    style: TextButton.styleFrom(
                      foregroundColor: appGreen,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Lihat semua →',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildServiceGrid(),
              const SizedBox(height: 9),
              const Text(
                'Ringkasan',
                style: TextStyle(
                    color: appInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const _SummaryCard(
                icon: Icons.priority_high_rounded,
                iconColor: Color(0xFFEA9B34),
                iconBackground: Color(0xFFFFF1D9),
                title: '1 surat menunggu diproses',
                subtitle: 'Lihat status pengajuan',
              ),
              const SizedBox(height: 8),
              const _SummaryCard(
                icon: Icons.access_time,
                iconColor: Color(0xFF6BB7A7),
                iconBackground: Color(0xFFE7F4F0),
                title: 'Jadwal ronda besok',
                subtitle: 'Sabtu · 20.00–22.00 · Pak Dedi',
              ),
            ],
          ),
        ),
      );

  Widget _buildServiceGrid() => LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final service in _services)
                SizedBox(
                  width: cardWidth,
                  height: 57,
                  child: _ServiceCard(
                    service: service,
                    onTap: () => _onServiceTap(service),
                  ),
                ),
            ],
          );
        },
      );

  Widget _buildOtherTab(int index) {
    final title = switch (index) {
      1 => 'Layanan SiRT',
      2 => 'Jadwal warga',
      _ => 'Profil saya',
    };

    if (index == 1) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            children: [
              Text(title,
                  style: const TextStyle(
                      color: appInk,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final service in _services)
                        SizedBox(
                          width: cardWidth,
                          height: 43,
                          child: _ServiceCard(
                            service: service,
                            onTap: () => _onServiceTap(service),
                            expanded: true,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    if (index == 2) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            children: [
              const Text('Jadwal Jaga',
                  style: TextStyle(
                      color: appInk,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              const Text('Semua warga dapat melihat jadwal.',
                  style: TextStyle(color: appMuted, fontSize: 10)),
              const SizedBox(height: 12),
              StreamBuilder<List<DutySchedule>>(
                stream: _dutyScheduleStream,
                builder: (context, snapshot) =>
                    _buildCitizenDutySchedules(snapshot),
              ),
            ],
          ),
        ),
      );
    }

    final user = Supabase.instance.client.auth.currentUser;
    return _buildCitizenProfile(user);
  }

  Widget _buildCitizenProfile(User? user) {
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final fullName = metadata['full_name']?.toString().trim();
    final name = fullName == null || fullName.isEmpty ? 'Warga' : fullName;
    final address = metadata['address']?.toString().trim();
    final initial = name.substring(0, 1).toUpperCase();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 22),
          children: [
            const Text('Profil Akun Warga',
                style: TextStyle(
                    color: appInk,
                    fontSize: 21,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(
              children: [
                InkWell(
                  onTap: _uploadingProfilePhoto ? null : _pickCitizenProfilePhoto,
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 23,
                        backgroundColor: const Color(0xFFE5F3EF),
                        backgroundImage: _profilePhotoUrl == null
                            ? null
                            : NetworkImage(_profilePhotoUrl!),
                        child: _profilePhotoUrl == null
                            ? Text(initial,
                                style: const TextStyle(
                                    color: appGreen,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800))
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                              color: appGreen, shape: BoxShape.circle),
                          child: _uploadingProfilePhoto
                              ? const SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.edit,
                                  color: Colors.white, size: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: appBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                color: appInk,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(user?.email ?? 'Email belum tersedia',
                            style: const TextStyle(
                                color: appMuted, fontSize: 9)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: FilledButton.icon(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                icon: const Icon(Icons.logout, size: 15),
                label: const Text('Keluar aplikasi'),
                style: FilledButton.styleFrom(
                  backgroundColor: appGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11)),
                  textStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 13),
            const Text('INFORMASI AKUN',
                style: TextStyle(
                    color: appInk,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .2)),
            const SizedBox(height: 8),
            _citizenProfileInfoCard(
              icon: Icons.location_on_outlined,
              title: 'Alamat',
              subtitle: address == null || address.isEmpty
                  ? 'Alamat belum diisi'
                  : address,
            ),
            const SizedBox(height: 7),
            _citizenProfileInfoCard(
              icon: Icons.verified_user_outlined,
              title: 'Status akun',
              subtitle: 'Terverifikasi',
            ),
          ],
        ),
      ),
    );
  }

  Widget _citizenProfileInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        margin: const EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: appBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                  color: Color(0xFFE5F3EF), shape: BoxShape.circle),
              child: Icon(icon, color: appGreen, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: appInk,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(color: appMuted, fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
      );

  Future<void> _pickCitizenProfilePhoto() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null || !mounted) return;
      if (bytes.length > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ukuran foto maksimal 5 MB.')),
        );
        return;
      }

      setState(() => _uploadingProfilePhoto = true);
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw const AuthException('Silakan masuk kembali.');
      final extension = file.extension?.toLowerCase() ?? '';
      final contentType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$extension';
      await client.storage.from('profile-photos').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );
      final photoUrl = client.storage.from('profile-photos').getPublicUrl(path);
      await ProfileService.saveMyAvatar(photoUrl);
      if (!mounted) return;
      setState(() => _profilePhotoUrl = photoUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto profil warga berhasil diperbarui.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Foto profil gagal diperbarui: $error')),
      );
    } finally {
      if (mounted) setState(() => _uploadingProfilePhoto = false);
    }
  }

  Widget _buildCitizenDutySchedules(
      AsyncSnapshot<List<DutySchedule>> snapshot) {
    if (snapshot.hasError) {
      return _ScheduleInfoCard(
        icon: Icons.error_outline,
        title: 'Jadwal belum dapat dimuat',
        subtitle: 'Periksa koneksi internet lalu coba lagi.',
      );
    }
    if (!snapshot.hasData) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: appGreen)),
      );
    }
    final schedules = snapshot.data!;
    if (schedules.isEmpty) {
      return const _ScheduleInfoCard(
        icon: Icons.access_time,
        title: 'Belum ada jadwal jaga',
        subtitle: 'Jadwal yang ditambahkan admin akan tampil di sini.',
      );
    }

    final grouped = <DateTime, List<DutySchedule>>{};
    for (final schedule in schedules) {
      final date = DateTime(schedule.startsAt.year, schedule.startsAt.month,
          schedule.startsAt.day);
      grouped.putIfAbsent(date, () => []).add(schedule);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 7, top: 4),
            child: Text(
              _formatScheduleDate(entry.key),
              style: const TextStyle(
                  color: appInk, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          for (final schedule in entry.value) ...[
            _CitizenDutyScheduleCard(schedule: schedule),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  String _formatScheduleDate(DateTime date) {
    const weekdays = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
    ];
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _showComingSoon(String serviceName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fitur $serviceName akan dibuat setelah beranda.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onServiceTap(_ServiceItem service) {
    if (service.name == 'Jadwal Jaga') {
      setState(() => _selectedTab = 2);
    } else if (service.name == 'Musyawarah') {
      _openCitizenPolling();
    } else if (service.name == 'Inventaris') {
      _openCitizenInventory();
    } else if (service.name == 'Surat' || service.name == 'Lapor Tamu') {
      _openCitizenRequests();
    } else {
      _showComingSoon(service.name);
    }
  }

  void _openCitizenPolling() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CitizenPollingScreen(
          onNavigateTab: (index) => setState(() => _selectedTab = index),
        ),
      ),
    );
  }

  void _openCitizenInventory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CitizenInventoryScreen(
          onNavigateTab: (index) => setState(() => _selectedTab = index),
        ),
      ),
    );
  }

  void _openCitizenRequests() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CitizenServiceRequestsScreen(
          onNavigateTab: (index) => setState(() => _selectedTab = index),
        ),
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: appGreen,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lingkungan lebih tertata,\ndimulai dari kita.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.18,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'Layanan RT selalu dekat untuk warga.',
              style: TextStyle(color: Color(0xFFD4EEE7), fontSize: 10),
            ),
          ],
        ),
      );
}

class _ServiceItem {
  final String name;
  final IconData icon;

  const _ServiceItem(this.name, this.icon);
}

class _ServiceCard extends StatelessWidget {
  final _ServiceItem service;
  final VoidCallback onTap;
  final bool expanded;

  const _ServiceCard({
    required this.service,
    required this.onTap,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: expanded ? 43 : null,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              border: Border.all(color: appBorder),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: expanded ? 9 : 12,
                  backgroundColor: const Color(0xFFE8F4F1),
                  child: Icon(service.icon,
                      color: appGreen, size: expanded ? 10 : 13),
                ),
                SizedBox(width: expanded ? 6 : 8),
                Expanded(
                  child: Text(
                    service.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: appInk,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: appBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: iconBackground,
              child: Icon(icon, color: iconColor, size: 13),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: appInk,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: appMuted, fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CitizenDutyScheduleCard extends StatelessWidget {
  final DutySchedule schedule;

  const _CitizenDutyScheduleCard({required this.schedule});

  String _formatClock(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}.${date.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: appBorder),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 12,
              backgroundColor: Color(0xFFE8F4F1),
              child: Icon(Icons.access_time, color: appGreen, size: 13),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${schedule.residentName} · ${schedule.shiftName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: appInk,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                      '${_formatClock(schedule.startsAt)}–${_formatClock(schedule.endsAt)}',
                      style: const TextStyle(color: appMuted, fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ScheduleInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ScheduleInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: appBorder),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: const Color(0xFFE8F4F1),
              child: Icon(icon, color: appGreen, size: 14),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: appInk,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(color: appMuted, fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
      );
}
