import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/session_provider.dart';
import '../../providers/project_provider.dart';
import '../../models/session_model.dart';
import '../../models/task_model.dart';
import '../../models/note_model.dart';
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
    final projectsProv = context.read<ProjectProvider>();
    final sessionsProv = context.read<SessionProvider>();
    await projectsProv.fetchProjects();
    await sessionsProv.fetchSessions();
    await sessionsProv.reconcileWithProjectIds(
      projectsProv.projects.map((p) => p.id).toSet(),
    );
  }

  void _showStartDialog() {
    final sessions = context.read<SessionProvider>();
    // Don't open if still loading data or already tracking a session
    if (sessions.isLoading || sessions.hasActiveSession) return;

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

    String projectTitle(String projectId) {
      try {
        return projects.projects.firstWhere((p) => p.id == projectId).title;
      } catch (_) {
        return 'Project';
      }
    }

    // Only allow starting when not already loading and not already tracking
    final canStart = !sessions.hasActiveSession && !sessions.isLoading;

    final completed = sessions.completedSessions;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthSessions =
        completed.where((s) => s.startTime.isAfter(monthStart)).toList();
    final monthDuration = monthSessions.fold<Duration>(
        Duration.zero, (a, s) => a + s.duration);
    final monthHours = monthDuration.inMinutes / 60.0;
    final avgSeconds = completed.isNotEmpty
        ? completed.fold<int>(0, (a, s) => a + s.duration.inSeconds) ~/
            completed.length
        : 0;
    final avgDuration = Duration(seconds: avgSeconds);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        actions: [
          if (canStart)
            IconButton(
              icon: const Icon(Icons.play_circle_outline),
              onPressed: _showStartDialog,
            ),
        ],
      ),
      body: sessions.isLoading && sessions.sessions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  if (sessions.hasActiveSession)
                    SliverToBoxAdapter(
                      child: _ActiveSessionBanner(
                        session: sessions.activeSession!,
                        projectTitle: sessions.activeProjectTitle ??
                            projectTitle(sessions.activeSession!.projectId),
                      ),
                    ),

                  if (completed.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                  label: 'TOTAL SESSIONS',
                                  value: '${completed.length}'),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatCard(
                                label: 'TIME THIS MONTH',
                                value: monthHours.toStringAsFixed(2),
                                unit: 'hrs',
                                highlight: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatCard(
                                label: 'AVG DURATION',
                                value: avgDuration.inMinutes > 0
                                    ? '${avgDuration.inMinutes}m'
                                    : '<1m',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (completed.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                        child: Text(
                          'Recent Sessions',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),

                  if (completed.isEmpty && !sessions.hasActiveSession)
                    SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.timer_outlined,
                        title: 'No Sessions Yet',
                        subtitle:
                            'Start a session to track time on your projects',
                        actionLabel: 'Start Session',
                        onAction: canStart ? _showStartDialog : null,
                      ),
                    ),

                  if (completed.isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final s = completed[i];
                          final title = projectTitle(s.projectId);
                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                                12, i == 0 ? 4 : 0, 12, 8),
                            child: _SessionTile(
                              session: s,
                              projectTitle: title,
                              onTap: () => context.push(
                                Uri(
                                  path: '/insights/session/${s.id}',
                                  queryParameters: {'projectTitle': title},
                                ).toString(),
                              ),
                              onDelete: () => sessions.deleteSession(s.id),
                            ),
                          );
                        },
                        childCount: completed.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
      floatingActionButton: canStart
          ? FloatingActionButton.extended(
              onPressed: _showStartDialog,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Session'),
            )
          : null,
    );
  }
}

// ── Active Session Banner ───────────────────────────────────────────────────

class _ActiveSessionBanner extends StatelessWidget {
  final SessionModel session;
  final String projectTitle;

  const _ActiveSessionBanner({
    required this.session,
    required this.projectTitle,
  });

  @override
  Widget build(BuildContext context) {
    final sessionProv = context.watch<SessionProvider>();
    final isPaused = sessionProv.isPaused;
    final theme = Theme.of(context);
    final accentColor =
        isPaused ? AppTheme.warningColor : AppTheme.primaryColor;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: accentColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPaused ? 'PAUSED' : 'LIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        projectTitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.65),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _BannerTimer(
                  session: session,
                  isPaused: isPaused,
                  frozenDuration: sessionProv.frozenDuration,
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BannerIconButton(
                icon: isPaused ? Icons.play_arrow : Icons.pause,
                color: AppTheme.warningColor,
                onTap: isPaused
                    ? () => sessionProv.resumeSession()
                    : () => sessionProv.pauseSession(),
              ),
              const SizedBox(width: 4),
              _BannerTextButton(
                icon: Icons.open_in_full,
                label: 'Focus',
                color: AppTheme.primaryColor,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _FocusModeScreen(
                      session: session,
                      projectTitle: projectTitle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _BannerIconButton(
                icon: Icons.stop,
                color: AppTheme.errorColor,
                onTap: () => context.read<SessionProvider>().stopSession(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _BannerIconButton(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      );
}

class _BannerTextButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BannerTextButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
        ),
      );
}

// ── Banner live timer ───────────────────────────────────────────────────────

class _BannerTimer extends StatefulWidget {
  final SessionModel session;
  final bool isPaused;
  final Duration? frozenDuration;

  const _BannerTimer(
      {required this.session, required this.isPaused, this.frozenDuration});

  @override
  State<_BannerTimer> createState() => _BannerTimerState();
}

class _BannerTimerState extends State<_BannerTimer> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (!widget.isPaused) _startTick();
  }

  void _startTick() {
    _tick?.cancel();
    _tick = Timer.periodic(
        const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }

  @override
  void didUpdateWidget(_BannerTimer old) {
    super.didUpdateWidget(old);
    if (widget.isPaused && !old.isPaused) {
      _tick?.cancel();
      _tick = null;
    } else if (!widget.isPaused && old.isPaused) {
      _startTick();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.isPaused
        ? (widget.frozenDuration ?? widget.session.duration)
        : widget.session.duration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final text = h > 0
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Text(text,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800));
  }
}

// ── Stat card ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final String? unit;
  final bool highlight;

  const _StatCard(
      {required this.label,
      required this.value,
      this.unit,
      this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? AppTheme.primaryColor : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: highlight
            ? null
            : Border.all(
                color: theme.colorScheme.onSurface.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: highlight
                  ? Colors.white70
                  : theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: highlight ? Colors.white : theme.colorScheme.primary,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(unit!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: highlight
                            ? Colors.white70
                            : theme.colorScheme.onSurface.withOpacity(0.5),
                      )),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Focus Mode Screen ───────────────────────────────────────────────────────

class _FocusModeScreen extends StatefulWidget {
  final SessionModel session;
  final String projectTitle;

  const _FocusModeScreen(
      {required this.session, required this.projectTitle});

  @override
  State<_FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<_FocusModeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final projectId = widget.session.projectId;
      Future.wait([
        context.read<ProjectProvider>().fetchTasks(projectId),
        context.read<ProjectProvider>()
            .fetchNotes(widget.session.id, 'session'),
      ]);
    });
  }

  Future<void> _confirmStop() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Session'),
        content: const Text('Are you sure you want to end this session?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<SessionProvider>().stopSession();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _addNote() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Note'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'Jot something down...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty && mounted) {
      final sessionId =
          context.read<SessionProvider>().activeSession?.id ??
              widget.session.id;
      await context.read<ProjectProvider>().createNote(
            content: ctrl.text.trim(),
            parentId: sessionId,
            parentType: 'session',
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionProv = context.watch<SessionProvider>();
    final projectProv = context.watch<ProjectProvider>();
    final theme = Theme.of(context);

    final session = sessionProv.activeSession ?? widget.session;
    final isPaused = sessionProv.isPaused;
    final allProjectTasks = projectProv.tasksForProject(session.projectId);
    final notes = projectProv.notesForParent(session.id);

    if (!sessionProv.hasActiveSession) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => Navigator.maybePop(context));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_fullscreen),
          tooltip: 'Minimize',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.projectTitle),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Column(
                children: [
                  _StatusBadge(isPaused: isPaused),
                  const SizedBox(height: 16),
                  _LargeTimer(
                    session: session,
                    isPaused: isPaused,
                    frozenDuration: sessionProv.frozenDuration,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: isPaused
                            ? () => sessionProv.resumeSession()
                            : () => sessionProv.pauseSession(),
                        icon: Icon(
                            isPaused ? Icons.play_arrow : Icons.pause,
                            size: 18),
                        label: Text(isPaused ? 'Resume' : 'Pause'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.warningColor,
                          side: const BorderSide(color: AppTheme.warningColor),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _confirmStop,
                        icon: const Icon(Icons.stop_circle_outlined, size: 18),
                        label: const Text('End Session'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.errorColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text('TASKS',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.5),
                      )),
                ],
              ),
            ),
            if (allProjectTasks.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'No tasks for this project yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withOpacity(0.4)),
                ),
              )
            else
              ...allProjectTasks.map((t) => CheckboxListTile(
                    value: session.taskIds.contains(t.id),
                    onChanged: (checked) async {
                      if (checked == null) return;
                      await context.read<SessionProvider>().setTaskChecked(
                            sessionId: session.id,
                            taskId: t.id,
                            isChecked: checked,
                          );
                    },
                    title: Text(t.name),
                    subtitle:
                        t.description.isNotEmpty ? Text(t.description) : null,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    controlAffinity: ListTileControlAffinity.leading,
                  )),
            const Divider(height: 24),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text('NOTES',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.5),
                      )),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addNote,
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text('Add note'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            if (notes.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'No notes yet — jot something down.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withOpacity(0.4)),
                ),
              )
            else
              ...notes.map((n) => _NoteCard(
                    note: n,
                    onDelete: () => context
                        .read<ProjectProvider>()
                        .deleteNote(n.id, session.id),
                  )),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Status badge ────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool isPaused;
  const _StatusBadge({required this.isPaused});

  @override
  Widget build(BuildContext context) {
    final color = isPaused ? AppTheme.warningColor : AppTheme.primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isPaused)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          if (isPaused)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.pause, size: 12, color: AppTheme.warningColor),
            ),
          Text(
            isPaused ? 'PAUSED' : 'ACTIVE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Large timer (focus mode) ─────────────────────────────────────────────────

class _LargeTimer extends StatefulWidget {
  final SessionModel session;
  final bool isPaused;
  final Duration? frozenDuration;

  const _LargeTimer(
      {required this.session, required this.isPaused, this.frozenDuration});

  @override
  State<_LargeTimer> createState() => _LargeTimerState();
}

class _LargeTimerState extends State<_LargeTimer> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (!widget.isPaused) _startTick();
  }

  void _startTick() {
    _tick?.cancel();
    _tick = Timer.periodic(
        const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }

  @override
  void didUpdateWidget(_LargeTimer old) {
    super.didUpdateWidget(old);
    if (widget.isPaused && !old.isPaused) {
      _tick?.cancel();
      _tick = null;
    } else if (!widget.isPaused && old.isPaused) {
      _startTick();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.isPaused
        ? (widget.frozenDuration ?? widget.session.duration)
        : widget.session.duration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final text = h > 0
        ? '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s'
        : '${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';

    return Text(text,
        style: const TextStyle(
            fontSize: 52, fontWeight: FontWeight.w800, letterSpacing: -1.5));
  }
}

// ── Task card ────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.name,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(task.description,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5))),
          ],
        ],
      ),
    );
  }
}

// ── Note card ────────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onDelete;
  const _NoteCard({required this.note, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: Text(note.content, style: theme.textTheme.bodyMedium)),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 16, color: AppTheme.errorColor),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── Session tile ─────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  final SessionModel session;
  final String projectTitle;
  final VoidCallback onDelete, onTap;

  const _SessionTile(
      {required this.session,
      required this.projectTitle,
      required this.onDelete,
      required this.onTap});

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
                      DateFormat('MMM d, y • h:mm a')
                          .format(session.startTime),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.5)),
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

// ── Start session sheet ───────────────────────────────────────────────────────

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
                  subtitle:
                      p.description.isNotEmpty ? Text(p.description) : null,
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
                        // Double-tap guard
                        if (_loading) return;
                        setState(() => _loading = true);

                        final sessionProv = context.read<SessionProvider>();

                        // Race-condition guard: session may have started elsewhere
                        if (sessionProv.hasActiveSession) {
                          if (context.mounted) Navigator.pop(context);
                          return;
                        }

                        final p = widget.projects
                            .firstWhere((x) => x.id == _selectedId);
                        final result = await sessionProv.startSession(
                          _selectedId!,
                          projectTitle: p.title,
                        );
                        if (!mounted) return;
                        if (result != null) {
                          Navigator.pop(context);
                        } else {
                          setState(() => _loading = false);
                          final err = sessionProv.error;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content:
                                Text(err ?? 'Failed to start session'),
                            backgroundColor: AppTheme.errorColor,
                          ));
                        }
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