import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'ingredient_group.dart';

/// [OLD]
/// class FilterOption {
///   final String name;
///   final bool isSelected;
///   FilterOption({required this.name, this.isSelected = false});
/// }
///
/// หมายเหตุ: โครงนี้ใช้ชื่ออย่างเดียว จึงแยกไม่ออกว่าเป็น “วัตถุดิบเดี่ยว”
/// หรือ “กลุ่มวัตถุดิบ” และไม่มีข้อมูลช่วยอื่น ๆ เช่น รูป/จำนวนสมาชิก
/// ด้านล่างคงพฤติกรรมเดิมไว้ (name + isSelected) และเพิ่มฟิลด์เสริมให้รองรับ backend ใหม่

/// ตัวเลือกกรองที่ใช้ได้ทั้ง “วัตถุดิบเดี่ยว” และ “กลุ่มวัตถุดิบ”
///
/// จุดประสงค์
/// - คงความง่าย: `name` และ `isSelected` ทำงานเหมือนเดิม
/// - ขยายความสามารถ: รู้ว่าเป็น “กลุ่ม” หรือไม่, มีรูป, มีจำนวนสมาชิก,
///   และมีรหัสอ้างอิงไว้คุยกับ API ได้ชัดเจน
@immutable
class FilterOption extends Equatable {
  /// ชื่อที่ใช้แสดงบน UI (เช่น “กุ้ง”, “เนื้อหมู” หรือชื่อกลุ่ม)
  final String name;

  /// สถานะถูกเลือกใน UI
  final bool isSelected;

  /// เป็นตัวกรองแบบ “กลุ่มวัตถุดิบ” หรือไม่
  final bool isGroup;

  /// ค่าที่ใช้ส่งคิวรีไป API (สำหรับกลุ่มควรเป็นชื่อกลุ่มที่ Trim แล้ว)
  ///
  /// เดิมถ้าไม่ได้ระบุ จะใช้ `name` เป็นค่าอ้างอิงโดยอัตโนมัติ
  final String code;

  /// รหัสอ้างอิงเพิ่มเติม (ถ้ามี) เช่น ingredient_id ตัวแทนของกลุ่ม
  final int? id;

  /// URL ภาพประกอบ (มักใช้กับการ์ดกลุ่มเพื่อแสดงรูปตัวแทน)
  final String? imageUrl;

  /// จำนวนสมาชิกภายในกลุ่ม (ใช้แสดง badge)
  final int? count;

  const FilterOption({
    required this.name,
    this.isSelected = false,
    this.isGroup = false,
    String? code,
    this.id,
    this.imageUrl,
    this.count,
  }) : code = code ?? name;

  /// สร้าง FilterOption จากข้อมูล “กลุ่มวัตถุดิบ”
  factory FilterOption.fromGroup(IngredientGroup g, {bool selected = false}) {
    return FilterOption(
      name: g.groupName,
      isSelected: selected,
      isGroup: true,
      code: g.groupName.trim(),
      id: g.representativeIngredientId,
      imageUrl: g.imageUrl.isNotEmpty ? g.imageUrl : null,
      count: g.itemCount,
    );
  }

  /// ทำสำเนาพร้อมแก้ไขค่าเฉพาะบางฟิลด์
  FilterOption copyWith({
    String? name,
    bool? isSelected,
    bool? isGroup,
    String? code,
    int? id,
    String? imageUrl,
    int? count,
  }) {
    return FilterOption(
      name: name ?? this.name,
      isSelected: isSelected ?? this.isSelected,
      isGroup: isGroup ?? this.isGroup,
      code: code ?? this.code,
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      count: count ?? this.count,
    );
  }

  /// สร้างตัวเลือก “ตรงไปยัง API” สำหรับ query แบบรวมเป็นแผนที่
  /// - ถ้าเป็นกลุ่มจะคืน key เป็น `include_groups[]` หรือ `exclude_groups[]`
  /// - ถ้าเป็นวัตถุดิบเดี่ยว ให้ UI รวมชื่อไว้ใน `include`/`exclude` เองตามแบบเดิม
  MapEntry<String, String> toQueryPair({bool exclude = false}) {
    if (isGroup) {
      return MapEntry(exclude ? 'exclude_groups[]' : 'include_groups[]', code);
    }
    // สำหรับวัตถุดิบเดี่ยว โครงสร้างเดิมของแอพจะรวมเป็นสตริง comma-separated
    // จึงคืนคีย์เป็น 'include'/'exclude' ให้ผู้เรียกไป join เองตามกลไกเดิม
    return MapEntry(exclude ? 'exclude' : 'include', name);
  }

  @override
  List<Object?> get props =>
      [name, isSelected, isGroup, code, id, imageUrl, count];

  @override
  String toString() =>
      'FilterOption(name: $name, isSelected: $isSelected, isGroup: $isGroup, code: $code, id: $id, count: $count)';
}
