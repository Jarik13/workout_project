import 'package:shared_preferences/shared_preferences.dart';

class LocalPreferences {
  static SharedPreferences? _prefs;
  
  static const _keyNotifications = 'local_notifications';
  static const _keyTheme = 'local_theme';
  static const _keyLanguage = 'local_language';
  static const _keyWorkoutStreak = 'workout_streak';
  static const _keyLastWorkoutDate = 'last_workout_date';
  static const _keyTotalMinutes = 'total_workout_minutes';
  static const _keyExpandedSections = 'expanded_sections';
  static const _keyLastViewedTab = 'last_viewed_tab';
  static const _keyShowMetrics = 'show_metrics';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static void _checkInit() {
    assert(_prefs != null, 'LocalPreferences not initialized. Call init() first.');
  }

  static Future<void> saveLocalNotifications(bool enabled) async {
    _checkInit();
    await _prefs!.setBool(_keyNotifications, enabled);
  }

  static bool getLocalNotifications() {
    _checkInit();
    return _prefs!.getBool(_keyNotifications) ?? true;
  }

  static Future<void> saveTheme(bool isDark) async {
    _checkInit();
    await _prefs!.setBool(_keyTheme, isDark);
  }

  static bool getTheme() {
    _checkInit();
    return _prefs!.getBool(_keyTheme) ?? false;
  }

  static Future<void> saveLanguage(String language) async {
    _checkInit();
    await _prefs!.setString(_keyLanguage, language);
  }

  static String getLanguage() {
    _checkInit();
    return _prefs!.getString(_keyLanguage) ?? 'en';
  }

  static Future<void> updateWorkoutStreak() async {
    _checkInit();
    final today = DateTime.now();
    final lastDate = _prefs!.getString(_keyLastWorkoutDate);
    
    if (lastDate != null) {
      final lastWorkout = DateTime.parse(lastDate);
      final difference = today.difference(lastWorkout).inDays;
      
      if (difference == 1) {
        final currentStreak = _prefs!.getInt(_keyWorkoutStreak) ?? 0;
        await _prefs!.setInt(_keyWorkoutStreak, currentStreak + 1);
      } else if (difference > 1) {
        await _prefs!.setInt(_keyWorkoutStreak, 1);
      }
    } else {
      await _prefs!.setInt(_keyWorkoutStreak, 1);
    }
    
    await _prefs!.setString(_keyLastWorkoutDate, today.toIso8601String());
  }

  static int getWorkoutStreak() {
    _checkInit();
    return _prefs!.getInt(_keyWorkoutStreak) ?? 0;
  }

  static Future<void> addWorkoutMinutes(int minutes) async {
    _checkInit();
    final current = _prefs!.getInt(_keyTotalMinutes) ?? 0;
    await _prefs!.setInt(_keyTotalMinutes, current + minutes);
  }

  static int getTotalMinutes() {
    _checkInit();
    return _prefs!.getInt(_keyTotalMinutes) ?? 0;
  }

  static Future<void> saveExpandedSections(List<String> sections) async {
    _checkInit();
    await _prefs!.setStringList(_keyExpandedSections, sections);
  }

  static List<String> getExpandedSections() {
    _checkInit();
    return _prefs!.getStringList(_keyExpandedSections) ?? ['account', 'notifications'];
  }

  static Future<void> saveLastViewedTab(String tab) async {
    _checkInit();
    await _prefs!.setString(_keyLastViewedTab, tab);
  }

  static String getLastViewedTab() {
    _checkInit();
    return _prefs!.getString(_keyLastViewedTab) ?? 'profile';
  }

  static Future<void> saveShowMetrics(bool show) async {
    _checkInit();
    await _prefs!.setBool(_keyShowMetrics, show);
  }

  static bool getShowMetrics() {
    _checkInit();
    return _prefs!.getBool(_keyShowMetrics) ?? true;
  }

  static Future<void> clearUserData() async {
    _checkInit();
    await _prefs!.remove(_keyWorkoutStreak);
    await _prefs!.remove(_keyLastWorkoutDate);
    await _prefs!.remove(_keyTotalMinutes);
    await _prefs!.remove(_keyLastViewedTab);
  }
}