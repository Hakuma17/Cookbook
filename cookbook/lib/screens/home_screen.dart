// lib/screens/home_screen.dart
import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';

// Store กลางไว้ sync รายการโปรด
import 'package:provider/provider.dart';
import '../main.dart' show routeObserver;
import '../stores/favorite_store.dart';

// โมเดล/บริการ
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/ingredient_group.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

// วิดเจ็ตที่ใช้บนหน้า Home
import '../widgets/recipe_card.dart';
import '../widgets/ingredient_card.dart';
import '../widgets/skeletons.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/allergy_warning_dialog.dart';
import '../widgets/empty_result_dialog.dart';

// ยูทิลรูป
import '../utils/safe_image.dart';

// กำหนดสัดส่วน/ขนาดที่ใช้ซ้ำ
const double _ingredientImageAspectRatio = 4 / 3;

// เวลารอพรีเช็คสั้น ๆ เพื่อไม่ให้ผู้ใช้รอนาน
const Duration _precheckTimeout = Duration(milliseconds: 1200);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  /* ───────────── State หลัก ───────────── */
  late Future<void> _initFuture;

  // ถ้าหลังบ้านมี “กลุ่มวัตถุดิบ” จะแสดงกลุ่ม; ถ้าไม่มีจะ fallback เป็นรายตัว
  List<Ingredient> _ingredients = [];
  List<IngredientGroup> _ingredientGroups = [];

  // สองแถบเมนู (ยอดนิยม/ใหม่ล่าสุด)
  List<Recipe> _popularRecipes = [];
  List<Recipe> _newRecipes = [];

  // ข้อมูลแพ้อาหารของผู้ใช้ (ไว้ขึ้นเตือนตอนกดการ์ดสูตร)
  List<Ingredient> _allergyList = [];
  List<int> _allergyIngredientIds = [];

  bool _isLoggedIn = false;
  String? _profileName;
  String? _profileImage;

  // 🔧 URL โปรไฟล์ที่ใส่ cache-bust แล้ว (สำหรับหน้า Home)
  String? _profileImageBusted;

  int _selectedIndex = 0;
  String? _errorMessage;
  bool _navBusy = false;
  bool _isLoading = true;

  // ✅ รีเฟรชเฉพาะตอนกลับจาก “หน้าเต็ม” ที่เราตั้งใจไป ไม่รีเฟรชตอนปิด dialog
  bool _refreshOnReturn = false;

  // helper: เติม query เพื่อ bust แคช
  String _withBust(String url) {
    if (url.isEmpty) return url;
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}v=${DateTime.now().millisecondsSinceEpoch}';
  }

  /* ───────────── Lifecycle ───────────── */
  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
  }

  Future<void> _initialize({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _errorMessage = null;
        _isLoading = true;
      });
    }
    try {
      await Future.wait([
        _loadLoginStatus(),
        _fetchAllData(force: forceRefresh),
      ]);
    } on UnauthorizedException {
      await _handleLogout(silent: true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e, st) {
      log('init error: $e', stackTrace: st);
      if (mounted) setState(() => _errorMessage = 'เกิดข้อผิดพลาดไม่คาดคิด');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // รีเฟรชเฉพาะเมื่อเราคาดหวัง (กลับจากหน้าเต็ม)
    if (_refreshOnReturn) {
      _refreshOnReturn = false;
      setState(() {
        _initFuture = _initialize(forceRefresh: true);
      });
    }
  }

  /* ───────────── นำทางแบบหน้าเต็ม (คาดหวังให้รีเฟรชเมื่อกลับ) ───────────── */
  Future<T?> _pushNamedExpectReturn<T>(String route, {Object? arguments}) {
    _refreshOnReturn = true;
    return Navigator.pushNamed<T>(context, route, arguments: arguments);
  }

  /* ───────────── ดึงข้อมูลหน้า Home ───────────── */
  Future<void> _fetchAllData({bool force = false}) async {
    // พยายามโหลด “กลุ่มวัตถุดิบ” ก่อน; ถ้าไม่สำเร็จค่อย fallback เป็นรายตัว
    try {
      final results = await Future.wait([
        ApiService.fetchIngredientGroups(),
        ApiService.fetchPopularRecipes(),
        ApiService.fetchNewRecipes(),
      ]);
      if (!mounted) return;
      setState(() {
        _ingredientGroups = results[0] as List<IngredientGroup>;
        _popularRecipes = results[1] as List<Recipe>;
        _newRecipes = results[2] as List<Recipe>;
      });
    } catch (_) {
      final results = await Future.wait([
        ApiService.fetchIngredients(),
        ApiService.fetchPopularRecipes(),
        ApiService.fetchNewRecipes(),
      ]);
      if (!mounted) return;
      setState(() {
        _ingredients = results[0] as List<Ingredient>;
        _popularRecipes = results[1] as List<Recipe>;
        _newRecipes = results[2] as List<Recipe>;
      });
    }
  }

  Future<void> _loadLoginStatus() async {
    await AuthService.init();
    if (await AuthService.isLoggedIn()) {
      final login = await AuthService.getLoginData();
      final allergy = await ApiService.fetchAllergyIngredients();

      // เติมสถานะรายการโปรดเข้าร้านกลาง (ให้หน้าอื่น sync ด้วย)
      try {
        final favs = await ApiService.fetchFavorites();
        context.read<FavoriteStore>().replaceWith(favs.map((r) => r.id));
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _isLoggedIn = true;
        _profileName = login['profileName'];
        _profileImage = login['profileImage'];
        _profileImageBusted = (_profileImage?.isNotEmpty ?? false)
            ? _withBust(_profileImage!)
            : '';
        _allergyList = allergy;
        _allergyIngredientIds = allergy.map((e) => e.id).toList();
      });
    } else if (mounted) {
      context.read<FavoriteStore>().clear();
      setState(() {
        _isLoggedIn = false;
        _profileName = null;
        _profileImage = null;
        _profileImageBusted = '';
        _allergyList = [];
        _allergyIngredientIds = [];
      });
    }
  }

  /* ───────────── ออกจากระบบ ───────────── */
  Future<void> _handleLogout({bool silent = false}) async {
    await AuthService.logout();
    if (mounted) context.read<FavoriteStore>().clear();
    if (mounted && !silent) {
      setState(() {
        _isLoggedIn = false;
        _profileName = null;
        _profileImage = null;
        _profileImageBusted = '';
        _allergyList = [];
        _allergyIngredientIds = [];
        _initFuture = _initialize(forceRefresh: true);
      });
    }
  }

  /* ───────────── เปลี่ยนแท็บล่าง ───────────── */
  Future<void> _onNavTap(int idx) async {
    if (idx == _selectedIndex || _navBusy) return;
    setState(() => _navBusy = true);
    try {
      switch (idx) {
        case 0:
          setState(() => _selectedIndex = idx);
          break;
        case 1:
          await _pushNamedExpectReturn('/search');
          break;
        case 2:
          if (!_isLoggedIn) {
            await _pushNamedExpectReturn('/login');
            return;
          }
          await _pushNamedExpectReturn('/my_recipes');
          break;
        case 3:
          await _pushNamedExpectReturn(_isLoggedIn ? '/profile' : '/settings');
          break;
      }
    } finally {
      if (mounted) setState(() => _navBusy = false);
    }
  }

  /* ───────────── พรีเช็ค “กลุ่มวัตถุดิบ” ก่อนนำทาง ─────────────
   * - ถ้ามีเมนูในกลุ่ม → ไปหน้า Search ทันที
   * - ถ้ายังไม่มีเมนู → เด้ง EmptyResultDialog ให้เลือก ยกเลิก/ไปต่อ
   *   (กด ยกเลิก = ปิด dialog เฉย ๆ, หน้า Home ไม่รีเฟรช)
   */
  Future<void> _onTapGroupHome(String groupName) async {
    List<Recipe> list;
    try {
      list = await ApiService.fetchRecipesByGroup(
        group: groupName,
        page: 1,
        limit: 1,
        sort: 'latest',
      ).timeout(_precheckTimeout, onTimeout: () => const <Recipe>[]);
    } catch (_) {
      list = const <Recipe>[]; // เช็คไม่สำเร็จถือว่าว่างไว้ก่อน
    }

    if (!mounted) return;

    if (list.isEmpty) {
      await showDialog(
        context: context,
        builder: (_) => EmptyResultDialog(
          subject: groupName, // ไม่ต้องเติมคำว่า "กลุ่ม"
          onProceed: () {
            Navigator.pop(context); // ปิด dialog ก่อน
            _pushNamedExpectReturn('/search', arguments: {'group': groupName});
          },
        ),
      );
    } else {
      _pushNamedExpectReturn('/search', arguments: {'group': groupName});
    }
  }

  /* ───────────── Build ───────────── */
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder(
      future: _initFuture,
      builder: (_, snap) {
        final noDataYet = _ingredientGroups.isEmpty && _ingredients.isEmpty;
        if (noDataYet && snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (_errorMessage != null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => setState(
                        () => _initFuture = _initialize(forceRefresh: true),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('ลองอีกครั้ง'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: cs.surface,
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildMainHomeView(),
                const SizedBox.shrink(),
                const SizedBox.shrink(),
                const SizedBox.shrink(),
              ],
            ),
          ),
          bottomNavigationBar: CustomBottomNav(
            selectedIndex: _selectedIndex,
            onItemSelected: _onNavTap,
            isLoggedIn: _isLoggedIn,
          ),
        );
      },
    );
  }

  /* ───────────── เนื้อหาหลักของ Home ───────────── */
  Widget _buildMainHomeView() => Column(
        children: [
          _buildCustomAppBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _initialize(forceRefresh: true),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIngredientSection(),
                    const SizedBox(height: 24),
                    _buildRecipeSection(
                      title: 'สูตรอาหารยอดนิยม',
                      recipes: _popularRecipes,
                      onAction: () => _pushNamedExpectReturn(
                        '/search',
                        arguments: {'initialSortIndex': 0},
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildRecipeSection(
                      title: 'สูตรอาหารอัปเดตใหม่',
                      recipes: _newRecipes,
                      onAction: () => _pushNamedExpectReturn(
                        '/search',
                        arguments: {'initialSortIndex': 2},
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

  /* ───────────── โซน “วัตถุดิบ/กลุ่มวัตถุดิบ” ─────────────
   * - ถ้ามีข้อมูลกลุ่ม → แสดงการ์ดกลุ่ม
   * - ถ้าไม่มี → แสดงการ์ดวัตถุดิบรายตัว (fallback)
   */
  Widget _buildIngredientSection() {
    final cs = Theme.of(context).colorScheme;
    final showingGroups = _ingredientGroups.isNotEmpty;

    return Container(
      color: cs.secondaryContainer,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          _buildSectionHeader(
            title: showingGroups ? 'กลุ่มวัตถุดิบ' : 'วัตถุดิบ',
            actionText: 'ดูทั้งหมด',
            onAction: () => _pushNamedExpectReturn('/all_ingredients'),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const hPad = 16.0, gap = 16.0;
              final totalPadding = (hPad * 2) + gap;
              final cardWidth = (constraints.maxWidth - totalPadding) / 2;

              final imageH = cardWidth / _ingredientImageAspectRatio;

              // ใช้ค่าของ IngredientCard ให้ layout ตรงกัน
              final nameH = IngredientCard.titleBoxHeightOf(context);

              const namePad = 8 + 8;
              final listH = (imageH + nameH + namePad + 2).ceilToDouble() + 1;

              // ระหว่างโหลด → โชว์ Skeleton
              if (_isLoading) {
                return SizedBox(
                  height: listH,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 6,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (_, __) => SizedBox(
                      width: cardWidth,
                      child: IngredientCardSkeleton(width: cardWidth),
                    ),
                  ),
                );
              }

              // โหมด “กลุ่มวัตถุดิบ”
              if (showingGroups) {
                final groups = _ingredientGroups;
                return SizedBox(
                  height: listH,
                  child: groups.isEmpty
                      ? const Center(child: Text('ไม่พบกลุ่มวัตถุดิบ'))
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: groups.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 16),
                          itemBuilder: (_, i) => SizedBox(
                            width: cardWidth,
                            child: IngredientCard(
                              group: groups[i],
                              width: cardWidth,
                              onTap: () =>
                                  _onTapGroupHome(groups[i].apiGroupValue),
                            ),
                          ),
                        ),
                );
              }

              // โหมด “วัตถุดิบรายตัว” (fallback)
              return SizedBox(
                height: listH,
                child: _ingredients.isEmpty
                    ? const Center(child: Text('ไม่พบวัตถุดิบ'))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _ingredients.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (_, i) => SizedBox(
                          width: cardWidth,
                          child: IngredientCard(
                            ingredient: _ingredients[i],
                            // ❗ ไม่ส่ง onTap → ให้ IngredientCard จัดการพรีเช็ค+dialog เอง
                          ),
                        ),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ความสูงกล่องชื่อ (สองบรรทัด) ใช้คำนวณความสูงแถบรายการ
  double _ingredientTitleBoxHeightOf(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final scale = MediaQuery.textScaleFactorOf(context);
    final style = ts.bodyMedium ?? const TextStyle(fontSize: 16, height: 1.2);
    final line = (style.fontSize ?? 16) * (style.height ?? 1.2);
    return (line * 2 * scale).ceilToDouble();
  }

  /* ───────────── โซน “สูตรอาหาร” (คาร์รอสเซลแนวนอน) ───────────── */
  Widget _buildRecipeSection({
    required String title,
    required List<Recipe> recipes,
    required VoidCallback onAction,
  }) =>
      Column(
        children: [
          _buildSectionHeader(
              title: title, actionText: 'ดูเพิ่มเติม', onAction: onAction),
          const SizedBox(height: 12),
          SizedBox(
            height: _recipeStripHeight(context),
            child: _isLoading
                ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 6,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (_, __) => const RecipeCardSkeleton(
                        width: kRecipeCardVerticalWidth),
                  )
                : (recipes.isEmpty
                    ? const Center(child: Text('ยังไม่มีสูตรอาหาร'))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: recipes.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (_, i) => RecipeCard(
                          recipe: recipes[i],
                          onTap: () => _handleRecipeTap(recipes[i]),
                        ),
                      )),
          ),
        ],
      );

  // หัวข้อแต่ละเซกชัน + ปุ่ม "ดูเพิ่มเติม"
  Widget _buildSectionHeader({
    required String title,
    required String actionText,
    required VoidCallback onAction,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Semantics(
            button: true,
            label: actionText,
            child: InkWell(
              onTap: onAction,
              child: Text(
                actionText,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // แถบบนสุด (รูปโปรไฟล์ + ปุ่มล็อกอิน/ออก)
  Widget _buildCustomAppBar() {
    final theme = Theme.of(context);
    final imageUrl = (_isLoggedIn && (_profileImageBusted?.isNotEmpty ?? false))
        ? _profileImageBusted!
        : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox.square(
              dimension: 48,
              child: SafeImage(
                key: ValueKey(
                    imageUrl), // เปลี่ยนคีย์เพื่อบังคับรีบิลด์เมื่อ bust เปลี่ยน
                url: imageUrl,
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
              _isLoggedIn ? 'สวัสดี ${_profileName ?? ''}' : 'ผู้เยี่ยมชม',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: _isLoggedIn ? 'ออกจากระบบ' : 'เข้าสู่ระบบ',
            icon: Icon(
              _isLoggedIn ? Icons.logout_outlined : Icons.login_outlined,
            ),
            onPressed: _isLoggedIn ? _handleLogout : () => _onNavTap(3),
          ),
        ],
      ),
    );
  }

  /* ───────────── เตือนแพ้อาหารตอนกดการ์ดสูตร ───────────── */
  void _handleRecipeTap(Recipe recipe) {
    final hasAllergy = recipe.hasAllergy; // ได้จาก backend แล้ว
    if (hasAllergy) {
      _showAllergyWarning(recipe);
    } else {
      _pushNamedExpectReturn('/recipe_detail', arguments: recipe);
    }
  }

  void _showAllergyWarning(Recipe recipe) {
    final badIds =
        recipe.ingredientIds.where(_allergyIngredientIds.contains).toSet();
    final badNames = _allergyList
        .where((ing) => badIds.contains(ing.id))
        .map((ing) => ing.displayName ?? ing.name)
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AllergyWarningDialog(
        recipe: recipe,
        badIngredientNames: badNames,
        onConfirm: (r) {
          Navigator.pop(context); // ปิด dialog ก่อน
          _pushNamedExpectReturn('/recipe_detail', arguments: r);
        },
      ),
    );
  }

  // คำนวณความสูงแถบคาร์รอสเซลสูตร
  double _recipeStripHeight(BuildContext context) {
    const imageW = kRecipeCardVerticalWidth;
    final imageH = imageW * (3 / 4);
    final ts = Theme.of(context).textTheme;
    final scale = MediaQuery.textScaleFactorOf(context);
    double lh(TextStyle s) => (s.height ?? 1.2) * (s.fontSize ?? 14);
    final titleH =
        lh(ts.titleMedium ?? const TextStyle(fontSize: 20)) * 2 * scale;
    final metaH =
        lh(ts.bodyMedium ?? const TextStyle(fontSize: 18)) * 1 * scale;
    const padding = 8 + 4 + 8 + 8;
    final h = imageH + titleH + metaH + padding;
    return h.ceilToDouble();
  }
}

/* ────────────────────────────────────────────────
 * การ์ด “กลุ่มวัตถุดิบ” (เฉพาะหน้า Home)
 * ─ ใช้ UI เรียบ ๆ และโยน onTap ออกไปให้พ่อเรียกพรีเช็คเอง
 *
 * [NOTE/LEGACY - ยังเก็บไว้] หลังอัปเดต เราเปลี่ยนไปใช้ IngredientCard
 * ในหน้า Home เพื่อให้มีป้าย "สูตร N" อัตโนมัติ
 * คลาสนี้จึงไม่ถูกเรียกใช้งานแล้ว แต่เก็บไว้เผื่อ rollback/อ้างอิง
 * ──────────────────────────────────────────────── */
class _GroupCard extends StatelessWidget {
  final double width;
  final String name;
  final String imageUrl;
  final VoidCallback onTap;

  const _GroupCard({
    required this.width,
    required this.name,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageH = width / _ingredientImageAspectRatio;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(
              width: width,
              height: imageH,
              child: SafeImage(
                url: imageUrl,
                fit: BoxFit.cover,
                error: Container(
                  color: theme.colorScheme.surfaceVariant,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
