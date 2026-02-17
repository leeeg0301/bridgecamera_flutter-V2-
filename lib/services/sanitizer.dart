class Sanitizer {
  static const String delim = '-';

  static String safeText(String? s) {
    if (s == null) return '';
    var t = s.trim();

    const banned = ['<', '>', ':', '"', '/', '\\', '|', '?', '*'];
    for (final ch in banned) {
      t = t.replaceAll(ch, '');
    }

    t = t.replaceAll('-', '_').replaceAll('.', '_');
    t = t.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).join(' ');
    return t;
  }

  static String buildFileName({
    required String bridge,
    required String direction,
    required String location,
    String? desc,
    String ext = 'jpg',
  }) {
    final parts = <String>[
      safeText(bridge),
      safeText(direction),
      safeText(location),
    ];

    final d = safeText(desc);
    if (d.isNotEmpty) parts.add(d);

    return '${parts.join(delim)}.$ext';
  }

  static List<String> splitBaseName(String fileName) {
    final base = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    return base.split(delim);
  }
}
