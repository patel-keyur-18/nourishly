import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

/// Composition root only (§12.3) — DI setup and bootstrap belong here, not
/// in [NourishlyApp]. There is nothing to wire yet beyond Riverpod's scope;
/// providers arrive with the features that need them.
void main() {
  runApp(const ProviderScope(child: NourishlyApp()));
}
