/// Product rule: no em or en dashes anywhere the user sees, in inputs or
/// outputs. The model is told not to emit them and the backend strips them, but
/// this is the client-side safety net (and it also cleans static UI text and the
/// offline demo content). Replaces both dash glyphs with a plain hyphen.
extension NoDashes on String {
  String get noDashes => replaceAll('—', '-').replaceAll('–', '-');
}
