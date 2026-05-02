import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const _android2x2 = 'HabitWidget2x2Provider';
  static const _android4x2 = 'HabitWidget4x2Provider';

  static Future<void> update({
    required int completed,
    required int total,
    required List<String> worstPendingHabitNames,
  }) async {
    try {
      await HomeWidget.saveWidgetData<int>('completed', completed);
      await HomeWidget.saveWidgetData<int>('total', total);
      for (var i = 0; i < 3; i++) {
        final name = i < worstPendingHabitNames.length
            ? worstPendingHabitNames[i]
            : '';
        await HomeWidget.saveWidgetData<String>('habit${i + 1}_name', name);
      }
      await HomeWidget.updateWidget(androidName: _android2x2);
      await HomeWidget.updateWidget(androidName: _android4x2);
    } catch (_) {
      // Widget update is non-critical — ignore errors silently.
    }
  }
}
