import '../database.dart';

/// Returns the id of the device's local profile, creating one ("You") if
/// none exists yet.
///
/// Profile creation UI is Phase 3 (§27.1 onboarding); until it exists,
/// logging needs *some* owner to attach entries to, so this is the
/// pragmatic stand-in — matches the common case anyway (§0.4: "typical
/// use: one profile per phone").
Future<String> ensureDefaultOwner(NourishlyDatabase db) async {
  final existing = await db.select(db.users).get();
  if (existing.isNotEmpty) return existing.first.id;

  const uuid = 'default-owner';
  await db
      .into(db.users)
      .insert(
        UsersCompanion.insert(
          id: uuid,
          displayName: 'You',
          avatarColor: '#3b4d9e',
        ),
      );
  return uuid;
}
