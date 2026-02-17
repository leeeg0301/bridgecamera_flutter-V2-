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

  final bridgeCtrl = TextEditingController();
  String bridge = '';
  String direction = '순천';

  // ✅ 위치: prefix는 드롭다운, 숫자는 드롭다운+직접입력
  String locPrefix = 'A';
  int locNumber = 1;

  // ✅ [추가] 숫자 입력 모드 여부 + 컨트롤러
  bool locManual = false;
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
    locNumCtrl.dispose(); // ✅ 추가
    super.dispose();
  }

  int _maxForPrefix(String prefix) {
    if (prefix == 'A') return 2;
    if (prefix == 'P') return 13;
    return 15; // S
  }

  List<int> _numbersForPrefix(String prefix) {
    final max = _maxForPrefix(prefix);
    return List.generate(max, (i) => i + 1);
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

  // ✅ [추가] 전체 결과 초기화 다이얼로그 + 실행
  Future<void> _confirmAndClearAll() async {
    if (saving) return;

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

    setState(() => saving = true);
    try {
      await manifest.clearAllResults(deletePhotos: true, deleteZips: true);

      if (!mounted) return;
      setState(() {
        lastSaved = '-';
        // 입력값은 유지해도 되지만, “전체 결과 초기화”니까 폼도 같이 리셋해줄게(혼란 방지)
        direction = '순천';
        locPrefix = 'A';
        locNumber = 1;
        locManual = false;
        locNumCtrl.text = '1';
        descCtrl.clear();
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
      if (mounted) setState(() => saving = false);
    }
  }

  // ✅ manual 입력값을 검증해서 locNumber로 반영
  void _applyManualNumber(String raw) {
    final n = int.tryParse(raw.trim());
    final max = _maxForPrefix(locPrefix);
    if (n == null) return;
    final clamped = n.clamp(1, max);
    locNumber = clamped;
    locNumCtrl.text = '$clamped';
  }

  Future<void> _pickAndSave(ImageSource source) async {
    final typed = bridgeCtrl.text.trim();
    if (typed.isNotEmpty) bridge = typed;
    if (bridge.isEmpty) return;

    // ✅ manual 모드면 입력값 반영
    if (locManual) {
      _applyManualNumber(locNumCtrl.text);
    }

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
            bridge: bridgeCtrl.text.trim(),
            direction: direction,
            location: location,
            desc: descCtrl.text,
            ext: 'jpg',
          );

    final nums = _numbersForPrefix(locPrefix);

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
                // ✅ [변경] 기존 “폼 초기화” 대신 “전체 결과 초기화”
                onPressed: saving ? null : _confirmAndClearAll,
                child: const Text('전체 초기화'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 교량: Autocomplete(검색+직접입력) 유지
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
            onChanged: saving ? null : (v) => setState(() => direction = v ?? direction),
            decoration: const InputDecoration(
              labelText: '방향',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          // ✅ 위치: prefix 드롭다운 + 번호(드롭다운 or 직접입력)
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
                          final max = _maxForPrefix(newPrefix);
                          setState(() {
                            locPrefix = newPrefix;
                            // prefix 바뀌면 범위 맞춰 리셋
                            locNumber = 1;
                            locNumCtrl.text = '1';
                            // manual 모드면 입력값도 안전하게
                            if (locManual) _applyManualNumber(locNumCtrl.text);
                            // 혹시 기존 번호가 1이 아닌 경우 대비
                            locNumber = locNumber.clamp(1, max);
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
                child: Column(
                  children: [
                    // ✅ 숫자 모드 선택: 드롭다운(숫자들 + "직접입력")
                    DropdownButtonFormField<String>(
                      value: locManual ? 'manual' : 'dropdown',
                      items: const [
                        DropdownMenuItem(value: 'dropdown', child: Text('드롭다운 선택')),
                        DropdownMenuItem(value: 'manual', child: Text('직접입력')),
                      ],
                      onChanged: saving
                          ? null
                          : (v) {
                              setState(() {
                                locManual = (v == 'manual');
                                if (!locManual) {
                                  // 드롭다운으로 돌아가면 현재 입력값을 범위에 맞춰 반영
                                  _applyManualNumber(locNumCtrl.text);
                                }
                              });
                            },
                      decoration: const InputDecoration(
                        labelText: '번호 입력 방식',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ✅ 실제 번호 UI
                    if (!locManual)
                      DropdownButtonFormField<int>(
                        value: nums.contains(locNumber) ? locNumber : 1,
                        items: nums
                            .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                            .toList(),
                        onChanged: saving ? null : (v) => setState(() => locNumber = v ?? locNumber),
                        decoration: const InputDecoration(
                          labelText: '번호(선택)',
                          border: OutlineInputBorder(),
                        ),
                      )
                    else
                      TextFormField(
                        controller: locNumCtrl,
                        enabled: !saving,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '번호(직접입력)',
                          border: const OutlineInputBorder(),
                          helperText: '범위: 1 ~ ${_maxForPrefix(locPrefix)}',
                        ),
                        onChanged: (v) => setState(() {
                          // 입력 중에도 미리보기 반영되도록 clamp만 수행
                          _applyManualNumber(v);
                        }),
                      ),
                  ],
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
            const Text('처리 중...'),
          ],
        ],
      ),
    );
  }
}
