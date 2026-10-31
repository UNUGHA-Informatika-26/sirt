import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/sirt_logo.dart';
import '../app_colors.dart';
import '../services/admin_dashboard_controller.dart';
import '../services/profile_service.dart';
import 'admin_approvals_screen.dart';
import 'admin_duty_schedule_screen.dart';
import 'admin_polling_screen.dart';
import 'admin_residents_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedTab = 0;
  String? _profilePhotoUrl;
  bool _uploadingProfilePhoto = false;
  late final AdminDashboardController _dashboardController;
  StreamSubscription<String?>? _profilePhotoSubscription;

  @override
  void initState() {
    super.initState();
    dashboardNavigationSignal.addListener(_goToDashboard);
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
    _dashboardController = AdminDashboardController();
  }

  void _goToDashboard() {
    if (mounted) setState(() => _selectedTab = 0);
  }

  @override
  void dispose() {
    dashboardNavigationSignal.removeListener(_goToDashboard);
    _dashboardController.dispose();
    _profilePhotoSubscription?.cancel();
    super.dispose();
  }

  static const _managementItems = <_ManagementData>[
    _ManagementData('Persetujuan', Icons.check_circle_outline, 1),
    _ManagementData('Data Warga', Icons.groups_2_outlined, 2),
    _ManagementData('Inventaris', Icons.inventory_2_outlined),
    _ManagementData('Jadwal Jaga', Icons.access_time_outlined),
    _ManagementData('Polling', Icons.poll_outlined),
  ];

  String get _today {
    const weekdays = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final now = DateTime.now();
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
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
                      ? const Text(
                          'RT',
                          style: TextStyle(
                              color: appGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w800),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: IndexedStack(
            index: _selectedTab,
            children: [
              _buildDashboard(),
              const AdminApprovalsScreen(),
              const AdminResidentsScreen(),
              _buildOtherTab(3),
            ],
          ),
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
                icon: Icon(Icons.home_outlined), label: 'Dashboard'),
            NavigationDestination(
                icon: Icon(Icons.check_circle_outline), label: 'Setujui'),
            NavigationDestination(
                icon: Icon(Icons.groups_2_outlined), label: 'Warga'),
            NavigationDestination(
                icon: Icon(Icons.account_circle_outlined), label: 'Profil'),
          ],
        ),
      );

  Widget _buildDashboard() => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 15, 18, 22),
            children: [
              const Text(
                'Dashboard RT',
                style: TextStyle(
                    color: appInk,
                    fontSize: 21,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(_today,
                  style: const TextStyle(color: appMuted, fontSize: 11)),
              const SizedBox(height: 12),
              const _WelcomeAdminCard(),
              const SizedBox(height: 14),
              const Text(
                'Ringkasan RT',
                style: TextStyle(
                    color: appInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _dashboardController,
                builder: (context, _) => LayoutBuilder(
                  builder: (context, constraints) {
                    final width = (constraints.maxWidth - 8) / 2;
                    final items = [
                      _SummaryData(_dashboardController.residentCount, 'Warga'),
                      _SummaryData(_dashboardController.pendingLetterCount,
                          'Surat menunggu'),
                      _SummaryData(_dashboardController.pendingLoanCount,
                          'Peminjaman menunggu'),
                      _SummaryData(_dashboardController.pendingGuestCount,
                          'Tamu menunggu'),
                      _SummaryData(_dashboardController.guestReportCount,
                          'Laporan tamu'),
                      _SummaryData(_dashboardController.activePollCount,
                          'Polling aktif'),
                    ];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final item in items)
                              SizedBox(
                                width: width,
                                height: 53,
                                child: _SummaryCard(data: item),
                              ),
                          ],
                        ),
                        if (_dashboardController.lastError != null) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'Sebagian ringkasan gagal dimuat. Periksa koneksi dan akses Supabase.',
                            style: TextStyle(color: appMuted, fontSize: 9),
                          ),
                        ] else if (_dashboardController.isLoading) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'Memuat ringkasan dari Supabase…',
                            style: TextStyle(color: appMuted, fontSize: 9),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Kelola aktivitas',
                style: TextStyle(
                    color: appInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 8) / 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in _managementItems)
                        SizedBox(
                          width: width,
                          height: 45,
                          child: _ManagementCard(
                            data: item,
                            onTap: () {
                              if (item.tabIndex != null) {
                                setState(() => _selectedTab = item.tabIndex!);
                              } else if (item.label == 'Jadwal Jaga') {
                                _openDutySchedule();
                              } else if (item.label == 'Polling') {
                                _openPolling();
                              } else {
                                _showComingSoon(item.label);
                              }
                            },
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

  Widget _buildOtherTab(int index) {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final fullName = metadata['full_name']?.toString().trim();
    final name = fullName == null || fullName.isEmpty ? 'Admin RT' : fullName;
    final address = metadata['address']?.toString().trim();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 22),
          children: [
            const Text('Profil Akun Admin',
                style: TextStyle(
                    color: appInk,
                    fontSize: 21,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(
              children: [
                InkWell(
                  onTap: _uploadingProfilePhoto ? null : _pickProfilePhoto,
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
                            ? const Text('RT',
                                style: TextStyle(
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
            _ProfileInfoCard(
              icon: Icons.location_on_outlined,
              title: 'Alamat',
              subtitle: address == null || address.isEmpty
                  ? 'Alamat belum diisi'
                  : address,
              onTap: () => _showProfileInfo('Alamat', address ?? ''),
            ),
            const SizedBox(height: 7),
            _ProfileInfoCard(
              icon: Icons.verified_user_outlined,
              title: 'Status akun',
              subtitle: 'Terverifikasi',
              onTap: () => _showProfileInfo('Status akun', 'Terverifikasi'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProfilePhoto() async {
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
        const SnackBar(
          content: Text('Foto profil admin berhasil diperbarui.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Foto tidak dapat dibuka: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingProfilePhoto = false);
    }
  }

  void _showProfileInfo(String title, String value) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(value.isEmpty ? 'Belum ada informasi.' : value),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Menu $item akan dihubungkan setelah dashboard.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openDutySchedule() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminDutyScheduleScreen(
          onNavigateTab: (index) => setState(() => _selectedTab = index),
        ),
      ),
    );
  }

  void _openPolling() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminPollingScreen(
          onNavigateTab: (index) => setState(() => _selectedTab = index),
        ),
      ),
    );
  }
}

class _WelcomeAdminCard extends StatelessWidget {
  const _WelcomeAdminCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
        decoration: BoxDecoration(
          color: const Color(0xFFE5F3EF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selamat datang, Ketua RT',
              style: TextStyle(
                  color: appGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 5),
            Text(
              'Pantau kebutuhan dan layanan warga.',
              style: TextStyle(color: appMuted, fontSize: 10),
            ),
          ],
        ),
      );
}

class _SummaryData {
  final int? value;
  final String label;

  const _SummaryData(this.value, this.label);
}

class _SummaryCard extends StatelessWidget {
  final _SummaryData data;

  const _SummaryCard({required this.data});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(11, 7, 8, 5),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: appBorder),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                data.value?.toString() ?? '…',
                style: const TextStyle(
                    color: appInk,
                    fontSize: 16,
                    height: 1,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: appMuted, fontSize: 9)),
            ],
          ),
      );
}

class _ManagementData {
  final String label;
  final IconData icon;
  final int? tabIndex;

  const _ManagementData(this.label, this.icon, [this.tabIndex]);
}

class _ManagementCard extends StatelessWidget {
  final _ManagementData data;
  final VoidCallback onTap;

  const _ManagementCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              border: Border.all(color: appBorder),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: const Color(0xFFE5F3EF),
                  child: Icon(data.icon, color: appGreen, size: 12),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: appInk,
                        fontSize: 9,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const Icon(Icons.chevron_right, color: appMuted, size: 15),
              ],
            ),
          ),
        ),
      );
}

class _ProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: appBorder),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: const Color(0xFFE5F3EF),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: appMuted, fontSize: 9)),
                    ],
                  ),
                ),
                const Icon(Icons.more_vert, color: appMuted, size: 15),
              ],
            ),
          ),
        ),
      );
}
