import 'package:flutter_test/flutter_test.dart';
import 'package:nourishly/features/data_backup/data/export_file_type.dart';

/// The guard on the bug that made Import do nothing at all on iOS.
///
/// `XTypeGroup` looks like one description of a file type, but each
/// platform implementation reads a different field and refuses to fall
/// back to the others. The group that shipped carried only `extensions`,
/// so `file_selector_ios` threw `ArgumentError` before a picker ever
/// appeared — and because the call sat outside the screen's error
/// handling, the button did nothing at all.
///
/// These assertions are the platform rules restated, taken from the
/// implementations themselves rather than from memory:
///
/// - `file_selector_ios` (`file_selector_ios.dart`): a group that does not
///   allow any file must have a non-empty `uniformTypeIdentifiers`.
/// - `file_selector_android` (`file_selector_android.dart`): a group that
///   does not allow any file must have a non-empty `mimeTypes` **or**
///   `extensions`.
/// - `file_selector_macos` follows iOS and reads UTIs.
///
/// A unit test cannot open a real picker, so it checks the thing that was
/// actually wrong: the declaration. That is enough to stop this
/// regressing, and it costs nothing to run.
void main() {
  group('the Nourishly export file type', () {
    test('satisfies the iOS and macOS rule (uniform type identifiers)', () {
      expect(
        nourishlyExportFileType.uniformTypeIdentifiers,
        isNotEmpty,
        reason:
            'file_selector_ios throws ArgumentError without these, which '
            'is why Import silently did nothing on an iPhone',
      );
      expect(
        nourishlyExportFileType.uniformTypeIdentifiers,
        contains('public.json'),
      );
    });

    test('satisfies the Android rule (mime types or extensions)', () {
      final hasMime = nourishlyExportFileType.mimeTypes?.isNotEmpty ?? false;
      final hasExtensions =
          nourishlyExportFileType.extensions?.isNotEmpty ?? false;
      expect(hasMime || hasExtensions, isTrue);
      expect(
        nourishlyExportFileType.mimeTypes,
        contains('application/json'),
        reason:
            "Android maps extensions through MimeTypeMap, which does not "
            'know "json" on every release — so the MIME type is given '
            'outright rather than inferred',
      );
    });

    test('every platform field is populated, not just the one we test on', () {
      // The failure mode here is a group that works on whichever device
      // the developer happens to hold. All four fields or none.
      expect(nourishlyExportFileType.extensions, isNotEmpty);
      expect(nourishlyExportFileType.mimeTypes, isNotEmpty);
      expect(nourishlyExportFileType.uniformTypeIdentifiers, isNotEmpty);
      expect(nourishlyExportFileType.label, isNotNull);
    });

    test('accepts files a mail app or cloud drive mislabels', () {
      // An export that arrives by email is often tagged text/plain, and
      // one from a cloud drive application/octet-stream. A picker that
      // cannot see the file is as broken as one that crashes; the archive
      // is validated when it is opened, so a wrong file gets a clear
      // message rather than being unselectable.
      expect(nourishlyExportFileType.mimeTypes, contains('text/plain'));
      expect(
        nourishlyExportFileType.uniformTypeIdentifiers,
        contains('public.data'),
      );
    });

    test('is not a wildcard — it still describes a JSON file', () {
      // The lenient fallbacks above must not slide into "any file at all",
      // which would make the picker useless for finding an export.
      expect(nourishlyExportFileType.allowsAny, isFalse);
      expect(nourishlyExportFileType.extensions, ['json']);
    });
  });
}
