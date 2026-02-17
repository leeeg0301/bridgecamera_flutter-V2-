class PhotoItem {
  final String path;
  final String name;
  bool selected;

  PhotoItem({
    required this.path,
    required this.name,
    this.selected = true,
  });
}
