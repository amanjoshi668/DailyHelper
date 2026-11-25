import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/i18n.dart';
import '../services/vault_storage.dart';
import '../widgets/upi_qr_painter.dart';

class UpiSettleScreen extends StatefulWidget {
  final BookingRecord booking;

  const UpiSettleScreen({
    super.key,
    required this.booking,
  });

  @override
  State<UpiSettleScreen> createState() => _UpiSettleScreenState();
}

class _UpiSettleScreenState extends State<UpiSettleScreen> {
  late TextEditingController _amountCtrl;
  String _method = 'UPI';
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.booking.visitFeeInr > 350 ? widget.booking.visitFeeInr : 350;
    _amountCtrl = TextEditingController(text: initial.toString());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final amt = int.tryParse(_amountCtrl.text.trim()) ?? widget.booking.visitFeeInr;
    await VaultStorage.instance.updateJobStatus(
      widget.booking.id,
      'completed',
      finalAmountInr: amt,
      paymentMethod: _method,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _copyUpi(String upiId) async {
    await Clipboard.setData(ClipboardData(text: upiId));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  Future<void> _openUpiApp(String upiUri) async {
    try {
      await launchUrl(Uri.parse(upiUri), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final vault = VaultStorage.instance;
    final lang = vault.lang;
    final pro = vault.currentProfessionalProfile;
    final theme = Theme.of(context);
    final amountText = _amountCtrl.text.trim().isEmpty ? '0' : _amountCtrl.text.trim();
    final encodedName = Uri.encodeComponent(pro.nameEn);
    final encodedNote = Uri.encodeComponent('DailyHelper ${widget.booking.id}');
    final upiPayload =
        'upi://pay?pa=${Uri.encodeComponent(pro.upiId)}&pn=$encodedName&am=$amountText&cu=INR&tn=$encodedNote';

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(lang, 'collectPayment')),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              key: const Key('settle_amount_field'),
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppStrings.tr(lang, 'finalAgreedAmount'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    key: const Key('settle_method_upi_chip'),
                    label: const Center(child: Text('UPI QR')),
                    selected: _method == 'UPI',
                    onSelected: (_) => setState(() => _method = 'UPI'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    key: const Key('settle_method_cash_chip'),
                    label: Center(child: Text(AppStrings.tr(lang, 'cash'))),
                    selected: _method == 'Cash',
                    onSelected: (_) => setState(() => _method = 'Cash'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_method == 'UPI') ...[
              Center(child: UpiQrWidget(data: upiPayload, size: 172)),
              const SizedBox(height: 12),
              Text(
                pro.upiId,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.tr(lang, 'directToBankZeroFee'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('copy_upi_id_btn'),
                    onPressed: () => _copyUpi(pro.upiId),
                    icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
                    label: Text(
                      _copied ? AppStrings.tr(lang, 'upiCopied') : AppStrings.tr(lang, 'copyUpiId'),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('open_upi_app_btn'),
                    onPressed: () => _openUpiApp(upiPayload),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(AppStrings.tr(lang, 'openUpiApp')),
                  ),
                ],
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Text(
                  'Collect ₹$amountText in cash directly from ${widget.booking.customerName}.',
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 24),
            FilledButton(
              key: const Key('confirm_payment_received_btn'),
              onPressed: _complete,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(AppStrings.tr(lang, 'paymentReceivedComplete')),
            ),
          ],
        ),
      ),
    );
  }
}
