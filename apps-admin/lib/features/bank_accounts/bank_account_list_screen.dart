import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../core/api/api_exception.dart';
import '../../models/bank_account.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';

const _popularBanks = ['BCA', 'BRI', 'Mandiri', 'BNI', 'BSI', 'BTN', 'CIMB Niaga', 'Permata', 'SeaBank', 'Bank Jago'];
const _popularEwallets = ['DANA', 'GoPay', 'OVO', 'ShopeePay', 'LinkAja', 'i.saku'];

class BankAccountListScreen extends ConsumerStatefulWidget {
  const BankAccountListScreen({super.key});

  @override
  ConsumerState<BankAccountListScreen> createState() => _BankAccountListScreenState();
}

class _BankAccountListScreenState extends ConsumerState<BankAccountListScreen> {
  String _filterType = 'all';

  Future<void> _openForm([BankAccount? account]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BankAccountForm(
        account: account,
        defaultType: _filterType == 'ewallet' ? 'ewallet' : 'bank_transfer',
      ),
    );
    if (saved == true) {
      ref.invalidate(bankAccountsProvider);
      if (mounted) {
        showMessage(context, account == null ? 'Rekening/E-Wallet ditambahkan.' : 'Rekening/E-Wallet diperbarui.');
      }
    }
  }

  Future<void> _toggle(BankAccount account) async {
    try {
      await ref.read(bankAccountServiceProvider).toggle(account.id);
      ref.invalidate(bankAccountsProvider);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete(BankAccount account) async {
    final ok = await confirm(
      context,
      title: 'Hapus ${account.isEwallet ? 'E-Wallet' : 'Rekening Bank'}',
      message: 'Hapus "${account.displayName}" (${account.accountNumber ?? '-'})?',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(bankAccountServiceProvider).delete(account.id);
      ref.invalidate(bankAccountsProvider);
      if (mounted) showMessage(context, '${account.displayName} dihapus.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _copyNumber(BankAccount account) async {
    final number = account.accountNumber;
    if (number == null || number.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: number));
    if (mounted) showMessage(context, 'Nomor ${account.displayName} disalin.');
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(bankAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bank & E-Wallet')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(bankAccountsProvider.future),
        child: accounts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorView(message: errorMessage(e), onRetry: () => ref.invalidate(bankAccountsProvider)),
            ],
          ),
          data: (items) {
            final bankCount = items.where((x) => !x.isEwallet).length;
            final ewalletCount = items.where((x) => x.isEwallet).length;
            final visible = items.where((x) => _filterType == 'all' || x.type == _filterType).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                Text(
                  'Daftar rekening bank dan e-wallet milik aplikasi/admin untuk pembayaran checkout dan top up manual dengan bukti transfer.',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('Semua (${items.length})'),
                      selected: _filterType == 'all',
                      onSelected: (_) => setState(() => _filterType = 'all'),
                    ),
                    ChoiceChip(
                      label: Text('Bank ($bankCount)'),
                      selected: _filterType == 'bank_transfer',
                      onSelected: (_) => setState(() => _filterType = 'bank_transfer'),
                    ),
                    ChoiceChip(
                      label: Text('E-Wallet ($ewalletCount)'),
                      selected: _filterType == 'ewallet',
                      onSelected: (_) => setState(() => _filterType = 'ewallet'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: EmptyView(
                      icon: Icons.account_balance_outlined,
                      text: 'Belum ada rekening bank atau e-wallet.',
                    ),
                  )
                else
                  for (final account in visible)
                    _BankAccountCard(
                      account: account,
                      onTap: () => _openForm(account),
                      onCopy: () => _copyNumber(account),
                      onToggle: () => _toggle(account),
                      onDelete: () => _delete(account),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BankAccountCard extends StatelessWidget {
  const _BankAccountCard({
    required this.account,
    required this.onTap,
    required this.onCopy,
    required this.onToggle,
    required this.onDelete,
  });

  final BankAccount account;
  final VoidCallback onTap;
  final VoidCallback onCopy;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final badgeColor = account.isEwallet ? AppColors.accent : AppColors.info;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    account.isEwallet ? Icons.account_balance_wallet_outlined : Icons.account_balance_outlined,
                    color: badgeColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            account.displayName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          StatusBadge(
                            label: account.isEwallet ? 'E-Wallet' : 'Bank',
                            color: badgeColor,
                          ),
                        ],
                      ),
                      if (account.accountNumber != null && account.accountNumber!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                account.accountNumber!,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: onCopy,
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.copy_rounded, size: 15, color: AppColors.mutedForeground),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (account.accountHolderName != null && account.accountHolderName!.isNotEmpty)
                        Text(
                          'a.n. ${account.accountHolderName}',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground),
                        ),
                      if (account.description != null && account.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          account.description!,
                          style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                        ),
                      ],
                      if (account.instructions != null && account.instructions!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          account.instructions!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.mutedForeground),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(value: account.isEnabled, onChanged: (_) => onToggle()),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.destructive),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BankAccountForm extends ConsumerStatefulWidget {
  const _BankAccountForm({this.account, required this.defaultType});

  final BankAccount? account;
  final String defaultType;

  @override
  ConsumerState<_BankAccountForm> createState() => _BankAccountFormState();
}

class _BankAccountFormState extends ConsumerState<_BankAccountForm> {
  late String _type = widget.account?.type ?? widget.defaultType;
  late final _bankName = TextEditingController(text: widget.account?.displayName);
  late final _accountNumber = TextEditingController(text: widget.account?.accountNumber);
  late final _accountHolder = TextEditingController(text: widget.account?.accountHolderName);
  late final _description = TextEditingController(text: widget.account?.description);
  late final _instructions = TextEditingController(text: widget.account?.instructions);
  late bool _isEnabled = widget.account?.isEnabled ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _bankName.dispose();
    _accountNumber.dispose();
    _accountHolder.dispose();
    _description.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final bankName = _bankName.text.trim();
    final accountNumber = _accountNumber.text.trim();
    final accountHolder = _accountHolder.text.trim();

    if (bankName.isEmpty) {
      setState(() => _error = 'Nama bank atau e-wallet wajib diisi.');
      return;
    }
    if (accountNumber.isEmpty) {
      setState(() => _error = 'Nomor rekening atau nomor e-wallet wajib diisi.');
      return;
    }
    if (accountHolder.isEmpty) {
      setState(() => _error = 'Atas nama pemilik wajib diisi.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(bankAccountServiceProvider).save(
        BankAccountInput(
          type: _type,
          bankName: bankName,
          accountNumber: accountNumber,
          accountHolderName: accountHolder,
          description: _description.text,
          instructions: _instructions.text,
          isEnabled: _isEnabled,
        ),
        id: widget.account?.id,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEwallet = _type == 'ewallet';
    final suggestions = isEwallet ? _popularEwallets : _popularBanks;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.account == null ? 'Tambah Bank / E-Wallet' : 'Ubah Bank / E-Wallet',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: 'bank_transfer',
                  icon: Icon(Icons.account_balance_outlined, size: 18),
                  label: Text('Rekening Bank'),
                ),
                ButtonSegment(
                  value: 'ewallet',
                  icon: Icon(Icons.account_balance_wallet_outlined, size: 18),
                  label: Text('E-Wallet'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in suggestions)
                  ActionChip(
                    label: Text(name, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _bankName.text = name),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bankName,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: isEwallet ? 'Nama E-Wallet *' : 'Nama Bank *',
                hintText: isEwallet ? 'mis. DANA, GoPay, OVO' : 'mis. BCA, BRI, Mandiri',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _accountNumber,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: isEwallet ? 'Nomor HP / E-Wallet *' : 'Nomor Rekening *',
                hintText: isEwallet ? 'mis. 081234567890' : 'mis. 1234567890',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _accountHolder,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Atas Nama (Pemilik) *',
                hintText: 'mis. PT Inovasi Online',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Deskripsi Singkat (opsional)',
                hintText: 'mis. Transfer manual & kirim bukti ke admin',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instructions,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                labelText: 'Instruksi Pembayaran (opsional)',
                hintText: 'mis. Transfer sesuai nominal tagihan lalu kirim foto bukti transfer ke admin.',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktif'),
              subtitle: const Text('Tampilkan di checkout dan top up manual'),
              value: _isEnabled,
              onChanged: (v) => setState(() => _isEnabled = v),
            ),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: AppColors.destructive)),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}

