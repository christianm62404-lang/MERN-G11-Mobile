import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/session_provider.dart';
import '../../providers/project_provider.dart';
import '../../models/session_model.dart';
import '../../models/task_model.dart';
import '../../widgets/empty_state.dart';
import '../../utils/app_theme.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    await Future.wait([
      context.read<SessionProvider>().fetchSessions(),
      context.read<ProjectProvider>().fetchProjects(),
    ]);
  }

  void _showStartSessionDialog() {
    final projects = context.read<ProjectProvider>().projects;
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Create a project first to start a session')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _StartSessionSheet(projects: projects),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionProvider>();
    final projects = context.watch<ProjectProvider>();

    String _projectTitle(String projectId) {
      try {
        return projects.projects.firstWhere((p) => p.id == projectId).title;
      } catch (_) {
        return 'Unknown Project';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        actions: [
          if (!sessions.hasActiveSession)
            IconButton(
              icon: const Icon(Icons.play_circle_outline),
              onPressed: _showStartSessionDialog,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: sessions.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (sessions.hasActiveSession)
                    _ActiveBanner(
                      session: sessions.activeSession!,
                      projectTitle: sessions.activeProjectTitle ??
                          _projectTitle(sessions.activeSession!.projectId),
                      onStop: () =>
                          context.read<SessionProvider>().stopSession(),
                      onPause: () =>
                          context.read<SessionProvider>().pauseSession(),
                    ),
                  Expanded(
                    child: sessions.completedSessions.isEmpty
                        ? EmptyState(
                            icon: Icons.timer_outlined,
                            title: 'No Sessions Yet',
                            subtitle:
                                'Start a session to track time on your projects',
                            actionLabel: 'Start Session',
                            onAction: _showStartSessionDialog,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: sessions.completedSessions.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final s = sessions.completedSessions[i];
                              final title = _projectTitle(s.projectId);
                              return _SessionTile(
                                session: s,
                                projectTitle: title,
                                onTap: () => context.push(
                                  Uri(
                                    path: '/insights/session/${s.id}',
                                    queryParameters: {'projectTitle': title},
                                  ).toString(),
                                ),
                                onDelete: () =>
                                    sessions.deleteSession(s.id),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
      floatingActionButton: !sessions.hasActiveSession
          ? FloatingActionButton.extended(
              onPressed: _showStartSessionDialog,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Session'),
            )
          : null,
    );
  }
}

// ── Active Banner ─────────────────────────────────────────────────────────────

class _ActiveBanner extends StatelessWidget {
  final SessionModel session;
  final String projectTitle;
  final VoidCallback onStop;
  final VoidCallback onPause;

  const _ActiveBanner({
    required this.session,
    required this.projectTitle,
    required this.onStop,
    required this.onPause,
  });

  Future<void> _showTaskSheet(BuildContext context) async {
    final projects = context.read<ProjectProvider>();
    await projects.fetchTasks(session.projectId);
    if (!context.mounted) return;
    final tasks = projects.tasksForProject(session.projectId);
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tasks in this project yet')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _TaskLinkSheet(
          session: session, tasks: tasks, projectId: session.projectId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.fiber_manual_record,
                color: AppTheme.secondaryColor, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tracking: $projectTitle',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(session.formattedDuration,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppTheme.secondaryColor)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showTaskSheet(context),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
            child: const Text('Tasks'),
          ),
          TextButton(
            onPressed: onPause,
            style: TextButton.styleFrom(foregroundColor: AppTheme.warningColor),
            child: const Text('Pause'),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: onStop,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
            ),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }
}

// ── Session Tile ──────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  final SessionModel session;
  final String projectTitle;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _SessionTile({
    required this.session,
    required this.projectTitle,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.timer_outlined,
                  color: AppTheme.warningColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(projectTitle,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    DateFormat('MMM d, y • h:mm a').format(session.startTime),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(session.formattedDuration,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary)),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppTheme.errorColor),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}

// ── Start Session Sheet ───────────────────────────────────────────────────────

class _StartSessionSheet extends StatefulWidget {
  final List<dynamic> projects;
  const _StartSessionSheet({required this.projects});

  @override
  State<_StartSessionSheet> createState() => _StartSessionSheetState();
}

class _StartSessionSheetState extends State<_StartSessionSheet> {
  String? _selectedId;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start Session',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Select a project to track time for',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6))),
            const SizedBox(height: 16),
            ...widget.projects.map((p) => RadioListTile<String>(
                  title: Text(p.title),
                  subtitle: p.description.isNotEmpty ? Text(p.description) : null,
                  value: p.id,
                  groupValue: _selectedId,
                  onChanged: (v) => setState(() => _selectedId = v),
                  contentPadding: EdgeInsets.zero,
                )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedId == null || _loading
                    ? null
                    : () async {
                        setState(() => _loading = true);
                        final p = widget.projects
                            .firstWhere((x) => x.id == _selectedId);
                        await context
                            .read<SessionProvider>()
                            .startSession(_selectedId!, projectTitle: p.title);
                        if (context.mounted) Navigator.pop(context);
                      },
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Start Tracking'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Task Link Sheet ───────────────────────────────────────────────────────────

class _TaskLinkSheet extends StatefulWidget {
  final SessionModel session;
  final List<TaskModel> tasks;
  final String projectId;

  const _TaskLinkSheet({
    required this.session,
    required this.tasks,
    required this.projectId,
  });

  @override
  State<_TaskLinkSheet> createState() => _TaskLinkSheetState();
}

class _TaskLinkSheetState extends State<_TaskLinkSheet> {
  late Set<String> _linked;

  @override
  void initState() {
    super.initState();
    _linked = widget.session.taskIds.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Link Tasks to Session',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Toggle tasks you worked on during this session',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.55))),
            const SizedBox(height: 16),
            ...widget.tasks.map((t) {
              final linked = _linked.contains(t.id);
              return CheckboxListTile(
                value: linked,
                contentPadding: EdgeInsets.zero,
                title: Text(t.name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: t.description.isNotEmpty ? Text(t.description) : null,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (val) async {
                  final sessionProv = context.read<SessionProvider>();
                  if (val == true) {
                    final ok = await sessionProv.addTaskToSession(t.id);
                    if (ok) setState(() => _linked.add(t.id));
                  } else {
                    final ok = await sessionProv.removeTaskFromSession(t.id);
                    if (ok) setState(() => _linked.remove(t.id));
                  }
                },
              );
            }),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
