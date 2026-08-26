import 'package:flutter/material.dart';
import 'package:matchmaster/models/sport.dart';
import 'package:matchmaster/scoring/scoring_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferências locais do usuário.
///
/// Guarda o que a versão anterior prometia mas não fazia: o "Lembrar de mim" do
/// login não tinha efeito nenhum e o nome do perfil era fixo no código.
class SettingsStore extends ChangeNotifier {
  SettingsStore._(this._prefs);

  static const String _kRememberMe = 'remember_me';
  static const String _kUserName = 'user_name';
  static const String _kThemeMode = 'theme_mode';
  static const String _kDefaultSport = 'default_sport';
  static const String _kScoringMode = 'scoring_mode';

  static const String defaultUserName = 'Jogador';

  final SharedPreferences _prefs;

  static Future<SettingsStore> load() async {
    return SettingsStore._(await SharedPreferences.getInstance());
  }

  /// Se o login deve ser pulado na próxima abertura.
  bool get rememberMe => _prefs.getBool(_kRememberMe) ?? false;

  String get userName {
    final String stored = _prefs.getString(_kUserName)?.trim() ?? '';
    return stored.isEmpty ? defaultUserName : stored;
  }

  ThemeMode get themeMode => switch (_prefs.getString(_kThemeMode)) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };

  Sport get defaultSport => Sport.fromId(_prefs.getString(_kDefaultSport));

  ScoringMode get scoringMode => ScoringMode.fromId(_prefs.getString(_kScoringMode));

  Future<void> setRememberMe(bool value, {String? userName}) async {
    await _prefs.setBool(_kRememberMe, value);
    if (userName != null && userName.trim().isNotEmpty) {
      await _prefs.setString(_kUserName, userName.trim());
    }
    notifyListeners();
  }

  Future<void> setUserName(String value) async {
    final String name = value.trim();
    if (name.isEmpty) {
      await _prefs.remove(_kUserName);
    } else {
      await _prefs.setString(_kUserName, name);
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_kThemeMode, mode.name);
    notifyListeners();
  }

  Future<void> setDefaultSport(Sport sport) async {
    await _prefs.setString(_kDefaultSport, sport.id);
    notifyListeners();
  }

  Future<void> setScoringMode(ScoringMode mode) async {
    await _prefs.setString(_kScoringMode, mode.name);
    notifyListeners();
  }

  /// Encerra a sessão: o próximo início volta a pedir login.
  Future<void> signOut() async {
    await _prefs.setBool(_kRememberMe, false);
    notifyListeners();
  }
}
