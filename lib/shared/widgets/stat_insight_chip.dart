import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/insight_service.dart';
import '../../core/services/premium_service.dart';
import '../../features/mentor/mentor_providers.dart' show aiKeyProvider;

class StatInsightChip extends ConsumerStatefulWidget {
  final String statId;
  final Map<String, dynamic> data;

  const StatInsightChip({
    super.key,
    required this.statId,
    required this.data,
  });

  @override
  ConsumerState<StatInsightChip> createState() => _StatInsightChipState();
}

class _StatInsightChipState extends ConsumerState<StatInsightChip> {
  String? _text;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final isPremium = ref.read(premiumProvider);
    if (!isPremium) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final apiKey = ref.read(aiKeyProvider);
    if (apiKey == null || apiKey.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final text = await InsightService.instance.getInsight(
      widget.statId,
      widget.data,
      apiKey,
    );
    if (mounted) {
      setState(() {
        _text = text.isEmpty ? null : text;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(premiumProvider);
    if (!isPremium) return const SizedBox.shrink();
    if (_loading) return const _Shimmer();
    if (_text == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryAccent.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bolt_rounded, size: 15, color: AppColors.primaryAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _text!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shimmer placeholder ──────────────────────────────────────────────────────

class _Shimmer extends StatefulWidget {
  const _Shimmer();

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        margin: const EdgeInsets.only(top: 12),
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated
              .withValues(alpha: 0.4 + 0.35 * _anim.value),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
