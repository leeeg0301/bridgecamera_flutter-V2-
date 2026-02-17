import 'dart:convert';
import 'package:flutter/services.dart';

class BridgeService {
  Future<List<String>> loadBridgeNames() async {
    final raw = await rootBundle.loadString('assets/data.csv');
    final lines = const LineSplitter().convert(raw);

    final names = <String>{};

    for (int i = 1; i < lines.length; i++) {
      final cols = lines[i].split(',');
      if (cols.length > 3) {
        names.add(cols[3].trim());
      }
    }

    final result = names.toList();
    result.sort();
    return result;
  }
}
