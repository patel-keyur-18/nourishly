import 'package:file_selector/file_selector.dart';

/// What a Nourishly export looks like to each platform's file picker.
///
/// All three descriptions of the same thing, because each platform reads
/// a different one and **ignores the others**. `extensions` alone is what
/// this shipped with, and it is why Import did nothing at all on an
/// iPhone: `file_selector_ios` throws `ArgumentError` for a type group
/// with no `uniformTypeIdentifiers`, rather than falling back to the
/// extension. Android converts extensions to MIME types through
/// `MimeTypeMap`, which does not know `json` on every release, so it is
/// given the MIME type outright too.
///
/// `public.json` is the system UTI; `public.text` and `public.data` sit
/// behind it so a file that arrived by email, or from a cloud drive that
/// tagged it as plain text or as an octet-stream, is still selectable. An
/// import that cannot see the file it needs is as broken as one that
/// crashes, and the archive is validated on open regardless — a wrong
/// file gets "that file is not a Nourishly export", not silence.
const nourishlyExportFileType = XTypeGroup(
  label: 'Nourishly export',
  extensions: ['json'],
  mimeTypes: ['application/json', 'text/json', 'text/plain'],
  uniformTypeIdentifiers: ['public.json', 'public.text', 'public.data'],
);
