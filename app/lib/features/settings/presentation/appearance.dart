import 'package:flutter/material.dart';

/// The three values `UserPreferences.theme` can hold (§27.13, FR-S-09).
///
/// A type rather than three bare strings, because the same values are
/// written by Settings, read by [NourishlyApp], and stored in a column
/// that an import can fill from another device — three places that have
/// to agree on the spelling, and nothing was checking that they did.
enum Appearance {
  /// The default, and what the prototype was approved in — the palette
  /// was drawn light-first (§27.14).
  light('light', 'Light'),
  dark('dark', 'Dark'),

  /// Follows the phone. Named "Match my phone" rather than "System"
  /// because that is the thing the user is actually choosing; "System"
  /// is what the setting is called in code, not what it does.
  system('system', 'Match my phone');

  const Appearance(this.id, this.label);

  /// The value stored in the column.
  final String id;
  final String label;

  /// Falls back to [light] for an unreadable value rather than throwing.
  ///
  /// The column can hold a string this build does not know — an import
  /// from a newer version, or a hand-edited archive. An app that refuses
  /// to start because it does not recognise a colour scheme would be a
  /// poor trade.
  static Appearance fromId(String? id) {
    for (final appearance in values) {
      if (appearance.id == id) return appearance;
    }
    return light;
  }

  ThemeMode get themeMode => switch (this) {
    Appearance.light => ThemeMode.light,
    Appearance.dark => ThemeMode.dark,
    Appearance.system => ThemeMode.system,
  };
}
