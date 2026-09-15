// Replays the whole FDC resolution offline, against the committed cache.
//
// `fetch_catalog` takes twenty-five minutes and needs an API key, which
// made every curation mistake cost a full round trip: run it, read the
// report, fix two rows, run it again. That loop is why this exists.
//
// The cache stores every candidate a search returned together with its
// description, so the decision `fetch_catalog` makes — walk the query
// ladder, refuse a candidate that names a different food or another form
// of it, take the first survivor — can be made here with no network at
// all. Rows whose queries are already cached are answered exactly as the
// real run would answer them; rows whose hint has changed since the last
// fetch say so instead of guessing.
//
//   dart run tools/catalog_pipeline/bin/preview_fdc.dart
//   dart run tools/catalog_pipeline/bin/preview_fdc.dart --all
import 'dart:io';

import 'package:catalog_pipeline/catalog_pipeline.dart';

/// What the ladder would settle on for one row.
sealed class _Outcome {
  const _Outcome();
}

class _Resolved extends _Outcome {
  const _Resolved(this.food, this.query, this.refused);
  final FdcCandidate food;
  final String query;
  final List<String> refused;
}

class _Unresolved extends _Outcome {
  const _Unresolved(this.refused, this.uncached);
  final List<String> refused;
  final List<String> uncached;
}

void main(List<String> args) {
  const known = ['--all'];
  final unknown = args.where((a) => !known.contains(a));
  if (unknown.isNotEmpty) {
    stderr.writeln('Usage: preview_fdc.dart [--all]');
    exit(64);
  }
  final showAll = args.contains('--all');

  final cache = FdcCache.defaultLocation();
  final rows = [
    for (final row in loadCatalogSources().rows)
      if (row.composition case final UsdaLookup lookup) (row.entry, lookup),
  ];

  final resolved = <String, _Resolved>{};
  final unresolved = <String, _Unresolved>{};

  for (final (entry, lookup) in rows) {
    final terms = [entry.foodName, ...entry.alsoNames, lookup.hint];
    final queries = <String>{
      if (lookup.hint.trim().isNotEmpty && !lookup.hint.startsWith('—'))
        _sanitize(lookup.hint),
      _sanitize(entry.foodName),
      for (final also in entry.alsoNames) _sanitize(also),
    }..removeWhere((q) => q.isEmpty);

    final refused = <String>[];
    final uncached = <String>[];
    _Resolved? hit;

    outer:
    for (final dataType in [FdcClient.preferredDataTypes, null]) {
      for (final query in queries) {
        final candidates = cache.readSearch(
          FdcCache.searchKey(query, pageSize: 3, dataType: dataType),
        );
        if (candidates == null) {
          // Unknown, and it stops the walk. A later query may be cached
          // and may answer — but the real run asks this one first, and
          // whatever it returns wins. Falling through to a stale answer
          // here would report a row as settled when the fetch is about to
          // decide it differently, which is the whole failure this tool
          // exists to end.
          uncached.add('$query [${dataType ?? '*'}]');
          break outer;
        }
        for (final candidate in candidates) {
          if (!describesSameFood(candidate.description, terms)) {
            refused.add('${candidate.description} — different food');
            continue;
          }
          final form = differentForm(candidate.description, terms);
          if (form.isNotEmpty) {
            refused.add('${candidate.description} — form: ${form.join(', ')}');
            continue;
          }
          hit = _Resolved(candidate, query, refused);
          break outer;
        }
      }
    }

    if (hit != null) {
      resolved[entry.foodName] = hit;
    } else {
      unresolved[entry.foodName] = _Unresolved(refused, uncached);
    }
  }

  final needsFetch = unresolved.entries
      .where((e) => e.value.uncached.isNotEmpty)
      .toList();
  final broken = unresolved.entries
      .where((e) => e.value.uncached.isEmpty)
      .toList();

  stdout.writeln('--- Offline preview of ${rows.length} USDA rows ---');
  stdout.writeln('Would resolve:            ${resolved.length}');
  stdout.writeln('Needs a fetch to know:    ${needsFetch.length}');
  stdout.writeln('Would fail with the cache we have: ${broken.length}');

  if (broken.isNotEmpty) {
    stdout.writeln(
      '\nNothing in the cache satisfies these. Every candidate was '
      'refused, so the hint needs to name the food FDC does:',
    );
    for (final e in broken) {
      stdout.writeln('  ${e.key}');
      for (final r in e.value.refused) {
        stdout.writeln('      refused: $r');
      }
    }
  }

  if (needsFetch.isNotEmpty) {
    stdout.writeln(
      '\nThese carry a hint the cache has never been asked. A fetch will '
      'answer them; nothing here is known to be wrong:',
    );
    for (final e in needsFetch) {
      stdout.writeln('  ${e.key}  (${e.value.uncached.first})');
      for (final r in e.value.refused) {
        stdout.writeln('      refused on a cached query: $r');
      }
    }
  }

  if (showAll) {
    stdout.writeln('\n--- What every resolved row would take ---');
    for (final name in resolved.keys.toList()..sort()) {
      final r = resolved[name]!;
      stdout.writeln('  ${name.padRight(30)} -> ${r.food.description}');
    }
  }
}

String _sanitize(String s) =>
    s.replaceAll(RegExp(r'[/()]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
