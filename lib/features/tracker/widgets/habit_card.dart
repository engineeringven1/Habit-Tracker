import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/habit.dart';

class HabitCard extends StatelessWidget {
  final Habit habit;
  final bool completed;
  final bool manuallyFailed;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onMarkFailed;
  final VoidCallback? onUnmarkFailed;
  final VoidCallback? onLongPress;
  final bool scheduledToday;
  final bool isPastDay;

  const HabitCard({
    super.key,
    required this.habit,
    required this.completed,
    this.manuallyFailed = false,
    this.onToggle,
    this.onMarkFailed,
    this.onUnmarkFailed,
    this.onLongPress,
    this.scheduledToday = true,
    this.isPastDay = false,
  });

  Future<void> _handleToggle(BuildContext context) async {
    if (onToggle == null) return;
    if (isPastDay) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Día pasado',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          content: Text(
            'Este día ya pasó. ¿Estás seguro que deseas continuar?',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style: GoogleFonts.inter(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Continuar',
                  style: GoogleFonts.inter(
                      color: AppColors.primaryAccent,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      if (confirmed == true) onToggle!(!completed);
    } else {
      onToggle!(!completed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveCompleted = completed || !scheduledToday;
    final isPastFailed = (isPastDay && scheduledToday && !completed && !manuallyFailed);
    final isManualFail = manuallyFailed && !isPastDay;
    final showFailBadge = isPastFailed || isManualFail;

    // Decide card styling
    Color leftBorderColor;
    Color cardColor;
    if (showFailBadge) {
      leftBorderColor = AppColors.dangerColor.withValues(alpha: 0.7);
      cardColor = Color.alphaBlend(
        AppColors.dangerColor.withValues(alpha: 0.04),
        AppColors.surfaceCard,
      );
    } else if (effectiveCompleted) {
      leftBorderColor = AppColors.successColor
          .withValues(alpha: scheduledToday ? 1.0 : 0.35);
      cardColor = Color.alphaBlend(
        AppColors.successColor
            .withValues(alpha: scheduledToday ? 0.05 : 0.02),
        AppColors.surfaceCard,
      );
    } else {
      leftBorderColor = Colors.transparent;
      cardColor = AppColors.surfaceCard;
    }

    // Whether to show the secondary "mark as won't complete" button:
    // only for pending habits on today (not past, not done, not already failed)
    final showFailButton = !isPastDay &&
        scheduledToday &&
        !effectiveCompleted &&
        !manuallyFailed &&
        onMarkFailed != null;

    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: leftBorderColor, width: 3),
        ),
      ),
      child: Opacity(
        opacity: scheduledToday ? 1.0 : 0.55,
        child: Row(
          children: [
            // Order number bubble
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${habit.sortOrder + 1}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Name + category
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    habit.category,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // "Won't complete" button — only for today's pending habits
            if (showFailButton)
              GestureDetector(
                onTap: onMarkFailed,
                child: Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.dangerColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.remove_circle_outline_rounded,
                    size: 18,
                    color: AppColors.dangerColor,
                  ),
                ),
              ),

            // Main action icon
            GestureDetector(
              onTap: isManualFail
                  ? onUnmarkFailed // tap red X → back to pending
                  : (scheduledToday && onToggle != null
                      ? () => _handleToggle(context)
                      : null),
              child: _CheckIcon(
                completed: effectiveCompleted,
                faded: !scheduledToday,
                showFail: showFailBadge,
              )
                  .animate(
                      key: ValueKey(
                          '${habit.id}_${effectiveCompleted}_$showFailBadge'))
                  .scale(
                    begin: const Offset(0.65, 0.65),
                    duration: 350.ms,
                    curve: Curves.elasticOut,
                  ),
            ),
          ],
        ),
      ),
      ),  // AnimatedContainer
    );    // GestureDetector
  }
}

class _CheckIcon extends StatelessWidget {
  final bool completed;
  final bool faded;
  final bool showFail;

  const _CheckIcon({
    required this.completed,
    this.faded = false,
    this.showFail = false,
  });

  @override
  Widget build(BuildContext context) {
    if (showFail) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.dangerColor.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child:
            Icon(Icons.close_rounded, color: AppColors.dangerColor, size: 18),
      );
    }
    if (completed) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: faded
              ? null
              : const LinearGradient(
                  colors: AppColors.gradientSuccess,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color:
              faded ? AppColors.successColor.withValues(alpha: 0.4) : null,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
      );
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.circle_outlined,
        color: AppColors.textSecondary,
        size: 18,
      ),
    );
  }
}
