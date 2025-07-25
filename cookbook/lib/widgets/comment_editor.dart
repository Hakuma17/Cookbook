import 'package:flutter/material.dart';
import 'package:cookbook/services/api_service.dart';
import 'package:cookbook/services/auth_service.dart';

/// Modal Bottom-Sheet สำหรับสร้างหรือแก้ไขคอมเมนต์
class CommentEditor extends StatefulWidget {
  final int recipeId;
  final int initialRating;
  final String initialText;

  const CommentEditor({
    super.key,
    required this.recipeId,
    this.initialRating = 0,
    this.initialText = '',
  });

  @override
  _CommentEditorState createState() => _CommentEditorState();
}

class _CommentEditorState extends State<CommentEditor> {
  late int _rating;
  late TextEditingController _controller;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /* ───────── submit ───────── */
  /// ✅ 1. ปรับปรุง Error Handling
  Future<void> _submit() async {
    if (_rating <= 0) {
      setState(() => _errorMsg = 'กรุณาให้คะแนนอย่างน้อย 1 ดาว');
      return;
    }

    // การเช็ค login ควรทำที่นี่ก่อนส่งข้อมูล
    if (!await AuthService.isLoggedIn()) {
      _showSnack('กรุณาเข้าสู่ระบบก่อนแสดงความคิดเห็น');
      // อาจจะ pop และนำทางไปหน้า login
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      await ApiService.postComment(
        widget.recipeId,
        _controller.text.trim(),
        _rating.toDouble(),
      );
      if (mounted)
        Navigator.pop(context, true); // ส่ง true กลับไปเพื่อบอกว่าสำเร็จ
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMsg = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'เกิดข้อผิดพลาดในการเชื่อมต่อ');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /* ───────── build ───────── */
  @override
  Widget build(BuildContext context) {
    // ✅ 2. ลบ Manual Responsive Calculation และใช้ Theme
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isEditing = widget.initialText.isNotEmpty;

    // Padding ที่ด้านล่างจะดัน UI ขึ้นเมื่อคีย์บอร์ดแสดง
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle สำหรับลาก
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ให้คะแนนและแสดงความคิดเห็น',
                style: textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Rating Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final ratingValue = i + 1;
              return IconButton(
                icon: Icon(
                  ratingValue <= _rating ? Icons.star : Icons.star_border,
                  size: 32,
                  color: ratingValue <= _rating ? Colors.amber : Colors.grey,
                ),
                onPressed: () => setState(() => _rating = ratingValue),
              );
            }),
          ),
          const SizedBox(height: 16),

          // Text Field
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 300,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: 'เขียนความคิดเห็นของคุณ (ไม่บังคับ)',
              counterText: '', // ซ่อน counter text เริ่มต้น
            ),
          ),

          // Error Message
          if (_errorMsg != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMsg!,
              style: textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),

          // Submit Button
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3),
                  )
                : Text(isEditing ? 'บันทึกการแก้ไข' : 'โพสต์ความคิดเห็น'),
          ),
        ],
      ),
    );
  }
}
