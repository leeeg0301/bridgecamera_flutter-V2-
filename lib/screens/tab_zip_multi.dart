import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart'; // ✅ XFile

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

  // ✅ [추가] 진행률 상태값
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

  Future<void> _resetSelections() async {
    // ✅ [추가] 전체 선택 해제 + lastZipPath 초기화
    await manifest.updateAllSelection(false);
    await _reload();
    if (mounted) {
      setState(() {
        lastZipPath = null;
        progressDone = 0;
        progressTotal = 0;
      });
    }
  }

  Future<void> _buildZip() async {
    final selected = items.where((e) => e.selected).toList();
    if (selected.isEmpty) return;

    setState(() {
      working = true;
      progressDone = 0;
      progressTotal = selected.length; // ✅ [추가] 총량 표시
    });

    try {
      final outDir = await manifest.zipsDir();

      final photoItems = selected
          .map((e) => PhotoItem(
                path: e.filePath,
                name: e.fileName,
                selected: true,
              ))
          .toList();

      final zipPath = await zipService.buildZip(
        items: photoItems,
        makeFolders: makeFolders,
        outDir: outDir,
        onProgress: (done, total) {
          // ✅ [추가] 진행률 업데이트(멈춘 느낌 해소)
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
    final progressValue =
        (progressTotal == 0) ? null : (progressDone / progressTotal);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ✅ [추가] 상단 버튼들(초기화)
          Row(
            children: [
              Text('총 ${items.length} / 선택 $selectedCount'),
              const Spacer(),
              OutlinedButton(
                onPressed: working ? null : _resetSelections, // ✅ [추가]
                child: const Text('초기화'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: (working || selectedCount == 0) ? null : _buildZip,
                child: const Text('ZIP 생성'),
              ),
            ],
          ),

          // ✅ [추가] 진행률 표시(멈춘 느낌 해소)
          if (working) ...[
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

          // 공유 버튼
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
