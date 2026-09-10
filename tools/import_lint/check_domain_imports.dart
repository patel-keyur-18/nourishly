// Enforces §12.3's load-bearing rule: "nutrition_core and nourishly_domain
// must not import Flutter, Drift, or any HTTP client." (NFR-M-02)
//
// This is deliberately a small, dependency-free script rather than a
// third-party analyzer plugin: the rule it checks is simple and static
// (source text, not type information), and a script we can read end to
// end is easier to trust than a plugin's YAML config doing the same job
// less legibly. Run from the repository root:
//
//   dart run tools/import_lint/check_domain_imports.dart
import 'dart:io';

/// The domain layer: packages that must stay pure Dart (§14.3).
const _domainPackages = [
  'packages/nutrition_core',
  'packages/nourishly_domain',
];

/// Substrings that must never appear in a domain-layer import/export
/// directive. Checked against the quoted URI text, so `package:flutter/…`
/// catches every Flutter package (material, widgets, cupertino, …), not
/// just the umbrella one.
const _forbidden = <String, String>{
  'package:flutter/': 'Flutter',
  'package:flutter_test/': 'Flutter',
  'package:drift/': 'Drift',
  'package:sqlite3': 'a database driver (Drift/SQLite)',
  'package:http/': 'an HTTP client',
  'package:dio/': 'an HTTP client',
  'dart:io': 'dart:io (file/network/process access)',
  'dart:html': 'dart:html (web network access)',
};

final _importExportPattern = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

void main() {
  final violations = <String>[];

  for (final packageDir in _domainPackages) {
    final dir = Directory(packageDir);
    if (!dir.existsSync()) {
      stderr.writeln('warning: $packageDir does not exist, skipping');
      continue;
    }
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // Generated code isn't hand-written and isn't the invariant this
      // check protects; skip it the same way analysis_options.yaml would.
      if (entity.path.endsWith('.g.dart') ||
          entity.path.endsWith('.freezed.dart')) {
        continue;
      }

      final content = entity.readAsStringSync();
      for (final match in _importExportPattern.allMatches(content)) {
        final uri = match.group(1)!;
        for (final entry in _forbidden.entries) {
          if (uri.startsWith(entry.key)) {
            violations.add(
              '${entity.path}: imports "$uri" (${entry.value} is forbidden in the domain layer)',
            );
          }
        }
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('import-lint: ${_domainPackages.join(', ')} are clean.');
    return;
  }

  stderr.writeln(
    'import-lint: domain-layer purity violated (AP-5, §12.3, §14.3):\n',
  );
  for (final v in violations) {
    stderr.writeln('  - $v');
  }
  stderr.writeln(
    '\n${_domainPackages.join(' and ')} must stay pure Dart — no Flutter, '
    'Drift, or network imports. This is what keeps the calculation engine '
    'testable in milliseconds and portable off the client.',
  );
  exit(1);
}
