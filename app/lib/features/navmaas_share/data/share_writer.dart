import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nourishly_data/nourishly_data.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/providers.dart';
import '../../food_catalog/data/food_catalog_providers.dart';

const _fileName = 'nourishly-share.json';

/// Where the Navmaas share file lives (ADR-012, docs/navmaas-share.md):
/// Android's private `filesDir/share`, which `ShareProvider` serves behind
/// a signature permission; iOS's App Group `group.com.patelkeyur.share`.
/// Null elsewhere: nothing to share with.
Future<Directory?> platformShareDirectory() async {
  if (Platform.isAndroid) {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/share').create(recursive: true);
  }
  if (Platform.isIOS) {
    final path = await const MethodChannel('nourishly/share')
        .invokeMethod<String>('groupDirectory');
    return path == null ? null : Directory(path);
  }
  return null;
}

final navmaasShareDirectoryProvider = Provider<Future<Directory?> Function()>(
  (ref) => platformShareDirectory,
);

/// How long the writer waits after a change, so a burst of edits is one
/// write. Overridden in tests.
final navmaasShareDebounceProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 2),
);

/// Keeps the share file in step with her log while sharing is on, and
/// removes it when sharing is off. Writes run one after another, so a
/// write that was pending when she turned sharing off can't bring the
/// file back.
class NavmaasShareWriter extends Notifier<void> {
  Timer? _debounce;
  Future<void> _last = Future.value();

  @override
  void build() {
    final db = ref.watch(nourishlyDatabaseProvider);
    final changes = db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            db.foodLogEntries,
            db.logEntryNutrients,
            db.foodItems,
            db.servingSizes,
            db.userPreferences,
          ]),
        )
        .listen((_) => _schedule());
    ref.onDispose(() {
      _debounce?.cancel();
      unawaited(changes.cancel());
    });
    _schedule();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(ref.read(navmaasShareDebounceProvider), () {
      unawaited(flush());
    });
  }

  /// Brings the file up to date now (the app going to the background).
  Future<void> flush() {
    _debounce?.cancel();
    return _last = _last.then((_) => _write()).catchError((Object e) {
      // Navmaas shows "couldn't read" for a stale or missing file; nothing
      // here is worth interrupting her for.
      debugPrint('Nourishly: share file not written ($e)');
    });
  }

  Future<void> _write() async {
    final dir = await ref.read(navmaasShareDirectoryProvider)();
    if (dir == null) return;
    final file = File('${dir.path}/$_fileName');
    final temp = File('${file.path}.tmp');
    final db = ref.read(nourishlyDatabaseProvider);
    final ownerId = await ref.read(defaultOwnerProvider.future);
    final prefs = await PreferencesDao(db).forOwner(ownerId);
    if (!prefs.shareWithNavmaas) {
      for (final f in [file, temp]) {
        if (f.existsSync()) await f.delete();
      }
      return;
    }
    final share = await buildNavmaasShare(
      db: db,
      ownerId: ownerId,
      today: ref.read(todayProvider),
      now: ref.read(clockProvider).now(),
    );
    await temp.writeAsString(jsonEncode(share), flush: true);
    await temp.rename(file.path);
  }
}

final navmaasShareWriterProvider = NotifierProvider<NavmaasShareWriter, void>(
  NavmaasShareWriter.new,
);
