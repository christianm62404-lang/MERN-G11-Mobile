import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/projects/projects_screen.dart';
import '../screens/projects/project_detail_screen.dart';
import '../screens/sessions/sessions_screen.dart';
import '../screens/insights/insights_screen.dart';
import '../screens/account/account_screen.dart';
import '../widgets/main_shell.dart';

class AppRouter {
  static GoRouter createRouter(BuildContext context) {
    return GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final status = auth.status;

        if (status == AuthStatus.unknown) return null;

        final loc = state.matchedLocation;
        final isAuthRoute = loc.startsWith('/login') ||
            loc.startsWith('/register') ||
            loc.startsWith('/verify-email') ||
            loc.startsWith('/forgot-password') ||
            loc.startsWith('/reset-password');

        if (status == AuthStatus.unauthenticated) {
          return isAuthRoute ? null : '/login';
        }

        if (status == AuthStatus.unverified) {
          // Allow verify-email; redirect everything else there
          return loc.startsWith('/verify-email') ? null : '/verify-email';
        }

        if (status == AuthStatus.authenticated && isAuthRoute) {
          return '/dashboard';
        }

        return null;
      },
      refreshListenable: Provider.of<AuthProvider>(context, listen: false),
      routes: [
        // ── Auth routes ────────────────────────────────────────────
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (_, __) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/verify-email',
          builder: (context, state) {
            final email = state.uri.queryParameters['email'] ?? '';
            return VerifyEmailScreen(email: email);
          },
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (context, state) {
            final token = state.uri.queryParameters['token'] ?? '';
            return ResetPasswordScreen(token: token);
          },
        ),

        // ── Authenticated shell ────────────────────────────────────
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, __) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/projects',
              builder: (_, __) => const ProjectsScreen(),
            ),
            GoRoute(
              path: '/projects/:id',
              builder: (context, state) => ProjectDetailScreen(
                projectId: state.pathParameters['id']!,
                projectTitle:
                    state.uri.queryParameters['title'] ?? 'Project',
              ),
            ),
            GoRoute(
              path: '/sessions',
              builder: (_, __) => const SessionsScreen(),
            ),
            GoRoute(
              path: '/insights',
              builder: (_, __) => const InsightsScreen(),
            ),
            GoRoute(
              path: '/account',
              builder: (_, __) => const AccountScreen(),
            ),
          ],
        ),
      ],
    );
  }
}
