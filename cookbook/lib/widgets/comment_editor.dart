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
  State<CommentEditor> createState() => _CommentEditorState();
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

  // ── Normalizer: ตัด zero-width, จูนบรรทัด, รวมช่องว่างให้เทียบได้แฟร์ ──
  String _norm(String s) {
    return s
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '') // zero-width
        .replaceAll(RegExp(r'[ \t]+'), ' ') // รวมช่องว่าง/แท็บ (คง \n ไว้)
        .trim();
  }

  /* ───────── submit ───────── */
  ///   Commit composing + กัน “แก้แต่ไม่เปลี่ยน” ไม่ให้ยิง API
  Future<void> _submit() async {
    // 1) commit composing ของ IME โดยไม่ต้องซ่อนคีย์บอร์ด
    final v = _controller.value;
    if (v.composing.isValid) {
      _controller.value = v.copyWith(composing: TextRange.empty);
    }

    // 2) ตรวจ “ไม่มีการเปลี่ยนแปลงจริง ๆ”
    final newNorm = _norm(_controller.text);
    final oldNorm = _norm(widget.initialText);
    final unchanged = (_rating == widget.initialRating) && (newNorm == oldNorm);

    if (unchanged) {
      if (mounted) Navigator.pop(context, false); // ปิดเงียบ ๆ ไม่ยิง API
      return;
    }

    if (_rating <= 0) {
      setState(() => _errorMsg = 'กรุณาให้คะแนนอย่างน้อย 1 ดาว');
      return;
    }

    if (!await AuthService.isLoggedIn()) {
      _showSnack('กรุณาเข้าสู่ระบบก่อนแสดงความคิดเห็น');
      if (mounted) Navigator.pop(context, false);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      await ApiService.postComment(
        widget.recipeId,
        newNorm, // ส่งข้อความที่ normalize แล้ว
        _rating.toDouble(),
      );
      if (mounted) Navigator.pop(context, true); // สำเร็จ
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMsg = e.message);
    } catch (_) {
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
    // ★ กัน overflow เวลา textScale ใหญ่ (เฉพาะแผ่นล่างนี้)
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final mq = MediaQuery.of(context);
    final clampedScaler =
        mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.12);

    final isEditing = widget.initialText.isNotEmpty;

    return MediaQuery(
      data: mq.copyWith(textScaler: clampedScaler),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ให้คะแนนและแสดงความคิดเห็น',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, false),
                  tooltip: 'ปิด',
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

            // Text Field (ยัง autofocus ตามเดิม)
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 300,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'เขียนความคิดเห็นของคุณ (ไม่บังคับ)',
                counterText: '',
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

            // Submit Button — กดได้ทันทีแม้คีย์บอร์ดเปิดอยู่
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : Text(isEditing ? 'บันทึกการแก้ไข' : 'โพสต์ความคิดเห็น'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
