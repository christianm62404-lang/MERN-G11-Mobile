import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/session_provider.dart';
import '../../providers/project_provider.dart';
import '../../utils/app_theme.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessions = context.watch<SessionProvider>();
    final projects = context.watch<ProjectProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: sessions.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary stats
                    _SummarySection(sessions: sessions),
                    const SizedBox(height: 24),

                    // Time by project bar chart
                    if (sessions.completedSessions.isNotEmpty) ...[
                      Text(
                        'Time by Project',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      _TimeByProjectChart(sessions: sessions, projects: projects),
                      const SizedBox(height: 12),
                      _ProjectBreakdownList(sessions: sessions, projects: projects),
                      const SizedBox(height: 24),

                      // Activity heatmap
                      Text(
                        'Daily Activity (Last 30 Days)',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      _ActivityHeatmap(sessions: sessions),
                      const SizedBox(height: 24),

                      // Weekly trend
                      Text(
                        'Weekly Trend',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      _WeeklyTrendChart(sessions: sessions),
                    ] else
                      const _NoDataCard(),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final SessionProvider sessions;
  const _SummarySection({required this.sessions});

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = sessions.completedSessions;

    final totalTime = completed.fold<Duration>(Duration.zero, (a, s) => a + s.duration);

    final thisWeek = completed.where((s) {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      return s.startTime.isAfter(weekStart);
    }).toList();
    final weekTime = thisWeek.fold<Duration>(Duration.zero, (a, s) => a + s.duration);

    final avgDuration = completed.isEmpty
        ? Duration.zero
        : Duration(
            seconds: completed.fold(0, (a, s) => a + s.duration.inSeconds) ~/
                completed.length,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Summary',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _InsightCard(title: 'Total Time', value: _fmt(totalTime), icon: Icons.schedule_outlined, color: AppTheme.primaryColor),
            _InsightCard(title: 'This Week', value: _fmt(weekTime), icon: Icons.date_range_outlined, color: AppTheme.secondaryColor),
            _InsightCard(title: 'Sessions', value: '${completed.length}', icon: Icons.timer_outlined, color: AppTheme.warningColor),
            _InsightCard(title: 'Avg Session', value: _fmt(avgDuration), icon: Icons.timelapse_outlined, color: AppTheme.primaryDark),
          ],
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _InsightCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 22),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeByProjectChart extends StatelessWidget {
  final SessionProvider sessions;
  final ProjectProvider projects;

  const _TimeByProjectChart({required this.sessions, required this.projects});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byProject = sessions.durationByProject;

    if (byProject.isEmpty) return const SizedBox.shrink();

    final sorted = byProject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();

    final colors = [
      AppTheme.primaryColor,
      AppTheme.secondaryColor,
      AppTheme.warningColor,
      AppTheme.primaryDark,
      Colors.purple,
    ];

    String projectName(String id) {
      try {
        return projects.projects.firstWhere((p) => p.id == id).title;
      } catch (_) {
        return 'Unknown';
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: top.first.value.inMinutes.toDouble() * 1.2,
                  barGroups: top.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.value.inMinutes.toDouble(),
                          color: colors[e.key % colors.length],
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}m',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= top.length) return const SizedBox.shrink();
                          final name = projectName(top[index].key);
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              name.length > 8 ? '${name.substring(0, 6)}…' : name,
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.dividerColor,
                      strokeWidth: 0.5,
                    ),
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

class _ActivityHeatmap extends StatelessWidget {
  final SessionProvider sessions;

  const _ActivityHeatmap({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final activity = sessions.dailyActivity;

    // Build last 35 days
    final days = List.generate(35, (i) {
      final d = now.subtract(Duration(days: 34 - i));
      return DateTime(d.year, d.month, d.day);
    });

    // Find max minutes for color scaling
    final maxMinutes = activity.values.isEmpty
        ? 1
        : activity.values
              .map((d) => d.inMinutes)
              .reduce((a, b) => a > b ? a : b)
              .clamp(1, 999);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                childAspectRatio: 1,
              ),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                final duration = activity[day];
                final intensity = duration != null
                    ? (duration.inMinutes / maxMinutes).clamp(0.15, 1.0)
                    : 0.0;

                return Tooltip(
                  message: duration != null
                      ? '${DateFormat('MMM d').format(day)}: ${duration.inHours}h ${duration.inMinutes.remainder(60)}m'
                      : DateFormat('MMM d').format(day),
                  child: Container(
                    decoration: BoxDecoration(
                      color: intensity > 0
                          ? AppTheme.secondaryColor.withOpacity(intensity)
                          : theme.colorScheme.onSurface.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Less', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5))),
                Row(
                  children: [0.1, 0.3, 0.5, 0.7, 1.0].map((v) => Container(
                    width: 12, height: 12,
                    margin: const EdgeInsets.only(left: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(v),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )).toList(),
                ),
                Text('More', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyTrendChart extends StatelessWidget {
  final SessionProvider sessions;

  const _WeeklyTrendChart({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    // Last 7 days
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    final activity = sessions.dailyActivity;

    final spots = days.asMap().entries.map((e) {
      final duration = activity[e.value];
      return FlSpot(e.key.toDouble(), (duration?.inMinutes ?? 0).toDouble());
    }).toList();

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY > 0 ? maxY * 1.2 : 60,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppTheme.primaryColor,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                      radius: 4,
                      color: AppTheme.primaryColor,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppTheme.primaryColor.withOpacity(0.1),
                  ),
                ),
              ],
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, _) {
                      final i = value.toInt();
                      if (i >= days.length) return const SizedBox.shrink();
                      return Text(
                        DateFormat('EEE').format(days[i]),
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, _) => Text(
                      '${value.toInt()}m',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: theme.dividerColor,
                  strokeWidth: 0.5,
                ),
              ),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectBreakdownList extends StatelessWidget {
  final SessionProvider sessions;
  final ProjectProvider projects;
  const _ProjectBreakdownList({required this.sessions, required this.projects});

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byProject = sessions.durationByProject;
    if (byProject.isEmpty) return const SizedBox.shrink();

    final sorted = byProject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<int>(0, (a, b) => a + b.value.inMinutes);

    String projectName(String id) {
      try {
        return projects.projects.firstWhere((p) => p.id == id).title;
      } catch (_) {
        return 'Unknown';
      }
    }

    final colors = [
      AppTheme.primaryColor,
      AppTheme.secondaryColor,
      AppTheme.warningColor,
      AppTheme.primaryDark,
      Colors.purple,
    ];

    return Column(
      children: sorted.asMap().entries.take(5).map((e) {
        final projectId = e.value.key;
        final dur = e.value.value;
        final pct = total > 0 ? dur.inMinutes / total : 0.0;
        final color = colors[e.key % colors.length];
        final name = projectName(projectId);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push(
              Uri(
                path: '/insights/project/$projectId',
                queryParameters: {'title': name},
              ).toString(),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 4,
                            backgroundColor:
                                theme.colorScheme.onSurface.withOpacity(0.08),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_fmt(dur),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text('${(pct * 100).toStringAsFixed(0)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.5))),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right,
                      size: 18,
                      color: theme.colorScheme.onSurface.withOpacity(0.3)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _NoDataCard extends StatelessWidget {
  const _NoDataCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.bar_chart_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No data yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Start tracking sessions to see insights',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
