import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';

import '../models/photo_item.dart';
import '../models/saved_photo.dart';
import '../services/manifest_service.dart';
import '../services/zip_service.dart';

class TabZipMulti extends StatefulWidget {
  const TabZipMulti({super.key});

  @override
  State<TabZipMulti> createState() => _TabZipMultiState();
}

class _TabZipMultiState extends State<TabZipMulti> {
  final manifest = ManifestService();
  final zipService = ZipService();

  List<SavedPhoto> items = [];
  bool makeFolders = true;
  bool working = false;

  int progressDone = 0;
  int progressTotal = 0;

  String? lastZipPath;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await manifest.loadAll();
    if (mounted) setState(() => items = list);
  }

  Future<void> _toggle(String id, bool v) async {
    await manifest.updateSelection(id, v);
    await _reload();
  }

  // ✅ [추가] 전체 결과 초기화 다이얼로그 + 실행
  Future<void> _confirmAndClearAll() async {
    if (working) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('전체 결과 초기화'),
        content: const Text(
          '저장된 사진(갤러리) + ZIP(Downloads) + 목록이 모두 삭제됩니다.\n'
          '이 작업은 되돌릴 수 없습니다.\n\n'
          '정말 초기화할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('초기화'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() {
      working = true;
      progressDone = 0;
      progressTotal = 0;
    });

    try {
      await manifest.clearAllResults(deletePhotos: true, deleteZips: true);
      await _reload();

      if (!mounted) return;
      setState(() {
        lastZipPath = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전체 결과 초기화 완료')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('초기화 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _buildZip() async {
    final selected = items.where((e) => e.selected).toList();
    if (selected.isEmpty) return;

    setState(() {
      working = true;
      progressDone = 0;
      progressTotal = selected.length;
    });

    try {
      final outDir = await manifest.zipsDir();

      final photoItems = selected
          .map((e) => PhotoItem(path: e.filePath, name: e.fileName, selected: true))
          .toList();

      final zipPath = await zipService.buildZip(
        items: photoItems,
        makeFolders: makeFolders,
        outDir: outDir,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            progressDone = done;
            progressTotal = total;
          });
        },
      );

      if (mounted) {
        setState(() => lastZipPath = zipPath);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ZIP 생성 완료: ${p.basename(zipPath)}')),
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = items.where((e) => e.selected).length;
    final progressValue = (progressTotal == 0) ? null : (progressDone / progressTotal);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text('총 ${items.length} / 선택 $selectedCount'),
              const Spacer(),
              OutlinedButton(
                // ✅ [변경] 기존 선택 초기화가 아니라 “전체 결과 초기화”
                onPressed: working ? null : _confirmAndClearAll,
                child: const Text('전체 초기화'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: (working || selectedCount == 0) ? null : _buildZip,
                child: const Text('ZIP 생성'),
              ),
            ],
          ),

          if (working && progressTotal > 0) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progressValue),
            const SizedBox(height: 6),
            Text('ZIP 생성 중... ($progressDone / $progressTotal)'),
          ],

          const SizedBox(height: 8),

          CheckboxListTile(
            value: makeFolders,
            onChanged: working ? null : (v) => setState(() => makeFolders = v ?? true),
            title: const Text('폴더 분류'),
          ),

          if (lastZipPath != null)
            Row(
              children: [
                OutlinedButton(
                  onPressed: () async {
                    await Share.shareXFiles([XFile(lastZipPath!)]);
                  },
                  child: const Text('공유'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.basename(lastZipPath!),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

          const Divider(),

          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final it = items[i];
                return CheckboxListTile(
                  value: it.selected,
                  onChanged: working ? null : (v) => _toggle(it.id, v ?? false),
                  title: Text(it.fileName),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
