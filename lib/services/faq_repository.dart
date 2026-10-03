import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class FaqItem {
  const FaqItem({required this.question, required this.answer, required this.category});
  final String question;
  final String answer;
  final String category;
}

/// Single predefined data source for the FAQ page. Loaded once from the
/// bundled asset and cached — every later request reuses the same in-memory
/// list instead of re-reading or re-parsing the file, and nothing is written
/// to device storage for this feature at all.
class FaqRepository {
  FaqRepository._();
  static List<FaqItem>? _cache;

  static Future<List<FaqItem>> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString('assets/faq.json');
    final list = (jsonDecode(raw) as List)
        .map((e) => FaqItem(
              question: e['q'] as String,
              answer: e['a'] as String,
              category: e['cat'] as String,
            ))
        .toList();
    _cache = list;
    return list;
  }

  static List<String> categoriesOf(List<FaqItem> items) {
    final seen = <String>{};
    final out = <String>[];
    for (final i in items) {
      if (seen.add(i.category)) out.add(i.category);
    }
    return out;
  }
}
