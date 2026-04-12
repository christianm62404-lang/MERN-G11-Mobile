import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../providers/project_provider.dart';
import '../../providers/session_provider.dart';
import '../../models/session_model.dart';
import '../../models/task_model.dart';
import '../../models/note_model.dart';
import '../../utils/app_theme.dart';

class InsightProjectScreen extends StatefulWidget {
  final String projectId;
  final String projectTitle;

  const InsightProjectScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<InsightProjectScreen> createState() => _InsightProjectScreenState();
}

class _InsightProjectScreenState extends State<InsightProjectScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await Future.wait([
      context.read<ProjectProvider>().fetchTasks(widget.projectId),
      context.read<ProjectProvider>().fetchNotes(widget.projectId, 'project'),
      context.read<SessionProvider>().fetchSessions(projectId: widget.projectId),
    ]);
    setState(() => _loading = false);
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projects = context.watch<ProjectProvider>();
    final sessions = context.watch<SessionProvider>();

    final tasks = projects.tasksForProject(widget.projectId);
    final notes = projects.notesForParent(widget.projectId);
    final completed = sessions.completedSessions
        .where((s) => s.projectId == widget.projectId)
        .toList();

    final totalTime = completed.fold<Duration>(
        Duration.zero, (a, s) => a + s.duration);
    final avgTime = completed.isEmpty
        ? Duration.zero
        : Duration(
            seconds: completed
                    .fold(0, (a, s) => a + s.duration.inSeconds) ~/
                completed.length);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectTitle,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _load)
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Stats strip ──────────────────────────────
                    _StatsRow(children: [
                      _StatTile(
                          label: 'Total Time',
                          value: _fmt(totalTime),
                          color: AppTheme.primaryColor),
                      _StatTile(
                          label: 'Sessions',
                          value: '${completed.length}',
                          color: AppTheme.secondaryColor),
                      _StatTile(
                          label: 'Avg Session',
                          value: completed.isEmpty ? '—' : _fmt(avgTime),
                          color: AppTheme.warningColor),
                    ]),
                    const SizedBox(height: 24),

                    // ── Session trend chart ───────────────────────
                    if (completed.isNotEmpty) ...[
                      _SectionHeader('Session Durations'),
                      const SizedBox(height: 8),
                      _SessionBarChart(sessions: completed),
                      const SizedBox(height: 24),
                    ],

                    // ── Tasks breakdown ───────────────────────────
                    if (tasks.isNotEmpty) ...[
                      _SectionHeader('Tasks'),
                      const SizedBox(height: 8),
                      ...tasks.map((t) => _TaskInsightTile(
                            task: t,
                            projectId: widget.projectId,
                            onNoteAdded: _load,
                          )),
                      const SizedBox(height: 24),
                    ],

                    // ── Project notes ─────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SectionHeader('Project Notes'),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add'),
                          onPressed: () =>
                              _showAddNote(context, widget.projectId, 'project'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (notes.isEmpty)
                      _EmptyCard('No project notes yet')
                    else
                      ...notes.map((n) => _NoteTile(
                            note: n,
                            onDelete: () async {
                              await context
                                  .read<ProjectProvider>()
                                  .deleteNote(n.id, widget.projectId);
                            },
                          )),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  void _showAddNote(
      BuildContext context, String parentId, String parentType) {
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
                        parentId: parentId,
                        parentType: parentType,
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

// ── Task tile with inline note support ───────────────────────────────────────

class _TaskInsightTile extends StatelessWidget {
  final TaskModel task;
  final String projectId;
  final VoidCallback onNoteAdded;

  const _TaskInsightTile(
      {required this.task,
      required this.projectId,
      required this.onNoteAdded});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = context.watch<ProjectProvider>().notesForParent(task.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.check_circle_outline,
                      color: AppTheme.primaryColor, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(task.name,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Text(task.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6))),
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('Notes',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                        letterSpacing: 0.5)),
              ),
              const SizedBox(height: 4),
              ...notes.map((n) => _NoteTile(
                    note: n,
                    compact: true,
                    onDelete: () async {
                      await context
                          .read<ProjectProvider>()
                          .deleteNote(n.id, task.id);
                    },
                  )),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Note', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero),
                onPressed: () {
                  final ctrl = TextEditingController();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (ctx) => Padding(
                      padding: EdgeInsets.only(
                          left: 24,
                          right: 24,
                          top: 24,
                          bottom:
                              MediaQuery.of(ctx).viewInsets.bottom + 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Note for "${task.name}"',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 16),
                          TextField(
                            controller: ctrl,
                            autofocus: true,
                            maxLines: 4,
                            decoration: const InputDecoration(
                                labelText: 'Note'),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (ctrl.text.trim().isEmpty) return;
                                await context
                                    .read<ProjectProvider>()
                                    .createNote(
                                      content: ctrl.text.trim(),
                                      parentId: task.id,
                                      parentType: 'task',
                                    );
                                if (ctx.mounted) Navigator.pop(ctx);
                                onNoteAdded();
                              },
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Session bar chart ─────────────────────────────────────────────────────────

class _SessionBarChart extends StatelessWidget {
  final List<SessionModel> sessions;
  const _SessionBarChart({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = sessions.length > 10
        ? sessions.sublist(sessions.length - 10)
        : sessions;
    final maxMins =
        last.map((s) => s.duration.inMinutes).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last ${last.length} sessions',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5))),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxMins.toDouble() * 1.2,
                  barGroups: last.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.duration.inMinutes.toDouble(),
                          color: AppTheme.primaryColor,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (v, _) => Text(
                          '${v.toInt()}m',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontSize: 9),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i >= last.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '#${i + 1}',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontSize: 9),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                        color: theme.dividerColor, strokeWidth: 0.5),
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final List<Widget> children;
  const _StatsRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: children
          .map((c) => Expanded(child: c))
          .expand((w) => [w, const SizedBox(width: 8)])
          .toList()
        ..removeLast(),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.circle, size: 8, color: color),
            const SizedBox(height: 8),
            Text(value,
                style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 2),
            Text(label,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w600));
  }
}

class _NoteTile extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onDelete;
  final bool compact;
  const _NoteTile(
      {required this.note, required this.onDelete, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: 14, vertical: compact ? 8 : 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(note.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: compact ? 12 : 14)),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, y').format(note.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.4),
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
  Widget build(BuildContext context) {
    return Card(
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
}
