import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/sirt_logo.dart';
import '../app_colors.dart';
import '../services/equipment_loan_service.dart';
import '../utils/app_error.dart';
import '../widgets/decision_document_button.dart';

class CitizenInventoryScreen extends StatefulWidget {
  final ValueChanged<int> onNavigateTab;

  const CitizenInventoryScreen({required this.onNavigateTab, super.key});

  @override
  State<CitizenInventoryScreen> createState() => _CitizenInventoryScreenState();
}

class _CitizenInventoryScreenState extends State<CitizenInventoryScreen> {
  late final Stream<List<InventoryItem>> _inventory;
  late final Stream<List<EquipmentLoanRequest>> _myRequests;

  @override
  void initState() {
    super.initState();
    _inventory = EquipmentLoanService.watchInventory();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    _myRequests = userId == null
        ? Stream<List<EquipmentLoanRequest>>.value(const [])
        : EquipmentLoanService.watchMyRequests(userId);
  }

  void _navigateTab(int index) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onNavigateTab(index);
  }

  Future<void> _openLoanForm(List<InventoryItem> items) async {
    if (items.isEmpty) {
      _message('Inventaris belum tersedia untuk dipinjam.');
      return;
    }
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _LoanRequestForm(items: items)),
    );
    if (sent == true && mounted) {
      _message('Pengajuan dikirim. Tunggu persetujuan admin.');
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: appBackground,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          titleSpacing: 20,
          title: const SirtLogo(),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 18),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFFE5F3EF),
                child: Icon(Icons.person, color: appGreen, size: 16),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: StreamBuilder<List<InventoryItem>>(
                stream: _inventory,
                builder: (context, inventorySnapshot) {
                  if (inventorySnapshot.hasError) {
                    return _InventoryError(
                        message: friendlyError(inventorySnapshot.error!));
                  }
                  if (!inventorySnapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(color: appGreen));
                  }
                  final items = inventorySnapshot.data!;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 15, 18, 22),
                    children: [
                      const Text('Inventaris RT',
                          style: TextStyle(
                              color: appInk,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 40,
                        child: FilledButton(
                          onPressed: () => _openLoanForm(items),
                          style: FilledButton.styleFrom(
                            backgroundColor: appGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11)),
                            textStyle: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                          child: const Text('Ajukan peminjaman'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('${items.length} barang terdata',
                          style: const TextStyle(
                              color: appInk,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      if (items.isEmpty)
                        const _InventoryInfoCard(
                            text: 'Belum ada inventaris RT.')
                      else
                        for (final item in items) ...[
                          _InventoryItemCard(item: item),
                          const SizedBox(height: 7),
                        ],
                      const SizedBox(height: 9),
                      const Text('Riwayat peminjaman saya',
                          style: TextStyle(
                              color: appInk,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      StreamBuilder<List<EquipmentLoanRequest>>(
                        stream: _myRequests,
                        builder: (context, requestSnapshot) {
                          if (requestSnapshot.hasError) {
                            return _InventoryInfoCard(
                                text: friendlyError(requestSnapshot.error!));
                          }
                          if (!requestSnapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator(
                                    color: appGreen));
                          }
                          final requests = requestSnapshot.data!;
                          if (requests.isEmpty) {
                            return const _InventoryInfoCard(
                                text: 'Belum ada pengajuan peminjaman.');
                          }
                          return Column(
                            children: requests
                                .map((request) => _CitizenLoanHistoryCard(
                                    request: request))
                                .toList(),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          height: 66,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFE5F3EF),
          selectedIndex: 1,
          onDestinationSelected: _navigateTab,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Beranda'),
            NavigationDestination(icon: Icon(Icons.grid_view_outlined), label: 'Layanan'),
            NavigationDestination(icon: Icon(Icons.access_time_outlined), label: 'Jadwal'),
            NavigationDestination(icon: Icon(Icons.account_circle_outlined), label: 'Profil'),
          ],
        ),
      );
}

class _LoanRequestForm extends StatefulWidget {
  final List<InventoryItem> items;
  const _LoanRequestForm({required this.items});

  @override
  State<_LoanRequestForm> createState() => _LoanRequestFormState();
}

class _LoanRequestFormState extends State<_LoanRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _purpose = TextEditingController();
  late InventoryItem _selectedItem;
  DateTime _loanDate = DateTime.now();
  DateTime _returnDate = DateTime.now().add(const Duration(days: 1));
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.items.first;
  }

  @override
  void dispose() {
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _chooseDate({required bool loanDate}) async {
    final current = loanDate ? _loanDate : _returnDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) {
      setState(() {
        if (loanDate) {
          _loanDate = selected;
          if (_returnDate.isBefore(selected)) _returnDate = selected;
        } else {
          _returnDate = selected;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_returnDate.isBefore(_loanDate)) {
      _message('Tanggal pengembalian harus setelah tanggal peminjaman.');
      return;
    }
    setState(() => _sending = true);
    try {
      await EquipmentLoanService.submit(
        item: _selectedItem,
        purpose: _purpose.text,
        loanDate: _loanDate,
        returnDate: _returnDate,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _message('Pengajuan gagal dikirim: ${friendlyError(error)}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: appBackground,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text('Pengajuan Pinjam'),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _label('Nama barang'),
                    DropdownButtonFormField<InventoryItem>(
                      value: _selectedItem,
                      decoration: _inputDecoration('Pilih barang'),
                      items: widget.items
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(
                                    '${item.name} · stok ${item.stock} unit'),
                              ))
                          .toList(),
                      onChanged: (item) {
                        if (item != null) setState(() => _selectedItem = item);
                      },
                    ),
                    const SizedBox(height: 13),
                    _label('Tujuan peminjaman'),
                    TextFormField(
                      controller: _purpose,
                      maxLines: 3,
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Isi tujuan peminjaman'
                          : null,
                      decoration: _inputDecoration('Contoh: acara kerja bakti'),
                    ),
                    const SizedBox(height: 13),
                    _label('Tanggal peminjaman'),
                    _DatePickerTile(
                        date: _loanDate,
                        onTap: () => _chooseDate(loanDate: true)),
                    const SizedBox(height: 13),
                    _label('Tanggal pengembalian'),
                    _DatePickerTile(
                        date: _returnDate,
                        onTap: () => _chooseDate(loanDate: false)),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 42,
                      child: FilledButton(
                        onPressed: _sending ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: appGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11)),
                        ),
                        child: Text(_sending ? 'Mengirim...' : 'Kirim pengajuan'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(text,
            style: const TextStyle(
                color: appMuted, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: appMuted, fontSize: 12),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: appBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: appBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: appGreen, width: 1.3)),
      );
}

class _DatePickerTile extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const _DatePickerTile({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.calendar_today_outlined, size: 15),
        label: Align(
            alignment: Alignment.centerLeft,
            child: Text('${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}')),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: appInk,
          backgroundColor: Colors.white,
          side: const BorderSide(color: appBorder),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
}

class _InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  const _InventoryItemCard({required this.item});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: appBorder),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(children: [
          const CircleAvatar(
            radius: 12,
            backgroundColor: Color(0xFFE5F3EF),
            child: Icon(Icons.inventory_2_outlined, color: appGreen, size: 13),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name,
                  style: const TextStyle(
                      color: appInk, fontSize: 10, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('Stok: ${item.stock} unit',
                  style: const TextStyle(color: appMuted, fontSize: 9)),
            ]),
          ),
          const Icon(Icons.more_vert, color: appMuted, size: 15),
        ]),
      );
}

class _CitizenLoanHistoryCard extends StatelessWidget {
  final EquipmentLoanRequest request;
  const _CitizenLoanHistoryCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final color = switch (request.status) {
      'approved' => appGreen,
      'rejected' => const Color(0xFFD95454),
      _ => const Color(0xFFCB8A19),
    };
    final status = switch (request.status) {
      'approved' => 'Disetujui',
      'rejected' => 'Ditolak',
      _ => 'Menunggu',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: appBorder),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(children: [
        const CircleAvatar(
          radius: 11,
          backgroundColor: Color(0xFFE5F3EF),
          child: Icon(Icons.inventory_2_outlined, color: appGreen, size: 12),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(request.itemName,
                style: const TextStyle(
                    color: appInk, fontSize: 10, fontWeight: FontWeight.w700)),
            Text('${_formatDate(request.loanDate)} – ${_formatDate(request.returnDate)}',
                style: const TextStyle(color: appMuted, fontSize: 9)),
            if (request.decisionDocumentPath != null)
              DecisionDocumentButton(path: request.decisionDocumentPath!),
          ]),
        ),
        Text(status,
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _InventoryInfoCard extends StatelessWidget {
  final String text;
  const _InventoryInfoCard({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: appBorder),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(text, style: const TextStyle(color: appMuted, fontSize: 10)),
      );
}

class _InventoryError extends StatelessWidget {
  final String message;
  const _InventoryError({required this.message});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: appMuted, fontSize: 12)),
        ),
      );
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
