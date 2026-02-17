import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../services/manifest_service.dart';
import '../services/sanitizer.dart';
import '../services/bridge_service.dart';
import '../services/logger_service.dart';

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

  final bridgeCtrl = TextEditingController();
  String bridge = '';
  String direction = '순천';

  // ✅ 위치: prefix(A/P/S) 드롭다운 + number 직접입력만
  String locPrefix = 'A';
  int locNumber = 1;
  final locNumCtrl = TextEditingController(text: '1');

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
        bridgeCtrl.text = bridge;
      }
    });
  }

  @override
  void dispose() {
    descCtrl.dispose();
    bridgeCtrl.dispose();
    locNumCtrl.dispose();
    super.dispose();
  }

  int _maxForPrefix(String prefix) {
    if (prefix == 'A') return 2;
    if (prefix == 'P') return 13;
    return 15; // S
  }

  // ✅ 입력값을 안전하게 정리해서 locNumber에 반영
  void _applyAndClampLocationNumber(String raw) {
    final n = int.tryParse(raw.trim());
    final max = _maxForPrefix(locPrefix);

    if (n == null) {
      // 숫자 아닌 입력이 들어오면 일단 반영 안 함 (미리보기 혼란 방지)
      return;
    }

    final clamped = n.clamp(1, max);
    locNumber = clamped;

    // 사용자가 999 입력해도 즉시 15 같은 값으로 정리되어 보이게
    if (locNumCtrl.text != '$clamped') {
      locNumCtrl.text = '$clamped';
      locNumCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: locNumCtrl.text.length),
      );
    }
  }

  String get location => '$locPrefix$locNumber';

  String _buildName(String ext) {
    return Sanitizer.buildFileName(
      bridge: bridge,
      direction: direction,
      location: location,
      desc: descCtrl.text,
      ext: ext,
    );
  }

  Future<void> _confirmAndClearAll() async {
    if (saving) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('전체 결과 초기화'),
        content: const Text(
          '저장된 사진(갤러리 전용폴더) + ZIP(Downloads) + 목록이 모두 삭제됩니다.\n'
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

    setState(() => saving = true);
    try {
      await manifest.clearAllResults(deletePhotos: true, deleteZips: true);

      if (!mounted) return;
      setState(() {
        lastSaved = '-';
        direction = '순천';
        locPrefix = 'A';
        locNumber = 1;
        locNumCtrl.text = '1';
        descCtrl.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전체 결과 초기화 완료')),
      );
    } catch (e, st) {
      await LoggerService.I.e('전체 초기화 실패(1P)', error: e, st: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('초기화 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _pickAndSave(ImageSource source) async {
    final typed = bridgeCtrl.text.trim();
    if (typed.isNotEmpty) bridge = typed;
    if (bridge.isEmpty) return;

    // ✅ 저장 전에 location number 확정(clamp)
    _applyAndClampLocationNumber(locNumCtrl.text);

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
    } catch (e, st) {
      await LoggerService.I.e('사진 저장 실패', error: e, st: st);
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
    // ✅ 미리보기에도 입력값 clamp 반영(단, 숫자 아니면 기존 locNumber 유지)
    final tmpNum = int.tryParse(locNumCtrl.text.trim());
    final max = _maxForPrefix(locPrefix);
    final previewLocNum = (tmpNum == null) ? locNumber : tmpNum.clamp(1, max);
    final previewLocation = '$locPrefix$previewLocNum';

    final preview = bridgeCtrl.text.trim().isEmpty
        ? '-'
        : Sanitizer.buildFileName(
            bridge: bridgeCtrl.text.trim(),
            direction: direction,
            location: previewLocation,
            desc: descCtrl.text,
            ext: 'jpg',
          );

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
                onPressed: saving ? null : _confirmAndClearAll,
                child: const Text('전체 초기화'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 교량: 검색 + 직접 입력
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
            fieldViewBuilder:
                (context, textEditingController, focusNode, onFieldSubmitted) {
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

          DropdownButtonFormField<String>(
            value: direction,
            items: const [
              DropdownMenuItem(value: '순천', child: Text('순천')),
              DropdownMenuItem(value: '영암', child: Text('영암')),
            ],
            onChanged:
                saving ? null : (v) => setState(() => direction = v ?? direction),
            decoration: const InputDecoration(
              labelText: '방향',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          // ✅ 위치: prefix 드롭다운 + number 직접 입력만
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
                          setState(() {
                            locPrefix = newPrefix;
                            // prefix 바뀌면 number는 1로 기본
                            locNumber = 1;
                            locNumCtrl.text = '1';
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
                child: TextFormField(
                  controller: locNumCtrl,
                  enabled: !saving,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '번호(직접입력)',
                    border: const OutlineInputBorder(),
                    helperText: '범위: 1 ~ ${_maxForPrefix(locPrefix)}',
                  ),
                  onChanged: (v) {
                    setState(() {
                      // 입력 즉시 clamp 반영 + locNumber 업데이트
                      _applyAndClampLocationNumber(v);
                    });
                  },
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
                  onPressed:
                      saving ? null : () => _pickAndSave(ImageSource.gallery),
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
            const Text('처리 중...'),
          ],
        ],
      ),
    );
  }
}
