// lib/models/ingredient_group.dart
import 'package:equatable/equatable.dart';

/// โมเดล “กลุ่มวัตถุดิบ”
///
/// รองรับผลลัพธ์จากหลังบ้านหลายรูปแบบคีย์:
/// 1) get_ingredient_groups.php
///    - group_name
///    - representative_ingredient_id
///    - representative_name
///    - image_url
///    - item_count
///    - catagorynew (alias เท่ากับ group_name)
///    - (อาจมี) cover_url | cover | banner_url
///    - ★ NEW: recipe_count (จำนวน “สูตร” ในกลุ่มจริง ๆ)
///
/// 2) get_ingredients.php?grouped=1
///    - โครงคีย์คล้ายข้อ 1 แต่อาจใช้ชื่อคีย์บางตัวต่างกัน
///
/// ชั้น compatibility getters:
///   - name           → ใช้แทน groupName
///   - displayName    → ★ เปลี่ยนให้คืน “ชื่อหมวด (groupName)” เสมอ
///   - totalRecipes   → ใช้ recipeCount ถ้ามี; ถ้าไม่มี fallback เป็น itemCount
///   - coverUrl       → ใช้ค่าที่พบ (อาจเป็น null)
class IngredientGroup extends Equatable {
  /// ชื่อกลุ่ม/หมวด (เช่น “กุ้ง”, “หมู”, “ปลา”)
  final String groupName;

  /// ingredient_id ของตัวแทนกลุ่ม
  final int representativeIngredientId;

  /// ชื่อวัตถุดิบของตัวแทน (ไว้ใช้อย่างอื่นได้)
  final String representativeName;

  /// URL ของภาพ (อาจว่าง)
  final String imageUrl;

  /// จำนวน “สมาชิกในกลุ่ม” (จากตาราง ingredients)
  final int itemCount;

  /// ★ NEW: จำนวน “สูตรอาหาร” ในกลุ่ม (จาก recipe_ingredient)
  final int recipeCount;

  /// (อาจมี) URL รูป cover/banner ของกลุ่ม
  final String? coverUrl;

  bool get hasRecipeCount => recipeCount > 0;

  bool get hasImage =>
      imageUrl.trim().isNotEmpty || (coverUrl?.trim().isNotEmpty ?? false);

  String get primaryImageUrl => (coverUrl?.trim().isNotEmpty ?? false)
      ? coverUrl!.trim()
      : imageUrl.trim();

  const IngredientGroup({
    required this.groupName,
    required this.representativeIngredientId,
    required this.representativeName,
    required this.imageUrl,
    required this.itemCount,
    required this.recipeCount,
    this.coverUrl,
  });

  /// แปลงจาก JSON โดยรองรับหลายชื่อคีย์ที่เทียบเท่ากัน
  factory IngredientGroup.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => (v ?? '').toString();
    int i(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    }

    final group = s(
      json['group_name'] ?? json['catagorynew'] ?? json['group'] ?? '',
    );

    final repId = i(
      json['representative_ingredient_id'] ??
          json['rep_id'] ??
          json['ingredient_id'],
    );

    final repName = s(
      json['representative_name'] ?? json['name'] ?? '',
    );

    final img = s(
      json['image_url'] ?? json['image'] ?? json['image_path'] ?? '',
    );

    // ★ NEW: แยกนับสองแบบชัดเจน
    final cntItems = i(
      json['item_count'] ??
          json['member_count'] ??
          json['count'] ??
          json['total'],
    );
    final cntRecipes = i(
      json['recipe_count'] ?? json['total_recipes'] ?? json['recipes'],
    );

    final cover = s(
      json['cover_url'] ?? json['cover'] ?? json['banner_url'] ?? '',
    );

    return IngredientGroup(
      groupName: group,
      representativeIngredientId: repId,
      representativeName: repName.isNotEmpty ? repName : group,
      imageUrl: img,
      itemCount: cntItems, // จำนวนสมาชิก
      recipeCount: cntRecipes, // จำนวนสูตร (0 ถ้า backend ยังไม่ส่ง)
      coverUrl: cover.isEmpty ? null : cover,
    );
  }

  Map<String, dynamic> toJson() => {
        'group_name': groupName,
        'representative_ingredient_id': representativeIngredientId,
        'representative_name': representativeName,
        'image_url': imageUrl,
        'item_count': itemCount,
        'recipe_count': recipeCount,
        if (coverUrl != null) 'cover_url': coverUrl,
      };

  IngredientGroup copyWith({
    String? groupName,
    int? representativeIngredientId,
    String? representativeName,
    String? imageUrl,
    int? itemCount,
    int? recipeCount,
    String? coverUrl,
  }) {
    return IngredientGroup(
      groupName: groupName ?? this.groupName,
      representativeIngredientId:
          representativeIngredientId ?? this.representativeIngredientId,
      representativeName: representativeName ?? this.representativeName,
      imageUrl: imageUrl ?? this.imageUrl,
      itemCount: itemCount ?? this.itemCount,
      recipeCount: recipeCount ?? this.recipeCount,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }

  /// ค่าที่เหมาะสมสำหรับส่งไปพารามิเตอร์ `group` ของ API
  String get apiGroupValue => groupName.trim();

  /* ─── Compatibility getters สำหรับฝั่ง UI เดิม ─── */

  /// เดิม UI ใช้ `group.name`
  String get name => groupName;

  /// เดิม UI ใช้ `group.displayName`
  /// ★ เปลี่ยนให้คืน “ชื่อหมวด” ตรง ๆ เพื่อให้การ์ดโชว์ชื่อหมวดแน่นอน
  String? get displayName => groupName.trim();

  /// เดิม UI ใช้ `group.totalRecipes`
  /// ใช้ recipeCount ก่อน; ถ้าไม่มี fallback = itemCount
  int get totalRecipes => recipeCount > 0 ? recipeCount : itemCount;

  @override
  List<Object?> get props => [
        groupName,
        representativeIngredientId,
        representativeName,
        imageUrl,
        itemCount,
        recipeCount,
        coverUrl,
      ];

  @override
  String toString() =>
      'IngredientGroup(groupName: $groupName, repId: $representativeIngredientId, items: $itemCount, recipes: $recipeCount)';
}
