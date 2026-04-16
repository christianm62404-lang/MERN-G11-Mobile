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

    if (_session != null) {
      try {
        _session =
            sessionProv.sessions.firstWhere((s) => s.id == widget.sessionId);
      } catch (_) {}
    }

    final session = _session;
    final notes =
        session != null ? projects.notesForParent(session.id) : <NoteModel>[];
    final allTasks =
        session != null ? projects.tasksForProject(session.projectId) : [];
    final linkedTasks =
        allTasks.where((t) => session?.taskIds.contains(t.id) ?? false).toList();

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
                        // ── Header ────────────────────────────────
                        Text(
                          'SESSION INSIGHT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.projectTitle,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('EEEE, MMMM d, y')
                              .format(session.startTime),
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.5)),
                        ),
                        const SizedBox(height: 20),

                        // ── Duration / Start / End boxes ──────────
                        _MetricRow(session: session),
                        const SizedBox(height: 28),

                        // ── Linked tasks ──────────────────────────
                        if (linkedTasks.isNotEmpty) ...[
                          _SectionHeader('Tasks Worked On'),
                          const SizedBox(height: 8),
                          ...linkedTasks.map((t) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                            Icons.check_circle_outline,
                                            color: AppTheme.primaryColor,
                                            size: 16),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(t.name,
                                                style: theme
                                                    .textTheme.bodyLarge
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600)),
                                            if (t.description.isNotEmpty)
                                              Text(t.description,
                                                  style: theme
                                                      .textTheme.bodySmall
                                                      ?.copyWith(
                                                          color: theme
                                                              .colorScheme
                                                              .onSurface
                                                              .withOpacity(
                                                                  0.55))),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                          const SizedBox(height: 20),
                        ],

                        // ── Notes ─────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _SectionHeader('Notes'),
                            TextButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Note'),
                              onPressed: () =>
                                  _showAddNote(context, session.id),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (notes.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.04),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'No notes for this session yet.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.4)),
                            ),
                          )
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
            Text('Add Note',
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

// ── Three metric boxes ────────────────────────────────────────────────────────

class _MetricRow extends StatelessWidget {
  final SessionModel session;
  const _MetricRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final dur = session.duration;
    final h = dur.inHours;
    final m = dur.inMinutes.remainder(60);
    // Show "—" for orphaned sessions that were never properly stopped.
    final durationStr = session.endTime == null
        ? '—'
        : (h > 0 ? '${h}h ${m}m' : m > 0 ? '${m}m' : '${dur.inSeconds}s');

    final startStr = DateFormat('h:mm a').format(session.startTime);
    final endStr = session.endTime != null
        ? DateFormat('h:mm a').format(session.endTime!)
        : '—';

    return Row(
      children: [
        Expanded(child: _MetricBox(label: 'DURATION', value: durationStr)),
        const SizedBox(width: 10),
        Expanded(child: _MetricBox(label: 'START', value: startStr)),
        const SizedBox(width: 10),
        Expanded(child: _MetricBox(label: 'END', value: endStr)),
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;
  const _MetricBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: theme.colorScheme.onSurface.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: theme.colorScheme.onSurface.withOpacity(0.45),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
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
