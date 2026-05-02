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
import '../../data/models/daily_log.dart';
import '../../data/models/daily_note.dart';
import '../../data/models/habit.dart';
import 'package:confetti/confetti.dart';
import '../../shared/utils/share_achievement.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../habits/habits_providers.dart' show habitsNotifierProvider;
import '../mentor/mentor_providers.dart'
    show aiKeyProvider, mentorProvider, pendingMilestonesProvider, MilestonePending;
import 'note_providers.dart';
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
  bool _milestonesChecked = false;
  final Map<String, GlobalKey> _habitKeys = {};

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es', null).then((_) {
      if (mounted) setState(() => _localeReady = true);
    });
    _seedOnFirstLaunch();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkMondayPlan());
  }

  // ─── 1B: Monday plan check ────────────────────────────────────────────────

  Future<void> _checkMondayPlan() async {
    if (!mounted) return;
    final today = DateTime.now();
    if (today.weekday != DateTime.monday) return;
    final apiKey = ref.read(aiKeyProvider);
    if (apiKey == null) return;

    final prefs = await SharedPreferences.getInstance();
    final todayStr = _fmtDate(today);
    if (prefs.getString('weekly_plan_monday') == todayStr) return;
    await prefs.setString('weekly_plan_monday', todayStr);

    if (!mounted) return;
    try {
      final plan = await ref.read(mentorProvider.notifier).generateWeeklyPlan();
      if (mounted) _showWeeklyPlanSheet(plan);
    } catch (_) {}
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

  // ─── 1D: Milestone celebration ────────────────────────────────────────────

  Future<void> _showMilestoneCelebrations(List<MilestonePending> pending) async {
    for (final p in pending) {
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surfaceCard,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => _MilestoneSheet(pending: p),
      );
      if (!mounted) return;
      await ref
          .read(habitsNotifierProvider.notifier)
          .addCelebratedMilestone(p.habit.id, p.milestone);
      ref.invalidate(pendingMilestonesProvider);
    }
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

  void _showEditLogSheet(dynamic habit, DailyLog? log, DateTime date) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EditLogSheet(
        habitName: habit.name as String,
        log: log,
        logDate: date,
        onSave: ({required bool completed, required bool manuallyFailed, DateTime? completedAt}) =>
            ref.read(dailyLogsProvider.notifier).updateLog(
              habit.id as String,
              completed: completed,
              manuallyFailed: manuallyFailed,
              completedAt: completedAt,
            ),
      ),
    );
  }

  void _showNoteSheet() {
    final existingText = ref.read(dailyNoteProvider).value?.noteText;
    final date = ref.read(selectedDateProvider);
    final dateLabel = _localeReady
        ? () {
            final raw =
                DateFormat("EEEE, d 'de' MMMM", 'es').format(date);
            return raw[0].toUpperCase() + raw.substring(1);
          }()
        : '${date.day}/${date.month}/${date.year}';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _NoteBottomSheet(
        existingText: existingText,
        dateLabel: dateLabel,
        onSave: (text) => ref.read(dailyNoteProvider.notifier).save(text),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // 1D: milestone celebration — fires once when provider first resolves
    ref.listen<AsyncValue<List<MilestonePending>>>(
        pendingMilestonesProvider, (_, next) {
      next.whenData((pending) {
        if (_milestonesChecked || pending.isEmpty) return;
        _milestonesChecked = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showMilestoneCelebrations(pending);
        });
      });
      if (next is AsyncData) _milestonesChecked = true;
    });

    final habitsAsync = ref.watch(habitsProvider);
    final remindersAsync = ref.watch(remindersProvider);
    final logsAsync = ref.watch(dailyLogsProvider);
    final score = ref.watch(dailyScoreProvider);
    final selectedDate = ref.watch(selectedDateProvider);

    final today = DateTime.now();
    String weekdayName(DateTime d) {
      if (_localeReady) {
        final raw = DateFormat('EEEE', 'es').format(d);
        return raw[0].toUpperCase() + raw.substring(1);
      }
      const abbr = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      return abbr[d.weekday - 1];
    }

    final String dateLabel;
    if (_isSameDay(selectedDate, today)) {
      dateLabel = 'Hoy · ${weekdayName(selectedDate)}';
    } else if (_isSameDay(selectedDate, today.subtract(const Duration(days: 1)))) {
      dateLabel = 'Ayer · ${weekdayName(selectedDate)}';
    } else if (_localeReady) {
      final raw = DateFormat("EEEE, d 'de' MMMM", 'es').format(selectedDate);
      dateLabel = raw[0].toUpperCase() + raw.substring(1);
    } else {
      dateLabel = '${selectedDate.day}/${selectedDate.month}';
    }

    final todayHabits = habitsAsync.value ?? <Habit>[];
    final todayLogs   = logsAsync.value   ?? <DailyLog>[];
    final Map<String, ({int done, int total})> catProgress = {};
    for (final h in todayHabits) {
      if (!h.daysOfWeek.contains(selectedDate.weekday)) continue;
      final isDone = todayLogs.any((l) => l.habitId == h.id && l.completed);
      final cur = catProgress[h.category] ?? (done: 0, total: 0);
      catProgress[h.category] = (
        done: cur.done + (isDone ? 1 : 0),
        total: cur.total + 1,
      );
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

            // ── SLIVER 2.2: Category chips ────────────────────────────────
            SliverToBoxAdapter(
              child: _CategoryChipRow(
                catProgress: catProgress,
                onTap: (category) {
                  Habit? target;
                  for (final h in todayHabits) {
                    if (h.category != category) continue;
                    if (!h.daysOfWeek.contains(selectedDate.weekday)) continue;
                    final log = todayLogs.where((l) => l.habitId == h.id).firstOrNull;
                    if (!(log?.completed ?? false) && !(log?.manuallyFailed ?? false)) {
                      target = h;
                      break;
                    }
                    target ??= h;
                  }
                  if (target == null) return;
                  final key = _habitKeys[target.id];
                  if (key?.currentContext != null) {
                    Scrollable.ensureVisible(
                      key!.currentContext!,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      alignment: 0.15,
                    );
                  }
                },
              ),
            ),

            // ── SLIVER 2.3: Daily note button ─────────────────────────────
            SliverToBoxAdapter(
              child: _NoteButton(
                noteAsync: ref.watch(dailyNoteProvider),
                onTap: _showNoteSheet,
              ),
            ),

            // ── SLIVER 2.5: Date selector ─────────────────────────────────
            const SliverToBoxAdapter(child: _DateSelector()),

            // ── SLIVER 3+4: Pending / Completed habits ────────────────────
            habitsAsync.when(
              data: (habits) {
                if (habits.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _emptyHint('Sin hábitos activos todavía'),
                  );
                }
                final weekday = selectedDate.weekday;
                final isPastDay = !_isSameDay(selectedDate, today);
                return logsAsync.when(
                  data: (logs) {
                    final pending = <dynamic>[];
                    final completed = <dynamic>[];
                    for (final habit in habits) {
                      final scheduledToday =
                          habit.daysOfWeek.contains(weekday);
                      final log = logs.where(
                          (l) => l.habitId == habit.id).firstOrNull;
                      final isDone = !scheduledToday ||
                          (log?.completed ?? false);
                      final isFailed = log?.manuallyFailed ?? false;
                      // Pending = scheduled today, not done, not manually failed
                      if (scheduledToday && !isDone && !isFailed) {
                        pending.add(habit);
                      } else {
                        completed.add(habit);
                      }
                    }

                    Widget buildCard(dynamic habit) {
                      final scheduledToday =
                          habit.daysOfWeek.contains(weekday);
                      final log = logs.where(
                          (l) => l.habitId == habit.id).firstOrNull;
                      final isDone = !scheduledToday ||
                          (log?.completed ?? false);
                      final isFailed = log?.manuallyFailed ?? false;
                      return HabitCard(
                        key: _habitKeys.putIfAbsent(habit.id as String, () => GlobalKey()),
                        habit: habit,
                        completed: isDone,
                        manuallyFailed: isFailed,
                        scheduledToday: scheduledToday,
                        isPastDay: isPastDay,
                        onToggle: scheduledToday
                            ? (val) => ref
                                .read(dailyLogsProvider.notifier)
                                .toggle(habit.id, val)
                            : null,
                        onMarkFailed: (!isPastDay && scheduledToday)
                            ? () => ref
                                .read(dailyLogsProvider.notifier)
                                .markFailed(habit.id, true)
                            : null,
                        onUnmarkFailed: isFailed
                            ? () => ref
                                .read(dailyLogsProvider.notifier)
                                .markFailed(habit.id, false)
                            : null,
                        onLongPress: () =>
                            _showEditLogSheet(habit, log, selectedDate),
                      );
                    }

                    return SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (pending.isNotEmpty) ...[
                            _sectionTitle('HÁBITOS PENDIENTES'),
                            ...pending.map(buildCard),
                          ],
                          if (completed.isNotEmpty) ...[
                            _sectionTitle('HÁBITOS COMPLETADOS'),
                            ...completed.map(buildCard),
                          ],
                        ],
                      ),
                    );
                  },
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

// ─── Edit Log Sheet ───────────────────────────────────────────────────────────

class _EditLogSheet extends StatefulWidget {
  final String habitName;
  final DailyLog? log;
  final DateTime logDate;
  final Future<void> Function({
    required bool completed,
    required bool manuallyFailed,
    DateTime? completedAt,
  }) onSave;

  const _EditLogSheet({
    required this.habitName,
    this.log,
    required this.logDate,
    required this.onSave,
  });

  @override
  State<_EditLogSheet> createState() => _EditLogSheetState();
}

class _EditLogSheetState extends State<_EditLogSheet> {
  late String _status; // 'pending' | 'completed' | 'failed'
  late DateTime _completedAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final log = widget.log;
    if (log?.completed == true) {
      _status = 'completed';
      _completedAt = log?.completedAt ?? DateTime.now();
    } else if (log?.manuallyFailed == true) {
      _status = 'failed';
      _completedAt = DateTime.now();
    } else {
      _status = 'pending';
      _completedAt = DateTime.now();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _completedAt.hour, minute: _completedAt.minute),
    );
    if (picked == null) return;
    setState(() {
      _completedAt = DateTime(
        widget.logDate.year, widget.logDate.month, widget.logDate.day,
        picked.hour, picked.minute,
      );
    });
  }

  String _formatTime() {
    final h = _completedAt.hour;
    final m = _completedAt.minute.toString().padLeft(2, '0');
    final ampm = h < 12 ? 'am' : 'pm';
    final h12 = h == 0 ? 12 : h > 12 ? h - 12 : h;
    return '$h12:$m $ampm';
  }

  Widget _chip(String value, IconData icon, String label, Color color) {
    final selected = _status == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _status = value;
          if (value == 'completed') {
            _completedAt = widget.log?.completedAt ?? DateTime.now();
          }
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.5) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: selected ? color : AppColors.textSecondary),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? color : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(Icons.edit_calendar_rounded,
                    color: AppColors.primaryAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.habitName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text('Editar registro',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            Text('Estado',
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip('pending', Icons.hourglass_empty_rounded,
                    'Pendiente', AppColors.textSecondary),
                const SizedBox(width: 8),
                _chip('completed', Icons.check_circle_rounded,
                    'Completado', AppColors.successColor),
                const SizedBox(width: 8),
                _chip('failed', Icons.cancel_rounded,
                    'Fallido', AppColors.dangerColor),
              ],
            ),
            if (_status == 'completed') ...[
              const SizedBox(height: 16),
              Text('Hora de completación',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 18, color: AppColors.primaryAccent),
                      const SizedBox(width: 10),
                      Text(
                        _formatTime(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20, fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.edit_rounded,
                          size: 15, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        final nav = Navigator.of(context);
                        await widget.onSave(
                          completed: _status == 'completed',
                          manuallyFailed: _status == 'failed',
                          completedAt: _status == 'completed'
                              ? _completedAt
                              : null,
                        );
                        if (!mounted) return;
                        nav.pop();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primaryAccent.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Guardar cambios',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Note Button ─────────────────────────────────────────────────────────────

class _NoteButton extends StatelessWidget {
  final AsyncValue<DailyNote?> noteAsync;
  final VoidCallback onTap;

  const _NoteButton({required this.noteAsync, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final note = noteAsync.value;
    final hasNote = note != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: GestureDetector(
        onTap: noteAsync.isLoading ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasNote
                  ? Icons.edit_note_rounded
                  : Icons.add_rounded,
              size: 15,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Text(
              hasNote ? 'Ver nota del día' : '+ Añadir nota del día',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Note Bottom Sheet ────────────────────────────────────────────────────────

class _NoteBottomSheet extends StatefulWidget {
  final String? existingText;
  final String dateLabel;
  final Future<void> Function(String text) onSave;

  const _NoteBottomSheet({
    this.existingText,
    required this.dateLabel,
    required this.onSave,
  });

  @override
  State<_NoteBottomSheet> createState() => _NoteBottomSheetState();
}

class _NoteBottomSheetState extends State<_NoteBottomSheet> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.existingText ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingText != null;
    final count = _ctrl.text.length;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
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
                Icon(
                  isEditing
                      ? Icons.edit_note_rounded
                      : Icons.note_add_outlined,
                  color: AppColors.primaryAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isEditing ? 'Editar nota del día' : 'Nota del día',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              widget.dateLabel,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              autofocus: true,
              maxLength: 300,
              maxLines: 5,
              minLines: 3,
              buildCounter: (_, {required currentLength, required maxLength, required isFocused}) => null,
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText:
                    '¿Cómo fue tu día? ¿Qué te ayudó o dificultó?',
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary.withValues(alpha: 0.45),
                ),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
              onChanged: (_) => setState(() {}),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$count / 300',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: count > 280
                      ? AppColors.dangerColor
                      : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _saving || _ctrl.text.trim().isEmpty
                        ? null
                        : () async {
                            setState(() => _saving = true);
                            final nav = Navigator.of(context);
                            await widget.onSave(_ctrl.text);
                            if (!mounted) return;
                            nav.pop();
                          },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primaryAccent.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Guardar',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
              ),
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
              icon: Icons.notifications_active_rounded,
              label: 'Probar notificaciones',
              onTap: () async {
                await NotificationService.requestPermission();
                await NotificationService.showTestNotification();
              },
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

// ─── Category Chip Row ────────────────────────────────────────────────────────

class _CategoryChipRow extends StatelessWidget {
  final Map<String, ({int done, int total})> catProgress;
  final void Function(String category) onTap;

  const _CategoryChipRow({required this.catProgress, required this.onTap});

  static const _palette = [
    Color(0xFF7C3AED),
    Color(0xFF06B6D4),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
  ];

  static Color _colorFor(String category) =>
      _palette[category.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    if (catProgress.isEmpty) return const SizedBox.shrink();

    final sorted = catProgress.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: sorted.map((entry) {
          final cat = entry.key;
          final done = entry.value.done;
          final total = entry.value.total;
          final pct = total == 0 ? 0.0 : done / total;
          final catColor = _colorFor(cat);

          final Color bg;
          final Color textColor;
          if (pct <= 0) {
            bg = AppColors.surfaceElevated;
            textColor = AppColors.textSecondary;
          } else if (pct >= 1.0) {
            bg = catColor;
            textColor = Colors.white;
          } else {
            bg = Color.lerp(AppColors.surfaceElevated, catColor, pct)!;
            textColor = Color.lerp(AppColors.textSecondary, Colors.white, pct)!;
          }

          final shortName = cat.length > 6 ? '${cat.substring(0, 5)}…' : cat;
          final pctStr = '${(pct * 100).round()}%';

          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(cat),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      shortName,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      pctStr,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: textColor.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
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
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondaryAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.calendar_today_rounded,
                    color: AppColors.secondaryAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Plan para esta semana',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text('3 prioridades concretas',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.textSecondary)),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          ...lines.asMap().entries.map((e) {
            final parts = e.value.split(':');
            final habit = parts.first.trim();
            final action = parts.length > 1 ? parts.sublist(1).join(':').trim() : '';
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 28, height: 28,
                  margin: const EdgeInsets.only(right: 12, top: 2),
                  decoration: BoxDecoration(
                      color: AppColors.secondaryAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text('${e.key + 1}',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: AppColors.secondaryAccent)),
                ),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habit, style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                    if (action.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(action, style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textSecondary,
                          height: 1.4)),
                    ],
                  ],
                )),
              ]),
            );
          }),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: Text('Cerrar', style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: () { Navigator.pop(context); onSave(); },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: Text('Guardar en Mentor',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              )),
            ]),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── 1D: Milestone celebration sheet ────────────────────────────────────────

class _MilestoneSheet extends StatefulWidget {
  final MilestonePending pending;
  const _MilestoneSheet({required this.pending});

  @override
  State<_MilestoneSheet> createState() => _MilestoneSheetState();
}

class _MilestoneSheetState extends State<_MilestoneSheet> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 4));
    _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final p = widget.pending;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        ConfettiWidget(
          confettiController: _confetti,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          numberOfParticles: 30,
          colors: const [
            Color(0xFF7C3AED), Color(0xFF06B6D4),
            Color(0xFFF59E0B), Color(0xFF10B981),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 24),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text('🏆', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text('${p.milestone} DÍAS',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 38, fontWeight: FontWeight.w800,
                      color: AppColors.warningColor, height: 1)),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(p.habit.name, textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ),
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warningColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.warningColor.withValues(alpha: 0.3)),
                ),
                child: Text(p.label, textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppColors.warningColor, height: 1.4)),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppColors.textSecondary.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text('Cerrar', style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () {
                      final p = widget.pending;
                      shareAchievementImage(
                        context,
                        title: p.label,
                        subtitle: '${p.milestone} días seguidos con "${p.habit.name}"',
                        topEmoji: '🏆',
                      );
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: Text('Compartir',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warningColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  )),
                ]),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}