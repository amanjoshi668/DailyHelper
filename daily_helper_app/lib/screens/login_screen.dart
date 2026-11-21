import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/i18n.dart';
import '../services/vault_storage.dart';

class LoginScreen extends StatefulWidget {
  final UserRole initialRole;
  final String? pendingWorkerName;
  final bool lockToCustomerForBooking;

  const LoginScreen({
    super.key,
    this.initialRole = UserRole.customer,
    this.pendingWorkerName,
    this.lockToCustomerForBooking = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late UserRole _selectedRole;
  bool _isRegister = false;
  bool _busy = false;
  String? _errorMsg;
  String _selectedTrade = 'electrician';

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    setState(() {
      _busy = true;
      _errorMsg = null;
    });

    String? err;
    if (_isRegister) {
      err = await AuthService.instance.registerWithEmail(
        name: _nameCtrl.text,
        email: _emailCtrl.text,
        password: _passCtrl.text,
        phone: _phoneCtrl.text,
        role: _selectedRole,
        trade: _selectedTrade,
        pin: VaultStorage.instance.pinCode,
      );
    } else {
      err = await AuthService.instance.signInWithEmail(
        email: _emailCtrl.text,
        password: _passCtrl.text,
        selectedRole: _selectedRole,
      );
    }

    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _errorMsg = err);
    } else {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _busy = true;
      _errorMsg = null;
    });
    final err = await AuthService.instance.signInWithGoogle(role: _selectedRole);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _errorMsg = err);
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = VaultStorage.instance.lang;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(lang, 'appName')),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isRegister
                        ? AppStrings.tr(lang, 'signUpTitle')
                        : AppStrings.tr(lang, 'signInTitle'),
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.pendingWorkerName != null
                        ? 'Sign in to confirm your appointment with ${widget.pendingWorkerName}.'
                        : (_selectedRole == UserRole.professional
                            ? 'Manage your job requests, rates, and Khata.'
                            : 'Book trusted local helpers and manage appointments.'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (!widget.lockToCustomerForBooking) ...[
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _RoleSegmentButton(
                              key: const Key('login_role_customer_btn'),
                              label: AppStrings.tr(lang, 'customer'),
                              selected: _selectedRole == UserRole.customer,
                              onTap: () => setState(() => _selectedRole = UserRole.customer),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _RoleSegmentButton(
                              key: const Key('login_role_pro_btn'),
                              label: AppStrings.tr(lang, 'professional'),
                              selected: _selectedRole == UserRole.professional,
                              onTap: () => setState(() => _selectedRole = UserRole.professional),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_errorMsg != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _errorMsg!,
                        style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (_isRegister) ...[
                    TextField(
                      key: const Key('login_name_field'),
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('login_phone_field'),
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_selectedRole == UserRole.professional) ...[
                      DropdownButtonFormField<String>(
                        key: const Key('login_trade_dropdown'),
                        value: _selectedTrade,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Primary Service / Trade',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'electrician', child: Text('Electrician')),
                          DropdownMenuItem(value: 'plumber', child: Text('Plumber')),
                          DropdownMenuItem(value: 'carpenter', child: Text('Carpenter')),
                          DropdownMenuItem(value: 'appliance', child: Text('AC & Appliance Repair')),
                          DropdownMenuItem(value: 'painter', child: Text('Painter')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedTrade = v);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],

                  TextField(
                    key: const Key('login_email_field'),
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('login_password_field'),
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),

                  FilledButton(
                    key: const Key('login_submit_btn'),
                    onPressed: _busy ? null : _submitEmail,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _isRegister
                          ? AppStrings.tr(lang, 'createAccount')
                          : AppStrings.tr(lang, 'signIn'),
                    ),
                  ),
                  const SizedBox(height: 14),

                  OutlinedButton.icon(
                    key: const Key('login_google_btn'),
                    onPressed: _busy ? null : _submitGoogle,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.account_circle_outlined, size: 20),
                    label: Text(AppStrings.tr(lang, 'continueGoogle')),
                  ),
                  const SizedBox(height: 14),

                  TextButton(
                    key: const Key('login_toggle_mode_btn'),
                    onPressed: () => setState(() {
                      _isRegister = !_isRegister;
                      _errorMsg = null;
                    }),
                    child: Text(
                      _isRegister
                          ? 'Already have an account? Sign In'
                          : 'New to DailyHelper? Create an account',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleSegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleSegmentButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
