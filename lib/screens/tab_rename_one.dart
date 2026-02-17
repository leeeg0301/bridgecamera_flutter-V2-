import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../services/manifest_service.dart';
import '../services/sanitizer.dart';
import '../services/bridge_service.dart';
import '../services/logger_service.dart'; // ✅ [변경] 실패 로그

class TabRenameOne extends StatefulWidget {
  const TabRenameOne({super.key});

  @override
  State<TabRenameOne> createState() => _TabRenameOneState();
}

class _TabRenameOneState extends State<TabRenameOne> {
  final manifest = ManifestService();
  final picker = ImagePicker();
  final bridgeService = BridgeService();

  List<String> bridges = [];

  String bridge = '';
  String direction = '순천';
  String location = 'A1';

  final descCtrl = TextEditingController();

  bool saving = false;
  String lastSaved = '-';

  // ✅ [변경] 저장 현황 표시용
  int totalCount = 0;
  int totalBytes = 0;

  @override
  void initState() {
    super.initState();
    _loadBridges();
    _refreshStats(); // ✅ [변경]
  }

  Future<void> _refreshStats() async {
    final c = await manifest.photoCount();
    final b = await manifest.photosBytes();
    if (!mounted) return;
    setState(() {
      totalCount = c;
      totalBytes = b;
    });
  }

  Future<void> _loadBridges() async {
    final list = await bridgeService.loadBridgeNames();
    if (!mounted) return;

    setState(() {
      bridges = list;
      if (bridges.isNotEmpty) {
        bridge = bridges.first;
      }
    });
  }

  @override
  void dispose() {
    descCtrl.dispose();
    super.dispose();
  }

  String _buildName(String ext) {
    return Sanitizer.buildFileName(
      bridge: bridge,
      direction: direction,
      location: location,
      desc: descCtrl.text,
      ext: ext,
    );
  }

  Future<void> _pickAndSave(ImageSource source) async {
    if (bridge.isEmpty) return;

    setState(() => saving = true);
    try {
      final x = await picker.pickImage(source: source, imageQuality: 100);
      if (x == null) return;

      final src = File(x.path);
      final ext = p.extension(x.path).replaceFirst('.', '').toLowerCase();
      final name = _buildName(ext.isEmpty ? 'jpg' : ext);

      final saved = await manifest.savePhoto(src, name);

      if (!mounted) return;
      setState(() => lastSaved = saved.fileName); // ✅ [변경] 실제 저장된 이름

      await _refreshStats(); // ✅ [변경] 저장될 때마다 갱신

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 완료: ${saved.fileName}\n${saved.filePath}')),
      );
    } catch (e, st) {
      await LoggerService.I.e('사진 저장 실패(UI)', error: e, st: st); // ✅ [변경]
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = bridge.isEmpty ? '-' : _buildName('jpg');
    final mb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text(
            '1페이지: 촬영/갤러리 → 파일명 적용 → 저장',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // ✅ [변경] 저장 현황 표시
          Text('저장된 사진: $totalCount개'),
          Text('저장 용량(대략): $mb MB'),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: bridge.isEmpty ? null : bridge,
            items: bridges
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: saving ? null : (v) => setState(() => bridge = v ?? bridge),
            decoration: const InputDecoration(
              labelText: '교량',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: direction,
            items: const [
              DropdownMenuItem(value: '순천', child: Text('순천')),
              DropdownMenuItem(value: '영암', child: Text('영암')),
            ],
            onChanged: saving ? null : (v) => setState(() => direction = v ?? direction),
            decoration: const InputDecoration(
              labelText: '방향',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: location,
            items: const [
              DropdownMenuItem(value: 'A1', child: Text('A1')),
              DropdownMenuItem(value: 'A2', child: Text('A2')),
              DropdownMenuItem(value: 'P1', child: Text('P1')),
              DropdownMenuItem(value: 'S1', child: Text('S1')),
            ],
            onChanged: saving ? null : (v) => setState(() => location = v ?? location),
            decoration: const InputDecoration(
              labelText: '위치',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: descCtrl,
            enabled: !saving,
            decoration: const InputDecoration(
              labelText: '내용(선택)',
              hintText: '예: 균열, 박리, 누수',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 12),
          Text('파일명 미리보기: $preview'),
          const SizedBox(height: 6),
          Text('마지막 저장: $lastSaved'),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saving ? null : () => _pickAndSave(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('촬영'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saving ? null : () => _pickAndSave(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('갤러리'),
                ),
              ),
            ],
          ),

          if (saving) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('저장 중...'),
          ],
        ],
      ),
    );
  }
}
