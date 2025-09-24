// lib/screens/all_ingredients_screen.dart
// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/safe_image.dart';

import '../models/ingredient.dart';
import '../models/ingredient_group.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

import '../widgets/ingredient_card.dart'; // ใช้ได้ทั้ง ingredient และ group
import '../widgets/custom_bottom_nav.dart';
import '../widgets/empty_result_dialog.dart';
import 'search_screen.dart';

// ★ NEW: สำหรับเรียกกล้องสแกนแล้วได้ชื่อวัตถุดิบ
import 'ingredient_photo_screen.dart' show scanIngredient;

enum ListingMode { groups, ingredients }

class AllIngredientsScreen extends StatefulWidget {
  final bool selectionMode;
  final void Function(Ingredient)? onSelected;
  const AllIngredientsScreen({
    super.key,
    this.selectionMode = false,
    this.onSelected,
  });

  @override
  State<AllIngredientsScreen> createState() => _AllIngredientsScreenState();
}

class _AllIngredientsScreenState extends State<AllIngredientsScreen> {
  /* ─── state ───────────────────────────────────────────── */
  late Future<void> _initFuture;

  // ข้อมูลทั้งหมดและผลลัพธ์ที่กรองแล้ว
  List<Ingredient> _allIng = [];
  List<Ingredient> _filteredIng = [];
  List<IngredientGroup> _allGroups = [];
  List<IngredientGroup> _filteredGroups = [];

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;

  // สถานะผู้ใช้
  bool _isLoggedIn = false;
  String? _username, _profileImg;

  // โหมดรายการ (เริ่มต้นเป็น กลุ่ม)
  ListingMode _mode = ListingMode.groups;

  // พรีเช็ค: cache ผลว่ามีเมนูไหม เพื่อลดดีเลย์ครั้งถัดไป
  final Map<String, bool> _existCacheIng = {};
  final Map<String, bool> _existCacheGroup = {};

  // จำกัดเวลาพรีเช็คสั้น ๆ เพื่อไม่ให้ผู้ใช้รอนาน
  static const Duration _precheckTimeout = Duration(milliseconds: 1200);

  /* ─── path helpers (โปรไฟล์ให้เป็น URL เต็ม + กันแคช) ─── */
  String _bust(String url) {
    if (url.isEmpty) return url;
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}t=${DateTime.now().millisecondsSinceEpoch}';
  }

  String? _normalizeServerPath(String? p) {
    if (p == null || p.isEmpty) return null;
    var s = p.replaceAll('\\', '/');
    final idx = s.indexOf('/uploads/');
    if (idx >= 0) s = s.substring(idx);
    final q = s.indexOf('?');
    if (q >= 0) s = s.substring(0, q);
    return s;
  }

  String? _composeFullUrl(String? maybePath) {
    if (maybePath == null || maybePath.isEmpty) return null;
    final full = ApiService.normalizeUrl(maybePath);
    // บัสต์เฉพาะรูปในโฟลเดอร์ผู้ใช้ เพื่อเคลียร์แคชหลังอัปโหลด
    return full.contains('/uploads/users/') ? _bust(full) : full;
  }

  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /* ─── data loaders ───────────────────────────────────── */
  Future<void> _initialize() async {
    await Future.wait([
      _loadUserInfo(),
      _loadGroups(),
      _loadIngredients(),
    ]);
    _applyFilter(); // เซ็ตฟิลเตอร์ครั้งแรกตามโหมด
  }

  Future<void> _loadUserInfo() async {
    _isLoggedIn = await AuthService.isLoggedIn();

    // ดึงก้อน login data แล้วจัดการรูปให้เป็น URL เต็ม + cache-bust
    final data = await AuthService.getLoginData();
    final rawName =
        (data['profileName'] ?? data['profile_name'] ?? '').toString().trim();
    final rawImg = (data['profileImage'] ??
            data['profile_image'] ??
            data['path_imgProfile'] ??
            '')
        .toString();

    final norm =
        _normalizeServerPath(rawImg) ?? rawImg; // เหลือเฉพาะ /uploads/... ถ้ามี
    final full = _composeFullUrl(norm) ?? // แปลงเป็น URL เต็ม + ?t=
        (rawImg.startsWith('http') ? rawImg : ''); // รองรับ external URL ตรง ๆ

    setState(() {
      _username = rawName.isEmpty ? null : rawName;
      _profileImg =
          full; // อาจเป็นค่าว่าง -> header จะ fallback เป็นรูป default
    });
  }

  Future<void> _loadIngredients() async {
    final list = await ApiService.fetchIngredients();
    if (!mounted) return;
    setState(() {
      _allIng = list;
      if (_mode == ListingMode.ingredients) _applyFilter();
    });
  }

  Future<void> _loadGroups() async {
    final list = await ApiService.fetchIngredientGroups();
    if (!mounted) return;
    setState(() {
      _allGroups = list;
      if (_mode == ListingMode.groups) _applyFilter();
    });
  }

  /* ─── search ─────────────────────────────────────────── */
  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _applyFilter);
  }

  // ★ NEW: แตกคำค้นเป็น token หลายคำ (เว้นวรรค/จุลภาค/เซมิโคลอน)
  List<String> _tokens(String q) => q
      .split(RegExp(r'[,\s;]+'))
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toList();

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();

    if (_mode == ListingMode.groups) {
      final clean = _allGroups.where((g) => g.groupName.trim().isNotEmpty);
      final toks = _tokens(q);
      _filteredGroups = (toks.isEmpty)
          ? clean.toList()
          : clean.where((g) {
              final name = g.groupName.toLowerCase();
              final disp = (g.displayName ?? '').toLowerCase();
              return toks.any((t) => name.contains(t) || disp.contains(t));
            }).toList();
    } else {
      final clean = _allIng.where((i) => i.name.trim().isNotEmpty);
      final toks = _tokens(q);
      _filteredIng = (toks.isEmpty)
          ? clean.toList()
          : clean.where((i) {
              final n = i.name.toLowerCase();
              final d = (i.displayName ?? '').toLowerCase();
              return toks.any((t) => n.contains(t) || d.contains(t));
            }).toList();
    }
    if (mounted) setState(() {});
  }

  /* ─── bottom-nav & actions ───────────────────────────── */
  void _onTabSelected(int idx) {
    if (idx == 1) return; // หน้าปัจจุบัน
    switch (idx) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/my_recipes');
        break;
      case 3:
        Navigator.pushReplacementNamed(
            context, _isLoggedIn ? '/profile' : '/settings');
        break;
    }
  }

  /* ─── helpers ────────────────────────────────────────── */
  void _unfocus() {
    if (_searchFocus.hasFocus) _searchFocus.unfocus();
  }

  // [NEW] toast สั้น ๆ
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ★ NEW: หา Ingredient ตามชื่อ/ชื่อแสดง แบบไม่สนตัวพิมพ์
  Ingredient? _findIngredientByNameOrDisplay(String name) {
    final key = name.trim().toLowerCase();
    for (final i in _allIng) {
      final n = i.name.trim().toLowerCase();
      final d = (i.displayName ?? '').trim().toLowerCase();
      if (n == key || (d.isNotEmpty && d == key)) return i;
    }
    return null;
  }

  // ★ NEW: กดไอคอนกล้องในช่องค้นหา
  Future<void> _onScanFromSearch() async {
    final names = await scanIngredient(context);
    if (names.isEmpty) return;

    // ใช้ผลลัพธ์ตัวแรกเป็นค่าเริ่มต้นของคำค้น
    final first = names.first.trim();
    if (_mode != ListingMode.ingredients) {
      setState(() => _mode = ListingMode.ingredients);
    }
    _searchCtrl.text = names.join(' ');
    _applyFilter();
    _unfocus();

    // ถ้าอยู่ใน selectionMode และพบชื่อที่ตรง → ส่งกลับทันที
    if (widget.selectionMode) {
      final matched = _findIngredientByNameOrDisplay(first);
      if (matched != null) {
        widget.onSelected?.call(matched);
        Navigator.pop(context, matched);
        return;
      }
      // ไม่เจอ → คงไว้เป็นคำค้น ให้ผู้ใช้เลือกเอง
      _showSnack('ไม่พบ “$first” ในรายการวัตถุดิบ — ตรวจสอบการสะกด');
    }
  }

  /* ─── PRECHECK + DIALOG (สไตล์เดียวกับหน้า Home) ───── */
  Future<void> _handleTapGroup(String apiGroupValue) async {
    // ใช้ cache ก่อน
    final cached = _existCacheGroup[apiGroupValue];
    if (cached != null) {
      if (cached) {
        Navigator.pushNamed(context, '/search',
            arguments: {'group': apiGroupValue});
      } else {
        await _showEmptyDialog(subject: apiGroupValue, isGroup: true);
      }
      return;
    }

    List<Recipe> list;
    try {
      list = await ApiService.fetchRecipesByGroup(
        group: apiGroupValue,
        page: 1,
        limit: 1,
        sort: 'latest',
      ).timeout(_precheckTimeout, onTimeout: () => const <Recipe>[]);
    } catch (_) {
      list = const <Recipe>[];
    }

    final hasAny = list.isNotEmpty;
    _existCacheGroup[apiGroupValue] = hasAny;

    if (hasAny) {
      Navigator.pushNamed(context, '/search',
          arguments: {'group': apiGroupValue});
    } else {
      await _showEmptyDialog(subject: apiGroupValue, isGroup: true);
    }
  }

  Future<void> _handleTapIngredient(Ingredient ing) async {
    // selectionMode: ส่งกลับแล้วปิดหน้าทันที (ไม่ต้องพรีเช็ค)
    if (widget.selectionMode) {
      widget.onSelected?.call(ing);
      Navigator.pop(context, ing);
      return;
    }

    final key = ing.name.trim();
    final cached = _existCacheIng[key];
    if (cached != null) {
      if (cached) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SearchScreen(ingredients: [key]),
          ),
        );
      } else {
        await _showEmptyDialog(subject: key, isGroup: false);
      }
      return;
    }

    bool hasAny = false;
    try {
      final r1 = await ApiService.searchRecipes(
        ingredientNames: [key],
        limit: 1,
      ).timeout(_precheckTimeout);
      hasAny = _hasResults(r1);
      if (!hasAny) {
        final r2 = await ApiService.searchRecipes(
          query: key,
          limit: 1,
        ).timeout(_precheckTimeout);
        hasAny = _hasResults(r2);
      }
    } catch (_) {
      hasAny = false;
    }

    _existCacheIng[key] = hasAny;

    if (hasAny) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SearchScreen(ingredients: [key]),
        ),
      );
    } else {
      await _showEmptyDialog(subject: key, isGroup: false);
    }
  }

  bool _hasResults(dynamic r) {
    try {
      final recs = (r as dynamic).recipes;
      if (recs is List && recs.isNotEmpty) return true;
      final t = (r as dynamic).total ?? (r as dynamic).count;
      return t is num && t > 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showEmptyDialog(
      {required String subject, required bool isGroup}) {
    // ใช้ EmptyResultDialog ที่เราใช้ในหน้า Home
    return showDialog(
      context: context,
      builder: (_) => EmptyResultDialog(
        subject: subject, // ไม่เติมคำว่า “กลุ่ม” ตามที่ขอ
        onProceed: () {
          Navigator.pop(context); // ปิด dialog
          if (isGroup) {
            Navigator.pushNamed(context, '/search',
                arguments: {'group': subject});
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SearchScreen(ingredients: [subject]),
              ),
            );
          }
        },
      ),
    );
  }

  /* ─── build ──────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      bottomNavigationBar: widget.selectionMode
          ? null
          : CustomBottomNav(
              selectedIndex: 1,
              onItemSelected: _onTabSelected,
              isLoggedIn: _isLoggedIn,
            ),
      body: SafeArea(
        child: GestureDetector(
          onTap: _unfocus,
          behavior: HitTestBehavior.translucent,
          child: Column(
            children: [
              /* ─── header ─── */
              _HeaderBar(
                username: _username,
                profileImg: _profileImg,
                selectionMode: widget.selectionMode,
                onActionPressed: widget.selectionMode
                    ? () => Navigator.pop(context)
                    : () async {
                        await AuthService.logout();
                        if (mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                              context, '/login', (_) => false);
                        }
                      },
              ),

              /* ─── mode switcher ─── */
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SegmentedButton<ListingMode>(
                  segments: const [
                    ButtonSegment(
                      value: ListingMode.groups,
                      label: Text('กลุ่มวัตถุดิบทั้งหมด'),
                      icon: Icon(Icons.category_outlined),
                    ),
                    ButtonSegment(
                      value: ListingMode.ingredients,
                      label: Text('วัตถุดิบทั้งหมด'),
                      icon: Icon(Icons.label_outline),
                    ),
                  ],
                  selected: {_mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) {
                    setState(() {
                      _mode = s.first;
                    });
                    _applyFilter(); // รีกรองตามโหมดใหม่
                  },
                ),
              ),

              /* ─── search box ─── */
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _unfocus(),
                  decoration: InputDecoration(
                    hintText: _mode == ListingMode.groups
                        ? 'ค้นหาชื่อกลุ่ม (เช่น กุ้งทะเล, นมวัว)...'
                        : 'คุณอยากหาวัตถุดิบอะไร?',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    // ★ NEW: ไอคอนกล้อง + ปุ่มล้าง
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'สแกนชื่อวัตถุดิบ',
                          icon: const Icon(Icons.camera_alt_outlined),
                          onPressed: _onScanFromSearch,
                        ),
                        if (_searchCtrl.text.isNotEmpty)
                          IconButton(
                            tooltip: 'ล้างคำค้นหา',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchCtrl.clear();
                              _applyFilter();
                              _unfocus();
                            },
                          ),
                      ],
                    ),
                    // ให้มีพื้นที่พอสำหรับ 2 ไอคอน
                    suffixIconConstraints:
                        const BoxConstraints(minWidth: 100, minHeight: 0),
                  ),
                ),
              ),

              // ★ แสดงจำนวนทั้งหมดในระบบตามโหมดปัจจุบัน
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _TotalsBadge(
                    isGroupMode: _mode == ListingMode.groups,
                    totalGroups: _allGroups.length,
                    totalIngredients: _allIng.length,
                    foundCount: _mode == ListingMode.groups
                        ? _filteredGroups.length
                        : _filteredIng.length,
                    hasQuery: _searchCtrl.text.trim().isNotEmpty,
                  ),
                ),
              ),

              /* ─── grid list ─── */
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildGrid(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ─── grid builder ───────────────────────────────────── */
  Widget _buildGrid() {
    return FutureBuilder(
      future: _initFuture,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _initFuture = _initialize()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('ลองอีกครั้ง'),
                ),
              ],
            ),
          );
        }

        // ว่างเปล่าตามโหมด
        if (_mode == ListingMode.groups && _allGroups.isEmpty) {
          return const Center(child: Text('ไม่พบกลุ่มวัตถุดิบ'));
        }
        if (_mode == ListingMode.ingredients && _allIng.isEmpty) {
          return const Center(child: Text('ไม่พบข้อมูลวัตถุดิบ'));
        }

        // ไม่มีผลจากการค้นหา
        if (_searchCtrl.text.isNotEmpty) {
          if (_mode == ListingMode.groups && _filteredGroups.isEmpty) {
            return Center(
              child: Text('ไม่พบกลุ่มสำหรับ “${_searchCtrl.text}”'),
            );
          }
          if (_mode == ListingMode.ingredients && _filteredIng.isEmpty) {
            return Center(
              child: Text('ไม่พบวัตถุดิบสำหรับ “${_searchCtrl.text}”'),
            );
          }
        }

        // คำนวณ layout ตามความกว้าง
        return LayoutBuilder(builder: (_, cs) {
          const minW = 120.0;
          const gap = 16.0;
          final cols = (cs.maxWidth / minW).floor().clamp(2, 6);
          final tileW = (cs.maxWidth - (cols - 1) * gap) / cols;

          // ขนาดตาม IngredientCard (รูป 4:3 + ชื่อ 2 บรรทัด)
          final ts = Theme.of(context).textTheme.titleMedium ??
              const TextStyle(fontSize: 16, height: 1.15);
          double lh(TextStyle s) => (s.fontSize ?? 16) * (s.height ?? 1.2);
          final titleBoxH = lh(ts) * 2;
          const vPad = 16.0;

          final imgH = tileW / kIngredientImageAspectRatio;
          final tileH = (imgH + titleBoxH + vPad + 2).roundToDouble();
          final ratio = tileW / tileH;

          // ดึงรีเฟรช + Scrollbar + ปิดคีย์บอร์ดเมื่อลาก
          return RefreshIndicator(
            onRefresh: () async {
              // รีโหลดเฉพาะชุดตามโหมด เพื่อเร็วขึ้น
              if (_mode == ListingMode.groups) {
                await _loadGroups();
              } else {
                await _loadIngredients();
              }
            },
            child: ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(
                scrollbars: false,
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.stylus,
                },
              ),
              child: Scrollbar(
                child: GridView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _mode == ListingMode.groups
                      ? _filteredGroups.length
                      : _filteredIng.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                    childAspectRatio: ratio,
                  ),
                  itemBuilder: (_, i) {
                    if (_mode == ListingMode.groups) {
                      final g = _filteredGroups[i];
                      return _tileWrapper(
                        child: IngredientCard(
                          group: g,
                          // ใช้พรีเช็ค + dialog น่ารัก ๆ แบบหน้า Home
                          // [NEW] ถ้าอยู่ใน selectionMode → แตะเพื่อ “เลือกกลุ่มนี้” ส่ง Ingredient ตัวแทนกลับไป
                          onTap: () async {
                            if (widget.selectionMode) {
                              final repId = g.representativeIngredientId;
                              if (repId <= 0) {
                                _showSnack('ไม่พบตัวแทนของกลุ่มนี้');
                                return;
                              }
                              // สร้าง Ingredient จากข้อมูลกลุ่ม (ผ่าน fromJson เพื่อชัวร์ชนิด)
                              final name =
                                  (g.displayName?.trim().isNotEmpty == true)
                                      ? g.displayName!.trim()
                                      : g.groupName.trim();
                              final ing = Ingredient.fromJson({
                                // รองรับทั้ง key id/ingredient_id ตามโมเดล
                                'id': repId,
                                'ingredient_id': repId,
                                'name': name,
                                'display_name': name,
                                'image_url': g.imageUrl,
                              });
                              widget.onSelected?.call(ing);
                              Navigator.pop(context, ing);
                            } else {
                              _handleTapGroup(g.apiGroupValue);
                            }
                          },
                        ),
                      );
                    } else {
                      final ing = _filteredIng[i];
                      return _tileWrapper(
                        child: IngredientCard(
                          ingredient: ing,
                          // ใช้พรีเช็ค + dialog น่ารัก ๆ
                          onTap: () => _handleTapIngredient(ing),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          );
        });
      },
    );
  }

  // ใส่กรอบ/เงาให้การ์ดเหมือนเดิม
  Widget _tileWrapper({required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(color: Colors.transparent, child: child),
      ),
    );
  }
}

/*──────────────────── header bar ───────────────────*/
class _HeaderBar extends StatelessWidget {
  final String? username, profileImg;
  final bool selectionMode;
  final VoidCallback onActionPressed;

  const _HeaderBar({
    required this.username,
    required this.profileImg,
    required this.selectionMode,
    required this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final String img = (profileImg ?? '').trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
        color: theme.colorScheme.surface,
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox.square(
              dimension: 48,
              child: SafeImage(
                // ถ้าไม่มี URL ให้ใช้รูป default ทันที
                url: img.isEmpty ? 'assets/images/default_avatar.png' : img,
                fit: BoxFit.cover,
                error: Image.asset(
                  'assets/images/default_avatar.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'สวัสดี ${username ?? 'คุณ'}',
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Semantics(
            button: true,
            label: selectionMode ? 'ปิดการเลือก' : 'ออกจากระบบ',
            child: IconButton(
              icon: Icon(selectionMode ? Icons.close : Icons.logout_outlined),
              tooltip: selectionMode ? 'ปิดการเลือก' : 'ออกจากระบบ',
              color: theme.colorScheme.onSurfaceVariant,
              onPressed: onActionPressed,
            ),
          ),
        ],
      ),
    );
  }
}

/*──────────────────── totals badge ───────────────────*/
class _TotalsBadge extends StatelessWidget {
  final bool isGroupMode;
  final int totalGroups;
  final int totalIngredients;
  final int? foundCount; // จำนวนรายการที่กรองแล้วตามคำค้น
  final bool hasQuery; // มีคำค้นหรือไม่
  const _TotalsBadge({
    required this.isGroupMode,
    required this.totalGroups,
    required this.totalIngredients,
    this.foundCount,
    this.hasQuery = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final total = isGroupMode ? totalGroups : totalIngredients;
    final labelAll = isGroupMode ? 'กลุ่มทั้งหมด' : 'วัตถุดิบทั้งหมด';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        hasQuery
            ? 'พบ ${foundCount ?? 0} รายการ ($labelAll: $total)'
            : '$labelAll: $total รายการ',
        style: tt.bodyMedium?.copyWith(
          color: cs.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
