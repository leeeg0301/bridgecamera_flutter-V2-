import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/saved_photo.dart';

class ManifestService {
  static const _manifest = 'saved_photos.json';

  Future<Directory> _baseDir() async =>
      getApplicationDocumentsDirectory();

  /// ✅ 사진 저장 위치 (전용 폴더)
  Future<Directory> photosDir() async {
    final d = Directory(
      '/storage/emulated/0/Pictures/BridgeCameraApp/photos',
    );
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return d;
  }

  /// ✅ ZIP 저장 위치
  Future<Directory> zipsDir() async {
    final d = Directory(
      '/storage/emulated/0/Download/BridgeCameraApp/exports',
    );
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return d;
  }

  Future<File> _manifestFile() async =>
      File(p.join((await _baseDir()).path, _manifest));

  /// 저장된 목록 로드
  Future<List<SavedPhoto>> loadAll() async {
    final f = await _manifestFile();
    if (!await f.exists()) return [];
    final raw = await f.readAsString();
    final list = jsonDecode(raw) as List;
    return list.map((e) => SavedPhoto.fromJson(e)).toList();
  }

  /// ✅ Atomic 저장
  Future<void> _saveAll(List<SavedPhoto> items) async {
    final f = await _manifestFile();
    final tmp = File('${f.path}.tmp');

    await tmp.writeAsString(
      jsonEncode(items.map((e) => e.toJson()).toList()),
      flush: true,
    );

    if (await f.exists()) {
      await f.delete();
    }

    await tmp.rename(f.path);
  }

  /// 동일 파일명 덮어쓰기 방지
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

  /// 사진 저장
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

  /// ✅ 전체 결과 초기화 (사진 + ZIP + 목록)
  Future<void> clearAllResults({
    bool deletePhotos = true,
    bool deleteZips = true,
  }) async {
    // 1️⃣ 사진 삭제 (manifest 기준으로만 삭제)
    if (deletePhotos) {
      final list = await loadAll();
      for (final it in list) {
        try {
          final f = File(it.filePath);
          if (await f.exists()) {
            await f.delete();
          }
        } catch (_) {}
      }
    }

    // 2️⃣ ZIP 삭제
    if (deleteZips) {
      try {
        final d = await zipsDir();
        if (await d.exists()) {
          await for (final e in d.list(recursive: false)) {
            if (e is File &&
                e.path.toLowerCase().endsWith('.zip')) {
              try {
                await e.delete();
              } catch (_) {}
            }
          }
        }
      } catch (_) {}
    }

    // 3️⃣ manifest 초기화
    await _saveAll([]);
  }

  /// 선택 상태 전체 변경 (필요 시 사용)
  Future<void> updateAllSelection(bool v) async {
    final list = await loadAll();
    for (final e in list) {
      e.selected = v;
    }
    await _saveAll(list);
  }
}
