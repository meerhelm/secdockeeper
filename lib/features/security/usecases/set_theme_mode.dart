import 'package:flutter/material.dart' show ThemeMode;

import '../lock_settings.dart';

class SetThemeModeUseCase {
  SetThemeModeUseCase(this._lockSettings);

  final LockSettings _lockSettings;

  Future<void> call(ThemeMode mode) => _lockSettings.setThemeMode(mode);
}
