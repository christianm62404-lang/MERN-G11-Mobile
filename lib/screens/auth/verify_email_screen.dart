import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../utils/app_theme.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _resendLoading = false;

  Future<void> _resend() async {
    setState(() => _resendLoading = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.resendVerification(widget.email);

    if (mounted) {
      setState(() => _resendLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Verification email sent!'
              : auth.errorMessage ?? 'Failed to resend'),
          backgroundColor: success ? AppTheme.secondaryColor : AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 56,
                  color: AppTheme.secondaryColor,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Check your email',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "We've sent a verification link to",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.email,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Click the link in the email to verify your account. The link expires in 1 hour.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton(
                label: 'Resend verification email',
                onPressed: _resend,
                isLoading: _resendLoading,
                isOutlined: true,
                icon: Icons.refresh,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) context.go('/login');
                  },
                child: const Text('Back to Sign In'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
