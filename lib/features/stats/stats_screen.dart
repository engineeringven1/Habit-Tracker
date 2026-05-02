import 'dart:ui' show ImageFilter;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/premium_gate.dart';
import '../../shared/widgets/stat_insight_chip.dart';
import '../tracker/tracker_providers.dart';
import 'stats_providers.dart';

// ─── Category colour map ──────────────────────────────────────────────────────

final _catColors = {
  'disciplina': AppColors.primaryAccent,
  'trabajo': AppColors.secondaryAccent,
  'finanzas': AppColors.warningColor,
  'salud': AppColors.successColor,
  'mente': Color(0xFF8B5CF6),
  'nutrición': Color(0xFFF97316),
  'restricción': AppColors.dangerColor,
};

Color _catColor(String cat) =>
    _catColors[cat] ?? AppColors.textSecondary;

// ─── Root screen ──────────────────────────────────────────────────────────────

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeksAsync = ref.watch(weeklyProgressProvider);
    final heroAsync = ref.watch(heroWeekProvider);
    final habitsAsync = ref.watch(habitsProvider);
    final gridAsync = ref.watch(sevenDayGridProvider);
    final streakAsync = ref.watch(bestStreakProvider);
    final top5StreaksAsync = ref.watch(top5StreaksProvider);
    final topAsync = ref.watch(topHabitsProvider);
    final bottomAsync = ref.watch(bottomHabitsProvider);
    final catAsync = ref.watch(categoryStatsProvider);
    final patternAsync = ref.watch(weekdayPatternProvider);
    final perfectAsync = ref.watch(perfectDaysProvider);
    final avgAsync = ref.watch(avg30Provider);
    final completionTimeAsync = ref.watch(completionTimeProvider);
    final failureWeekdayAsync = ref.watch(failureByWeekdayProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App bar ─────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppColors.backgroundBase,
            surfaceTintColor: Colors.transparent,
            pinned: false,
            floating: true,
            automaticallyImplyLeading: false,
            title: Text(
              'Estadísticas',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── 1. Hero week card ──────────────────────────────────
                heroAsync.when(
                  data: (h) => _HeroWeekCard(stats: h)
                      .animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
                  loading: () => const _Skeleton(height: 180),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                heroAsync.when(
                  data: (h) => StatInsightChip(
                    statId: 'weekly_progress',
                    data: {
                      'yesterday_pct': h.current.pct.round(),
                      'avg7': h.current.pct.round(),
                    },
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 14),

                // ── 2. KPI chips row ───────────────────────────────────
                _KpiRow(
                  weeksAsync: weeksAsync,
                  perfectAsync: perfectAsync,
                  avgAsync: avgAsync,
                ).animate().fadeIn(delay: 80.ms, duration: 400.ms),
                const SizedBox(height: 14),

                // ── 2b. Streak hero card ───────────────────────────────
                streakAsync.when(
                  data: (s) => s == null
                      ? const SizedBox.shrink()
                      : _StreakHeroCard(streak: s)
                          .animate()
                          .fadeIn(delay: 100.ms, duration: 400.ms)
                          .slideY(begin: 0.1),
                  loading: () => const _Skeleton(height: 120),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 14),

                // ── 3. 12-week bar chart ───────────────────────────────
                weeksAsync.when(
                  data: (w) => w.isEmpty
                      ? const SizedBox.shrink()
                      : _WeeklyBarChart(weeks: w)
                          .animate()
                          .fadeIn(delay: 120.ms, duration: 400.ms),
                  loading: () => const _Skeleton(height: 230),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 14),

                // ── 4. Day-of-week pattern ─────────────────────────────
                patternAsync.when(
                  data: (p) => _WeekdayCard(pattern: p)
                      .animate()
                      .fadeIn(delay: 160.ms, duration: 400.ms),
                  loading: () => const _Skeleton(height: 160),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 14),

                // ── 4b. Failure by weekday ────────────────────────────
                failureWeekdayAsync.when(
                  data: (d) => _FailureByWeekdayCard(data: d)
                      .animate()
                      .fadeIn(delay: 195.ms, duration: 400.ms),
                  loading: () => const _Skeleton(height: 220),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 14),

                // ── 4c. Completion time distribution ──────────────────
                completionTimeAsync.when(
                  data: (buckets) {
                    final hasData = buckets.any((b) => b.count > 0);
                    return hasData
                        ? _CompletionTimeCard(buckets: buckets)
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 400.ms)
                        : const SizedBox.shrink();
                  },
                  loading: () => const _Skeleton(height: 200),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 14),

                // ── 5. Category breakdown ──────────────────────────────
                catAsync.when(
                  data: (cats) => _CategoryCard(stats: cats)
                      .animate()
                      .fadeIn(delay: 240.ms, duration: 400.ms),
                  loading: () => const _Skeleton(height: 200),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 14),

                // ── 6. Radar by category ──────────────────────────────
                catAsync.when(
                  data: (cats) => cats.length < 3
                      ? const SizedBox.shrink()
                      : _RadarCategoryCard(stats: cats)
                          .animate()
                          .fadeIn(delay: 260.ms, duration: 400.ms),
                  loading: () => const _Skeleton(height: 360),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 14),

                // ── 8. Top habits ──────────────────────────────────────
                topAsync.when(
                  data: (top) => _HabitRankCard(
                    title: 'Top hábitos',
                    subtitle: 'Mejores 30 días',
                    icon: Icons.star_rounded,
                    iconColor: AppColors.warningColor,
                    items: top,
                    isTop: true,
                  ).animate().fadeIn(delay: 280.ms, duration: 400.ms),
                  loading: () => const _Skeleton(height: 220),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 14),

                // ── 8. Bottom habits ───────────────────────────────────
                bottomAsync.when(
                  data: (bot) => _HabitRankCard(
                    title: 'Necesitan atención',
                    subtitle: 'Menor cumplimiento',
                    icon: Icons.flag_rounded,
                    iconColor: AppColors.dangerColor,
                    items: bot,
                    isTop: false,
                  ).animate().fadeIn(delay: 320.ms, duration: 400.ms),
                  loading: () => const _Skeleton(height: 220),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 14),

                // ── 9. Top 5 streaks ───────────────────────────────────
                top5StreaksAsync.when(
                  data: (items) => items.isEmpty
                      ? const SizedBox.shrink()
                      : _TopStreaksCard(items: items)
                          .animate()
                          .fadeIn(delay: 340.ms, duration: 400.ms),
                  loading: () => const _Skeleton(height: 200),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 14),

                // ── 10. 7-day habit grid ───────────────────────────────
                _sectionLabel('Últimos 7 días'),
                habitsAsync.when(
                  data: (habits) => gridAsync.when(
                    data: (grid) => _SevenDayGrid(
                            habits: habits, grid: grid)
                        .animate()
                        .fadeIn(delay: 360.ms, duration: 400.ms),
                    loading: () => const _Skeleton(height: 100),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  loading: () => const _Skeleton(height: 100),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          t.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
            color: AppColors.textSecondary,
          ),
        ),
      );
}

// ─── 1. Hero week card ────────────────────────────────────────────────────────

class _HeroWeekCard extends StatelessWidget {
  final ({WeekStats current, WeekStats? prev}) stats;
  const _HeroWeekCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cur = stats.current;
    final pct = cur.pct;
    final done = cur.completed;
    final total = cur.total;
    final double? delta = stats.prev != null ? pct - stats.prev!.pct : null;
    final progress = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.gradientPrimary,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryAccent.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Últimos 7 días',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                          letterSpacing: 0.5,
                        )),
                    const SizedBox(height: 6),
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$done de $total hábitos·día',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              _MiniRing(value: progress),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 12),
            _DeltaBadge(delta: delta),
          ],
        ],
      ),
    );
  }
}

class _MiniRing extends StatelessWidget {
  final double value;
  const _MiniRing({required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: 1,
            strokeWidth: 7,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          CircularProgressIndicator(
            value: value,
            strokeWidth: 7,
            backgroundColor: Colors.transparent,
            valueColor:
                const AlwaysStoppedAnimation<Color>(Colors.white),
            strokeCap: StrokeCap.round,
          ),
        ],
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  final double delta;
  const _DeltaBadge({required this.delta});

  @override
  Widget build(BuildContext context) {
    final up = delta > 0;
    final eq = delta == 0;
    final color = eq
        ? Colors.white.withValues(alpha: 0.5)
        : up
            ? AppColors.successColor
            : AppColors.dangerColor;
    final icon = eq
        ? Icons.remove_rounded
        : up
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded;
    final label = eq
        ? 'Sin cambio vs semana anterior'
        : '${up ? '+' : ''}${delta.toStringAsFixed(1)}% vs semana anterior';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── 2. KPI row ───────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> weeksAsync;
  final AsyncValue<int> perfectAsync;
  final AsyncValue<double> avgAsync;

  const _KpiRow({
    required this.weeksAsync,
    required this.perfectAsync,
    required this.avgAsync,
  });

  @override
  Widget build(BuildContext context) {
    final perfect = perfectAsync.value ?? 0;
    final avg = avgAsync.value ?? 0;
    final weeks = weeksAsync.value;
    final weekCount = weeks?.length ?? 0;

    return Row(
      children: [
        _KpiChip(
          icon: Icons.workspace_premium_rounded,
          label: 'Días perfectos',
          value: '$perfect',
          sub: 'últimos 30 días',
          accent: AppColors.warningColor,
        ),
        const SizedBox(width: 10),
        _KpiChip(
          icon: Icons.insights_rounded,
          label: 'Prom. 30 días',
          value: '${(avg * 100).toStringAsFixed(0)}%',
          sub: 'cumplimiento diario',
          accent: AppColors.secondaryAccent,
        ),
        const SizedBox(width: 10),
        _KpiChip(
          icon: Icons.calendar_month_rounded,
          label: 'Semanas',
          value: '$weekCount',
          sub: 'con registro',
          accent: AppColors.primaryAccent,
        ),
      ],
    );
  }
}

class _KpiChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color accent;

  const _KpiChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: accent.withValues(alpha: 0.15), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: accent),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (sub != null)
              Text(
                sub!,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: AppColors.textSecondary.withValues(alpha: 0.65),
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── 2b. Streak hero card ─────────────────────────────────────────────────────

class _StreakHeroCard extends StatelessWidget {
  final (String, int) streak;
  const _StreakHeroCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    final name = streak.$1;
    final days = streak.$2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEA580C), Color(0xFFF97316)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF97316).withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hábito con más días seguidos',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$days',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7, left: 6),
                      child: Text(
                        days == 1 ? 'día' : 'días',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              size: 36,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 3. 12-week bar chart ─────────────────────────────────────────────────────

class _WeeklyBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> weeks;
  const _WeeklyBarChart({required this.weeks});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: 'Progreso semanal',
            subtitle: weeks.length == 1 ? 'Última 1 semana' : 'Últimas ${weeks.length} semanas',
            icon: Icons.bar_chart_rounded,
            iconColor: AppColors.primaryAccent,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final minWidth = constraints.maxWidth;
              final scrollWidth = weeks.length * 22.0;
              final chartWidth = scrollWidth > minWidth ? scrollWidth : minWidth;
              return SizedBox(
                height: 150,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartWidth,
                    child: BarChart(
                      _chartData(),
                      swapAnimationDuration: const Duration(milliseconds: 700),
                      swapAnimationCurve: Curves.easeOutCubic,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _Legend(color: AppColors.primaryAccent, label: 'Semanas anteriores'),
              const SizedBox(width: 14),
              _Legend(color: AppColors.secondaryAccent, label: 'Esta semana'),
            ],
          ),
        ],
      ),
    );
  }

  BarChartData _chartData() {
    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: 100,
      minY: 0,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => AppColors.surfaceElevated,
          tooltipRoundedRadius: 10,
          getTooltipItem: (group, _, rod, _) => BarTooltipItem(
            '${rod.toY.toStringAsFixed(0)}%',
            GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 25,
        getDrawingHorizontalLine: (_) => FlLine(
          color: AppColors.textSecondary.withValues(alpha: 0.08),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (v, meta) {
              final idx = v.toInt();
              final isCurrent = idx == weeks.length - 1;
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(
                  isCurrent ? 'HOY' : 'S${idx + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight:
                        isCurrent ? FontWeight.w700 : FontWeight.w400,
                    color: isCurrent
                        ? AppColors.secondaryAccent
                        : AppColors.textSecondary,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups: List.generate(weeks.length, (i) {
        final isCurrent = i == weeks.length - 1;
        final val =
            (weeks[i]['score_percentage'] as num? ?? 0).toDouble();
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              width: 10,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
              gradient: isCurrent
                  ? LinearGradient(
                      colors: AppColors.gradientAccent,
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    )
                  : LinearGradient(
                      colors: AppColors.gradientPrimary,
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
            ),
          ],
        );
      }),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ─── 4. Day-of-week pattern ───────────────────────────────────────────────────

class _WeekdayCard extends StatelessWidget {
  final List<double> pattern; // 0=Mon … 6=Sun
  const _WeekdayCard({required this.pattern});

  static const _days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  Widget build(BuildContext context) {
    final maxVal = pattern.reduce((a, b) => a > b ? a : b);
    final bestIdx = pattern.indexOf(maxVal);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: 'Patrón semanal',
            subtitle: 'Por día de la semana (52 semanas)',
            icon: Icons.calendar_view_week_rounded,
            iconColor: AppColors.secondaryAccent,
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final val = pattern[i];
              final isBest = i == bestIdx;
              final barH = maxVal == 0 ? 2.0 : (val / maxVal) * 80;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    children: [
                      Text(
                        '${(val * 100).round()}%',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isBest
                              ? AppColors.secondaryAccent
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        height: barH.clamp(4.0, 80.0),
                        decoration: BoxDecoration(
                          gradient: isBest
                              ? LinearGradient(
                                  colors: AppColors.gradientAccent,
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                )
                              : LinearGradient(
                                  colors: [
                                    AppColors.primaryAccent
                                        .withValues(alpha: 0.4),
                                    AppColors.primaryAccent
                                        .withValues(alpha: 0.7),
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _days[i],
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: isBest
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isBest
                              ? AppColors.secondaryAccent
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── 5. Category breakdown ────────────────────────────────────────────────────

class _CategoryCard extends ConsumerWidget {
  final List<CategoryStat> stats;
  const _CategoryCard({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendMap = ref.watch(categoryWeekTrendProvider).value ?? {};

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: 'Por categoría',
            subtitle: 'Promedio últimos 30 días',
            icon: Icons.donut_small_rounded,
            iconColor: AppColors.warningColor,
          ),
          const SizedBox(height: 16),
          ...stats.map((s) => _CategoryRow(
                stat: s,
                trend: trendMap[s.category],
              )),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategoryStat stat;
  final CategoryTrend? trend;
  const _CategoryRow({required this.stat, this.trend});

  Widget _deltaChip() {
    final t = trend;
    if (t == null || t.current == null || t.prev == null) {
      return Text('—',
          style: GoogleFonts.inter(
              fontSize: 12, color: AppColors.textSecondary));
    }
    final delta = ((t.current! - t.prev!) * 100).round();
    if (delta.abs() < 2) {
      return Icon(Icons.arrow_forward_rounded,
          size: 13, color: AppColors.textSecondary);
    }
    final up = delta > 0;
    final color = up ? AppColors.successColor : AppColors.dangerColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 1),
        Text(
          '${delta > 0 ? '+' : ''}${delta}pp',
          style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _catColor(stat.category);
    final pct = (stat.rate * 100).round();
    final hasTrend =
        trend != null && trend!.fourWeeks.any((v) => v != null);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hasTrend
          ? () => showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => _CategoryTrendSheet(
                  category: stat.category,
                  color: color,
                  trend: trend!,
                ),
              )
          : null,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 36,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _capitalize(stat.category),
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary),
                        ),
                      ),
                      _deltaChip(),
                      const SizedBox(width: 8),
                      Text(
                        '$pct%',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: stat.rate.clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: color.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            ),
            if (hasTrend)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.textSecondary.withValues(alpha: 0.4)),
              ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─── Category trend sheet ─────────────────────────────────────────────────────

class _CategoryTrendSheet extends StatelessWidget {
  final String category;
  final Color color;
  final CategoryTrend trend;

  const _CategoryTrendSheet({
    required this.category,
    required this.color,
    required this.trend,
  });

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final weeks = trend.fourWeeks;
    final spots = <FlSpot>[
      for (int i = 0; i < weeks.length; i++)
        if (weeks[i] != null) FlSpot(i.toDouble(), weeks[i]! * 100),
    ];

    const labels = ['Sem -3', 'Sem -2', 'Sem ant.', 'Esta sem.'];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.show_chart_rounded, size: 17, color: color),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _capitalize(category),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Evolución últimas 4 semanas',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (spots.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Sin datos para este período',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.surfaceElevated,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 3,
                  minY: 0,
                  maxY: 100,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: 25,
                        getTitlesWidget: (v, _) => Text(
                          '${v.toInt()}%',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, _) {
                          final i = v.round();
                          if (i < 0 || i >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              labels[i],
                              style: GoogleFonts.inter(
                                  fontSize: 9,
                                  color: i == 3
                                      ? color
                                      : AppColors.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: spots.length > 2,
                      curveSmoothness: 0.3,
                      color: color,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, _, _) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: color,
                          strokeWidth: 2,
                          strokeColor: AppColors.surfaceCard,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── 7 & 8. Habit rank cards (top / bottom) ───────────────────────────────────

class _HabitRankCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final List<HabitRate> items;
  final bool isTop;

  const _HabitRankCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.items,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
              title: title,
              subtitle: subtitle,
              icon: icon,
              iconColor: iconColor),
          const SizedBox(height: 14),
          ...List.generate(items.length, (i) {
            final item = items[i];
            final pct = (item.rate * 100).round();
            final color = isTop
                ? AppColors.successColor
                : pct >= 50
                    ? AppColors.warningColor
                    : AppColors.dangerColor;
            final catColor = _catColor(item.habit.category);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: catColor),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.habit.name,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: item.rate.clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor:
                                color.withValues(alpha: 0.12),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$pct%',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Top 5 streaks card ───────────────────────────────────────────────────────

class _TopStreaksCard extends StatelessWidget {
  final List<HabitStreak> items;
  const _TopStreaksCard({required this.items});

  static const _medals = ['🥇', '🥈', '🥉'];
  static const _flameColor = Color(0xFFF97316);

  @override
  Widget build(BuildContext context) {
    final maxStreak = items.isEmpty ? 1 : items.first.streak;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: 'Constancia Récord',
            subtitle: 'Top 5 hábitos con más días seguidos',
            icon: Icons.local_fire_department_rounded,
            iconColor: _flameColor,
          ),
          const SizedBox(height: 16),
          ...List.generate(items.length, (i) {
            final item = items[i];
            final ratio = item.streak / maxStreak;
            final isTop3 = i < 3;
            final badgeLabel = isTop3 ? _medals[i] : '${i + 1}';
            final catColor = _catColor(item.habit.category);

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      badgeLabel,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: isTop3 ? 18 : 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.habit.name,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 14,
                                  color: _flameColor,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${item.streak}d',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _flameColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 5,
                            backgroundColor: catColor.withValues(alpha: 0.12),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(catColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── 9. 7-day compliance grid ─────────────────────────────────────────────────

class _SevenDayGrid extends StatelessWidget {
  final List<dynamic> habits;
  final Map<String, List<bool?>> grid;

  const _SevenDayGrid({required this.habits, required this.grid});

  static const _dayAbbr = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  Widget build(BuildContext context) {
    if (habits.isEmpty) return const SizedBox.shrink();

    final today = DateTime.now();
    // Column i corresponds to today - (7 - i) days, i.e. the last 7 days excl. today.
    final colDates = List.generate(7, (i) => today.subtract(Duration(days: 7 - i)));

    return _Card(
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox()),
              ...List.generate(
                7,
                (i) => Expanded(
                  child: Center(
                    child: Text(
                      _dayAbbr[colDates[i].weekday - 1],
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 36),
            ],
          ),
          const SizedBox(height: 8),
          ...habits.map((h) {
            final days = grid[h.id] ?? List<bool?>.filled(7, null);
            final done = days.where((d) => d == true).length;
            final scheduled = days.where((d) => d != null).length;
            final pct = scheduled == 0 ? 0 : (done / scheduled * 100).round();
            final color = _catColor(h.category);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      h.name,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ),
                  ...List.generate(7, (i) {
                    final state = days[i]; // true=done, false=pending, null=no programado
                    return Expanded(
                      child: Center(
                        child: state == null
                            ? Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated
                                      .withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                              )
                            : Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: state
                                      ? color
                                      : AppColors.surfaceElevated,
                                  shape: BoxShape.circle,
                                  boxShadow: state
                                      ? [
                                          BoxShadow(
                                            color: color.withValues(alpha: 0.4),
                                            blurRadius: 4,
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                      ),
                    );
                  }),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$pct%',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: done >= 5
                            ? AppColors.successColor
                            : done >= 3
                                ? AppColors.warningColor
                                : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── 6. Radar by category ────────────────────────────────────────────────────

class _RadarCategoryCard extends StatelessWidget {
  final List<CategoryStat> stats;
  const _RadarCategoryCard({required this.stats});

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _insight() {
    final sorted = [...stats]..sort((a, b) => a.rate.compareTo(b.rate));
    final worst = sorted.first;
    final best1 = sorted.last;
    final best2 = sorted.length > 1 ? sorted[sorted.length - 2] : null;
    final worstPct = (worst.rate * 100).round();

    String text =
        '${_capitalize(worst.category)} ($worstPct%) es el vértice colapsado. ';
    if (best2 != null) {
      text +=
          '${_capitalize(best1.category)} y ${_capitalize(best2.category)} en el polo superior. ';
    }
    text +=
        'El polígono asimétrico señala dónde asignar el próximo ciclo de atención.';
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final maxPct = stats
        .map((s) => s.rate * 100)
        .reduce((a, b) => a > b ? a : b);
    const tickStep = 5.0;
    final tickCount = (maxPct / tickStep).ceil().clamp(2, 10);
    final chartMax = tickCount * tickStep;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: 'Radar por categoría',
            subtitle:
                'Cumplimiento promedio últimos 30 días · ${stats.length} dimensiones',
            icon: Icons.radar_rounded,
            iconColor: AppColors.primaryAccent,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: RadarChart(
              RadarChartData(
                dataSets: [
                  // Invisible dataset that forces the axis max to chartMax
                  RadarDataSet(
                    dataEntries: List.generate(
                        stats.length, (_) => RadarEntry(value: chartMax)),
                    borderColor: Colors.transparent,
                    fillColor: Colors.transparent,
                    borderWidth: 0,
                    entryRadius: 0,
                  ),
                  RadarDataSet(
                    dataEntries: stats
                        .map((s) => RadarEntry(value: s.rate * 100))
                        .toList(),
                    borderColor: AppColors.primaryAccent,
                    fillColor:
                        AppColors.primaryAccent.withValues(alpha: 0.2),
                    borderWidth: 2,
                    entryRadius: 4,
                  ),
                ],
                radarShape: RadarShape.polygon,
                radarBorderData: BorderSide(
                  color: AppColors.textSecondary.withValues(alpha: 0.2),
                  width: 1,
                ),
                titleTextStyle: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                titlePositionPercentageOffset: 0.2,
                getTitle: (index, angle) {
                  final s = stats[index];
                  return RadarChartTitle(
                    text:
                        '${_capitalize(s.category)}\n${(s.rate * 100).round()}%',
                    angle: 0,
                  );
                },
                tickCount: tickCount,
                ticksTextStyle: GoogleFonts.inter(
                  fontSize: 8,
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                ),
                tickBorderData: BorderSide(
                  color: AppColors.textSecondary.withValues(alpha: 0.1),
                  width: 1,
                ),
                gridBorderData: BorderSide(
                  color: AppColors.textSecondary.withValues(alpha: 0.1),
                  width: 1,
                ),
                radarBackgroundColor: Colors.transparent,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    size: 15, color: AppColors.warningColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _insight(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 4b. Completion time distribution card ────────────────────────────────────

class _CompletionTimeCard extends StatelessWidget {
  final List<TimeBucket> buckets;
  const _CompletionTimeCard({required this.buckets});

  static const _colors = [
    Color(0xFF60A5FA), // Madrugada  – blue
    Color(0xFFFBBF24), // Mañana     – amber
    Color(0xFFF97316), // Tarde      – orange
    Color(0xFFEC4899), // Atardecer  – pink
    Color(0xFF8B5CF6), // Noche      – purple
  ];

  String _insight() {
    final total = buckets.fold(0, (s, b) => s + b.count);
    if (total == 0) return 'Completa hábitos para ver tu distribución horaria.';

    int peakIdx = 0;
    for (int i = 1; i < buckets.length; i++) {
      if (buckets[i].count > buckets[peakIdx].count) peakIdx = i;
    }
    final peak = buckets[peakIdx];
    final peakPct = (peak.pct * 100).round();
    final morningPct = ((buckets[0].pct + buckets[1].pct) * 100).round();

    switch (peakIdx) {
      case 0:
      case 1:
        return '$morningPct% de tus completaciones ocurren antes del mediodía. '
            'Ventana de máxima ejecución: ${peak.timeRange}. '
            'Trátala como terreno estratégico irrenunciable.';
      case 2:
        return 'Tu pico de rendimiento está en la tarde. '
            '$peakPct% de hábitos se completan entre ${peak.timeRange}.';
      case 3:
        return 'Prefieres terminar el día fuerte. '
            '$peakPct% de completaciones entre ${peak.timeRange}. '
            'No cedas a la fatiga de final de día.';
      default:
        return 'Eres nocturno por excelencia: $peakPct% de tus hábitos se '
            'cumplen después de las 9 pm. Vigila el descanso.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = buckets.fold(0, (s, b) => s + b.count);
    final subtitle = total == 0
        ? 'Sin datos con timestamp aún'
        : 'Basado en $total completaciones registradas';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: 'Hora de completación',
            subtitle: subtitle,
            icon: Icons.access_time_rounded,
            iconColor: AppColors.primaryAccent,
          ),
          const SizedBox(height: 18),
          ...List.generate(buckets.length, (i) {
            final b = buckets[i];
            final color = _colors[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          b.timeRange,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: b.pct,
                        minHeight: 10,
                        backgroundColor: color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '${(b.pct * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    size: 15, color: AppColors.warningColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _insight(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared building blocks ───────────────────────────────────────────────────

// ─── Failure by weekday card ──────────────────────────────────────────────────

class _FailureByWeekdayCard extends StatelessWidget {
  final FailureWeekdayData data;
  const _FailureByWeekdayCard({required this.data});

  static const _dayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _dayNames = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  Color _barColor(double rate) {
    if (rate < 0.20) return AppColors.successColor;
    if (rate < 0.50) return AppColors.warningColor;
    return AppColors.dangerColor;
  }

  @override
  Widget build(BuildContext context) {
    final maxRate = data.days.fold(0.0, (m, d) => d.failureRate > m ? d.failureRate : m);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: '¿Cuándo fallas más?',
            subtitle: 'Tasa de fallo por día · últimos 30 días',
            icon: Icons.trending_down_rounded,
            iconColor: AppColors.dangerColor,
          ),
          const SizedBox(height: 18),
          if (!data.hasEnoughData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Necesitas al menos 2 semanas de datos para esta estadística.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ...data.days.map((d) {
              final label = _dayLabels[d.weekday - 1];
              final rate = d.failureRate;
              final barColor = _barColor(rate);
              final tappable = d.worst.isNotEmpty;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: tappable
                    ? () => showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _FailureDaySheet(
                            dayName: _dayNames[d.weekday - 1],
                            stats: d,
                          ),
                        )
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Stack(
                            children: [
                              Container(height: 26, color: AppColors.surfaceElevated),
                              FractionallySizedBox(
                                widthFactor: maxRate == 0
                                    ? 0
                                    : (rate / maxRate).clamp(0.0, 1.0),
                                child: Container(
                                  height: 26,
                                  color: barColor.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${(rate * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: barColor,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 20,
                        child: tappable
                            ? Icon(
                                Icons.chevron_right_rounded,
                                size: 15,
                                color: AppColors.textSecondary.withValues(alpha: 0.4),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _FailureDaySheet extends StatelessWidget {
  final String dayName;
  final WeekdayFailInfo stats;

  const _FailureDaySheet({required this.dayName, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.dangerColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.trending_down_rounded,
                    size: 17, color: AppColors.dangerColor),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Peores hábitos el $dayName',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${(stats.failureRate * 100).round()}% de fallo promedio ese día',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...stats.worst.asMap().entries.map((e) {
            final item = e.value;
            final pct = (item.rate * 100).round();
            final color = pct < 20
                ? AppColors.successColor
                : pct < 50
                    ? AppColors.warningColor
                    : AppColors.dangerColor;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${e.key + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.name,
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$pct%',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  const _CardHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: iconColor),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            Text(subtitle,
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double height;
  const _Skeleton({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryAccent,
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}
