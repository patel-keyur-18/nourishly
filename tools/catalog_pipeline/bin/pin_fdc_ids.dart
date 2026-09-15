// Writes the FoodData Central id each row resolved to back into the
// catalog tables, so the search is never consulted for that row again.
//
//   dart run tools/catalog_pipeline/bin/pin_fdc_ids.dart          # preview
//   dart run tools/catalog_pipeline/bin/pin_fdc_ids.dart --write  # apply
//
// Why pin at all. FDC's search ranking is what put salt on `Butter,
// salted`, rice on `Potatoes, au gratin`, spinach on spinach souffle and
// sweet potato on frozen puffs — and because the search reran on every
// fetch, every fetch was a fresh chance to pick wrong. A row that names
// its id is settled: `USDA #170393 potatoes flesh and skin raw` fetches
// exactly that record for as long as it exists, and the descriptor after
// it stays as documentation.
//
// Read from `build/catalog_seed_draft.json` — the output of the fetch
// whose choices are being recorded — or, with --from-seed, from the
// committed seed.
import 'dart:convert';
import 'dart:io';

import 'package:catalog_pipeline/catalog_pipeline.dart';

void main(List<String> args) {
  const known = ['--write', '--from-seed'];
  final unknown = args.where((a) => !known.contains(a));
  if (unknown.isNotEmpty) {
    stderr.writeln('Usage: pin_fdc_ids.dart [--write] [--from-seed]');
    exit(64);
  }
  final write = args.contains('--write');

  final source = args.contains('--from-seed')
      ? 'app/assets/catalog/seed_v1.json'
      : 'build/catalog_seed_draft.json';
  final file = File(source);
  if (!file.existsSync()) {
    stderr.writeln(
      'No $source. Run fetch_catalog first, or pass --from-seed to pin '
      'from the committed seed.',
    );
    exit(1);
  }

  // Row name -> the id it resolved to.
  final resolvedIds = <String, int>{};
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final rows = (json['resolved'] ?? json['foodItems']) as List;
  for (final r in rows.cast<Map<String, dynamic>>()) {
    if (r['kind'] != 'ingredient') continue;
    final name = (r['foodName'] ?? r['canonicalName']) as String?;
    final id = r['fdcId'] ?? int.tryParse('${r['provenanceId']}');
    if (name != null && id is int) resolvedIds[name] = id;
  }

  final pinned = <String>[];
  final alreadyPinned = <String>[];
  final repinned = <String>[];
  final unresolved = <String>[];

  for (final path
      in Directory('docs/catalog')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md') && !f.path.endsWith('README.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path))) {
    final lines = path.readAsStringSync().split('\n');
    var touched = false;

    for (var i = 0; i < lines.length; i++) {
      final match = RegExp(r'^\| (?:\*\*①\*\* )?([^|]+?) \| ')
          .firstMatch(lines[i]);
      if (match == null) continue;
      final name = match.group(1)!.trim();

      final cells = lines[i].split(' | ');
      final composition = cells.last
          .replaceAll(RegExp(r'\s*\|\s*$'), '')
          .trim();
      final parsed = CompositionParser().parse(composition);
      if (parsed is! UsdaLookup) continue;

      final id = resolvedIds[name];
      if (id == null) {
        unresolved.add(name);
        continue;
      }
      if (parsed.fdcId == id) {
        alreadyPinned.add(name);
        continue;
      }

      // Keep everything after `USDA` as written, only swapping the pin in
      // front of it. The descriptor and any trailing curator note are
      // what make the row readable and they are not this tool's to edit.
      final body = composition
          .replaceFirst(RegExp(r'^USDA\b', caseSensitive: false), '')
          .trim()
          .replaceFirst(RegExp(r'^#\d+\s*'), '');
      cells[cells.length - 1] = 'USDA #$id $body |';
      lines[i] = cells.join(' | ');
      touched = true;
      (parsed.fdcId == null ? pinned : repinned).add(
        '$name  #${parsed.fdcId ?? '-'} -> #$id',
      );
    }

    if (touched && write) path.writeAsStringSync(lines.join('\n'));
  }

  stdout.writeln('Read ${resolvedIds.length} resolved ids from $source\n');
  stdout.writeln('Newly pinned:      ${pinned.length}');
  stdout.writeln('Already pinned:    ${alreadyPinned.length}');
  stdout.writeln('Pin changed:       ${repinned.length}');
  stdout.writeln('No id to pin:      ${unresolved.length}');

  if (repinned.isNotEmpty) {
    stdout.writeln(
      '\nThese were pinned to a different record before. A pin only '
      'changes because someone changed it, so read these:',
    );
    for (final r in repinned) {
      stdout.writeln('  $r');
    }
  }
  if (unresolved.isNotEmpty) {
    stdout.writeln('\nNo id available (not in $source):');
    for (final u in unresolved) {
      stdout.writeln('  $u');
    }
  }
  stdout.writeln(
    write
        ? '\nWritten. Run parse_catalog --check, then fetch_catalog to '
              'confirm every pin resolves.'
        : '\nNothing written. Re-run with --write to apply.',
  );
}
