import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/i18n.dart';
import '../services/vault_storage.dart';
import 'login_screen.dart';

class WorkerDetailScreen extends StatelessWidget {
  final WorkerProfile worker;
  final String initialIssueNote;
  final VoidCallback onBookingConfirmed;

  const WorkerDetailScreen({
    super.key,
    required this.worker,
    this.initialIssueNote = '',
    required this.onBookingConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    final lang = VaultStorage.instance.lang;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(lang, 'bookAppointment')),
        centerTitle: false,
      ),
      body: SafeArea(
        child: WorkerDetailPane(
          worker: worker,
          initialIssueNote: initialIssueNote,
          onBookingConfirmed: () {
            Navigator.of(context).pop();
            onBookingConfirmed();
          },
        ),
      ),
    );
  }
}

class WorkerDetailPane extends StatefulWidget {
  final WorkerProfile worker;
  final String initialIssueNote;
  final VoidCallback onBookingConfirmed;

  const WorkerDetailPane({
    super.key,
    required this.worker,
    this.initialIssueNote = '',
    required this.onBookingConfirmed,
  });

  @override
  State<WorkerDetailPane> createState() => _WorkerDetailPaneState();
}

class _WorkerDetailPaneState extends State<WorkerDetailPane> {
  late String _selectedDate;
  late String _selectedSlot;
  late TextEditingController _noteCtrl;
  late TextEditingController _addrCtrl;

  @override
  void initState() {
    super.initState();
    final dates = VaultStorage.instance.upcomingDateChoices;
    _selectedDate = dates.first['id']!;
    _selectedSlot = _firstOpenSlot(widget.worker);
    _noteCtrl = TextEditingController(text: widget.initialIssueNote);
    _addrCtrl = TextEditingController(text: VaultStorage.instance.savedAddress);
  }

  @override
  void didUpdateWidget(covariant WorkerDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.worker.id != widget.worker.id) {
      _selectedSlot = _firstOpenSlot(widget.worker);
    }
    if (oldWidget.initialIssueNote != widget.initialIssueNote &&
        widget.initialIssueNote.isNotEmpty) {
      _noteCtrl.text = widget.initialIssueNote;
    }
  }

  String _firstOpenSlot(WorkerProfile w) {
    for (final s in VaultStorage.standardSlots) {
      if (!w.blockedSlots.contains(s)) return s;
    }
    return VaultStorage.standardSlots.first;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmBooking() async {
    if (!AuthService.instance.isLoggedIn) {
      final signedIn = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            initialRole: UserRole.customer,
            pendingWorkerName: widget.worker.nameEn,
            lockToCustomerForBooking: true,
          ),
        ),
      );
      if (signedIn != true || !mounted || !AuthService.instance.isLoggedIn) {
        return;
      }
    }

    if (AuthService.instance.currentUser.role != UserRole.customer) {
      return;
    }

    await VaultStorage.instance.createBooking(
      worker: widget.worker,
      dateStr: _selectedDate,
      slotWindow: _selectedSlot,
      issueNote: _noteCtrl.text,
      fullAddress: _addrCtrl.text,
    );
    if (!mounted) return;
    widget.onBookingConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final vault = VaultStorage.instance;
    final lang = vault.lang;
    final theme = Theme.of(context);
    final w = widget.worker;
    final dates = vault.upcomingDateChoices;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      child: Text(
                        w.initials,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  w.localizedName(lang),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (w.verified) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.verified, size: 16, color: theme.colorScheme.primary),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${AppStrings.tradeLabel(lang, w.trade)} · ${w.experienceYears} yrs · ${w.languages}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '★ ${w.ratingAvg.toStringAsFixed(1)}',
                      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      key: Key('save_helper_btn_${w.id}'),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        vault.isWorkerSaved(w.id) ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: vault.isWorkerSaved(w.id)
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () {
                        vault.toggleSavedWorker(w.id);
                        setState(() {});
                      },
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(
                      '${AppStrings.tr(lang, 'visitFee')}: ₹${w.visitFeeInr}',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${AppStrings.tr(lang, 'hourlyRate')}: ₹${w.hourlyRateInr}/hr',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${AppStrings.tr(lang, 'dailyRate')}: ₹${w.dailyRateInr}',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (w.customRates.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.tr(lang, 'serviceRateCard'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final rate in w.customRates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              rate.service,
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '₹${rate.priceInr}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: w
                      .localizedSkills(lang)
                      .map(
                        (s) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(s, style: theme.textTheme.bodySmall),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            AppStrings.tr(lang, 'selectDate'),
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: dates.asMap().entries.map((entry) {
              final idx = entry.key;
              final d = entry.value;
              final id = d['id']!;
              final label = idx == 0
                  ? AppStrings.tr(lang, 'today')
                  : (idx == 1 ? AppStrings.tr(lang, 'tomorrow') : d['en']!);
              return ChoiceChip(
                label: Text(label),
                selected: _selectedDate == id,
                onSelected: (_) => setState(() => _selectedDate = id),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          Text(
            AppStrings.tr(lang, 'selectSlot'),
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: VaultStorage.standardSlots.map((slot) {
              final blocked = w.blockedSlots.contains(slot);
              return ChoiceChip(
                label: Text(slot),
                selected: _selectedSlot == slot && !blocked,
                onSelected: blocked ? null : (_) => setState(() => _selectedSlot = slot),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          TextField(
            key: const Key('booking_issue_note_field'),
            controller: _noteCtrl,
            decoration: InputDecoration(
              labelText: AppStrings.tr(lang, 'issueNoteHint'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('booking_address_field'),
            controller: _addrCtrl,
            decoration: InputDecoration(
              labelText: '${AppStrings.tr(lang, 'addressHint')} (PIN ${vault.pinCode})',
              hintText: 'e.g., Flat 402, Palm Grove, near 4th Block',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.tr(lang, 'visitGuarantee'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          FilledButton(
            key: const Key('confirm_booking_btn'),
            onPressed: _confirmBooking,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              '${AppStrings.tr(lang, 'confirmBooking')} · ₹${w.visitFeeInr} ${AppStrings.tr(lang, 'visit')}',
            ),
          ),
        ],
      ),
    );
  }
}
