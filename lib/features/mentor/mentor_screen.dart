import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  bool _generatingPlan = false;
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
    final error =
        await ref.read(mentorProvider.notifier).generateBlock(blockType);
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

  Future<void> _generatePlan() async {
    setState(() => _generatingPlan = true);
    try {
      final plan =
          await ref.read(mentorProvider.notifier).generateWeeklyPlan();
      if (mounted) _showWeeklyPlanSheet(plan);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPlan = false);
    }
  }

  void _showWeeklyPlanSheet(String plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _WeeklyPlanSheet(
        plan: plan,
        onSave: () async {
          await ref.read(mentorProvider.notifier).saveWeeklyPlan(plan);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Plan guardado en Mentor ✓')),
            );
          }
        },
      ),
    );
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
          SliverToBoxAdapter(child: _Header()),

          // ── No API Key warning ──────────────────────────────────────────
          if (apiKey == null)
            SliverToBoxAdapter(child: _NoKeyCard())
          else ...[
            // ── Generate + Plan buttons ────────────────────────────────────
            SliverToBoxAdapter(
              child: _ActionButtons(
                generatingAll: _generatingAll,
                generatingPlan: _generatingPlan,
                hasInsights: insights.isNotEmpty,
                onGenerate: _generateAll,
                onPlan: _generatePlan,
              ),
            ),

            // ── Error banner ───────────────────────────────────────────────
            if (_globalError != null)
              SliverToBoxAdapter(
                child: _ErrorBanner(message: _globalError!),
              ),

            // ── Saved weekly plan (if any) ─────────────────────────────────
            if (insights['weekly_plan'] != null)
              SliverToBoxAdapter(
                child: _SavedPlanCard(insight: insights['weekly_plan']!)
                    .animate()
                    .fadeIn(duration: 350.ms),
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
                    onRefresh:
                        _generatingAll || _generatingBlocks.contains(block.type)
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

            // ── 1A: Chat section ───────────────────────────────────────────
            const SliverToBoxAdapter(child: _ChatSection()),

            // ── 1C: Habit suggestion ───────────────────────────────────────
            const SliverToBoxAdapter(child: _SuggestionCard()),
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
                child: const Icon(Icons.psychology_rounded,
                    color: Colors.white, size: 24),
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
                        fontSize: 13, color: AppColors.textSecondary),
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
            color: AppColors.primaryAccent.withValues(alpha: 0.3), width: 1),
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
            child: Icon(Icons.key_rounded,
                color: AppColors.primaryAccent, size: 26),
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
            'Para activar Tu Mentor necesitas una clave API de Groq (gratis). '
            'Obtén la tuya en console.groq.com y añádela desde el menú de tu cuenta.',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action Buttons (generate all + plan) ────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final bool generatingAll;
  final bool generatingPlan;
  final bool hasInsights;
  final VoidCallback onGenerate;
  final VoidCallback onPlan;

  const _ActionButtons({
    required this.generatingAll,
    required this.generatingPlan,
    required this.hasInsights,
    required this.onGenerate,
    required this.onPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          // Primary: generate all insights
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: generatingAll ? null : onGenerate,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: generatingAll
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                  color: generatingAll ? AppColors.surfaceCard : null,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (generatingAll) ...[
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: AppColors.primaryAccent, strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Generando análisis...',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary),
                      ),
                    ] else ...[
                      const Icon(Icons.auto_awesome_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        hasInsights
                            ? 'Regenerar análisis completo'
                            : 'Generar análisis completo',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Secondary: weekly plan
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: generatingPlan ? null : onPlan,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.secondaryAccent.withValues(alpha: 0.35),
                      width: 1),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (generatingPlan) ...[
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            color: AppColors.secondaryAccent, strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Generando plan...',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary),
                      ),
                    ] else ...[
                      Icon(Icons.calendar_today_rounded,
                          size: 15, color: AppColors.secondaryAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Generar plan semanal',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryAccent),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
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
            child: Text(message,
                style:
                    GoogleFonts.inter(fontSize: 13, color: AppColors.dangerColor)),
          ),
        ],
      ),
    );
  }
}

// ─── Saved Plan Card ──────────────────────────────────────────────────────────

class _SavedPlanCard extends StatelessWidget {
  final MentorInsight insight;
  const _SavedPlanCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final lines = insight.content
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          left: BorderSide(color: AppColors.secondaryAccent, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.calendar_today_rounded,
                      color: AppColors.secondaryAccent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Plan de esta semana',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...lines.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(right: 10, top: 1),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${e.key + 1}',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondaryAccent),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textPrimary.withValues(alpha: 0.85),
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              )),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              'Generado ${_timeAgo(insight.generatedAt)}',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.6)),
            ),
          ),
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
    return DateFormat('d MMM', 'es').format(dt);
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
                            color: AppColors.textPrimary),
                      ),
                      Text(
                        block.subtitle,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _CardContent(
              insight: insight,
              isGenerating: isGenerating,
              blockColor: block.color,
              onGenerate: insight == null ? onRefresh : null,
            ),
          ),
          if (insight != null && !isGenerating)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Text(
                'Generado ${_timeAgo(insight!.generatedAt)}',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.6)),
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

// ─── Card Content / Shimmer / Empty State ────────────────────────────────────

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
    if (isGenerating) return _LoadingShimmer(color: blockColor);
    if (insight == null) {
      return _EmptyState(color: blockColor, onGenerate: onGenerate);
    }
    return Text(
      insight!.content,
      style: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textPrimary.withValues(alpha: 0.85),
          height: 1.65),
    );
  }
}

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
          Icon(Icons.hourglass_empty_rounded,
              size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            'Sin generar aún — pulsa el botón superior',
            style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

// ─── 1A: Chat section ────────────────────────────────────────────────────────

class _ChatSection extends ConsumerStatefulWidget {
  const _ChatSection();

  @override
  ConsumerState<_ChatSection> createState() => _ChatSectionState();
}

class _ChatSectionState extends ConsumerState<_ChatSection> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  static const _maxChars = 500;

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || text.length > _maxChars) return;
    _ctrl.clear();
    await ref.read(chatProvider.notifier).send(text);
    // Scroll to bottom after response
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final charCount = _ctrl.text.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          left: BorderSide(
              color: AppColors.primaryAccent.withValues(alpha: 0.5), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.chat_bubble_outline_rounded,
                      color: AppColors.primaryAccent, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  'Pregúntale a tu mentor',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
          ),

          // Message history
          if (chat.messages.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: chat.messages.length,
                itemBuilder: (_, i) {
                  final msg = chat.messages[i];
                  return _ChatBubble(message: msg);
                },
              ),
            ),

          // Typing indicator
          if (chat.isTyping)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primaryAccent,
                      shape: BoxShape.circle,
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fadeIn(duration: 400.ms),
                  const SizedBox(width: 4),
                  Text(
                    'Escribiendo...',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

          // Error
          if (chat.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                chat.error!,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.dangerColor),
              ),
            ),

          const SizedBox(height: 10),

          // Input row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TextField(
                          controller: _ctrl,
                          maxLines: null,
                          maxLength: _maxChars,
                          buildCounter: (_, {required currentLength,
                              required isFocused, maxLength}) =>
                              null,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _send(),
                          style: GoogleFonts.inter(
                              fontSize: 14, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Pregúntale algo a tu mentor...',
                            hintStyle: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.textSecondary),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(0, 0, 10, 6),
                          child: Text(
                            '$charCount/$_maxChars',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: charCount > _maxChars * 0.9
                                  ? AppColors.warningColor
                                  : AppColors.textSecondary.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: chat.isTyping ? null : _send,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: chat.isTyping
                          ? null
                          : LinearGradient(
                              colors: AppColors.gradientPrimary,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: chat.isTyping
                          ? AppColors.surfaceElevated
                          : null,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.send_rounded,
                      size: 18,
                      color: chat.isTyping
                          ? AppColors.textSecondary
                          : Colors.white,
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

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          gradient: isUser
              ? LinearGradient(
                  colors: AppColors.gradientPrimary,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isUser ? null : AppColors.surfaceElevated,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          message.text,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isUser ? Colors.white : AppColors.textPrimary,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

// ─── 1B: Weekly plan bottom sheet ────────────────────────────────────────────

class _WeeklyPlanSheet extends StatelessWidget {
  final String plan;
  final VoidCallback onSave;

  const _WeeklyPlanSheet({required this.plan, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final lines = plan
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(3)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.calendar_today_rounded,
                      color: AppColors.secondaryAccent, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan para esta semana',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    Text(
                      '3 prioridades concretas',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          ...lines.asMap().entries.map((e) {
            final parts = e.value.split(':');
            final habit = parts.isNotEmpty ? parts.first.trim() : e.value;
            final action =
                parts.length > 1 ? parts.sublist(1).join(':').trim() : '';
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: 12, top: 2),
                    decoration: BoxDecoration(
                      color:
                          AppColors.secondaryAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${e.key + 1}',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondaryAccent),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                        if (action.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            action,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 6),

          // Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppColors.textSecondary.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      'Cerrar',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onSave();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      'Guardar en Mentor',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── 1C: Habit suggestion card ───────────────────────────────────────────────

class _SuggestionCard extends ConsumerWidget {
  const _SuggestionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(habitSuggestionProvider);
    final apiKey = ref.watch(aiKeyProvider);

    if (apiKey == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          left: BorderSide(color: AppColors.successColor, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.successColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.add_circle_outline_rounded,
                      color: AppColors.successColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tu próximo hábito',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                ),
                // Refresh button
                async.maybeWhen(
                  loading: () => SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: AppColors.successColor, strokeWidth: 2),
                  ),
                  orElse: () => IconButton(
                    onPressed: () =>
                        ref.read(habitSuggestionProvider.notifier).generate(),
                    icon: Icon(Icons.refresh_rounded,
                        size: 18, color: AppColors.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
              ],
            ),
          ),

          // Body
          async.when(
            loading: () => Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: _LoadingShimmer(color: AppColors.successColor),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Text(
                'No se pudo generar la sugerencia. Toca el botón de refresh.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            data: (suggestion) {
              if (suggestion == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            suggestion.name,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                AppColors.successColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            suggestion.category,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.successColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      suggestion.justification,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ref
                              .read(habitNamePrefillProvider.notifier)
                              .state = suggestion.name;
                          context.go('/habits');
                        },
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(
                          'Añadir este hábito',
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 480.ms);
  }
}
