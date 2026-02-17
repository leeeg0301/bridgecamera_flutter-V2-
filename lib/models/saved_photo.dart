class SavedPhoto {
  final String id;
  final String fileName;
  final String filePath;
  final int createdAtMs;
  bool selected;

  SavedPhoto({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.createdAtMs,
    this.selected = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'filePath': filePath,
        'createdAtMs': createdAtMs,
        'selected': selected,
      };

  static SavedPhoto fromJson(Map<String, dynamic> j) => SavedPhoto(
        id: j['id'],
        fileName: j['fileName'],
        filePath: j['filePath'],
        createdAtMs: j['createdAtMs'],
        selected: j['selected'],
      );
}
