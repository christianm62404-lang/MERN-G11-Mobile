import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/session_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/stat_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    await Future.wait([
      context.read<ProjectProvider>().fetchProjects(),
      context.read<SessionProvider>().fetchSessions(),
    ]);
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final projects = context.watch<ProjectProvider>();
    final sessions = context.watch<SessionProvider>();
    final firstName = auth.user?.firstName ?? 'there';

    final totalTime = sessions.completedSessions
        .fold<Duration>(Duration.zero, (a, s) => a + s.duration);

    final now = DateTime.now();
    final todayTime = sessions.completedSessions
        .where((s) =>
            s.startTime.year == now.year &&
            s.startTime.month == now.month &&
            s.startTime.day == now.day)
        .fold<Duration>(Duration.zero, (a, s) => a + s.duration);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello, $firstName',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Text(
              DateFormat('EEEE, MMMM d').format(now),
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
          ],
        ),
        actions: [
          if (sessions.hasActiveSession)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.fiber_manual_record,
                    color: AppTheme.secondaryColor, size: 12),
                label: Text(
                  sessions.activeSession!.formattedDuration,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Active session banner ──
              if (sessions.hasActiveSession) ...[
                _ActiveSessionBanner(
                  session: sessions.activeSession!,
                  projectTitle: sessions.activeProjectTitle,
                  onStop: () => context.read<SessionProvider>().stopSession(),
                ),
                const SizedBox(height: 16),
              ],

              // ── Stats ──
              Text('Overview',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  StatCard(
                      title: 'Projects',
                      value: '${projects.projects.length}',
                      icon: Icons.folder_outlined,
                      iconColor: AppTheme.primaryColor),
                  StatCard(
                      title: "Today's Time",
                      value: _fmtDuration(todayTime),
                      icon: Icons.today_outlined,
                      iconColor: AppTheme.secondaryColor),
                  StatCard(
                      title: 'Total Sessions',
                      value: '${sessions.completedSessions.length}',
                      icon: Icons.timer_outlined,
                      iconColor: AppTheme.warningColor),
                  StatCard(
                      title: 'Total Time',
                      value: _fmtDuration(totalTime),
                      icon: Icons.schedule_outlined,
                      iconColor: AppTheme.primaryDark),
                ],
              ),

              const SizedBox(height: 24),

              // ── Recent projects ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Projects',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  TextButton(
                      onPressed: () => context.go('/projects'),
                      child: const Text('See all')),
                ],
              ),
              const SizedBox(height: 8),
              if (projects.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (projects.projects.isEmpty)
                _EmptyProjectsCard(onTap: () => context.go('/projects'))
              else
                ...projects.projects.take(3).map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ProjectCard(
                        title: p.title,
                        description: p.description,
                        onTap: () => context.go(
                          '/projects/${p.id}?title=${Uri.encodeComponent(p.title)}',
                        ),
                      ),
                    )),

              const SizedBox(height: 24),

              // ── Recent sessions ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Sessions',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  TextButton(
                      onPressed: () => context.go('/sessions'),
                      child: const Text('See all')),
                ],
              ),
              const SizedBox(height: 8),
              if (sessions.completedSessions.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text('No sessions yet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.5))),
                    ),
                  ),
                )
              else
                ...sessions.completedSessions.take(3).map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SessionItem(session: s, projects: projects),
                    )),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ActiveSessionBanner extends StatelessWidget {
  final dynamic session;
  final String? projectTitle;
  final VoidCallback onStop;

  const _ActiveSessionBanner(
      {required this.session, this.projectTitle, required this.onStop});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record,
              color: AppTheme.secondaryColor, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Session in progress',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryColor,
                        fontWeight: FontWeight.w600)),
                Text(projectTitle ?? 'Unknown project',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Text(session.formattedDuration,
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondaryColor)),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onStop,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final String title, description;
  final VoidCallback onTap;
  const _ProjectCard(
      {required this.title, required this.description, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.folder_outlined,
                    color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (description.isNotEmpty)
                      Text(description,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.6)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyProjectsCard extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyProjectsCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.add_circle_outline,
                  color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Text('Create your first project',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionItem extends StatelessWidget {
  final dynamic session;
  final ProjectProvider projects;
  const _SessionItem({required this.session, required this.projects});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String projectTitle = 'Unknown';
    try {
      projectTitle = projects.projects
          .firstWhere((p) => p.id == session.projectId)
          .title;
    } catch (_) {}

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.timer_outlined,
                  color: AppTheme.warningColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(projectTitle,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    DateFormat('MMM d, h:mm a').format(session.startTime),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
            Text(session.formattedDuration,
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }
}
