import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/dark_mode_provider.dart';
import '../../core/theme/palette_provider.dart';
import '../../data/models/reminder.dart';
import '../../data/repositories/seed_repository.dart';
import '../mentor/mentor_providers.dart' show aiKeyProvider;
import 'tracker_providers.dart';
import 'widgets/habit_card.dart';
import 'widgets/score_ring.dart';

class TrackerScreen extends ConsumerStatefulWidget {
  const TrackerScreen({super.key});

  @override
  ConsumerState<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends ConsumerState<TrackerScreen> {
  bool _localeReady = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es', null).then((_) {
      if (mounted) setState(() => _localeReady = true);
    });
    _seedOnFirstLaunch();
  }

  void _seedOnFirstLaunch() {
    SeedRepository(Supabase.instance.client).seedIfFirstTime().then((_) async {
      if (!mounted) return;
      ref.invalidate(habitsProvider);
      ref.invalidate(remindersProvider);
      await NotificationService.requestPermission();
      // Load fresh data, then reschedule only incomplete habits for today.
      final habits    = await ref.read(habitsProvider.future);
      final reminders = await ref.read(remindersProvider.future);
      await ref.read(dailyLogsProvider.notifier).loadLogs();
      final logs = ref.read(dailyLogsProvider).value ?? [];
      final completedIds = logs
          .where((l) => l.completed)
          .map((l) => l.habitId)
          .toSet();
      await NotificationService.rescheduleAll(
        habits,
        reminders,
        completedHabitIds: completedIds,
      );
    });
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) return 'Buenos días ☀️';
    if (hour >= 12 && hour < 18) return 'Buenas tardes 🌤️';
    return 'Buenas noches 🌙';
  }

  String get _formattedDate {
    if (!_localeReady) return '';
    final raw =
        DateFormat("EEEE, d 'de' MMMM", 'es').format(DateTime.now());
    return '${raw[0].toUpperCase()}${raw.substring(1)}';
  }

  String get _userInitial {
    final email =
        Supabase.instance.client.auth.currentUser?.email ?? '';
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }

  Future<void> _onRefresh() async {
    ref.invalidate(habitsProvider);
    ref.invalidate(remindersProvider);
    await ref.read(dailyLogsProvider.notifier).loadLogs();
  }

  void _showUserMenu() {
    final email =
        Supabase.instance.client.auth.currentUser?.email ?? '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UserMenuSheet(
        email: email,
        userInitial: _userInitial,
        onChangePassword: () {
          Navigator.pop(context);
          _showChangePasswordDialog();
        },
        onGeminiKey: () {
          Navigator.pop(context);
          _showGeminiKeyDialog();
        },
        onSignOut: () async {
          Navigator.pop(context);
          await Supabase.instance.client.auth.signOut();
          if (mounted) context.go('/login');
        },
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => const _ChangePasswordDialog(),
    );
  }

  void _showGeminiKeyDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => const _GeminiKeyDialog(),
    );
  }

  String _habitSectionTitle(DateTime date) {
    final today = DateTime.now();
    if (_isSameDay(date, today)) return 'HOY';
    final yesterday = today.subtract(const Duration(days: 1));
    if (_isSameDay(date, yesterday)) return 'AYER';
    if (!_localeReady) return '${date.day}/${date.month}/${date.year}';
    return DateFormat("d 'DE' MMMM", 'es').format(date).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsProvider);
    final remindersAsync = ref.watch(remindersProvider);
    final logsAsync = ref.watch(dailyLogsProvider);
    final score = ref.watch(dailyScoreProvider);
    final selectedDate = ref.watch(selectedDateProvider);

    final today = DateTime.now();
    final String dateLabel;
    if (_isSameDay(selectedDate, today)) {
      dateLabel = 'Hoy';
    } else if (_isSameDay(selectedDate, today.subtract(const Duration(days: 1)))) {
      dateLabel = 'Ayer';
    } else if (_localeReady) {
      dateLabel = DateFormat("d MMM", 'es').format(selectedDate);
    } else {
      dateLabel = '${selectedDate.day}/${selectedDate.month}';
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primaryAccent,
        backgroundColor: AppColors.surfaceCard,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── SLIVER 1: Header ──────────────────────────────────────────
            SliverAppBar(
              backgroundColor: AppColors.backgroundBase,
              surfaceTintColor: Colors.transparent,
              expandedHeight: 140,
              floating: false,
              pinned: false,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.none,
                background: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 52, 20, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              _greeting,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formattedDate,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _showUserMenu,
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              AppColors.primaryAccent.withValues(alpha: 0.2),
                          child: Text(
                            _userInitial,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryAccent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── SLIVER 2: Score card ──────────────────────────────────────
            SliverToBoxAdapter(
              child: _ScoreCard(score: score, dateLabel: dateLabel),
            ),

            // ── SLIVER 2.5: Date selector ─────────────────────────────────
            const SliverToBoxAdapter(child: _DateSelector()),

            // ── SLIVER 3: Habits ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: _sectionTitle(_habitSectionTitle(selectedDate)),
            ),
            habitsAsync.when(
              data: (habits) {
                if (habits.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _emptyHint('Sin hábitos activos todavía'),
                  );
                }
                final weekday = selectedDate.weekday;
                return logsAsync.when(
                  data: (logs) => SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final habit = habits[i];
                        final scheduledToday =
                            habit.daysOfWeek.contains(weekday);
                        final completed = !scheduledToday ||
                            logs.any(
                                (l) => l.habitId == habit.id && l.completed);
                        return HabitCard(
                          key: ValueKey(habit.id),
                          habit: habit,
                          completed: completed,
                          scheduledToday: scheduledToday,
                          onToggle: scheduledToday
                              ? (val) => ref
                                  .read(dailyLogsProvider.notifier)
                                  .toggle(habit.id, val)
                              : null,
                        );
                      },
                      childCount: habits.length,
                    ),
                  ),
                  loading: () => const SliverToBoxAdapter(
                    child: _LoadingIndicator(),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: _errorMessage(e.toString()),
                  ),
                );
              },
              loading: () =>
                  const SliverToBoxAdapter(child: _LoadingIndicator()),
              error: (e, _) =>
                  SliverToBoxAdapter(child: _errorMessage(e.toString())),
            ),

            // ── SLIVER 4: Reminders ───────────────────────────────────────
            SliverToBoxAdapter(child: _sectionTitle('RECORDATORIOS')),
            remindersAsync.when(
              data: (reminders) {
                if (reminders.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _emptyHint('Sin recordatorios configurados'),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _ReminderCard(reminder: reminders[i]),
                    childCount: reminders.length,
                  ),
                );
              },
              loading: () =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, _) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _emptyHint(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _errorMessage(String message) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.dangerColor,
          ),
        ),
      );
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ─── Date Selector ───────────────────────────────────────────────────────────

class _DateSelector extends ConsumerWidget {
  const _DateSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = _isSameDay(selected, today);

    late String label;
    if (isToday) {
      label = 'Hoy';
    } else if (_isSameDay(selected, today.subtract(const Duration(days: 1)))) {
      label = 'Ayer';
    } else {
      try {
        final raw = DateFormat("EEEE d 'de' MMMM", 'es').format(selected);
        label = '${raw[0].toUpperCase()}${raw.substring(1)}';
      } catch (_) {
        label = '${selected.day}/${selected.month}/${selected.year}';
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 22),
              color: AppColors.textSecondary,
              onPressed: () => ref.read(selectedDateProvider.notifier).state =
                  selected.subtract(const Duration(days: 1)),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selected,
                    firstDate: DateTime(today.year - 1, today.month, today.day),
                    lastDate: today,
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: Theme.of(ctx).colorScheme.copyWith(
                          primary: AppColors.primaryAccent,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null && context.mounted) {
                    ref.read(selectedDateProvider.notifier).state =
                        DateTime(picked.year, picked.month, picked.day);
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isToday
                            ? AppColors.primaryAccent
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 14,
                      color: isToday
                          ? AppColors.primaryAccent.withValues(alpha: 0.7)
                          : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: isToday
                    ? AppColors.surfaceElevated
                    : AppColors.textSecondary,
              ),
              onPressed: isToday
                  ? null
                  : () {
                      final next = selected.add(const Duration(days: 1));
                      if (!next.isAfter(today)) {
                        ref.read(selectedDateProvider.notifier).state = next;
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Score Card ──────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final (int, int) score;
  final String dateLabel;

  const _ScoreCard({required this.score, required this.dateLabel});

  @override
  Widget build(BuildContext context) {
    final (completed, total) = score;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.gradientPrimary,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryAccent.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completed / $total',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              ScoreRing(completed: completed, total: total),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'hábitos completados',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reminder Card ───────────────────────────────────────────────────────────

class _ReminderCard extends ConsumerWidget {
  final Reminder reminder;

  const _ReminderCard({required this.reminder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(reminderDoneProvider
        .select((m) => m[reminder.id] == _todayStr()));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: done && reminder.isActive
            ? Color.alphaBlend(
                AppColors.successColor.withValues(alpha: 0.05),
                AppColors.surfaceCard,
              )
            : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: done && reminder.isActive
                ? AppColors.successColor
                : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_outlined,
              size: 15,
              color: done && reminder.isActive
                  ? AppColors.successColor
                  : reminder.isActive
                      ? AppColors.secondaryAccent
                      : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              reminder.name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: done && reminder.isActive
                    ? AppColors.textSecondary
                    : reminder.isActive
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
              ),
            ),
          ),
          if (!reminder.isActive)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'pausado',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () => ref
                  .read(reminderDoneProvider.notifier)
                  .toggle(reminder.id),
              child: _ReminderCheck(done: done)
                  .animate(key: ValueKey('${reminder.id}_$done'))
                  .scale(
                    begin: const Offset(0.65, 0.65),
                    duration: 350.ms,
                    curve: Curves.elasticOut,
                  ),
            ),
        ],
      ),
    );
  }

  static String _todayStr() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _ReminderCheck extends StatelessWidget {
  final bool done;
  const _ReminderCheck({required this.done});

  @override
  Widget build(BuildContext context) {
    if (done) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.gradientSuccess,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
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

// ─── Loading Indicator ───────────────────────────────────────────────────────

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryAccent,
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}

// ─── User Menu Sheet ─────────────────────────────────────────────────────────

class _UserMenuSheet extends ConsumerWidget {
  final String email;
  final String userInitial;
  final VoidCallback onChangePassword;
  final VoidCallback onGeminiKey;
  final Future<void> Function() onSignOut;

  const _UserMenuSheet({
    required this.email,
    required this.userInitial,
    required this.onChangePassword,
    required this.onGeminiKey,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final isDark  = ref.watch(darkModeProvider);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.gradientPrimary,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      userInitial,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mi cuenta',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.surfaceElevated),
            _MenuItem(
              icon: Icons.lock_outline_rounded,
              label: 'Cambiar contraseña',
              onTap: onChangePassword,
            ),
            Divider(
                height: 1,
                color: AppColors.surfaceElevated,
                indent: 56,
                endIndent: 20),
            _MenuItem(
              icon: Icons.key_rounded,
              label: 'Clave API Groq',
              onTap: onGeminiKey,
            ),
            Divider(height: 1, color: AppColors.surfaceElevated, indent: 56, endIndent: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    size: 22,
                    color: AppColors.primaryAccent,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      isDark ? 'Modo oscuro' : 'Modo claro',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Switch(
                    value: !isDark,
                    onChanged: (_) =>
                        ref.read(darkModeProvider.notifier).toggle(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.surfaceElevated),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paleta de colores',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: appPalettes.map((p) {
                      final isSelected = p.id == palette.id;
                      return GestureDetector(
                        onTap: () =>
                            ref.read(paletteProvider.notifier).select(p),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: p.gradientPrimary,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: isSelected
                                  ? const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 18)
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              p.name,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.surfaceElevated),
            _MenuItem(
              icon: Icons.logout_rounded,
              label: 'Cerrar sesión',
              color: AppColors.dangerColor,
              onTap: onSignOut,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (color ?? AppColors.primaryAccent)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: c),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: c,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─── Change Password Dialog ───────────────────────────────────────────────────

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newPass = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (newPass.length < 6) {
      setState(
          () => _error = 'La contraseña debe tener al menos 6 caracteres');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: newPass));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contraseña actualizada correctamente'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Error al actualizar. Inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceCard,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cambiar contraseña',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            _PasswordField(
              controller: _newCtrl,
              label: 'Nueva contraseña',
              obscure: _obscureNew,
              onToggle: () =>
                  setState(() => _obscureNew = !_obscureNew),
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _confirmCtrl,
              label: 'Confirmar contraseña',
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.dangerColor),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppColors.surfaceElevated),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryAccent,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Guardar',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600),
                          ),
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

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.inter(
          color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
            color: AppColors.textSecondary, fontSize: 13),
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Gemini Key Dialog ────────────────────────────────────────────────────────

class _GeminiKeyDialog extends ConsumerStatefulWidget {
  const _GeminiKeyDialog();

  @override
  ConsumerState<_GeminiKeyDialog> createState() => _GeminiKeyDialogState();
}

class _GeminiKeyDialogState extends ConsumerState<_GeminiKeyDialog> {
  late final TextEditingController _ctrl;
  bool _saving = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final current = ref.read(aiKeyProvider) ?? '';
    _ctrl = TextEditingController(text: current);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(aiKeyProvider.notifier).save(_ctrl.text);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clave API guardada'),
          backgroundColor: AppColors.successColor,
        ),
      );
    }
  }

  Future<void> _clear() async {
    setState(() => _saving = true);
    await ref.read(aiKeyProvider.notifier).clear();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clave API eliminada'),
          backgroundColor: AppColors.warningColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = (ref.watch(aiKeyProvider) ?? '').isNotEmpty;

    return Dialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.key_rounded,
                      color: AppColors.primaryAccent, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  'Clave API Groq',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Obtén tu clave gratis en Groq Console (console.groq.com)',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              obscureText: _obscure,
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'gsk_••••••••••••••••••••••••',
                labelStyle: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 12),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (hasKey)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : _clear,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppColors.dangerColor, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Eliminar',
                        style: GoogleFonts.inter(
                            color: AppColors.dangerColor,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                if (hasKey) const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Guardar',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600),
                          ),
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
