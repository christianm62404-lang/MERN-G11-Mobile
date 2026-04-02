import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/project_provider.dart';
import '../../providers/session_provider.dart';
import '../../models/task_model.dart';
import '../../models/note_model.dart';
import '../../utils/app_theme.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;
  final String projectTitle;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    await Future.wait([
      context.read<ProjectProvider>().fetchTasks(widget.projectId),
      context.read<ProjectProvider>().fetchNotes(widget.projectId, 'project'),
      context.read<SessionProvider>().fetchSessions(projectId: widget.projectId),
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    final sessions = context.read<SessionProvider>();
    if (sessions.hasActiveSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stop the current session before starting a new one'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }
    await sessions.startSession(widget.projectId, projectTitle: widget.projectTitle);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session started for "${widget.projectTitle}"'),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessions = context.watch<SessionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tasks'),
            Tab(text: 'Notes'),
            Tab(text: 'Sessions'),
          ],
        ),
        actions: [
          if (sessions.hasActiveSession &&
              sessions.activeSession?.projectId == widget.projectId)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.stop, color: AppTheme.errorColor),
                label: Text(
                  sessions.activeSession!.formattedDuration,
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
                onPressed: () => sessions.stopSession(sessions.activeSession!.id),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.play_arrow, color: AppTheme.secondaryColor),
                label: const Text('Track', style: TextStyle(color: AppTheme.secondaryColor)),
                onPressed: _startSession,
              ),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TasksTab(projectId: widget.projectId),
          _NotesTab(projectId: widget.projectId, parentType: 'project'),
          _SessionsTab(projectId: widget.projectId),
        ],
      ),
    );
  }
}

// ─── Tasks Tab ────────────────────────────────────────────────────────────────

class _TasksTab extends StatelessWidget {
  final String projectId;

  const _TasksTab({required this.projectId});

  void _showTaskForm(BuildContext context, {TaskModel? task}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TaskFormSheet(projectId: projectId, task: task),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<ProjectProvider>().tasksForProject(projectId);

    return tasks.isEmpty
        ? Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.task_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('No tasks yet'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Task'),
                        onPressed: () => _showTaskForm(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        : Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _TaskTile(
                      task: task,
                      projectId: projectId,
                      onEdit: () => _showTaskForm(context, task: task),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Task'),
                    onPressed: () => _showTaskForm(context),
                  ),
                ),
              ),
            ],
          );
  }
}

class _TaskTile extends StatelessWidget {
  final TaskModel task;
  final String projectId;
  final VoidCallback onEdit;

  const _TaskTile({required this.task, required this.projectId, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.check_circle_outline, color: AppTheme.primaryColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.name, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                  if (task.description.isNotEmpty)
                    Text(task.description, style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    )),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'delete') {
                  context.read<ProjectProvider>().deleteTask(task.id, projectId);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.errorColor))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskFormSheet extends StatefulWidget {
  final String projectId;
  final TaskModel? task;
  const _TaskFormSheet({required this.projectId, this.task});

  @override
  State<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<_TaskFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.task?.name ?? '');
    _descCtrl = TextEditingController(text: widget.task?.description ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final provider = context.read<ProjectProvider>();
    bool success;
    if (widget.task != null) {
      success = await provider.updateTask(
        widget.task!.id, widget.projectId,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
      );
    } else {
      final result = await provider.createTask(
        projectId: widget.projectId,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
      );
      success = result != null;
    }
    if (mounted) {
      setState(() => _loading = false);
      if (success) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.task != null ? 'Edit Task' : 'New Task',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Task Name'),
              validator: (v) => v?.isEmpty ?? true ? 'Name is required' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.task != null ? 'Save' : 'Create Task'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Notes Tab ────────────────────────────────────────────────────────────────

class _NotesTab extends StatelessWidget {
  final String projectId;
  final String parentType;

  const _NotesTab({required this.projectId, required this.parentType});

  void _showAddNote(BuildContext context) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Note', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Note', hintText: 'Write your note here...'),
              maxLines: 5,
              autofocus: true,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (ctrl.text.trim().isEmpty) return;
                  await context.read<ProjectProvider>().createNote(
                    content: ctrl.text.trim(),
                    parentId: projectId,
                    parentType: parentType,
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

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<ProjectProvider>().notesForParent(projectId);
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notes_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('No notes yet'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Note'),
                        onPressed: () => _showAddNote(context),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final note = notes[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
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
                                    DateFormat('MMM d, y h:mm a').format(note.createdAt),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor, size: 18),
                              onPressed: () => context.read<ProjectProvider>().deleteNote(note.id, projectId),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Note'),
              onPressed: () => _showAddNote(context),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Sessions Tab ─────────────────────────────────────────────────────────────

class _SessionsTab extends StatelessWidget {
  final String projectId;

  const _SessionsTab({required this.projectId});

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionProvider>().completedSessions
        .where((s) => s.projectId == projectId)
        .toList();
    final theme = Theme.of(context);

    if (sessions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No sessions yet. Use the Track button above.'),
          ],
        ),
      );
    }

    final totalTime = sessions.fold<Duration>(Duration.zero, (acc, s) => acc + s.duration);
    final hours = totalTime.inHours;
    final minutes = totalTime.inMinutes.remainder(60);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatPill(label: 'Sessions', value: '${sessions.length}'),
              _StatPill(label: 'Total Time', value: '${hours}h ${minutes}m'),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final session = sessions[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.timer_outlined, color: AppTheme.warningColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('MMM d, y').format(session.startTime),
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${DateFormat('h:mm a').format(session.startTime)} – ${session.endTime != null ? DateFormat('h:mm a').format(session.endTime!) : 'ongoing'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        session.formattedDuration,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
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
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}
