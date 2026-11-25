import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import 'food_catalog_seed.dart';

String foodKey(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'\s+'), '');

/// Search presentation only. Never use for storage eligibility or expiry defaults.
String foodCatalogSearchKey(String value) {
  final key = foodKey(
    value,
  ).replaceFirst(RegExp(r'\(?\d+(?:\.\d+)?(?:kg|g|ml|l|개|봉|팩|통|병)\)?$'), '');
  return const {
        '후춧가루': '후추',
        '후추가루': '후추',
        '분쇄후추': '후추',
        '모짜렐라치즈': '모차렐라',
        '모차렐라치즈': '모차렐라',
        '체다치즈': '체더치즈',
        '마늘종': '마늘쫑',
        '간마늘': '다진마늘',
      }[key] ??
      key;
}

class FoodEntry {
  FoodEntry(this.name, this.category, this.aliases, this.guidance);
  final String name, category;
  final List<String> aliases;
  final List<Map<String, dynamic>> guidance;
  factory FoodEntry.fromJson(Map<String, dynamic> row) => FoodEntry(
    row['name'] as String,
    row['category'] as String,
    List<String>.from(row['aliases'] as List),
    (row['guidance'] as List)
        .map((g) => Map<String, dynamic>.from(g as Map))
        .toList(),
  );
  bool matches(String value) =>
      [name, ...aliases].any((s) => foodKey(s) == foodKey(value));
}

final bundledFoods = (jsonDecode(foodCatalogSeed) as List)
    .map((r) => FoodEntry.fromJson(Map<String, dynamic>.from(r as Map)))
    .toList(growable: false);

FoodEntry? findFood(String name, [List<FoodEntry>? entries]) {
  final found = (entries ?? bundledFoods).where((e) => e.matches(name));
  return found.length == 1 ? found.single : null;
}

final foodCatalogProvider = FutureProvider.autoDispose<List<FoodEntry>>((
  ref,
) async {
  final rows = await ref
      .watch(supabaseProvider)
      .from('food_catalog')
      .select('name,category,aliases,guidance')
      .order('name')
      .limit(1000)
      .timeout(const Duration(seconds: 10));
  return rows.map((r) => FoodEntry.fromJson(r)).toList(growable: false);
});
