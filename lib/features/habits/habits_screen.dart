import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/habit.dart';
import '../../data/models/reminder.dart';
import '../../shared/widgets/gradient_button.dart';
import 'habits_providers.dart';

// ─── 3-hour time blocks ───────────────────────────────────────────────────────

const _kBlocks = [
  (label: '12am – 3am',  startHr:  0, endHr:  3),
  (label: '3am – 6am',   startHr:  3, endHr:  6),
  (label: '6am – 9am',   startHr:  6, endHr:  9),
  (label: '9am – 12pm',  startHr:  9, endHr: 12),
  (label: '12pm – 3pm',  startHr: 12, endHr: 15),
  (label: '3pm – 6pm',   startHr: 15, endHr: 18),
  (label: '6pm – 9pm',   startHr: 18, endHr: 21),
  (label: '9pm – 12am',  startHr: 21, endHr: 23),
];

int _blockFromStartHr(int startHr) {
  final i = _kBlocks.indexWhere((b) => b.startHr == startHr);
  return i >= 0 ? i : (startHr ~/ 3).clamp(0, 7);
}

int _blockFromEndHr(int endHr) {
  final i = _kBlocks.indexWhere((b) => b.endHr == endHr);
  return i >= 0 ? i : 2; // default to 6am-9am
}

// ─────────────────────────────────────────────────────────────────────────────

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  void _openCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _CreateHabitSheet(),
    );
  }

  void _openEditSheet(BuildContext context, Habit habit, int total) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditHabitSheet(habit: habit, totalHabits: total),
    );
  }

  void _openAddReminderSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AddReminderSheet(),
    );
  }

  void _openEditReminderSheet(BuildContext context, Reminder reminder) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditReminderSheet(reminder: reminder),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text('Nueva categoría',
            style: GoogleFonts.plusJakartaSans(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.inter(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancelar',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              ref.read(categoriesProvider.notifier).add(ctrl.text);
              Navigator.pop(dialogCtx);
            },
            child: Text('Añadir',
                style: GoogleFonts.inter(color: AppColors.primaryAccent,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsNotifierProvider);
    final remindersAsync = ref.watch(remindersNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      appBar: AppBar(
        title: Text(
          'Configuración',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.backgroundBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreateSheet(context),
        backgroundColor: Colors.transparent,
        elevation: 6,
        shape: const CircleBorder(),
        child: Ink(
          decoration: ShapeDecoration(
            gradient: LinearGradient(
              colors: AppColors.gradientPrimary,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: const CircleBorder(),
          ),
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ),
      body: habitsAsync.when(
        data: (habits) => _buildBody(context, ref, habits, remindersAsync),
        loading: () => Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryAccent,
            strokeWidth: 2.5,
          ),
        ),
        error: (e, _) => Center(
          child: Text(e.toString(),
              style: GoogleFonts.inter(color: AppColors.dangerColor)),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    List<Habit> habits,
    AsyncValue<List<Reminder>> remindersAsync,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Habits section title ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'HÁBITOS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: AppColors.textSecondary,
              ),
            ),
          ),

          if (habits.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Añade tu primer hábito con el botón +',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              itemCount: habits.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                ref
                    .read(habitsNotifierProvider.notifier)
                    .reorderHabits(oldIndex, newIndex);
              },
              itemBuilder: (_, i) => _HabitManageCard(
                key: ValueKey(habits[i].id),
                habit: habits[i],
                index: i,
                onToggle: (val) => ref
                    .read(habitsNotifierProvider.notifier)
                    .toggleActive(habits[i].id, val),
                onEdit: () => _openEditSheet(context, habits[i], habits.length),
              ),
            ),

          // ── Reminders section ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Text(
                  'RECORDATORIOS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: AppColors.primaryAccent,
                  ),
                  onPressed: () => _openAddReminderSheet(context),
                ),
              ],
            ),
          ),

          remindersAsync.when(
            data: (reminders) {
              if (reminders.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Text(
                    'Sin recordatorios todavía',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                );
              }
              return Column(
                children: reminders
                    .map((r) => _ReminderRow(
                          key: ValueKey(r.id),
                          reminder: r,
                          onToggle: (val) => ref
                              .read(remindersNotifierProvider.notifier)
                              .toggleReminder(r.id, val),
                          onDelete: () => ref
                              .read(remindersNotifierProvider.notifier)
                              .deleteReminder(r.id),
                          onEdit: () => _openEditReminderSheet(context, r),
                        ))
                    .toList(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // ── Categories section ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Text(
                  'CATEGORÍAS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.add_circle_outline,
                      color: AppColors.primaryAccent),
                  onPressed: () => _showAddCategoryDialog(context, ref),
                ),
              ],
            ),
          ),

          Consumer(
            builder: (_, ref, _) {
              final cats = ref.watch(categoriesProvider);
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cats.map((cat) {
                    return Chip(
                      label: Text(cat,
                          style: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.textPrimary)),
                      backgroundColor: AppColors.surfaceCard,
                      side: BorderSide(
                          color: AppColors.surfaceElevated, width: 1),
                      deleteIcon: Icon(Icons.close,
                          size: 14, color: AppColors.textSecondary),
                      onDeleted: () =>
                          ref.read(categoriesProvider.notifier).remove(cat),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  }).toList(),
                ),
              );
            },
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ─── Habit Manage Card ────────────────────────────────────────────────────────

class _HabitManageCard extends StatelessWidget {
  final Habit habit;
  final int index;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  const _HabitManageCard({
    super.key,
    required this.habit,
    required this.index,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Drag handle
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
              child: Icon(Icons.drag_indicator,
                  color: AppColors.textSecondary, size: 20),
            ),
          ),

          // Order bubble (display only)
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primaryAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${habit.sortOrder + 1}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryAccent,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Name + category + day preview
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
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
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _CategoryBadge(category: habit.category),
                      const SizedBox(width: 8),
                      _DayDots(daysOfWeek: habit.daysOfWeek),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Edit button
          IconButton(
            onPressed: onEdit,
            icon: Icon(Icons.edit_outlined,
                size: 18, color: AppColors.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),

          // Active toggle
          Switch(value: habit.isActive, onChanged: onToggle),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ─── Category Badge ───────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  final String category;

  const _CategoryBadge({required this.category});

  static final Map<String, (Color, Color)> _palette = {
    'disciplina': (AppColors.primaryAccent, Color(0xFFC4B5FD)),
    'trabajo': (AppColors.secondaryAccent, Color(0xFFA5F3FC)),
    'salud': (AppColors.successColor, Color(0xFFA7F3D0)),
    'nutrición': (AppColors.warningColor, Color(0xFFFDE68A)),
    'finanzas': (Color(0xFF8B5CF6), Color(0xFFDDD6FE)),
    'restricción': (AppColors.surfaceElevated, AppColors.textSecondary),
    'mente': (Color(0xFFEC4899), Color(0xFFFBCFE8)),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _palette[category.toLowerCase()] ??
        (AppColors.surfaceElevated, AppColors.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        category,
        style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: fg),
      ),
    );
  }
}

// ─── Day Dots (read-only preview) ────────────────────────────────────────────

class _DayDots extends StatelessWidget {
  final List<int> daysOfWeek;
  const _DayDots({required this.daysOfWeek});

  static const _labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (i) {
        final active = daysOfWeek.contains(i + 1);
        return Container(
          margin: const EdgeInsets.only(right: 2),
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: active
                ? AppColors.primaryAccent.withValues(alpha: 0.85)
                : AppColors.surfaceElevated,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            _labels[i],
            style: GoogleFonts.inter(
              fontSize: 7,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        );
      }),
    );
  }
}

// ─── Reminder Row ─────────────────────────────────────────────────────────────

class _ReminderRow extends StatelessWidget {
  final Reminder reminder;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ReminderRow({
    super.key,
    required this.reminder,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.dangerColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline, color: AppColors.dangerColor, size: 22),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              reminder.notifyEnabled
                  ? Icons.notifications_rounded
                  : Icons.notifications_outlined,
              size: 18,
              color: reminder.isActive
                  ? AppColors.secondaryAccent
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: reminder.isActive
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (reminder.notifyEnabled)
                    Text(
                      '${reminder.notifyHr.toString().padLeft(2, '0')}:00',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.secondaryAccent,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              icon: Icon(Icons.edit_outlined,
                  size: 18, color: AppColors.textSecondary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            Switch(value: reminder.isActive, onChanged: onToggle),
          ],
        ),
      ),
    );
  }
}

// ─── Edit Habit Sheet ─────────────────────────────────────────────────────────

class _EditHabitSheet extends ConsumerStatefulWidget {
  final Habit habit;
  final int totalHabits;

  const _EditHabitSheet({required this.habit, required this.totalHabits});

  @override
  ConsumerState<_EditHabitSheet> createState() => _EditHabitSheetState();
}

class _EditHabitSheetState extends ConsumerState<_EditHabitSheet> {

  late final TextEditingController _nameCtrl;
  late final TextEditingController _posCtrl;
  late String   _category;
  late List<int> _daysOfWeek;
  late bool _notifyEnabled;
  late int  _notifyBlock;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.habit.name);
    _posCtrl  = TextEditingController(text: '${widget.habit.sortOrder + 1}');
    _category      = widget.habit.category;
    _daysOfWeek    = List.from(widget.habit.daysOfWeek);
    _notifyEnabled = widget.habit.notifyEnabled;
    _notifyBlock   = _blockFromStartHr(widget.habit.notifyStartHr);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _posCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final enteredPos = int.tryParse(_posCtrl.text.trim());
    final newPos = enteredPos == null
        ? widget.habit.sortOrder + 1
        : enteredPos.clamp(1, widget.totalHabits);

    setState(() => _saving = true);

    final notifier = ref.read(habitsNotifierProvider.notifier);

    // 1. Update all fields (name, category, days, notifications)
    await notifier.updateHabitFields(
      id:            widget.habit.id,
      name:          name,
      category:      _category,
      daysOfWeek:    _daysOfWeek,
      notifyEnabled: _notifyEnabled,
      notifyStartHr: _kBlocks[_notifyBlock].startHr,
      notifyEndHr:   _kBlocks[_notifyBlock].endHr,
    );

    // 2. Reorder if position changed
    final currentHabits = ref.read(habitsNotifierProvider).value ?? [];
    final currentIndex  = currentHabits.indexWhere((h) => h.id == widget.habit.id);
    final newIndex = newPos - 1;
    if (currentIndex != -1 && newIndex != currentIndex) {
      await notifier.reorderHabits(currentIndex, newIndex);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Editar hábito',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // Name
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              style: GoogleFonts.inter(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Nombre del hábito'),
            ),
            const SizedBox(height: 20),

            // Position
            Row(
              children: [
                Text(
                  'Posición',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(1 – ${widget.totalHabits})',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _posCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryAccent,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      filled: true,
                      fillColor: AppColors.primaryAccent.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: AppColors.primaryAccent, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Category
            Text(
              'Categoría:',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ref.watch(categoriesProvider).map((cat) {
                final selected = _category == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (v) {
                    if (v) setState(() => _category = cat);
                  },
                  selectedColor:
                      AppColors.primaryAccent.withValues(alpha: 0.2),
                  backgroundColor: AppColors.surfaceElevated,
                  side: BorderSide(
                    color: selected
                        ? AppColors.primaryAccent
                        : Colors.transparent,
                    width: 1.5,
                  ),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: selected
                        ? AppColors.primaryAccent
                        : AppColors.textSecondary,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Days of week
            Text(
              'Días de la semana:',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            _DayPicker(
              selected: _daysOfWeek,
              onChanged: (days) => setState(() => _daysOfWeek = days),
            ),
            const SizedBox(height: 20),

            // ── Notifications ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications_outlined,
                          size: 18, color: AppColors.secondaryAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Notificaciones',
                            style: GoogleFonts.inter(
                                fontSize: 14, color: AppColors.textPrimary)),
                      ),
                      Switch(
                        value: _notifyEnabled,
                        onChanged: (v) => setState(() => _notifyEnabled = v),
                      ),
                    ],
                  ),
                  if (_notifyEnabled) ...[
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        '¿En qué franja horaria sueles hacerlo?',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _BlockPicker(
                      selectedBlock: _notifyBlock,
                      onChanged: (b) => setState(() => _notifyBlock = b),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            GradientButton(
              label: 'Guardar',
              onPressed: _save,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Create Habit Sheet ───────────────────────────────────────────────────────

class _CreateHabitSheet extends ConsumerStatefulWidget {
  const _CreateHabitSheet();

  @override
  ConsumerState<_CreateHabitSheet> createState() => _CreateHabitSheetState();
}

class _CreateHabitSheetState extends ConsumerState<_CreateHabitSheet> {
  final _nameController = TextEditingController();
  String _category = 'disciplina';
  bool _hasScore = true;
  bool   _saving       = false;
  List<int> _daysOfWeek    = const [1, 2, 3, 4, 5, 6, 7];
  bool _notifyEnabled = false;
  int  _notifyBlock   = 2;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    final currentHabits = ref.read(habitsNotifierProvider).value ?? [];
    final userId = Supabase.instance.client.auth.currentUser!.id;

    final habit = Habit(
      id: '',
      userId: userId,
      name: name,
      category: _category,
      hasScore: _hasScore,
      isActive: true,
      sortOrder: currentHabits.length,
      createdAt: DateTime.now().toUtc(),
      daysOfWeek:    _daysOfWeek,
      notifyEnabled: _notifyEnabled,
      notifyStartHr: _kBlocks[_notifyBlock].startHr,
      notifyEndHr:   _kBlocks[_notifyBlock].endHr,
    );

    await ref.read(habitsNotifierProvider.notifier).createHabit(habit);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Nuevo hábito',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            autofocus: true,
            style: GoogleFonts.inter(color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'Nombre del hábito'),
          ),
          const SizedBox(height: 20),
          Text(
            'Categoría:',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ref.watch(categoriesProvider).map((cat) {
              final selected = _category == cat;
              return ChoiceChip(
                label: Text(cat),
                selected: selected,
                onSelected: (v) {
                  if (v) setState(() => _category = cat);
                },
                selectedColor:
                    AppColors.primaryAccent.withValues(alpha: 0.2),
                backgroundColor: AppColors.surfaceElevated,
                side: BorderSide(
                  color: selected
                      ? AppColors.primaryAccent
                      : Colors.transparent,
                  width: 1.5,
                ),
                labelStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: selected
                      ? AppColors.primaryAccent
                      : AppColors.textSecondary,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cuenta para puntaje',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.textPrimary),
                ),
              ),
              Switch(
                value: _hasScore,
                onChanged: (v) => setState(() => _hasScore = v),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Días de la semana:',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          _DayPicker(
            selected: _daysOfWeek,
            onChanged: (days) => setState(() => _daysOfWeek = days),
          ),
          const SizedBox(height: 20),

          // ── Notifications ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications_outlined,
                        size: 18, color: AppColors.secondaryAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Notificaciones',
                          style: GoogleFonts.inter(
                              fontSize: 14, color: AppColors.textPrimary)),
                    ),
                    Switch(
                      value: _notifyEnabled,
                      onChanged: (v) => setState(() => _notifyEnabled = v),
                    ),
                  ],
                ),
                if (_notifyEnabled) ...[
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      '¿En qué franja horaria sueles hacerlo?',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _BlockPicker(
                    selectedBlock: _notifyBlock,
                    onChanged: (b) => setState(() => _notifyBlock = b),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          GradientButton(
            label: 'Guardar',
            onPressed: _save,
            isLoading: _saving,
          ),
        ],
      ),
    );
  }
}

// ─── Block Picker ─────────────────────────────────────────────────────────────

class _BlockPicker extends StatelessWidget {
  final int selectedBlock;
  final ValueChanged<int> onChanged;

  const _BlockPicker({
    required this.selectedBlock,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(_kBlocks.length, (i) {
        final block = _kBlocks[i];
        final selected = i == selectedBlock;
        return GestureDetector(
          onTap: () => onChanged(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            padding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primaryAccent.withValues(alpha: 0.18)
                  : AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? AppColors.primaryAccent
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Text(
              block.label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? AppColors.primaryAccent
                    : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Edit Reminder Sheet ──────────────────────────────────────────────────────

class _EditReminderSheet extends ConsumerStatefulWidget {
  final Reminder reminder;
  const _EditReminderSheet({required this.reminder});

  @override
  ConsumerState<_EditReminderSheet> createState() => _EditReminderSheetState();
}

class _EditReminderSheetState extends ConsumerState<_EditReminderSheet> {
  late final TextEditingController _nameCtrl;
  late bool _notifyEnabled;
  late int  _notifyBlock;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl      = TextEditingController(text: widget.reminder.name);
    _notifyEnabled = widget.reminder.notifyEnabled;
    _notifyBlock   = _blockFromEndHr(widget.reminder.notifyHr);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final updated = widget.reminder.copyWith(
      name:          name,
      notifyEnabled: _notifyEnabled,
      notifyHr:      _kBlocks[_notifyBlock].endHr,
    );
    await ref.read(remindersNotifierProvider.notifier).updateReminder(updated);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text('Eliminar recordatorio',
            style: GoogleFonts.plusJakartaSans(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('¿Eliminar "${widget.reminder.name}"?',
            style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('Cancelar',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text('Eliminar',
                style: GoogleFonts.inter(
                    color: AppColors.dangerColor,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref
          .read(remindersNotifierProvider.notifier)
          .deleteReminder(widget.reminder.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Editar recordatorio',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              style: GoogleFonts.inter(color: AppColors.textPrimary),
              decoration:
                  const InputDecoration(hintText: 'Nombre del recordatorio'),
            ),
            const SizedBox(height: 20),

            // ── Notifications ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications_outlined,
                          size: 18, color: AppColors.secondaryAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Notificaciones',
                            style: GoogleFonts.inter(
                                fontSize: 14, color: AppColors.textPrimary)),
                      ),
                      Switch(
                        value: _notifyEnabled,
                        onChanged: (v) => setState(() => _notifyEnabled = v),
                      ),
                    ],
                  ),
                  if (_notifyEnabled) ...[
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        '¿En qué franja horaria sueles hacerlo?',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _BlockPicker(
                      selectedBlock: _notifyBlock,
                      onChanged: (b) => setState(() => _notifyBlock = b),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),
            GradientButton(
              label: 'Guardar',
              onPressed: _save,
              isLoading: _saving,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _delete,
                icon: Icon(Icons.delete_outline,
                    size: 18, color: AppColors.dangerColor),
                label: Text('Eliminar recordatorio',
                    style: GoogleFonts.inter(
                        color: AppColors.dangerColor,
                        fontWeight: FontWeight.w500)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.dangerColor, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Day Picker ───────────────────────────────────────────────────────────────

class _DayPicker extends StatelessWidget {
  final List<int> selected;
  final ValueChanged<List<int>> onChanged;

  const _DayPicker({required this.selected, required this.onChanged});

  static const _labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = i + 1;
        final isSelected = selected.contains(day);
        return GestureDetector(
          onTap: () {
            final next = List<int>.from(selected);
            if (isSelected) {
              if (next.length > 1) next.remove(day);
            } else {
              next.add(day);
            }
            onChanged(next..sort());
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryAccent
                  : AppColors.surfaceElevated,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _labels[i],
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Add Reminder Sheet ───────────────────────────────────────────────────────

class _AddReminderSheet extends ConsumerStatefulWidget {
  const _AddReminderSheet();

  @override
  ConsumerState<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends ConsumerState<_AddReminderSheet> {
  final _nameController = TextEditingController();
  bool _notifyEnabled = false;
  int  _notifyBlock   = 2;
  bool _saving        = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    await ref.read(remindersNotifierProvider.notifier).createReminder(
      name,
      notifyEnabled: _notifyEnabled,
      notifyHr: _kBlocks[_notifyBlock].endHr,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Nuevo recordatorio',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            autofocus: true,
            style: GoogleFonts.inter(color: AppColors.textPrimary),
            decoration:
                const InputDecoration(hintText: 'Nombre del recordatorio'),
          ),
          const SizedBox(height: 20),

          // ── Notifications ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications_outlined,
                        size: 18, color: AppColors.secondaryAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Notificaciones',
                          style: GoogleFonts.inter(
                              fontSize: 14, color: AppColors.textPrimary)),
                    ),
                    Switch(
                      value: _notifyEnabled,
                      onChanged: (v) => setState(() => _notifyEnabled = v),
                    ),
                  ],
                ),
                if (_notifyEnabled) ...[
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      '¿En qué franja horaria sueles hacerlo?',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _BlockPicker(
                    selectedBlock: _notifyBlock,
                    onChanged: (b) => setState(() => _notifyBlock = b),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),
          GradientButton(
            label: 'Guardar',
            onPressed: _save,
            isLoading: _saving,
          ),
        ],
      ),
    );
  }
}
