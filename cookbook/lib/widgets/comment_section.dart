import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // listEquals
import 'package:cookbook/services/auth_service.dart';

import '../models/comment.dart';
import 'comment_card.dart';
import 'comment_input_field.dart';

double _s(BuildContext context, double base) =>
    MediaQuery.textScalerOf(context).scale(base);

// StatefulWidget เพื่อจัดการ state ของรายการคอมเมนต์
class CommentSection extends StatefulWidget {
  final Comment? myComment;
  final List<Comment> otherComments;
  final int currentRating;
  final bool isLoggedIn;
  final ValueChanged<int> onRatingSelected;
  final VoidCallback onCommentPressed;
  final ValueChanged<Comment> onEdit;
  final ValueChanged<Comment> onDelete;

  const CommentSection({
    super.key,
    this.myComment,
    required this.otherComments,
    required this.currentRating,
    required this.isLoggedIn,
    required this.onRatingSelected,
    required this.onCommentPressed,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  // รายการคอมเมนต์ที่จะแสดง (paginate)
  late List<Comment> _displayedComments;
  final int _commentsPerPage = 10;

  // เก็บ Future ไว้ ไม่สร้างใหม่ทุก build
  late Future<Map<String, dynamic>> _loginDataFuture;

  @override
  void initState() {
    super.initState();
    _initializeComments();
    _loginDataFuture = AuthService.getLoginData();
  }

  // อัปเดต state เมื่อพร็อพเปลี่ยน (เช่น โหลดคอมเมนต์ชุดใหม่/จำนวนเปลี่ยน)
  @override
  void didUpdateWidget(covariant CommentSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    final listChanged =
        !identical(widget.otherComments, oldWidget.otherComments) ||
            widget.otherComments.length != oldWidget.otherComments.length ||
            !listEquals(widget.otherComments, oldWidget.otherComments);

    if (listChanged) {
      final keep =
          _displayedComments.length.clamp(0, widget.otherComments.length);
      _displayedComments = widget.otherComments.sublist(0, keep);
    }

    // ถ้าสถานะล็อกอินเปลี่ยน รีโหลด future หนึ่งครั้ง
    if (widget.isLoggedIn != oldWidget.isLoggedIn) {
      _loginDataFuture = AuthService.getLoginData();
    }
  }

  // กำหนดค่าเริ่มต้นให้รายการคอมเมนต์
  void _initializeComments() {
    final initialCount = widget.otherComments.length > _commentsPerPage
        ? _commentsPerPage
        : widget.otherComments.length;
    _displayedComments = widget.otherComments.sublist(0, initialCount);
  }

  // โหลดคอมเมนต์เพิ่มเติม
  void _loadMoreComments() {
    setState(() {
      final currentCount = _displayedComments.length;
      final nextCount = (currentCount + _commentsPerPage)
          .clamp(0, widget.otherComments.length);
      _displayedComments = widget.otherComments.sublist(0, nextCount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final hasMyComment = widget.myComment != null && !widget.myComment!.isEmpty;
    final totalComments = widget.otherComments.length + (hasMyComment ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.isLoggedIn)
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
            child: hasMyComment
                ? _buildMyCommentBox(context, widget.myComment!)
                : _buildFirstCommentBox(context),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('เข้าสู่ระบบเพื่อให้คะแนน/แสดงความคิดเห็น',
                        style: textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.center,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        icon: const Icon(Icons.login),
                        label: const Text('เข้าสู่ระบบ'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('ความคิดเห็นทั้งหมด ($totalComments)',
              style: textTheme.titleLarge),
        ),
        const SizedBox(height: 8),
        if (widget.otherComments.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _displayedComments.length,
            itemBuilder: (context, index) {
              final c = _displayedComments[index];
              return CommentCard(
                // ✅ key ใช้ฟิลด์ที่มีอยู่ เพื่อความเสถียร
                key: ValueKey(
                  'c_${c.userId ?? "u"}_${c.createdAt?.millisecondsSinceEpoch ?? index}',
                ),
                comment: c,
                cardColor: Colors.white,
              );
            },
          )
        else if (!hasMyComment)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Center(
              child: Text(
                'ยังไม่มีความคิดเห็นสำหรับสูตรนี้',
                style: textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        if (_displayedComments.length < widget.otherComments.length)
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            child: Center(
              child: TextButton(
                onPressed: _loadMoreComments,
                child: const Text('ดูความคิดเห็นเพิ่มเติม'),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------- UI ส่วน "ความคิดเห็นของคุณ" ----------------
  Widget _buildMyCommentBox(BuildContext context, Comment comment) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(.45), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('ความคิดเห็นของคุณ', style: tt.titleLarge),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _tonalIconButton(
                      context,
                      icon: Icons.delete_outline,
                      tooltip: 'ลบ',
                      onTap: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('ยืนยันการลบ'),
                            content: const Text(
                                'คุณต้องการลบคอมเมนต์นี้ใช่หรือไม่?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('ยกเลิก'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text('ลบ',
                                    style: TextStyle(color: cs.error)),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) widget.onDelete(comment);
                      },
                    ),
                    const SizedBox(width: 8),
                    _tonalIconButton(
                      context,
                      icon: Icons.edit_outlined,
                      tooltip: 'แก้ไข',
                      onTap: () => widget.onEdit(comment),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: cs.outlineVariant.withOpacity(.4)),
          const SizedBox(height: 12),

          // ใช้ future ที่ cache ไว้
          FutureBuilder<Map<String, dynamic>>(
            future: _loginDataFuture,
            builder: (ctx, snap) {
              final data = snap.data ?? const {};
              final fallbackAvatar = (comment.avatarUrl?.isNotEmpty ?? false)
                  ? null
                  : (data['profileImage'] as String?);
              final fallbackName =
                  (comment.profileName?.trim().isNotEmpty ?? false)
                      ? null
                      : (data['profileName'] as String?);

              return CommentContent(
                comment: comment,
                avatarOverride: fallbackAvatar,
                nameOverride: fallbackName,
                showInlineActions: false,
                onEdit: widget.onEdit,
                onDelete: widget.onDelete,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFirstCommentBox(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;

    final active = theme.colorScheme.tertiary;
    final inactive = theme.colorScheme.outlineVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('คุณคิดอย่างไรกับสูตรนี้?', style: tt.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final ratingValue = i + 1;
                final selected = ratingValue <= widget.currentRating;
                return IconButton(
                  tooltip: 'ให้ $ratingValue ดาว',
                  icon: Icon(
                    selected ? Icons.star : Icons.star_border,
                    size: _s(context, 24),
                    color: selected ? active : inactive,
                  ),
                  onPressed: () => widget.onRatingSelected(ratingValue),
                );
              }),
            ),
            const SizedBox(height: 12),
            CommentInputField(onTap: widget.onCommentPressed),
          ],
        ),
      ),
    );
  }

  Widget _tonalIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 2.0,
      shadowColor: Colors.black.withOpacity(0.25),
      color: cs.surfaceContainerHigh,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon),
        onPressed: onTap,
        iconSize: 20,
        color: cs.onSurfaceVariant,
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
