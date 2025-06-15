import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FavoriteButton
/// ปุ่มกดเพิ่ม/ลบสูตรโปรด (วงกลมขนาด 43.63×43.63, ขอบ 1.0907px)
/// - [initialIsFavorited] ค่าตั้งต้น
/// - [onChanged] จะถูกเรียกพร้อมสถานะใหม่ (true=เพิ่ม, false=ลบ)
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
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    setState(() {
      _canToggle = userId != null;
    });
  }

  @override
  void didUpdateWidget(covariant FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIsFavorited != oldWidget.initialIsFavorited) {
      setState(() {
        _isFavorited = widget.initialIsFavorited;
      });
    }
    _checkUserStatus(); // รีเช็ก login ทุกครั้งที่ widget rebuild
  }

  Future<void> _toggleFavorite() async {
    if (!_canToggle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนเพิ่มรายการโปรด')),
      );
      return;
    }

    setState(() => _loading = true);
    final newValue = !_isFavorited;
    try {
      await widget.onChanged(newValue);
      setState(() => _isFavorited = newValue);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถเปลี่ยนสถานะโปรดได้')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const double size = 43.63;
    const double borderWidth = 1.0907;
    const double iconSize = 21.81;
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
        padding: const EdgeInsets.all((43.63 - 21.81) / 2), // = 10.91
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: _loading
            ? const SizedBox(
                width: iconSize,
                height: iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: borderWidth,
                  color: Color(0xFFFF9B05),
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
