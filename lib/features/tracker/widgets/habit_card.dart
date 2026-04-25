import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/habit.dart';

class HabitCard extends StatelessWidget {
  final Habit habit;
  final bool completed;
  final ValueChanged<bool>? onToggle;
  // false = not scheduled today → auto-completed, toggle disabled
  final bool scheduledToday;

  const HabitCard({
    super.key,
    required this.habit,
    required this.completed,
    this.onToggle,
    this.scheduledToday = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveCompleted = completed || !scheduledToday;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: effectiveCompleted
            ? Color.alphaBlend(
                AppColors.successColor.withValues(
                    alpha: scheduledToday ? 0.05 : 0.02),
                AppColors.surfaceCard,
              )
            : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: effectiveCompleted
                ? AppColors.successColor.withValues(
                    alpha: scheduledToday ? 1.0 : 0.35)
                : Colors.transparent,
            width: 3,
          ),
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

            const SizedBox(width: 12),

            // Completion toggle (disabled if not scheduled today)
            GestureDetector(
              onTap: scheduledToday && onToggle != null
                  ? () => onToggle!(!completed)
                  : null,
              child: _CheckIcon(
                      completed: effectiveCompleted,
                      faded: !scheduledToday)
                  .animate(key: ValueKey('${habit.id}_$effectiveCompleted'))
                  .scale(
                    begin: const Offset(0.65, 0.65),
                    duration: 350.ms,
                    curve: Curves.elasticOut,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckIcon extends StatelessWidget {
  final bool completed;
  final bool faded;

  const _CheckIcon({required this.completed, this.faded = false});

  @override
  Widget build(BuildContext context) {
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
          color: faded ? AppColors.successColor.withValues(alpha: 0.4) : null,
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
