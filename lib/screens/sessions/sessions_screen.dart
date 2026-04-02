import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/session_provider.dart';
import '../../providers/project_provider.dart';
import '../../models/session_model.dart';
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
        const SnackBar(content: Text('Create a project first to start a session')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _StartSessionSheet(projects: projects),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionProvider>();
    final projects = context.watch<ProjectProvider>();

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
                  // Active session banner
                  if (sessions.hasActiveSession)
                    _ActiveBanner(
                      session: sessions.activeSession!,
                      projectTitle: sessions.activeProjectTitle ??
                          _getProjectTitle(sessions.activeSession!.projectId, projects),
                      onStop: () => sessions.stopSession(sessions.activeSession!.id),
                    ),

                  // Sessions list
                  Expanded(
                    child: sessions.completedSessions.isEmpty
                        ? EmptyState(
                            icon: Icons.timer_outlined,
                            title: 'No Sessions Yet',
                            subtitle: 'Start a session to track time on your projects',
                            actionLabel: 'Start Session',
                            onAction: _showStartSessionDialog,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: sessions.completedSessions.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final session = sessions.completedSessions[i];
                              return _SessionTile(
                                session: session,
                                projectTitle: _getProjectTitle(session.projectId, projects),
                                onDelete: () => sessions.deleteSession(session.id),
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

  String _getProjectTitle(String projectId, ProjectProvider projects) {
    try {
      return projects.projects.firstWhere((p) => p.id == projectId).title;
    } catch (_) {
      return 'Unknown Project';
    }
  }
}

class _ActiveBanner extends StatelessWidget {
  final SessionModel session;
  final String projectTitle;
  final VoidCallback onStop;

  const _ActiveBanner({
    required this.session,
    required this.projectTitle,
    required this.onStop,
  });

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
            child: const Icon(Icons.fiber_manual_record, color: AppTheme.secondaryColor, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tracking: $projectTitle',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  session.formattedDuration,
                  style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.secondaryColor),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onStop,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
            ),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final SessionModel session;
  final String projectTitle;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.session,
    required this.projectTitle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.timer_outlined, color: AppTheme.warningColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    projectTitle,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    DateFormat('MMM d, y • h:mm a').format(session.startTime),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  session.formattedDuration,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorColor),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StartSessionSheet extends StatefulWidget {
  final List<dynamic> projects;
  const _StartSessionSheet({required this.projects});

  @override
  State<_StartSessionSheet> createState() => _StartSessionSheetState();
}

class _StartSessionSheetState extends State<_StartSessionSheet> {
  String? _selectedProjectId;
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
            Text(
              'Start Session',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a project to track time for',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            ...widget.projects.map((project) => RadioListTile<String>(
              title: Text(project.title),
              subtitle: project.description.isNotEmpty ? Text(project.description) : null,
              value: project.id,
              groupValue: _selectedProjectId,
              onChanged: (v) => setState(() => _selectedProjectId = v),
              contentPadding: EdgeInsets.zero,
            )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedProjectId == null || _loading
                    ? null
                    : () async {
                        setState(() => _loading = true);
                        final project = widget.projects.firstWhere((p) => p.id == _selectedProjectId);
                        await context.read<SessionProvider>().startSession(
                          _selectedProjectId!,
                          projectTitle: project.title,
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Start Tracking'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
