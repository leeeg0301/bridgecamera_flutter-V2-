import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/saved_photo.dart';

class ManifestService {
  static const _manifest = 'saved_photos.json';

  Future<Directory> _baseDir() async => getApplicationDocumentsDirectory();

  // (네가 운영형으로 바꾼 기준 유지)
  Future<Directory> photosDir() async {
    final d = Directory('/storage/emulated/0/Pictures'); // 사진은 갤러리(Pictures)에만
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<Directory> zipsDir() async {
    final d = Directory('/storage/emulated/0/Download/BridgeCameraApp/exports'); // zip은 downloads
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<File> _manifestFile() async =>
      File(p.join((await _baseDir()).path, _manifest));

  Future<List<SavedPhoto>> loadAll() async {
    final f = await _manifestFile();
    if (!await f.exists()) return [];
    final raw = await f.readAsString();
    final list = jsonDecode(raw) as List;
    return list.map((e) => SavedPhoto.fromJson(e)).toList();
  }

  // ✅ atomic 저장 유지
  Future<void> _saveAll(List<SavedPhoto> items) async {
    final f = await _manifestFile();
    final tmp = File('${f.path}.tmp');

    await tmp.writeAsString(
      jsonEncode(items.map((e) => e.toJson()).toList()),
      flush: true,
    );

    if (await f.exists()) await f.delete();
    await tmp.rename(f.path);
  }

  Future<String> _avoidCollisionName(Directory dir, String name) async {
    final ext = p.extension(name);
    final base = p.basenameWithoutExtension(name);

    var candidate = name;
    var i = 1;

    while (await File(p.join(dir.path, candidate)).exists()) {
      candidate = '${base}-${i.toString().padLeft(3, '0')}$ext';
      i++;
    }
    return candidate;
  }

  Future<SavedPhoto> savePhoto(File src, String name) async {
    final dir = await photosDir();

    final safeName = await _avoidCollisionName(dir, name);
    final dst = File(p.join(dir.path, safeName));
    await src.copy(dst.path);

    final now = DateTime.now().millisecondsSinceEpoch;

    final item = SavedPhoto(
      id: now.toString(),
      fileName: safeName,
      filePath: dst.path,
      createdAtMs: now,
    );

    final list = await loadAll();
    list.insert(0, item);
    await _saveAll(list);
    return item;
  }

  Future<void> updateSelection(String id, bool v) async {
    final list = await loadAll();
    for (final e in list) {
      if (e.id == id) e.selected = v;
    }
    await _saveAll(list);
  }

  // ✅ [추가] 전체 결과 초기화 (사진 + manifest + zip 모두 정리)
  Future<void> clearAllResults({
    bool deletePhotos = true,
    bool deleteZips = true,
  }) async {
    // 1) 사진 삭제( manifest 기준으로만 삭제 → Pictures 전체를 건드리지 않음 )
    if (deletePhotos) {
      final list = await loadAll();
      for (final it in list) {
        try {
          final f = File(it.filePath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }

    // 2) zip 삭제 (exports 폴더 안 zip만)
    if (deleteZips) {
      try {
        final d = await zipsDir();
        if (await d.exists()) {
          await for (final e in d.list(recursive: false)) {
            if (e is File && e.path.toLowerCase().endsWith('.zip')) {
              try { await e.delete(); } catch (_) {}
            }
          }
        }
      } catch (_) {}
    }

    // 3) manifest 초기화
    await _saveAll([]);
  }

  // ✅ [유지/필요] 2P에서 “선택 초기화” 같은 것 필요하면 사용
  Future<void> updateAllSelection(bool v) async {
    final list = await loadAll();
    for (final e in list) {
      e.selected = v;
    }
    await _saveAll(list);
  }
}
