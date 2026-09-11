/// Nourishly's design system: tokens, theme, and (as features are built)
/// shared charts and components.
///
/// Every value here is generated from or traces back to
/// `docs/design/tokens/nourishly-indigo.json` — the single source of truth.
/// Regenerate the token file with `dart run tools/token_gen/generate_tokens.dart`
/// from the repository root; never hand-edit `src/tokens.g.dart`.
library;

export 'src/tokens.g.dart';
export 'src/components/energy_ring.dart';
export 'src/components/nourishly_bottom_nav.dart';
export 'src/components/nourishly_card.dart';
export 'src/components/nutrient_bar.dart';
export 'src/components/status_chip.dart';
export 'src/components/water_vessel.dart';
export 'src/theme/nourishly_colors.dart';
export 'src/theme/nourishly_theme.dart';
export 'src/theme/nourishly_typography.dart';
