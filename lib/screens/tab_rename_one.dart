import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../services/manifest_service.dart';
import '../services/sanitizer.dart';
import '../services/bridge_service.dart';

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

  // ✅ [변경] 교량은 Autocomplete + 직접입력용 컨트롤러 사용
  final bridgeCtrl = TextEditingController();

  String bridge = '';
  String direction = '순천';

  // ✅ [변경] 위치를 "prefix + number"로 쪼갬
  String locPrefix = 'A'; // A / P / S
  int locNumber = 1;      // prefix에 따라 범위 다름

  final descCtrl = TextEditingController();

  bool saving = false;
  String lastSaved = '-';

  @override
  void initState() {
    super.initState();
    _loadBridges();
  }

  Future<void> _loadBridges() async {
    final list = await bridgeService.loadBridgeNames();
    if (!mounted) return;

    setState(() {
      bridges = list;
      if (bridges.isNotEmpty) {
        bridge = bridges.first;
        bridgeCtrl.text = bridge; // ✅ [추가] 초기값 표시
      }
    });
  }

  @override
  void dispose() {
    descCtrl.dispose();
    bridgeCtrl.dispose(); // ✅ [추가]
    super.dispose();
  }

  // ✅ [추가] prefix에 따라 번호 범위
  List<int> _locNumbersForPrefix(String prefix) {
    if (prefix == 'A') return [1, 2];
    if (prefix == 'P') return List.generate(13, (i) => i + 1); // 1~13
    return List.generate(15, (i) => i + 1); // S: 1~15
  }

  String get location => '$locPrefix$locNumber'; // ✅ [변경] 실제 location 문자열

  String _buildName(String ext) {
    return Sanitizer.buildFileName(
      bridge: bridge,
      direction: direction,
      location: location, // ✅ [변경]
      desc: descCtrl.text,
      ext: ext,
    );
  }

  void _resetForm() {
    // ✅ [추가] 1P 초기화 버튼 동작
    setState(() {
      bridge = bridges.isNotEmpty ? bridges.first : '';
      bridgeCtrl.text = bridge;
      direction = '순천';
      locPrefix = 'A';
      locNumber = 1;
      descCtrl.clear();
      lastSaved = '-';
    });
  }

  Future<void> _pickAndSave(ImageSource source) async {
    // ✅ [변경] Autocomplete에서 직접 입력한 값 반영
    final typed = bridgeCtrl.text.trim();
    if (typed.isNotEmpty) bridge = typed;

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
      setState(() => lastSaved = saved.fileName);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 완료: ${saved.fileName}')),
      );
    } catch (e) {
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
    final preview = bridgeCtrl.text.trim().isEmpty
        ? '-'
        : Sanitizer.buildFileName(
            bridge: bridgeCtrl.text.trim(), // ✅ [변경] 입력중 미리보기 반영
            direction: direction,
            location: location,
            desc: descCtrl.text,
            ext: 'jpg',
          );

    final locNums = _locNumbersForPrefix(locPrefix);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '1페이지: 촬영/갤러리 → 파일명 적용 → 저장',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton(
                onPressed: saving ? null : _resetForm, // ✅ [추가]
                child: const Text('초기화'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ✅ [변경] 교량: Autocomplete(검색+직접입력)
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue v) {
              final q = v.text.trim();
              if (q.isEmpty) return const Iterable<String>.empty();
              return bridges.where((b) => b.contains(q));
            },
            onSelected: (v) {
              setState(() {
                bridge = v;
                bridgeCtrl.text = v;
              });
            },
            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
              // ✅ [주의] Autocomplete가 자체 컨트롤러를 넘겨주므로 bridgeCtrl과 동기화
              textEditingController.text = bridgeCtrl.text;
              textEditingController.selection = TextSelection.fromPosition(
                TextPosition(offset: textEditingController.text.length),
              );

              textEditingController.addListener(() {
                bridgeCtrl.text = textEditingController.text;
              });

              return TextFormField(
                controller: textEditingController,
                focusNode: focusNode,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: '교량(검색/직접입력)',
                  border: OutlineInputBorder(),
                ),
                onFieldSubmitted: (_) => onFieldSubmitted(),
              );
            },
          ),

          const SizedBox(height: 12),

          // 방향(기존 그대로)
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

          // ✅ [변경] 위치: prefix + number 방식
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: locPrefix,
                  items: const [
                    DropdownMenuItem(value: 'A', child: Text('A')),
                    DropdownMenuItem(value: 'P', child: Text('P')),
                    DropdownMenuItem(value: 'S', child: Text('S')),
                  ],
                  onChanged: saving
                      ? null
                      : (v) {
                          final newPrefix = v ?? locPrefix;
                          final newNums = _locNumbersForPrefix(newPrefix);
                          setState(() {
                            locPrefix = newPrefix;
                            // ✅ prefix 바뀌면 번호가 범위를 벗어날 수 있으니 1로 리셋
                            locNumber = newNums.first;
                          });
                        },
                  decoration: const InputDecoration(
                    labelText: '위치 구분',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  value: locNums.contains(locNumber) ? locNumber : locNums.first,
                  items: locNums
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: saving ? null : (v) => setState(() => locNumber = v ?? locNumber),
                  decoration: const InputDecoration(
                    labelText: '번호',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
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
