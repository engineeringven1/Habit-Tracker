import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/utils/share_achievement.dart';
import '../../core/constants/app_colors.dart';
import 'arena_providers.dart';

class ArenaScreen extends ConsumerStatefulWidget {
  const ArenaScreen({super.key});

  @override
  ConsumerState<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends ConsumerState<ArenaScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _borderCtrl;
  late final ConfettiController _confettiCtrl;

  @override
  void initState() {
    super.initState();
    _borderCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _borderCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arenaAsync = ref.watch(arenaDataProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      body: Stack(
        children: [
          arenaAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Error: $e', style: TextStyle(color: AppColors.textSecondary)),
            ),
            data: (data) => _ArenaBody(
              data: data,
              borderCtrl: _borderCtrl,
              confettiCtrl: _confettiCtrl,
              onRefresh: () => ref.invalidate(arenaDataProvider),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiCtrl,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              gravity: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _ArenaBody extends StatelessWidget {
  final ArenaData data;
  final AnimationController borderCtrl;
  final ConfettiController confettiCtrl;
  final VoidCallback onRefresh;

  const _ArenaBody({
    required this.data,
    required this.borderCtrl,
    required this.confettiCtrl,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppColors.backgroundBase,
          expandedHeight: 0,
          floating: true,
          title: Text(
            'Arena',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
              onPressed: onRefresh,
              tooltip: 'Actualizar',
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _LevelCard(data: data, ctrl: borderCtrl),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: _SectionHeader('Logros', Icons.emoji_events_rounded),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _AchievementsGrid(achievements: data.achievements),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: _SectionHeader('Estadísticas de identidad', Icons.person_rounded),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _IdentityStatsGrid(stats: data.identityStats),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: _SectionHeader('Desafíos semanales', Icons.bolt_rounded),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: _WeeklyChallengesBlock(
              challenges: data.weeklyChallenges,
              confettiCtrl: confettiCtrl,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryAccent),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

// ─── Block 1: Level Card ──────────────────────────────────────────────────────

class _LevelCard extends StatelessWidget {
  final ArenaData data;
  final AnimationController ctrl;

  const _LevelCard({required this.data, required this.ctrl});

  String get _initials {
    return 'Y';
  }

  @override
  Widget build(BuildContext context) {
    final level = data.level;
    final color = levelColor(level.index);
    final pts = data.totalPoints;
    final isMax = level.max == -1;
    final progress = isMax ? 1.0 : (pts - level.min) / (level.max - level.min);
    final ptsToNext = isMax ? 0 : level.max - pts;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceElevated, width: 1),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Animated avatar
          AnimatedBuilder(
            animation: ctrl,
            builder: (_, child) {
              return CustomPaint(
                painter: _GradientRingPainter(
                  color: color,
                  progress: ctrl.value,
                ),
                child: child,
              );
            },
            child: Container(
              width: 96,
              height: 96,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.3), AppColors.surfaceCard],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  _initials,
                  style: TextStyle(
                    color: color,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            level.name,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$pts pts totales',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          if (!isMax) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${level.min} pts',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                Text(
                  '$ptsToNext pts para ${_nextLevelName(level.index)}',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                Text(
                  '${level.max} pts',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOut,
                builder: (_, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceElevated,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
          ] else
            Text(
              'Has alcanzado la cima',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
        ],
      ),
    );
  }

  String _nextLevelName(int idx) {
    const names = ['Aprendiz', 'Filósofo', 'Estoico', 'Sabio', 'Maestro', 'Inmutable'];
    return idx < names.length ? names[idx] : '';
  }
}

class _GradientRingPainter extends CustomPainter {
  final Color color;
  final double progress;

  _GradientRingPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      transform: GradientRotation(progress * math.pi * 2),
      colors: [
        color.withValues(alpha: 0.0),
        color,
        color.withValues(alpha: 0.0),
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_GradientRingPainter old) => old.progress != progress;
}

// ─── Block 2: Achievements Grid ───────────────────────────────────────────────

class _AchievementsGrid extends StatelessWidget {
  final List<AchievementStatus> achievements;

  const _AchievementsGrid({required this.achievements});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: achievements.length,
      itemBuilder: (context, i) {
        final a = achievements[i];
        return _AchievementCell(
          status: a,
          onTap: () => _showAchievementDetail(context, a),
        );
      },
    );
  }

  void _showAchievementDetail(BuildContext context, AchievementStatus a) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              a.def.icon,
              size: 48,
              color: a.unlocked ? AppColors.primaryAccent : AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              a.def.name,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            if (a.unlocked) ...[
              Text(
                a.def.description,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Desbloqueado el ${a.unlockedDate ?? ''}',
                style: TextStyle(color: AppColors.primaryAccent, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                '+${a.def.bonusPts} pts',
                style: TextStyle(
                  color: AppColors.primaryAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => shareAchievementImage(
                  context,
                  title: a.def.name,
                  subtitle: a.def.description,
                  icon: a.def.icon,
                ),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Compartir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ] else ...[
              Text(
                a.progressHint,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Recompensa: +${a.def.bonusPts} pts',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _AchievementCell extends StatelessWidget {
  final AchievementStatus status;
  final VoidCallback onTap;

  const _AchievementCell({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unlocked = status.unlocked;
    final color = unlocked ? AppColors.primaryAccent : AppColors.textSecondary.withValues(alpha: 0.35);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: unlocked ? AppColors.primaryAccent.withValues(alpha: 0.4) : AppColors.surfaceElevated,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(status.def.icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              status.def.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unlocked ? AppColors.textPrimary : AppColors.textSecondary.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: unlocked ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (unlocked && status.unlockedDate != null) ...[
              const SizedBox(height: 4),
              Text(
                status.unlockedDate!,
                style: TextStyle(color: AppColors.primaryAccent, fontSize: 9),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Block 3: Identity Stats ──────────────────────────────────────────────────

class _IdentityStatsGrid extends StatelessWidget {
  final IdentityStats stats;

  const _IdentityStatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Tasa de recuperación',
        stats.recoveryRateDays == 0
            ? 'Sin datos'
            : '${stats.recoveryRateDays.toStringAsFixed(1)} días',
        Icons.replay_rounded,
      ),
      (
        'Hora pico',
        stats.peakHour ?? 'Sin datos',
        Icons.schedule_rounded,
      ),
      (
        'Categoría dominante',
        stats.dominantCategory ?? 'Sin datos',
        Icons.category_rounded,
      ),
      (
        'Hábito más longevo',
        stats.longestStreakHabit != null
            ? '${stats.longestStreakHabit} (${stats.longestStreakDays}d)'
            : 'Sin datos',
        Icons.whatshot_rounded,
      ),
      (
        'Total completados',
        '${stats.totalCompletions}',
        Icons.check_circle_rounded,
      ),
      (
        'Días activos',
        '${stats.activeDays}',
        Icons.calendar_today_rounded,
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: items
          .map((item) => _StatCard(label: item.$1, value: item.$2, icon: item.$3))
          .toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceElevated),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.primaryAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ),
            ],
          ),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Block 4: Weekly Challenges ───────────────────────────────────────────────

class _WeeklyChallengesBlock extends StatelessWidget {
  final List<WeeklyChallenge> challenges;
  final ConfettiController confettiCtrl;

  const _WeeklyChallengesBlock({
    required this.challenges,
    required this.confettiCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: challenges
          .map((ch) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ChallengeCard(challenge: ch, confettiCtrl: confettiCtrl),
              ))
          .toList(),
    );
  }
}

class _ChallengeCard extends StatefulWidget {
  final WeeklyChallenge challenge;
  final ConfettiController confettiCtrl;

  const _ChallengeCard({required this.challenge, required this.confettiCtrl});

  @override
  State<_ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<_ChallengeCard> {
  bool _celebrated = false;

  @override
  void didUpdateWidget(_ChallengeCard old) {
    super.didUpdateWidget(old);
    if (!old.challenge.completed && widget.challenge.completed && !_celebrated) {
      _celebrated = true;
      widget.confettiCtrl.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.challenge;
    final progress = ch.def.target == 0 ? 1.0 : ch.current / ch.def.target;
    final color = ch.completed ? const Color(0xFF4CAF50) : AppColors.primaryAccent;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ch.completed
              ? const Color(0xFF4CAF50).withValues(alpha: 0.5)
              : AppColors.surfaceElevated,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ch.def.description,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (ch.completed)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 22)
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${ch.def.bonusPts} pts',
                    style: TextStyle(
                      color: AppColors.primaryAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    builder: (_, val, _) => LinearProgressIndicator(
                      value: val,
                      minHeight: 7,
                      backgroundColor: AppColors.surfaceElevated,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${ch.current}/${ch.def.target}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (ch.completed && ch.pointsAwarded)
                Row(
                  children: [
                    const Icon(Icons.check_rounded, size: 13, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 4),
                    Text(
                      '+${ch.def.bonusPts} pts otorgados',
                      style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 12),
                    ),
                  ],
                )
              else
                const SizedBox.shrink(),
              Text(
                ch.daysLeft == 0
                    ? 'Último día'
                    : '${ch.daysLeft} días restantes',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
