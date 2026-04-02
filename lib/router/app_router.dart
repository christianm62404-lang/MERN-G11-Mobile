import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/verify_email_screen.dart';
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
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final status = authProvider.status;

        if (status == AuthStatus.unknown) return null;

        final isAuthRoute = state.matchedLocation.startsWith('/login') ||
            state.matchedLocation.startsWith('/register') ||
            state.matchedLocation.startsWith('/verify-email');

        if (status == AuthStatus.unauthenticated) {
          return isAuthRoute ? null : '/login';
        }

        if (status == AuthStatus.unverified) {
          return state.matchedLocation.startsWith('/verify-email')
              ? null
              : '/verify-email';
        }

        if (status == AuthStatus.authenticated && isAuthRoute) {
          return '/dashboard';
        }

        return null;
      },
      refreshListenable: Provider.of<AuthProvider>(context, listen: false),
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/verify-email',
          builder: (context, state) {
            final email = state.uri.queryParameters['email'] ?? '';
            return VerifyEmailScreen(email: email);
          },
        ),
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/projects',
              builder: (context, state) => const ProjectsScreen(),
            ),
            GoRoute(
              path: '/projects/:id',
              builder: (context, state) {
                final projectId = state.pathParameters['id']!;
                final title = state.uri.queryParameters['title'] ?? 'Project';
                return ProjectDetailScreen(
                  projectId: projectId,
                  projectTitle: title,
                );
              },
            ),
            GoRoute(
              path: '/sessions',
              builder: (context, state) => const SessionsScreen(),
            ),
            GoRoute(
              path: '/insights',
              builder: (context, state) => const InsightsScreen(),
            ),
            GoRoute(
              path: '/account',
              builder: (context, state) => const AccountScreen(),
            ),
          ],
        ),
      ],
    );
  }
}
