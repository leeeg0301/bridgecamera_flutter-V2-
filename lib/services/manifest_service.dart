import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/saved_photo.dart';
import 'logger_service.dart'; // ✅ [변경] 실패 로그 남기기

class ManifestService {
  static const _manifest = 'saved_photos.json';

  Future<Directory> _baseDir() async => getApplicationDocumentsDirectory();

  // ✅ [변경] 사진은 "갤러리에서 찾기 쉬운" Pictures 폴더에만 저장
  Future<Directory> photosDir() async {
    final d = Directory('/storage/emulated/0/Pictures');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  // ✅ [변경] ZIP은 Download/BridgeCameraApp/exports 폴더
  Future<Directory> zipsDir() async {
    final d = Directory('/storage/emulated/0/Download/BridgeCameraApp/exports');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<File> _manifestFile() async =>
      File(p.join((await _baseDir()).path, _manifest));

  Future<List<SavedPhoto>> loadAll() async {
    final f = await _manifestFile();
    if (!await f.exists()) return [];
    try {
      final raw = await f.readAsString();
      final list = jsonDecode(raw) as List;
      return list.map((e) => SavedPhoto.fromJson(e)).toList();
    } catch (e, st) {
      // ✅ [변경] json 깨짐 등도 로그로 남김
      await LoggerService.I.e('manifest load 실패', error: e, st: st);
      return [];
    }
  }

  // ✅ [변경] atomic 저장(중간에 앱 꺼져도 json 깨질 확률 낮춤)
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

  // ✅ [변경] 동일 파일명 충돌 방지: -001, -002 자동 부여
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

    // ✅ [변경] Pictures 폴더에 저장할 때도 이름 충돌 방지
    final safeName = await _avoidCollisionName(dir, name);
    final dst = File(p.join(dir.path, safeName));

    try {
      await src.copy(dst.path);
    } catch (e, st) {
      await LoggerService.I.e('사진 저장(copy) 실패', error: e, st: st);
      rethrow;
    }

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

  // ✅ [변경] 저장 현황 표시용(파일 많아지면 쌓이는지 확인)
  Future<int> photoCount() async {
    final list = await loadAll();
    return list.length;
  }

  // ✅ [변경] Pictures 폴더 전체가 아니라 "manifest에 기록된 파일"만 합산 (정확)
  Future<int> photosBytes() async {
    final list = await loadAll();
    int sum = 0;
    for (final it in list) {
      try {
        final f = File(it.filePath);
        if (await f.exists()) sum += await f.length();
      } catch (_) {}
    }
    return sum;
  }
    // ✅ [추가] 2P에서 "초기화" 버튼 누르면 전체 선택 상태를 한 번에 바꾸기 위해 추가
  Future<void> updateAllSelection(bool v) async {
    final list = await loadAll();
    for (final e in list) {
      e.selected = v;
    }
    await _saveAll(list);
  }
}
