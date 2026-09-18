// Generates packages/nourishly_ui/lib/src/tokens.g.dart from
// docs/design/tokens/nourishly-indigo.json — the single source of truth for
// the Nourishly design system.
//
// Run from the repository root:
//   dart run tools/token_gen/generate_tokens.dart
//
// Do not hand-edit tokens.g.dart. Change the JSON, then regenerate.
import 'dart:convert';
import 'dart:io';

void main() {
  final repoRoot = Directory.current.path;
  final tokensFile = File('$repoRoot/docs/design/tokens/nourishly-indigo.json');
  if (!tokensFile.existsSync()) {
    stderr.writeln(
      'Could not find ${tokensFile.path}. Run this script from the repository root.',
    );
    exit(1);
  }
  final tokens =
      jsonDecode(tokensFile.readAsStringSync()) as Map<String, dynamic>;

  final buffer = StringBuffer();
  buffer.writeln(_header(tokens));
  buffer.writeln(_fontTokens(tokens['font'] as Map<String, dynamic>));
  buffer.writeln(_typeScale(tokens['typeScale'] as Map<String, dynamic>));
  buffer.writeln(_space(tokens['space'] as Map<String, dynamic>));
  buffer.writeln(_radius(tokens['radius'] as Map<String, dynamic>));
  buffer.writeln(_stroke(tokens['stroke'] as Map<String, dynamic>));
  buffer.writeln(_motion(tokens['motion'] as Map<String, dynamic>));
  buffer.writeln(_target(tokens['target'] as Map<String, dynamic>));
  buffer.writeln(_chart(tokens['chart'] as Map<String, dynamic>));

  final color = tokens['color'] as Map<String, dynamic>;
  buffer.writeln(_palette('light', color['light'] as Map<String, dynamic>));
  buffer.writeln(_palette('dark', color['dark'] as Map<String, dynamic>));

  final outFile = File('$repoRoot/packages/nourishly_ui/lib/src/tokens.g.dart');
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(buffer.toString());
  stdout.writeln('Wrote ${outFile.path}');

  final format = Process.runSync('dart', ['format', outFile.path]);
  if (format.exitCode != 0) {
    stderr.writeln(format.stdout);
    stderr.writeln(format.stderr);
    exit(format.exitCode);
  }
  stdout.writeln('Formatted ${outFile.path}');
}

String _header(Map<String, dynamic> tokens) =>
    '''
// GENERATED CODE — do not hand-edit.
// Source: docs/design/tokens/nourishly-indigo.json (version ${tokens['version']}, ${tokens['status']})
// Regenerate with: dart run tools/token_gen/generate_tokens.dart
// ignore_for_file: public_member_api_docs

import 'package:flutter/widgets.dart' show BoxShadow, Color, Cubic, Curve, Offset;
''';

String _dartString(Object value) =>
    "'${value.toString().replaceAll("'", "\\'")}'";

String _fontTokens(Map<String, dynamic> font) =>
    '''
class NourishlyFontTokens {
  const NourishlyFontTokens._();

  static const String display = ${_dartString(font['display'])};
  static const String body = ${_dartString(font['body'])};
  static const String mono = ${_dartString(font['mono'])};
  static const String fallback = ${_dartString(font['fallback'])};
}
''';

String _typeStyleClassName(String key) =>
    'NourishlyTypeStyle${key[0].toUpperCase()}${key.substring(1)}';

String _typeScale(Map<String, dynamic> typeScale) {
  final buffer = StringBuffer('''
class NourishlyTypeStyleSpec {
  const NourishlyTypeStyleSpec({
    required this.size,
    required this.lineHeight,
    required this.weight,
    required this.tracking,
    this.uppercase = false,
    this.tabularNumerals = false,
  });

  /// Font size in logical pixels.
  final double size;

  /// Line height as a multiplier of [size].
  final double lineHeight;

  /// Font weight, 100-900.
  final int weight;

  /// Letter spacing in logical pixels, already resolved from the token's
  /// em-relative tracking value.
  final double tracking;

  final bool uppercase;
  final bool tabularNumerals;
}

class NourishlyTypeScale {
  const NourishlyTypeScale._();

''');

  for (final entry in typeScale.entries) {
    final spec = entry.value as Map<String, dynamic>;
    final size = (spec['size'] as num).toDouble();
    final lineHeight = (spec['lineHeight'] as num).toDouble();
    final weight = spec['weight'] as int;
    final trackingRaw = spec['tracking'] as String;
    final trackingEm = trackingRaw == '0'
        ? 0.0
        : double.parse(trackingRaw.replaceAll('em', ''));
    final trackingPx = trackingEm * size;
    final uppercase = spec['transform'] == 'uppercase';
    final tabular = spec['variantNumeric'] == 'tabular-nums';
    buffer.writeln(
      '  static const NourishlyTypeStyleSpec ${entry.key} = NourishlyTypeStyleSpec(\n'
      '    size: $size,\n'
      '    lineHeight: $lineHeight,\n'
      '    weight: $weight,\n'
      '    tracking: ${trackingPx.toStringAsFixed(6)},\n'
      '    uppercase: $uppercase,\n'
      '    tabularNumerals: $tabular,\n'
      '  );\n',
    );
  }
  buffer.writeln('}');
  return buffer.toString();
}

String _space(Map<String, dynamic> space) {
  final buffer = StringBuffer(
    'class NourishlySpace {\n  const NourishlySpace._();\n\n',
  );
  for (final entry in space.entries) {
    buffer.writeln(
      '  static const double s${entry.key} = ${(entry.value as num).toDouble()};',
    );
  }
  buffer.writeln('}');
  return buffer.toString();
}

String _radius(Map<String, dynamic> radius) {
  final buffer = StringBuffer(
    'class NourishlyRadius {\n  const NourishlyRadius._();\n\n',
  );
  for (final entry in radius.entries) {
    buffer.writeln(
      '  static const double ${entry.key} = ${(entry.value as num).toDouble()};',
    );
  }
  buffer.writeln('}');
  return buffer.toString();
}

String _stroke(Map<String, dynamic> stroke) {
  final buffer = StringBuffer(
    'class NourishlyStroke {\n  const NourishlyStroke._();\n\n',
  );
  for (final entry in stroke.entries) {
    buffer.writeln(
      '  static const double ${entry.key} = ${(entry.value as num).toDouble()};',
    );
  }
  buffer.writeln('}');
  return buffer.toString();
}

String _motion(Map<String, dynamic> motion) {
  final easing = motion['easing'] as String;
  final match = RegExp(
    r'cubic-bezier\(([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+)\)',
  ).firstMatch(easing)!;
  final a = match.group(1),
      b = match.group(2),
      c = match.group(3),
      d = match.group(4);
  return '''
class NourishlyMotion {
  const NourishlyMotion._();

  static const Duration instant = Duration(milliseconds: ${motion['instant']});
  static const Duration fast = Duration(milliseconds: ${motion['fast']});
  static const Duration base = Duration(milliseconds: ${motion['base']});
  static const Duration slow = Duration(milliseconds: ${motion['slow']});

  /// Cubic bezier easing curve: $easing
  static const Curve easing = Cubic($a, $b, $c, $d);
}
''';
}

String _target(Map<String, dynamic> target) =>
    '''
class NourishlyTarget {
  const NourishlyTarget._();

  static const double minTouch = ${(target['minTouch'] as num).toDouble()};
  static const double minTouchCompact = ${(target['minTouchCompact'] as num).toDouble()};
}
''';

String _chart(Map<String, dynamic> chart) =>
    '''
class NourishlyChart {
  const NourishlyChart._();

  /// Every progress track runs to this multiple of the target so overshoot
  /// stays visible; never fill a bar to its own edge at target.
  static const double trackToTargetRatio = ${(chart['trackToTargetRatio'] as num).toDouble()};
}
''';

String _colorLiteral(String hex) {
  final h = hex.substring(1);
  return "Color(0xFF$h)";
}

String _rgbaLiteral(String rgba) {
  final match = RegExp(
    r'rgba\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)',
  ).firstMatch(rgba)!;
  final r = int.parse(match.group(1)!);
  final g = int.parse(match.group(2)!);
  final b = int.parse(match.group(3)!);
  final a = double.parse(match.group(4)!);
  final alpha = (a * 255).round();
  final hex = ((alpha << 24) | (r << 16) | (g << 8) | b) & 0xFFFFFFFF;
  return 'Color(0x${hex.toRadixString(16).padLeft(8, '0').toUpperCase()})';
}

List<String> _parseShadows(String css) {
  // Split on commas that separate shadows (i.e. that follow a closing
  // paren), not the commas inside rgba(...). CSS also permits a unitless
  // "0" length, so lengths are parsed with an optional "px" suffix.
  final parts = css.split(RegExp(r'(?<=\))\s*,\s*'));
  final shadows = <String>[];
  for (final part in parts) {
    final colorMatch = RegExp(r'rgba\([^)]*\)').firstMatch(part)!;
    final colorLiteral = _rgbaLiteral(colorMatch.group(0)!);
    final lengths = part
        .substring(0, colorMatch.start)
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((s) => s.replaceAll('px', ''))
        .toList();
    final dx = lengths[0];
    final dy = lengths[1];
    final blur = lengths[2];
    final spread = lengths.length > 3 ? lengths[3] : '0';
    shadows.add(
      'BoxShadow(color: $colorLiteral, offset: Offset($dx, $dy), '
      'blurRadius: $blur, spreadRadius: $spread)',
    );
  }
  return shadows;
}

String _elevationList(String key, Map<String, dynamic> elevation) {
  final value = elevation[key] as String;
  if (value == 'none') return '<BoxShadow>[]';
  final shadows = _parseShadows(value);
  return '<BoxShadow>[${shadows.join(', ')}]';
}

String _paletteClassName(String mode) =>
    'Nourishly${mode[0].toUpperCase()}${mode.substring(1)}Colors';

String _palette(String mode, Map<String, dynamic> colors) {
  final status = colors['status'] as Map<String, dynamic>;
  final series = colors['series'] as Map<String, dynamic>;
  final elevation = colors['elevation'] as Map<String, dynamic>;
  final className = _paletteClassName(mode);

  return '''
/// The ${mode == 'light' ? 'light' : 'dark'} palette, straight from
/// docs/design/tokens/nourishly-indigo.json `color.$mode`.
class $className {
  const $className._();

  static const Color bg = ${_colorLiteral(colors['bg'] as String)};
  static const Color surface = ${_colorLiteral(colors['surface'] as String)};
  static const Color surface2 = ${_colorLiteral(colors['surface2'] as String)};
  static const Color surface3 = ${_colorLiteral(colors['surface3'] as String)};
  static const Color line = ${_colorLiteral(colors['line'] as String)};
  static const Color lineStrong = ${_colorLiteral(colors['lineStrong'] as String)};
  static const Color ink = ${_colorLiteral(colors['ink'] as String)};
  static const Color ink2 = ${_colorLiteral(colors['ink2'] as String)};
  static const Color ink3 = ${_colorLiteral(colors['ink3'] as String)};
  static const Color inkDisabled = ${_colorLiteral(colors['inkDisabled'] as String)};
  static const Color accent = ${_colorLiteral(colors['accent'] as String)};
  static const Color accentHover = ${_colorLiteral(colors['accentHover'] as String)};
  static const Color accentInk = ${_colorLiteral(colors['accentInk'] as String)};
  static const Color accentSoft = ${_colorLiteral(colors['accentSoft'] as String)};
  static const Color accentSoftInk = ${_colorLiteral(colors['accentSoftInk'] as String)};
  static const Color track = ${_colorLiteral(colors['track'] as String)};
  static const Color focus = ${_colorLiteral(colors['focus'] as String)};
  static const Color scrim = ${_rgbaLiteral(colors['scrim'] as String)};
  static const Color danger = ${_colorLiteral(colors['danger'] as String)};
  static const Color dangerSoft = ${_colorLiteral(colors['dangerSoft'] as String)};

  // Status colours are reserved and never reused as a series colour; they
  // always ship with a label and a dot, never colour alone.
  static const Color statusOk = ${_colorLiteral(status['ok'] as String)};
  static const Color statusLow = ${_colorLiteral(status['low'] as String)};
  static const Color statusHigh = ${_colorLiteral(status['high'] as String)};
  static const Color statusUnknown = ${_colorLiteral(status['unknown'] as String)};

  // Series order is fixed: protein, carbs, fat, fibre. Hues are assigned by
  // slot and never cycled or reassigned by rank.
  static const Color seriesProtein = ${_colorLiteral(series['protein'] as String)};
  static const Color seriesCarbs = ${_colorLiteral(series['carbs'] as String)};
  static const Color seriesFat = ${_colorLiteral(series['fat'] as String)};
  static const Color seriesFibre = ${_colorLiteral(series['fibre'] as String)};

  static const List<BoxShadow> elevation0 = ${_elevationList('0', elevation)};
  static const List<BoxShadow> elevation1 = ${_elevationList('1', elevation)};
  static const List<BoxShadow> elevation2 = ${_elevationList('2', elevation)};
  static const List<BoxShadow> elevation3 = ${_elevationList('3', elevation)};
}
''';
}
