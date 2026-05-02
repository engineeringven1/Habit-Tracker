import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PremiumNotifier extends StateNotifier<bool> {
  static const _key = 'is_premium';

  PremiumNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    state = !state;
    await prefs.setBool(_key, state);
  }

  Future<void> set(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    state = value;
    await prefs.setBool(_key, value);
  }
}

final premiumProvider = StateNotifierProvider<PremiumNotifier, bool>(
  (_) => PremiumNotifier(),
);
