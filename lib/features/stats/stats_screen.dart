import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
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
    final habitsAsync = ref.watch(habitsProvider);
    final gridAsync = ref.watch(sevenDayGridProvider);
    final streakAsync = ref.watch(bestStreakProvider);
    final topAsync = ref.watch(topHabitsProvider);
    final bottomAsync = ref.watch(bottomHabitsProvider);
    final catAsync = ref.watch(categoryStatsProvider);
    final patternAsync = ref.watch(weekdayPatternProvider);
    final perfectAsync = ref.watch(perfectDaysProvider);
    final avgAsync = ref.watch(avg30Provider);

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
                weeksAsync.when(
                  data: (w) => _HeroWeekCard(weeks: w)
                      .animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
                  loading: () => const _Skeleton(height: 180),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 14),

                // ── 2. KPI chips row ───────────────────────────────────
                _KpiRow(
                  weeksAsync: weeksAsync,
                  streakAsync: streakAsync,
                  perfectAsync: perfectAsync,
                  avgAsync: avgAsync,
                ).animate().fadeIn(delay: 80.ms, duration: 400.ms),
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

                // ── 5. Category breakdown ──────────────────────────────
                catAsync.when(
                  data: (cats) => _CategoryCard(stats: cats)
                      .animate()
                      .fadeIn(delay: 240.ms, duration: 400.ms),
                  loading: () => const _Skeleton(height: 200),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 14),

                // ── 7. Top habits ──────────────────────────────────────
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

                // ── 9. 7-day habit grid ────────────────────────────────
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
  final List<Map<String, dynamic>> weeks;
  const _HeroWeekCard({required this.weeks});

  @override
  Widget build(BuildContext context) {
    if (weeks.isEmpty) return const SizedBox.shrink();
    final cur = weeks.last;
    final pct = (cur['score_percentage'] as num? ?? 0).toDouble();
    final done = (cur['completed_count'] as num? ?? 0).toInt();
    final total = (cur['total_possible'] as num? ?? 0).toInt();
    double? delta;
    if (weeks.length >= 2) {
      delta = pct -
          (weeks[weeks.length - 2]['score_percentage'] as num? ?? 0)
              .toDouble();
    }
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
                    Text('Esta semana',
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
          Text(
            '${(value * 100).round()}%',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
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
  final AsyncValue<(String, int)?> streakAsync;
  final AsyncValue<int> perfectAsync;
  final AsyncValue<double> avgAsync;

  const _KpiRow({
    required this.weeksAsync,
    required this.streakAsync,
    required this.perfectAsync,
    required this.avgAsync,
  });

  @override
  Widget build(BuildContext context) {
    final streak = streakAsync.value;
    final perfect = perfectAsync.value ?? 0;
    final avg = avgAsync.value ?? 0;
    final weeks = weeksAsync.value;
    final weekCount = weeks?.length ?? 0;

    return Row(
      children: [
        _KpiChip(
          icon: Icons.local_fire_department_rounded,
          label: 'Racha',
          value: streak != null ? '${streak.$2}d' : '—',
          sub: streak?.$1,
          accent: const Color(0xFFF97316),
        ),
        const SizedBox(width: 10),
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
          ],
        ),
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
            subtitle: 'Últimas ${weeks.length} semanas',
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

class _CategoryCard extends StatelessWidget {
  final List<CategoryStat> stats;
  const _CategoryCard({required this.stats});

  @override
  Widget build(BuildContext context) {
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
          ...stats.map((s) => _CategoryRow(stat: s)),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategoryStat stat;
  const _CategoryRow({required this.stat});

  @override
  Widget build(BuildContext context) {
    final color = _catColor(stat.category);
    final pct = (stat.rate * 100).round();

    return Padding(
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _capitalize(stat.category),
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary),
                    ),
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
                    backgroundColor:
                        color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
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

// ─── 9. 7-day compliance grid ─────────────────────────────────────────────────

class _SevenDayGrid extends StatelessWidget {
  final List<dynamic> habits;
  final Map<String, List<bool?>> grid;

  const _SevenDayGrid({required this.habits, required this.grid});

  static const _dayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    if (habits.isEmpty) return const SizedBox.shrink();

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
                      _dayLabels[i],
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

// ─── Shared building blocks ───────────────────────────────────────────────────

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
