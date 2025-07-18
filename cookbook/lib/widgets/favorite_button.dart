import 'package:cookbook/services/auth_service.dart';
import 'package:flutter/material.dart';

/// FavoriteButton (responsive)
/// ปุ่มเพิ่ม/ลบสูตรโปรด (วงกลม)  • แจ้ง onChanged(newState) ทุกครั้ง
class FavoriteButton extends StatefulWidget {
  final bool initialIsFavorited;
  final Future<void> Function(bool newValue) onChanged;

  const FavoriteButton({
    Key? key,
    required this.initialIsFavorited,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  late bool _isFavorited;
  bool _loading = false;
  bool _canToggle = false;

  @override
  void initState() {
    super.initState();
    _isFavorited = widget.initialIsFavorited;
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    final data = await AuthService.getLoginData();
    if (!mounted) return;
    setState(() => _canToggle = data['userId'] != null);
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
    if (!_canToggle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนเพิ่มรายการโปรด')),
      );
      return;
    }
    setState(() => _loading = true);

    final newState = !_isFavorited;
    try {
      await widget.onChanged(newState);
      if (mounted) setState(() => _isFavorited = newState);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถเปลี่ยนสถานะโปรดได้')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    /* ── responsive metrics ── */
    final w = MediaQuery.of(context).size.width;
    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);

    final size = clamp(w * 0.12, 36, 56); // Ø ปุ่ม
    final iconSize = size * 0.50; // Ø ไอคอน
    final borderWidth = size * 0.025; // ความหนาขอบ
    final pad = (size - iconSize) / 2; // padding ให้ไอคอนกลาง

    final borderColor =
        _isFavorited ? const Color(0xFFFF9B05) : const Color(0xFFD8D8D8);
    final iconColor =
        _isFavorited ? const Color(0xFFFF9B05) : const Color(0xFF828282);

    return InkWell(
      onTap: _loading ? null : _toggleFavorite,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: _loading
            ? SizedBox(
                width: iconSize,
                height: iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: borderWidth,
                  color: const Color(0xFFFF9B05),
                ),
              )
            : Icon(
                _isFavorited ? Icons.favorite : Icons.favorite_border,
                size: iconSize,
                color: iconColor,
              ),
      ),
    );
  }
}
