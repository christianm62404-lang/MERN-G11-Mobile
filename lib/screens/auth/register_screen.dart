import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../utils/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose(); _emailController.dispose();
    _passwordController.dispose(); _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final success = await auth.register(email: email, password: _passwordController.text, firstName: _firstNameController.text.trim());
    if (success && mounted) {
      context.go('/verify-email?email=${Uri.encodeComponent(email)}');
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.errorMessage ?? 'Registration failed'),
        backgroundColor: AppTheme.errorColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(width: 32, height: 32,
                      decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.access_time_rounded, size: 18, color: Colors.white)),
                    const SizedBox(width: 10),
                    const Text('TimeTrack', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                  ]),
                  const SizedBox(height: 28),
                  const Text('Get started.', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Text('Create your account and start tracking\nyour work sessions today.', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.5)),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(color: Color(0xFFF9F9F9), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Create account', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: AppTheme.lightTextPrimary)),
                      Text('Get started with TimeTrack — it\'s free', style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.lightTextSecondary)),
                      const SizedBox(height: 24),
                      AppTextField(label: 'First Name', hint: 'Your first name', controller: _firstNameController, prefixIcon: Icons.person_outlined, textInputAction: TextInputAction.next,
                        validator: (v) { if (v == null || v.isEmpty) return 'First name is required'; return null; }),
                      const SizedBox(height: 14),
                      AppTextField(label: 'Email', hint: 'you@example.com', controller: _emailController, keyboardType: TextInputType.emailAddress, prefixIcon: Icons.email_outlined, textInputAction: TextInputAction.next,
                        validator: (v) { if (v == null || v.isEmpty) return 'Email is required'; if (!v.contains('@')) return 'Enter a valid email'; return null; }),
                      const SizedBox(height: 14),
                      AppTextField(label: 'Password', controller: _passwordController, obscureText: true, prefixIcon: Icons.lock_outlined, textInputAction: TextInputAction.next,
                        validator: (v) { if (v == null || v.isEmpty) return 'Password is required'; if (v.length < 8) return 'Min 8 characters'; return null; }),
                      const SizedBox(height: 14),
                      AppTextField(label: 'Confirm Password', controller: _confirmPasswordController, obscureText: true, prefixIcon: Icons.lock_outlined, textInputAction: TextInputAction.done,
                        validator: (v) { if (v == null || v.isEmpty) return 'Please confirm your password'; if (v != _passwordController.text) return 'Passwords do not match'; return null; }),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: AppTheme.secondaryContainer, borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          Icon(Icons.info_outline, size: 16, color: AppTheme.primaryDark),
                          const SizedBox(width: 10),
                          Expanded(child: Text("You'll receive a confirmation email to verify your account after registration.", style: TextStyle(fontSize: 12, color: AppTheme.primaryDark, height: 1.4))),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      AppButton(label: 'Create Account', onPressed: _register, isLoading: auth.isLoading),
                      const SizedBox(height: 20),
                      Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('Already have an account?', style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.lightTextSecondary)),
                        TextButton(onPressed: () => context.go('/login'), style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                          child: const Text('Sign in', style: TextStyle(fontWeight: FontWeight.w600))),
                      ])),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
