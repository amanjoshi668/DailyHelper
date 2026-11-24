import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/ai_issue_parser.dart';
import '../services/auth_service.dart';
import '../services/i18n.dart';
import '../services/vault_storage.dart';
import '../widgets/top_notification_banner.dart';
import 'settings_screen.dart';
import 'upi_settle_screen.dart';
import 'worker_detail_screen.dart';

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> with WidgetsBindingObserver {
  int _custTabIndex = 0; // 0: Explore, 1: Bookings
  int _proTabIndex = 0; // 0: Jobs, 1: Rates & Khata

  String _selectedTrade = 'all';
  String _searchQuery = '';
  AiParseSuggestion? _aiSuggestion;
  String? _selectedWorkerId;

  final _searchCtrl = TextEditingController();
  final _visitFeeCtrl = TextEditingController();
  final _hourlyRateCtrl = TextEditingController();
  final _upiIdCtrl = TextEditingController();
  final _servicePinsCtrl = TextEditingController();
  String? _syncedProId;

  static const List<String> _tradeFilterIds = [
    'all',
    'electrician',
    'plumber',
    'carpenter',
    'appliance',
    'painter',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      VaultStorage.instance.refreshFromCloud();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    _visitFeeCtrl.dispose();
    _hourlyRateCtrl.dispose();
    _upiIdCtrl.dispose();
    _servicePinsCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    final suggestion = AiIssueParser.parseDeterministic(val);
    setState(() {
      _searchQuery = val;
      _aiSuggestion = suggestion;
      if (suggestion != null) {
        _selectedTrade = suggestion.trade;
      } else if (val.trim().isEmpty) {
        _selectedTrade = 'all';
      }
    });

    if (val.trim().split(RegExp(r'\s+')).length >= 10) {
      AiIssueParser.parseHybrid(val).then((res) {
        if (!mounted || _searchCtrl.text != val || res == null) return;
        setState(() {
          _aiSuggestion = res;
          _selectedTrade = res.trade;
        });
      });
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _searchQuery = '';
      _aiSuggestion = null;
      _selectedTrade = 'all';
    });
  }

  Future<void> _dialPhone(String phone, String name) async {
    final clean = phone.replaceAll(' ', '');
    final uri = Uri.parse('tel:$clean');
    try {
      final launched = await launchUrl(uri);
      if (!launched) {
        await VaultStorage.instance.pushTopNotification(
          title: 'Calling $name',
          body: phone,
        );
      }
    } catch (_) {
      await VaultStorage.instance.pushTopNotification(
        title: 'Calling $name',
        body: phone,
      );
    }
  }

  Future<void> _showPinSelectorDialog(BuildContext context) async {
    final vault = VaultStorage.instance;
    final ctrl = TextEditingController(text: vault.pinCode);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select PIN Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final pin in ['560034', '110001', '400050'])
                  ActionChip(
                    label: Text('📍 $pin'),
                    onPressed: () {
                      vault.setPinCode(pin);
                      Navigator.of(ctx).pop();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('pin_dialog_input'),
              controller: ctrl,
              maxLength: 6,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '6-digit PIN Code',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('pin_dialog_apply_btn'),
            onPressed: () {
              final v = ctrl.text.trim();
              if (RegExp(r'^\d{6}$').hasMatch(v)) {
                vault.setPinCode(v);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatarButton(BuildContext context, AppUser user, String pageContext) {
    final theme = Theme.of(context);
    return InkWell(
      key: const Key('header_user_icon_btn'),
      customBorder: const CircleBorder(),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SettingsScreen(pageContext: pageContext),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: !user.isGuest
            ? CircleAvatar(
                radius: 17,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  user.initials,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              )
            : Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.person_outline, size: 20),
              ),
      ),
    );
  }

  // --- Customer Views (Explore + Bookings ONLY — Zero Khata!) ---
  Widget _buildCustomerExploreList(BuildContext context, bool isSplitView) {
    final vault = VaultStorage.instance;
    final lang = vault.lang;
    final theme = Theme.of(context);
    final tradeOnline = vault.workers.where((w) {
      if (!w.isOnline) return false;
      if (_selectedTrade != 'all' && w.trade != _selectedTrade) return false;
      return true;
    }).toList();

    final exactPin = tradeOnline.where((w) => w.servicePins.contains(vault.pinCode)).toList();
    final filtered = exactPin.isNotEmpty ? exactPin : tradeOnline;
    final showingNearbyFallback = exactPin.isEmpty && tradeOnline.isNotEmpty;

    return RefreshIndicator(
      onRefresh: vault.refreshFromCloud,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
        // Clean Single Search Input (Zero Guest Banner Clutter!)
        TextField(
          key: const Key('explore_search_field'),
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: AppStrings.tr(lang, 'searchHint'),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _clearSearch,
                  )
                : null,
            filled: true,
            fillColor: theme.colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
        ),

        if (_aiSuggestion != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Matched: ${AppStrings.tradeLabel(lang, _aiSuggestion!.trade)} (${_aiSuggestion!.tierLabel})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: _clearSearch,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Reset'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),

        // Clean Category Pills
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _tradeFilterIds.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final id = _tradeFilterIds[i];
              final selected = _selectedTrade == id;
              return ChoiceChip(
                key: Key('trade_chip_$id'),
                label: Text(AppStrings.tradeLabel(lang, id)),
                selected: selected,
                onSelected: (_) => setState(() => _selectedTrade = id),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        if (showingNearbyFallback) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 2),
            child: Text(
              'Showing nearby available helpers for PIN ${vault.pinCode}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else
          const SizedBox(height: 4),

        // Spacious, Uncluttered Worker Cards
        for (final w in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              key: Key('worker_card_${w.id}'),
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openWorkerForBooking(context, w, isSplitView),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isSplitView && (_selectedWorkerId ?? filtered.first.id) == w.id)
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 21,
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
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (w.verified) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.verified,
                                      size: 15,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${AppStrings.tradeLabel(lang, w.trade)} · ${w.experienceYears} yrs',
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
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '₹${w.visitFeeInr} ${AppStrings.tr(lang, 'visit')} · ₹${w.hourlyRateInr}/hr',
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          key: Key('book_worker_btn_${w.id}'),
                          onPressed: () => _openWorkerForBooking(context, w, isSplitView),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: Text(AppStrings.tr(lang, 'book')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openWorkerForBooking(BuildContext context, WorkerProfile worker, bool isSplitView) {
    if (isSplitView) {
      setState(() => _selectedWorkerId = worker.id);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkerDetailScreen(
          worker: worker,
          initialIssueNote: _aiSuggestion?.summaryNote ?? _searchQuery,
          onBookingConfirmed: () {
            if (mounted) setState(() => _custTabIndex = 1);
          },
        ),
      ),
    );
  }

  Widget _buildCustomerBookingsList(BuildContext context) {
    final vault = VaultStorage.instance;
    final lang = vault.lang;
    final theme = Theme.of(context);
    final items = vault.bookings;

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppStrings.tr(lang, 'noBookingsYet'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: vault.refreshFromCloud,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final b = items[i];
          return Container(
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
                    Expanded(
                      child: Text(
                        b.localizedWorkerName(lang),
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        b.status.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppStrings.tradeLabel(lang, b.trade)} · ${b.bookingDate}, ${b.slotWindow}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(b.issueNote, style: theme.textTheme.bodyMedium),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1),
                ),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      b.finalAmountInr != null
                          ? 'Paid ₹${b.finalAmountInr} (${b.paymentMethod ?? 'Cash'})'
                          : '₹${b.visitFeeInr} ${AppStrings.tr(lang, 'visit')}',
                      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (b.status == 'requested')
                      OutlinedButton(
                        key: Key('cust_cancel_btn_${b.id}'),
                        onPressed: () => vault.cancelBooking(b.id),
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        child: Text(AppStrings.tr(lang, 'cancel')),
                      )
                    else if (b.status == 'confirmed' || b.status == 'in_progress')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _dialPhone(b.workerPhone, b.workerNameEn),
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                            icon: const Icon(Icons.phone_outlined, size: 16),
                            label: Text(AppStrings.tr(lang, 'call')),
                          ),
                          if (b.status == 'confirmed') ...[
                            const SizedBox(width: 6),
                            TextButton(
                              key: Key('cust_cancel_btn_${b.id}'),
                              onPressed: () => vault.cancelBooking(b.id),
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              child: Text(AppStrings.tr(lang, 'cancel')),
                            ),
                          ],
                        ],
                      )
                    else if (b.status == 'completed')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...List.generate(5, (starIdx) {
                            final st = starIdx + 1;
                            final active = (b.customerRating ?? 0) >= st;
                            return InkWell(
                              onTap: () => vault.rateCompletedBooking(b.id, st),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Icon(
                                  active ? Icons.star : Icons.star_border,
                                  size: 20,
                                  color: active
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          }),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            key: Key('cust_rebook_btn_${b.id}'),
                            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: () {
                              final w = vault.workers.firstWhere(
                                (x) => x.id == b.workerId,
                                orElse: () => vault.workers.first,
                              );
                              _openWorkerForBooking(context, w, false);
                            },
                            child: Text(AppStrings.tr(lang, 'bookAgain')),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Professional Views (Jobs + Rates & Khata ONLY — Zero Explore!) ---
  Widget _buildProfessionalJobsView(BuildContext context) {
    final vault = VaultStorage.instance;
    final lang = vault.lang;
    final theme = Theme.of(context);
    final pro = vault.currentProfessionalProfile;
    final requests = vault.bookings.where((b) => b.status == 'requested').toList();
    final schedule = vault.bookings
        .where((b) => b.status == 'confirmed' || b.status == 'in_progress')
        .toList();

    return RefreshIndicator(
      onRefresh: vault.refreshFromCloud,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
        // Clean Online Availability Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pro.localizedName(lang),
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      AppStrings.tr(lang, 'availableBookings'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                key: const Key('pro_online_switch'),
                value: pro.isOnline,
                onChanged: (v) => vault.updateProfessionalProfile(isOnline: v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // New Requests
        Text(
          '${AppStrings.tr(lang, 'newRequests')} (${requests.length})',
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (requests.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Text(
              AppStrings.tr(lang, 'noPendingRequests'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final b in requests)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${b.bookingDate} · ${b.slotWindow}',
                          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '₹${b.visitFeeInr} ${AppStrings.tr(lang, 'visit')}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${b.locality} (PIN ${b.pinCode})',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    b.issueNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          key: Key('pro_accept_btn_${b.id}'),
                          onPressed: () => vault.updateJobStatus(b.id, 'confirmed'),
                          child: Text(AppStrings.tr(lang, 'accept')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          key: Key('pro_decline_btn_${b.id}'),
                          onPressed: () => vault.updateJobStatus(b.id, 'declined'),
                          child: Text(AppStrings.tr(lang, 'decline')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

        const SizedBox(height: 18),

        // Upcoming Schedule
        Text(
          '${AppStrings.tr(lang, 'upcomingSchedule')} (${schedule.length})',
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (schedule.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Text(
              AppStrings.tr(lang, 'noUpcomingJobs'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final b in schedule)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          b.customerName,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(b.slotWindow, style: theme.textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    b.fullAddress,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _dialPhone(b.customerPhone, b.customerName),
                        icon: const Icon(Icons.phone_outlined, size: 16),
                        label: Text(AppStrings.tr(lang, 'call')),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: b.status == 'confirmed'
                            ? FilledButton(
                                key: Key('pro_start_btn_${b.id}'),
                                onPressed: () => vault.updateJobStatus(b.id, 'in_progress'),
                                child: Text(AppStrings.tr(lang, 'startWork')),
                              )
                            : FilledButton(
                                key: Key('pro_complete_btn_${b.id}'),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => UpiSettleScreen(booking: b),
                                    ),
                                  );
                                },
                                child: Text(AppStrings.tr(lang, 'completeCollect')),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfessionalRatesAndKhataView(BuildContext context) {
    final vault = VaultStorage.instance;
    final lang = vault.lang;
    final theme = Theme.of(context);
    final pro = vault.currentProfessionalProfile;

    if (_syncedProId != pro.id) {
      _syncedProId = pro.id;
      _visitFeeCtrl.text = pro.visitFeeInr.toString();
      _hourlyRateCtrl.text = pro.hourlyRateInr.toString();
      _upiIdCtrl.text = pro.upiId;
      _servicePinsCtrl.text = pro.servicePins.join(', ');
    }

    void saveRateCard() {
      final visit = int.tryParse(_visitFeeCtrl.text.trim()) ?? pro.visitFeeInr;
      final hourly = int.tryParse(_hourlyRateCtrl.text.trim()) ?? pro.hourlyRateInr;
      final upi = _upiIdCtrl.text.trim();
      final pins = _servicePinsCtrl.text
          .split(RegExp(r'[\s,]+'))
          .map((s) => s.trim())
          .where((s) => RegExp(r'^\d{6}$').hasMatch(s))
          .toList();
      vault.updateProfessionalProfile(
        visitFeeInr: visit,
        hourlyRateInr: hourly,
        upiId: upi.isEmpty ? pro.upiId : upi,
        servicePins: pins.isEmpty ? pro.servicePins : pins,
        showSavedNotif: true,
      );
    }

    return RefreshIndicator(
      onRefresh: vault.refreshFromCloud,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
        // Clean Khata Summary Card (No Export Button on Home — tucked in Settings!)
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
              Text(
                AppStrings.tr(lang, 'khataSummary'),
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: AppStrings.tr(lang, 'today'),
                      value: '₹${pro.khataTodayInr}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatTile(
                      label: AppStrings.tr(lang, 'thisMonth'),
                      value: '₹${pro.khataMonthInr}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatTile(
                      label: AppStrings.tr(lang, 'completed'),
                      value: '${pro.jobsCompleted}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Editable Rates & Slots Card
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
              Text(
                AppStrings.tr(lang, 'ratesAndSlots'),
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('pro_visit_fee_field'),
                      controller: _visitFeeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: '${AppStrings.tr(lang, 'visitFee')} (₹)',
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (v) {
                        final parsed = int.tryParse(v.trim());
                        if (parsed != null) {
                          vault.updateProfessionalProfile(visitFeeInr: parsed);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const Key('pro_hourly_rate_field'),
                      controller: _hourlyRateCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: '${AppStrings.tr(lang, 'hourlyRate')} (₹)',
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (v) {
                        final parsed = int.tryParse(v.trim());
                        if (parsed != null) {
                          vault.updateProfessionalProfile(hourlyRateInr: parsed);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('pro_upi_field'),
                controller: _upiIdCtrl,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: AppStrings.tr(lang, 'upiId'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('pro_pins_field'),
                controller: _servicePinsCtrl,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: AppStrings.tr(lang, 'servicePins'),
                  hintText: '560034, 560095',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('pro_save_rates_btn'),
                  onPressed: saveRateCard,
                  child: Text(AppStrings.tr(lang, 'saveChanges')),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                AppStrings.tr(lang, 'availableSlots'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: VaultStorage.standardSlots.map((slot) {
                  final blocked = pro.blockedSlots.contains(slot);
                  return FilterChip(
                    label: Text(slot),
                    selected: !blocked,
                    onSelected: (_) {
                      final next = List<String>.from(pro.blockedSlots);
                      if (blocked) {
                        next.remove(slot);
                      } else {
                        next.add(slot);
                      }
                      vault.updateProfessionalProfile(blockedSlots: next);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AuthService.instance, VaultStorage.instance]),
      builder: (context, _) {
        final auth = AuthService.instance;
        final vault = VaultStorage.instance;
        final user = auth.currentUser;
        final lang = vault.lang;
        final isPro = auth.isLoggedIn && user.role == UserRole.professional;
        final topNotif = vault.activeTopNotification;

        final pageContext = isPro
            ? (_proTabIndex == 0 ? 'Jobs' : 'Rates & Khata')
            : (_custTabIndex == 0 ? 'Explore' : 'Bookings');

        return LayoutBuilder(
          builder: (context, constraints) {
            final isSplitView = constraints.maxWidth >= 900;

            Widget mainBody;
            if (isSplitView) {
              if (isPro) {
                mainBody = Row(
                  children: [
                    Expanded(flex: 7, child: _buildProfessionalJobsView(context)),
                    const VerticalDivider(width: 1),
                    Expanded(flex: 5, child: _buildProfessionalRatesAndKhataView(context)),
                  ],
                );
              } else {
                final selectedWorker = vault.workers.firstWhere(
                  (w) => w.id == _selectedWorkerId,
                  orElse: () => vault.workers.first,
                );
                mainBody = Row(
                  children: [
                    Expanded(
                      flex: 7,
                      child: _custTabIndex == 0
                          ? _buildCustomerExploreList(context, true)
                          : _buildCustomerBookingsList(context),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 5,
                      child: WorkerDetailPane(
                        worker: selectedWorker,
                        initialIssueNote: _aiSuggestion?.summaryNote ?? _searchQuery,
                        onBookingConfirmed: () => setState(() => _custTabIndex = 1),
                      ),
                    ),
                  ],
                );
              }
            } else {
              if (isPro) {
                mainBody = _proTabIndex == 0
                    ? _buildProfessionalJobsView(context)
                    : _buildProfessionalRatesAndKhataView(context);
              } else {
                mainBody = _custTabIndex == 0
                    ? _buildCustomerExploreList(context, false)
                    : _buildCustomerBookingsList(context);
              }
            }

            final pendingProRequests =
                vault.bookings.where((b) => b.status == 'requested').length;

            return Scaffold(
              appBar: AppBar(
                titleSpacing: 16,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.tr(lang, 'appName'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                    InkWell(
                      key: const Key('header_pin_btn'),
                      onTap: () => _showPinSelectorDialog(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '📍 ${vault.pinCode} ▾',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  if (isSplitView && !isPro) ...[
                    TextButton(
                      onPressed: () => setState(() => _custTabIndex = 0),
                      child: Text(AppStrings.tr(lang, 'explore')),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _custTabIndex = 1),
                      child: Text('${AppStrings.tr(lang, 'bookings')} (${vault.bookings.length})'),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildUserAvatarButton(context, user, pageContext),
                  ),
                ],
              ),
              body: Stack(
                children: [
                  Positioned.fill(child: mainBody),
                  if (topNotif != null)
                    Positioned(
                      top: 10,
                      left: 12,
                      right: 12,
                      child: TopNotificationBanner(
                        notification: topNotif,
                        onDismiss: () => vault.dismissTopNotification(topNotif.id),
                      ),
                    ),
                ],
              ),
              bottomNavigationBar: isSplitView
                  ? null
                  : isPro
                      ? NavigationBar(
                          selectedIndex: _proTabIndex,
                          onDestinationSelected: (idx) => setState(() => _proTabIndex = idx),
                          destinations: [
                            NavigationDestination(
                              key: const Key('pro_tab_jobs'),
                              icon: Badge(
                                isLabelVisible: pendingProRequests > 0,
                                label: Text('$pendingProRequests'),
                                child: const Icon(Icons.assignment_outlined),
                              ),
                              selectedIcon: const Icon(Icons.assignment),
                              label: AppStrings.tr(lang, 'jobs'),
                            ),
                            NavigationDestination(
                              key: const Key('pro_tab_khata'),
                              icon: const Icon(Icons.currency_rupee_outlined),
                              selectedIcon: const Icon(Icons.currency_rupee),
                              label: AppStrings.tr(lang, 'ratesKhata'),
                            ),
                          ],
                        )
                      : NavigationBar(
                          selectedIndex: _custTabIndex,
                          onDestinationSelected: (idx) => setState(() => _custTabIndex = idx),
                          destinations: [
                            NavigationDestination(
                              key: const Key('cust_tab_explore'),
                              icon: const Icon(Icons.search_outlined),
                              selectedIcon: const Icon(Icons.search),
                              label: AppStrings.tr(lang, 'explore'),
                            ),
                            NavigationDestination(
                              key: const Key('cust_tab_bookings'),
                              icon: Badge(
                                isLabelVisible: vault.bookings.isNotEmpty,
                                label: Text('${vault.bookings.length}'),
                                child: const Icon(Icons.calendar_today_outlined),
                              ),
                              selectedIcon: const Icon(Icons.calendar_today),
                              label: AppStrings.tr(lang, 'bookings'),
                            ),
                          ],
                        ),
            );
          },
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
