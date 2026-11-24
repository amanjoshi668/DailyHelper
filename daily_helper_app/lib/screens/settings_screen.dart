import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/gcp_backend_service.dart';
import '../services/i18n.dart';
import '../services/notification_service.dart';
import '../services/vault_storage.dart';
import 'bug_report_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  final String pageContext;

  const SettingsScreen({
    super.key,
    required this.pageContext,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AuthService.instance, VaultStorage.instance]),
      builder: (context, _) {
        final auth = AuthService.instance;
        final vault = VaultStorage.instance;
        final user = auth.currentUser;
        final lang = vault.lang;
        final theme = Theme.of(context);
        final isProfessional = !user.isGuest && user.role == UserRole.professional;

        return Scaffold(
          appBar: AppBar(
            title: Text(AppStrings.tr(lang, 'settings')),
            centerTitle: false,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Account Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: auth.isLoggedIn
                      ? Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: theme.colorScheme.primary,
                              child: Text(
                                user.initials,
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    user.email,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              key: const Key('settings_sign_out_btn'),
                              onPressed: () async {
                                await auth.signOut();
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: Text(AppStrings.tr(lang, 'signOut')),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Not signed in',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Sign in as Customer or Professional',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton(
                              key: const Key('settings_sign_in_btn'),
                              onPressed: () async {
                                final ok = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                                );
                                if (ok == true && context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: Text(AppStrings.tr(lang, 'signIn')),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 18),

                // Preferences Card
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const Key('settings_reminders_switch'),
                        title: Text(
                          AppStrings.tr(lang, 'notifications'),
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        value: vault.remindersEnabled,
                        onChanged: (val) => vault.setRemindersEnabled(val),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        key: const Key('settings_language_tile'),
                        title: Text(
                          AppStrings.tr(lang, 'language'),
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        trailing: Text(
                          lang == 'en' ? 'English' : 'हिंदी',
                          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        onTap: () => vault.setLanguage(lang == 'en' ? 'hi' : 'en'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // More Options (Export Khata ONLY for Professionals — NEVER for Customers!)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    AppStrings.tr(lang, 'moreOptions'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      if (isProfessional) ...[
                        ListTile(
                          key: const Key('settings_export_khata_tile'),
                          leading: const Icon(Icons.download_outlined, size: 20),
                          title: Text(AppStrings.tr(lang, 'exportKhata')),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ExportKhataScreen()),
                            );
                          },
                        ),
                        const Divider(height: 1),
                      ],
                      ListTile(
                        key: const Key('settings_report_bug_tile'),
                        leading: const Icon(Icons.bug_report_outlined, size: 20),
                        title: Text(AppStrings.tr(lang, 'reportBug')),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BugReportScreen(pageContext: pageContext),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        key: const Key('settings_policy_tile'),
                        leading: const Icon(Icons.shield_outlined, size: 20),
                        title: Text(AppStrings.tr(lang, 'fairPlayPolicy')),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const FairPlayPolicyScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'DailyHelper v${GcpBackendService.appVersion}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ExportKhataScreen extends StatelessWidget {
  const ExportKhataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vault = VaultStorage.instance;
    final csv = vault.generateKhataCsv();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(vault.lang, 'exportKhata')),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Export your completed jobs and direct Cash/UPI earnings as a portable CSV ledger.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    csv,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('download_khata_csv_btn'),
                onPressed: () async {
                  await NotificationService.instance.saveExportDocument(
                    filename: 'daily_helper_khata.csv',
                    mimeType: 'text/csv',
                    content: csv,
                  );
                  await vault.pushTopNotification(
                    title: 'Khata Exported',
                    body: 'Saved daily_helper_khata.csv successfully.',
                  );
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.save_alt, size: 18),
                label: const Text('Save .CSV File'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FairPlayPolicyScreen extends StatelessWidget {
  const FairPlayPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = VaultStorage.instance.lang;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(lang, 'fairPlayPolicy')),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ListTile(
              leading: Icon(Icons.verified_outlined),
              title: Text('1. Upfront Visit Fee'),
              subtitle: Text(
                'If you decide not to proceed after on-site inspection, only the stated Visit Fee applies.',
              ),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.handshake_outlined),
              title: Text('2. Agree Before Repair Starts'),
              subtitle: Text(
                'Final labor and material estimate is agreed directly with the professional before starting work.',
              ),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.qr_code_2_outlined),
              title: Text('3. 100% Direct Cash / UPI Settlement'),
              subtitle: Text(
                'Pay directly to the professional upon completion with 0% platform commission.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
