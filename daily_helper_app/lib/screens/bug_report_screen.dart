import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/gcp_backend_service.dart';
import '../services/i18n.dart';
import '../services/vault_storage.dart';

class BugReportScreen extends StatefulWidget {
  final String pageContext;

  const BugReportScreen({
    super.key,
    required this.pageContext,
  });

  @override
  State<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends State<BugReportScreen> {
  final _descCtrl = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  List<BugReportRecord> _openBugs = [];

  @override
  void initState() {
    super.initState();
    _refreshOpenBugs();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshOpenBugs() async {
    setState(() => _loading = true);
    final email = AuthService.instance.currentUser.email;
    final items = await GcpBackendService.instance.getOpenBugReportsForCurrentUser(email);
    if (!mounted) return;
    setState(() {
      _openBugs = items;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    final text = _descCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _submitting = true);
    final email = AuthService.instance.currentUser.email;
    await GcpBackendService.instance.submitBugReport(
      description: text,
      pageContext: widget.pageContext,
      userEmail: email,
    );
    _descCtrl.clear();
    await VaultStorage.instance.pushTopNotification(
      title: 'Bug Report Submitted',
      body: 'Logged to database. It will automatically disappear once fixed.',
    );
    await _refreshOpenBugs();
    if (!mounted) return;
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final lang = VaultStorage.instance.lang;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(lang, 'reportBug')),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Context: ${widget.pageContext} · v${GcpBackendService.appVersion}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('bug_description_field'),
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: AppStrings.tr(lang, 'describeIssueHint'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('submit_bug_btn'),
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(AppStrings.tr(lang, 'submitBug')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              '${AppStrings.tr(lang, 'openReports')} (${_openBugs.length})',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),

            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else if (_openBugs.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Text(
                  AppStrings.tr(lang, 'noOpenBugs'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ..._openBugs.map(
                (b) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              b.pageContext.isEmpty ? 'General' : b.pageContext,
                              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              AppStrings.tr(lang, 'openBadge'),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(b.description, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
