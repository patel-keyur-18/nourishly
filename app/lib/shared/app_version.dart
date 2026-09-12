/// The app's own version, for Settings' footer and for the export
/// manifest (§30.6).
///
/// A constant rather than a `package_info_plus` lookup: one string is not
/// worth a plugin and a platform channel, and `app_version_test.dart`
/// checks it against `pubspec.yaml` so the two cannot drift.
const appVersion = '0.1.0';

/// The scoring ruleset these targets and scores were computed under
/// (ADR-010, §25.7). Stamped into every export, because a summary read
/// against a different ruleset is a different number.
const rulesetVersion = '2026.09';
