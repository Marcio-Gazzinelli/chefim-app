part of '../main.dart';

class PreferencesService {
  PreferencesService._();

  static final PreferencesService instance = PreferencesService._();

  static const String _nightModeKey = 'night_mode';
  static const String _dataSaverKey = 'data_saver';
  static const String _automaticSyncKey = 'automatic_sync';
  static const String _personalizedSuggestionsKey = 'personalized_suggestions';

  static const String _expiryNotificationsKey = 'expiry_notifications';
  static const String _recipeNotificationsKey = 'recipe_notifications';
  static const String _shoppingNotificationsKey = 'shopping_notifications';
  static const String _expiryWarningDaysKey = 'expiry_warning_days';
  static const String _currentUserIdKey = 'current_user_id';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<bool> getNightMode() async {
    return await _preferences.getBool(_nightModeKey) ?? false;
  }

  Future<void> setNightMode(bool enabled) async {
    await _preferences.setBool(_nightModeKey, enabled);
  }

  Future<bool> getDataSaver() async {
    return await _preferences.getBool(_dataSaverKey) ?? true;
  }

  Future<void> setDataSaver(bool enabled) async {
    await _preferences.setBool(_dataSaverKey, enabled);
  }

  Future<bool> getAutomaticSync() async {
    return await _preferences.getBool(_automaticSyncKey) ?? true;
  }

  Future<void> setAutomaticSync(bool enabled) async {
    await _preferences.setBool(_automaticSyncKey, enabled);
  }

  Future<bool> getPersonalizedSuggestions() async {
    return await _preferences.getBool(_personalizedSuggestionsKey) ?? false;
  }

  Future<void> setPersonalizedSuggestions(bool enabled) async {
    await _preferences.setBool(_personalizedSuggestionsKey, enabled);
  }

  Future<bool> getExpiryNotifications() async {
    return await _preferences.getBool(_expiryNotificationsKey) ?? true;
  }

  Future<void> setExpiryNotifications(bool enabled) async {
    await _preferences.setBool(_expiryNotificationsKey, enabled);
  }

  Future<bool> getRecipeNotifications() async {
    return await _preferences.getBool(_recipeNotificationsKey) ?? true;
  }

  Future<void> setRecipeNotifications(bool enabled) async {
    await _preferences.setBool(_recipeNotificationsKey, enabled);
  }

  Future<bool> getShoppingNotifications() async {
    return await _preferences.getBool(_shoppingNotificationsKey) ?? false;
  }

  Future<void> setShoppingNotifications(bool enabled) async {
    await _preferences.setBool(_shoppingNotificationsKey, enabled);
  }

  Future<int> getExpiryWarningDays() async {
    return await _preferences.getInt(_expiryWarningDaysKey) ?? 3;
  }

  Future<void> setExpiryWarningDays(int days) async {
    await _preferences.setInt(_expiryWarningDaysKey, days);
  }

  Future<int?> getCurrentUserId() async {
    return _preferences.getInt(_currentUserIdKey);
  }

  Future<void> setCurrentUserId(int userId) async {
    await _preferences.setInt(_currentUserIdKey, userId);
  }

  Future<void> clearCurrentUserId() async {
    await _preferences.remove(_currentUserIdKey);
  }
}
