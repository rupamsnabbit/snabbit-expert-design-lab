/// Stable localization map key from display copy (e.g. `"Home Cleaning"` → `home_cleaning`).
/// Empty if [input] has no letters/digits after normalization.
String snakeCaseLocalizationKey(String input) {
  final lower = input.trim().toLowerCase();
  if (lower.isEmpty) return '';
  var s = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  s = s.replaceAll(RegExp(r'_+'), '_');
  if (s.startsWith('_')) {
    s = s.substring(1);
  }
  if (s.endsWith('_')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}
