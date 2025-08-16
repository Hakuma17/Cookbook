import 'package:cookbook/services/auth_service.dart';
import 'package:flutter/material.dart';

/// FavoriteButton (responsive)
/// ปุ่มเพิ่ม/ลบสูตรโปรด (วงกลม) • แจ้ง onChanged(newState) ทุกครั้ง
class FavoriteButton extends StatefulWidget {
  final bool initialIsFavorited;
  final Future<void> Function(bool newValue) onChanged;

  const FavoriteButton({
    super.key,
    required this.initialIsFavorited,
    required this.onChanged,
  });

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  late bool _isFavorited;
  bool _isLoading = false;
  bool _isLoggedIn = false; // ✅ 1. เปลี่ยนชื่อ state ให้ชัดเจนขึ้น

  @override
  void initState() {
    super.initState();
    _isFavorited = widget.initialIsFavorited;
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;
    setState(() => _isLoggedIn = loggedIn);
  }

  @override
  void didUpdateWidget(covariant FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIsFavorited != oldWidget.initialIsFavorited) {
      setState(() => _isFavorited = widget.initialIsFavorited);
    }
    _checkUserStatus(); // รีเช็กทุกครั้งเพื่อกรณี logout/login
  }

  Future<void> _toggleFavorite() async {
    if (!_isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนเพิ่มรายการโปรด')),
      );
      // ✅ 2. แนะนำให้มีการนำทางไปหน้า Login ด้วย
      // ★ Added: นำทางไปหน้า Login (สามารถส่ง nextRoute เพิ่มเองได้ถ้าต้องการ)
      Navigator.pushNamed(context, '/login');
      return;
    }
    setState(() => _isLoading = true);

    final newState = !_isFavorited;
    try {
      await widget.onChanged(newState);
      if (mounted) setState(() => _isFavorited = newState);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 3. ลบ Manual Responsive Calculation และใช้ Theme
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // ✅ 4. เปลี่ยนมาใช้ IconButton ที่สามารถกำหนดสไตล์ได้ยืดหยุ่น
    final button = IconButton(
      onPressed: _isLoading ? null : _toggleFavorite,
      iconSize: 28, // กำหนดขนาดไอคอนที่เหมาะสม
      tooltip: _isFavorited ? 'ลบออกจากสูตรโปรด' : 'เพิ่มเป็นสูตรโปรด',
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.surface,
        foregroundColor:
            _isFavorited ? colorScheme.primary : colorScheme.onSurfaceVariant,
        side: BorderSide(
          color: _isFavorited
              ? colorScheme.primary
              : colorScheme.outline.withOpacity(0.5),
          width: 1.5,
        ),
        // ใช้ elevation จาก Theme ของ Card เพื่อความสอดคล้อง
        elevation: theme.cardTheme.elevation ?? 1.0,
      ),
      icon: _isLoading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colorScheme.primary,
              ),
            )
          : Icon(
              _isFavorited ? Icons.favorite : Icons.favorite_border,
            ),
    );

    // ★ Added: ครอบด้วย Semantics เพื่อการเข้าถึง (A11y)
    return Semantics(
      button: true,
      toggled: _isFavorited,
      label: _isFavorited ? 'เอาออกจากรายการโปรด' : 'เพิ่มเป็นรายการโปรด',
      child: button,
    );
  }
}
