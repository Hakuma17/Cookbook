import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

/// Modal Bottom-Sheet สำหรับสร้างหรือแก้ไขคอมเมนต์
class CommentEditor extends StatefulWidget {
  final int recipeId;
  final int initialRating;
  final String initialText;
  final VoidCallback onSubmitted;

  const CommentEditor({
    Key? key,
    required this.recipeId,
    this.initialRating = 0,
    this.initialText = '',
    required this.onSubmitted,
  }) : super(key: key);

  @override
  _CommentEditorState createState() => _CommentEditorState();
}

class _CommentEditorState extends State<CommentEditor> {
  late int _rating;
  late TextEditingController _controller;
  bool _isLoading = false;
  String? _error;

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
  Future<void> _submit() async {
    if (_rating <= 0) {
      setState(() => _error = 'กรุณาให้คะแนนก่อนโพสต์');
      return;
    }
    if (!await AuthService.isLoggedIn()) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          // แสดง SnackBar แจ้งเตือน
          const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนโพสต์')),
        );
      }
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ApiService.postComment(
        widget.recipeId,
        _controller.text.trim(),
        _rating.toDouble(),
      );
      widget.onSubmitted();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /* ───────── build ───────── */
  @override
  Widget build(BuildContext context) {
    /* responsive metrics */
    final w = MediaQuery.of(context).size.width;
    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);

    final radius = clamp(w * 0.04, 14, 22); // มุมโค้ง dialog
    final handleW = clamp(w * 0.16, 40, 60); // แถบจับด้านบน
    final handleH = clamp(w * 0.012, 3, 6);
    final padBox = clamp(w * 0.04, 14, 20); // padding ในกล่อง
    final titleF = clamp(w * 0.047, 16, 20); // ฟอนต์หัวเรื่อง
    final starSz = clamp(w * 0.085, 26, 34); // ขนาดดาว
    final textF = clamp(w * 0.04, 14, 16); // ฟอนต์ข้อความอินพุต
    final btnF = clamp(w * 0.043, 14, 18); // ฟอนต์ปุ่มโพสต์
    final errF = textF; // ฟอนต์ error
    final fieldRad = radius * 0.7; // รัศมีกรอบ TextField

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Stack(
          children: [
            /* ───── กล่องหลัก ───── */
            Container(
              padding: EdgeInsets.all(padBox),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(radius),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: handleW,
                      height: handleH,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(handleH / 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('ให้คะแนนและแสดงความคิดเห็น',
                      style: TextStyle(
                          fontSize: titleF, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),

                  /* ───── ดาว rating ───── */
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final filled = i < _rating;
                        return GestureDetector(
                          onTap: () => setState(() => _rating = i + 1),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              filled ? Icons.star : Icons.star_border,
                              size: starSz,
                              color: filled
                                  ? const Color(0xFFFFCC00)
                                  : Colors.grey,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),

                  /* ───── ช่องคอมเมนต์ ───── */
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    maxLength: 300,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(fontSize: textF),
                    decoration: InputDecoration(
                      hintText: 'เขียนความคิดเห็นของคุณ (ไม่บังคับ)',
                      hintStyle: TextStyle(fontSize: textF),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(fieldRad)),
                      counterText: '',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: TextStyle(color: Colors.red, fontSize: errF)),
                  ],
                  const SizedBox(height: 16),

                  /* ───── ปุ่มโพสต์ / บันทึก ───── */
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9B05),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: padBox * 0.6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(radius)),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: starSz * 0.7,
                              height: starSz * 0.7,
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              widget.initialText.isEmpty ? 'โพสต์' : 'บันทึก',
                              style: TextStyle(
                                  fontSize: btnF, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            /* ───── ปุ่มปิด ───── */
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                icon: Icon(Icons.close, size: titleF + 2),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
