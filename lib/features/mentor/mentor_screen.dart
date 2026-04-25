import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/mentor_insight.dart';
import 'mentor_providers.dart';

// ─── Block metadata ───────────────────────────────────────────────────────────

class _BlockDef {
  final String type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _BlockDef(this.type, this.title, this.subtitle, this.icon, this.color);
}

final _blocks = [
  _BlockDef(
    'weekly_pulse',
    'Pulso de la semana',
    'Comportamiento de los últimos 7 días',
    Icons.timeline_rounded,
    AppColors.primaryAccent,
  ),
  _BlockDef(
    'monthly_trend',
    'Tendencia del mes',
    'Evolución por categorías vs mes anterior',
    Icons.trending_up_rounded,
    AppColors.successColor,
  ),
  _BlockDef(
    'hidden_pattern',
    'Tu patrón oculto',
    'Lo que revelan tus días de la semana',
    Icons.auto_awesome_rounded,
    AppColors.secondaryAccent,
  ),
  _BlockDef(
    'habit_at_risk',
    'Hábito en riesgo',
    'El que necesita tu atención ahora',
    Icons.warning_amber_rounded,
    AppColors.dangerColor,
  ),
  _BlockDef(
    'whats_working',
    'Lo que está funcionando',
    'Tus logros y rachas activas',
    Icons.star_rounded,
    AppColors.warningColor,
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class MentorScreen extends ConsumerStatefulWidget {
  const MentorScreen({super.key});

  @override
  ConsumerState<MentorScreen> createState() => _MentorScreenState();
}

class _MentorScreenState extends ConsumerState<MentorScreen> {
  bool _generatingAll = false;
  String? _globalError;
  final Set<String> _generatingBlocks = {};

  Future<void> _generateAll() async {
    setState(() {
      _generatingAll = true;
      _globalError = null;
    });
    final error = await ref.read(mentorProvider.notifier).generateAll();
    if (mounted) {
      setState(() {
        _generatingAll = false;
        _globalError = error;
      });
    }
  }

  Future<void> _regenerateBlock(String blockType) async {
    setState(() => _generatingBlocks.add(blockType));
    final error = await ref.read(mentorProvider.notifier).generateBlock(blockType);
    if (mounted) {
      setState(() => _generatingBlocks.remove(blockType));
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiKey = ref.watch(aiKeyProvider);
    final insights = ref.watch(mentorProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _Header(),
          ),

          // ── No API Key warning ──────────────────────────────────────────
          if (apiKey == null)
            SliverToBoxAdapter(
              child: _NoKeyCard(),
            )
          else ...[
            // ── Generate button ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _GenerateButton(
                generating: _generatingAll,
                hasInsights: insights.isNotEmpty,
                onGenerate: _generateAll,
              ),
            ),

            // ── Error banner ───────────────────────────────────────────────
            if (_globalError != null)
              SliverToBoxAdapter(
                child: _ErrorBanner(message: _globalError!),
              ),

            // ── 5 Insight blocks ───────────────────────────────────────────
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final block = _blocks[i];
                  final insight = insights[block.type];
                  final isGenerating = _generatingBlocks.contains(block.type) ||
                      _generatingAll;
                  return _InsightCard(
                    block: block,
                    insight: insight,
                    isGenerating: isGenerating,
                    onRefresh: _generatingAll || _generatingBlocks.contains(block.type)
                        ? null
                        : () => _regenerateBlock(block.type),
                  ).animate().fadeIn(
                        duration: 400.ms,
                        delay: (i * 80).ms,
                      );
                },
                childCount: _blocks.length,
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tu Mentor',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Análisis personalizado con IA',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── No Key Card ─────────────────────────────────────────────────────────────

class _NoKeyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.key_rounded,
              color: AppColors.primaryAccent,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Configura tu clave API',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Para activar Tu Mentor necesitas una clave API de Groq (gratis). Obtén la tuya en console.groq.com y añádela desde el menú de tu cuenta (avatar superior derecho).',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Menú de cuenta → Clave API Groq',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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

// ─── Generate Button ──────────────────────────────────────────────────────────

class _GenerateButton extends StatelessWidget {
  final bool generating;
  final bool hasInsights;
  final VoidCallback onGenerate;

  const _GenerateButton({
    required this.generating,
    required this.hasInsights,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: generating ? null : onGenerate,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              gradient: generating
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
              color: generating ? AppColors.surfaceCard : null,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (generating) ...[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: AppColors.primaryAccent,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Generando análisis...',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    hasInsights ? 'Regenerar análisis completo' : 'Generar análisis completo',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Error Banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.dangerColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.dangerColor, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.dangerColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Insight Card ─────────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  final _BlockDef block;
  final MentorInsight? insight;
  final bool isGenerating;
  final VoidCallback? onRefresh;

  const _InsightCard({
    required this.block,
    required this.insight,
    required this.isGenerating,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          left: BorderSide(color: block.color, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: block.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(block.icon, color: block.color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        block.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        block.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Refresh icon
                if (onRefresh != null && insight != null)
                  IconButton(
                    onPressed: isGenerating ? null : onRefresh,
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: isGenerating
                          ? AppColors.textSecondary.withValues(alpha: 0.4)
                          : AppColors.textSecondary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
              ],
            ),
          ),

          // ── Content ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _CardContent(
              insight: insight,
              isGenerating: isGenerating,
              blockColor: block.color,
              onGenerate: insight == null ? onRefresh : null,
            ),
          ),

          // ── Footer ────────────────────────────────────────────────────
          if (insight != null && !isGenerating)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Text(
                'Generado ${_timeAgo(insight!.generatedAt)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
              ),
            )
          else
            const SizedBox(height: 14),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'ahora mismo';
    if (diff.inHours < 1) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'ayer';
    if (diff.inDays < 7) return 'hace ${diff.inDays} días';
    return DateFormat('d MMM', 'es').format(dt);
  }
}

// ─── Card Content ─────────────────────────────────────────────────────────────

class _CardContent extends StatelessWidget {
  final MentorInsight? insight;
  final bool isGenerating;
  final Color blockColor;
  final VoidCallback? onGenerate;

  const _CardContent({
    required this.insight,
    required this.isGenerating,
    required this.blockColor,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    if (isGenerating) {
      return _LoadingShimmer(color: blockColor);
    }

    if (insight == null) {
      return _EmptyState(color: blockColor, onGenerate: onGenerate);
    }

    return Text(
      insight!.content,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textPrimary.withValues(alpha: 0.85),
        height: 1.65,
      ),
    );
  }
}

// ─── Loading Shimmer ──────────────────────────────────────────────────────────

class _LoadingShimmer extends StatelessWidget {
  final Color color;

  const _LoadingShimmer({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        3,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          height: 12,
          width: i == 2 ? 120 : double.infinity,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fadeIn(duration: 800.ms, curve: Curves.easeInOut),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final Color color;
  final VoidCallback? onGenerate;

  const _EmptyState({required this.color, required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.hourglass_empty_rounded,
            size: 15,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            'Sin generar aún — pulsa el botón superior',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
