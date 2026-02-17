import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../models/photo_item.dart';
import 'sanitizer.dart';

class ZipService {
  Future<String> buildZip({
    required List<PhotoItem> items,
    required bool makeFolders,
    required Directory outDir,
    String? zipName,
    void Function(int done, int total)? onProgress, // ✅ [추가] 진행률 콜백
  }) async {
    final selected = items.where((e) => e.selected).toList();
    if (selected.isEmpty) {
      throw Exception('선택된 사진이 없습니다.');
    }

    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    final baseZipName = zipName ?? '점검사진_$stamp.zip';
    final finalZipName = await _avoidZipCollision(outDir, baseZipName);
    final zipPath = p.join(outDir.path, finalZipName);

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    final total = selected.length;
    int done = 0;

    for (final item in selected) {
      final f = File(item.path);
      if (!await f.exists()) {
        // ✅ [추가] 파일이 없어도 진행률은 올라가게 처리(멈춘 것처럼 보이는 문제 방지)
        done++;
        onProgress?.call(done, total);
        continue;
      }

      final fileName = p.basename(item.path);

      String arcName = fileName;
      if (makeFolders) {
        final parts = Sanitizer.splitBaseName(fileName);
        if (parts.length >= 3) {
          arcName = '${parts[0]}/${parts[1]}/${parts[2]}/$fileName';
        }
      }

      encoder.addFile(f, arcName);

      // ✅ [추가] 진행률 업데이트
      done++;
      onProgress?.call(done, total);
    }

    encoder.close();
    return zipPath;
  }

  Future<String> _avoidZipCollision(Directory dir, String name) async {
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
}
