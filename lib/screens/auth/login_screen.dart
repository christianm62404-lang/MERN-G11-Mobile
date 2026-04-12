import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../utils/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.login(_emailController.text.trim(), _passwordController.text);
    if (!success && mounted) {
      if (auth.status == AuthStatus.unverified) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.errorMessage ?? 'Login failed'),
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
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.access_time_rounded, size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    const Text('TimeTrack', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                  ]),
                  const SizedBox(height: 28),
                  const Text('Welcome back.', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Text('Sign in to continue tracking your work.', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(color: Color(0xFFF9F9F9), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sign in', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: AppTheme.lightTextPrimary)),
                      const SizedBox(height: 24),
                      AppTextField(label: 'Email', hint: 'you@example.com', controller: _emailController, keyboardType: TextInputType.emailAddress, prefixIcon: Icons.email_outlined, textInputAction: TextInputAction.next,
                        validator: (v) { if (v == null || v.isEmpty) return 'Email is required'; if (!v.contains('@')) return 'Enter a valid email'; return null; }),
                      const SizedBox(height: 14),
                      AppTextField(label: 'Password', controller: _passwordController, obscureText: true, prefixIcon: Icons.lock_outlined, textInputAction: TextInputAction.done,
                        validator: (v) { if (v == null || v.isEmpty) return 'Password is required'; return null; }),
                      Align(alignment: Alignment.centerRight,
                        child: TextButton(onPressed: () => context.go('/forgot-password'),
                          style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor, padding: const EdgeInsets.symmetric(vertical: 4)),
                          child: const Text('Forgot password?', style: TextStyle(fontSize: 13)))),
                      const SizedBox(height: 8),
                      AppButton(label: 'Sign In', onPressed: _login, isLoading: auth.isLoading),
                      const SizedBox(height: 20),
                      Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text("Don't have an account?", style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.lightTextSecondary)),
                        TextButton(onPressed: () => context.go('/register'), style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                          child: const Text('Sign up', style: TextStyle(fontWeight: FontWeight.w600))),
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
