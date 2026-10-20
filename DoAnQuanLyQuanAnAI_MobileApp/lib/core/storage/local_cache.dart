import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LocalCache {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences get _p {
    assert(_prefs != null, 'LocalCache chưa được khởi tạo. Gọi LocalCache.init() trước.');
    return _prefs!;
  }

  // ── Menu cache ───────────────────────────────────────────────
  static const _menuKey      = 'cached_menu_items';
  static const _menuCatsKey  = 'cached_menu_cats';
  static const _menuTimeKey  = 'cached_menu_time';
  static const _menuTTL      = Duration(minutes: 5);

  static Future<void> saveMenuItems(List<Map<String, dynamic>> items) async {
    await _p.setString(_menuKey, jsonEncode(items));
    await _p.setString(_menuTimeKey, DateTime.now().toIso8601String());
  }

  static Future<void> saveMenuCategories(List<Map<String, dynamic>> cats) async {
    await _p.setString(_menuCatsKey, jsonEncode(cats));
  }

  static List<Map<String, dynamic>>? getMenuItems() {
    if (!_isMenuFresh()) return null;
    final raw = _p.getString(_menuKey);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>();
  }

  static List<Map<String, dynamic>>? getMenuCategories() {
    if (!_isMenuFresh()) return null;
    final raw = _p.getString(_menuCatsKey);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>();
  }

  static bool _isMenuFresh() {
    final timeStr = _p.getString(_menuTimeKey);
    if (timeStr == null) return false;
    final cached = DateTime.tryParse(timeStr);
    if (cached == null) return false;
    return DateTime.now().difference(cached) < _menuTTL;
  }

  static Future<void> clearMenuCache() async {
    await _p.remove(_menuKey);
    await _p.remove(_menuCatsKey);
    await _p.remove(_menuTimeKey);
  }

  // ── Settings ─────────────────────────────────────────────────
  static const _langKey    = 'app_locale';
  static const _themeKey   = 'app_theme';

  static String getLanguage() => _p.getString(_langKey) ?? 'vi';
  static Future<void> saveLanguage(String lang) => _p.setString(_langKey, lang);

  static bool getDarkMode() => _p.getBool(_themeKey) ?? false;
  static Future<void> saveDarkMode(bool val) => _p.setBool(_themeKey, val);

  // ── Generic helpers ──────────────────────────────────────────
  static Future<void> clear() => _p.clear();
}
