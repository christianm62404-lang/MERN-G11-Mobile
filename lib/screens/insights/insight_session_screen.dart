import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/project_provider.dart';
import '../../providers/session_provider.dart';
import '../../models/session_model.dart';
import '../../models/note_model.dart';
import '../../utils/app_theme.dart';

class InsightSessionScreen extends StatefulWidget {
  final String sessionId;
  final String projectTitle;

  const InsightSessionScreen({
    super.key,
    required this.sessionId,
    required this.projectTitle,
  });

  @override
  State<InsightSessionScreen> createState() => _InsightSessionScreenState();
}

class _InsightSessionScreenState extends State<InsightSessionScreen> {
  bool _loading = true;
  SessionModel? _session;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Fetch all sessions so we can find ours
    await context.read<SessionProvider>().fetchSessions();
    final sessions = context.read<SessionProvider>().sessions;
    try {
      _session = sessions.firstWhere((s) => s.id == widget.sessionId);
      if (_session != null) {
        await Future.wait([
          context.read<ProjectProvider>().fetchTasks(_session!.projectId),
          context.read<ProjectProvider>().fetchNotes(_session!.id, 'session'),
        ]);
      }
    } catch (_) {
      _session = null;
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projects = context.watch<ProjectProvider>();
    final sessionProv = context.watch<SessionProvider>();

    // Keep session in sync
    if (_session != null) {
      try {
        _session = sessionProv.sessions.firstWhere((s) => s.id == widget.sessionId);
      } catch (_) {}
    }

    final session = _session;
    final notes = session != null ? projects.notesForParent(session.id) : <NoteModel>[];
    final allTasks = session != null ? projects.tasksForProject(session.projectId) : [];
    final linkedTasks = allTasks.where((t) => session?.taskIds.contains(t.id) ?? false).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectTitle,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : session == null
              ? const Center(child: Text('Session not found'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Session summary card ──────────────────
                        _SessionSummaryCard(
                            session: session, projectTitle: widget.projectTitle),
                        const SizedBox(height: 24),

                        // ── Linked tasks ──────────────────────────
                        _SectionHeader('Tasks Worked On'),
                        const SizedBox(height: 8),
                        if (linkedTasks.isEmpty)
                          _EmptyCard('No tasks linked to this session')
                        else
                          ...linkedTasks.map((t) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.check_circle_outline,
                                            color: AppTheme.primaryColor, size: 16),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(t.name,
                                                style: theme.textTheme.bodyLarge
                                                    ?.copyWith(fontWeight: FontWeight.w600)),
                                            if (t.description.isNotEmpty)
                                              Text(t.description,
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                      color: theme.colorScheme.onSurface
                                                          .withOpacity(0.55))),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                        const SizedBox(height: 24),

                        // ── Session notes ─────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _SectionHeader('Session Notes'),
                            TextButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add'),
                              onPressed: () => _showAddNote(context, session.id),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (notes.isEmpty)
                          _EmptyCard('No notes for this session')
                        else
                          ...notes.map((n) => _NoteTile(
                                note: n,
                                onDelete: () async {
                                  await context
                                      .read<ProjectProvider>()
                                      .deleteNote(n.id, session.id);
                                },
                              )),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  void _showAddNote(BuildContext context, String sessionId) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Session Note',
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Note', hintText: 'Write your note…'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (ctrl.text.trim().isEmpty) return;
                  await context.read<ProjectProvider>().createNote(
                        content: ctrl.text.trim(),
                        parentId: sessionId,
                        parentType: 'session',
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                },
                child: const Text('Save Note'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Session summary card ──────────────────────────────────────────────────────

class _SessionSummaryCard extends StatelessWidget {
  final SessionModel session;
  final String projectTitle;
  const _SessionSummaryCard(
      {required this.session, required this.projectTitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dur = session.duration;
    final h = dur.inHours;
    final m = dur.inMinutes.remainder(60);
    final s = dur.inSeconds.remainder(60);
    final durationStr = h > 0 ? '${h}h ${m}m' : m > 0 ? '${m}m ${s}s' : '${s}s';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.timer_outlined,
                      color: AppTheme.warningColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(projectTitle,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(
                        DateFormat('EEE, MMM d y').format(session.startTime),
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                _InfoPill(
                    icon: Icons.schedule_outlined,
                    label: durationStr,
                    color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                _InfoPill(
                    icon: Icons.access_time,
                    label: DateFormat('h:mm a').format(session.startTime),
                    color: AppTheme.secondaryColor),
                if (session.endTime != null) ...[
                  const SizedBox(width: 12),
                  _InfoPill(
                      icon: Icons.flag_outlined,
                      label: DateFormat('h:mm a').format(session.endTime!),
                      color: AppTheme.warningColor),
                ],
              ],
            ),
            if (session.taskIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoPill(
                  icon: Icons.task_alt_outlined,
                  label: '${session.taskIds.length} task${session.taskIds.length == 1 ? '' : 's'}',
                  color: AppTheme.primaryDark),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w600));
}

class _NoteTile extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onDelete;
  const _NoteTile({required this.note, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(note.content, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, y').format(note.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                        fontSize: 10),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 16, color: AppTheme.errorColor),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard(this.message);
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4))),
          ),
        ),
      );
}
