import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/comment.dart';

double _s(BuildContext context, double base) =>
    MediaQuery.textScalerOf(context).scale(base);

// [NEW] Widget “ไส้ใน” ของคอมเมนต์ (ไม่มี Card หุ้ม)
class CommentContent extends StatelessWidget {
  final Comment comment;
  final String? nameOverride;
  final String? avatarOverride;
  final bool showInlineActions;
  final ValueChanged<Comment>? onEdit;
  final ValueChanged<Comment>? onDelete;

  const CommentContent({
    super.key,
    required this.comment,
    this.nameOverride,
    this.avatarOverride,
    this.showInlineActions = true,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final c = comment;

    final userName = (() {
      final o = nameOverride?.trim() ?? '';
      if (o.isNotEmpty) return o;
      final n = (c.profileName ?? '').trim();
      return n.isNotEmpty ? n : 'ผู้ใช้ทั่วไป';
    })();

    final dateText = c.createdAt != null
        ? DateFormat('d MMM yyyy', 'th').format(c.createdAt!)
        : 'ไม่ระบุวันที่';

    final avatarUrl = avatarOverride?.trim().isNotEmpty == true
        ? avatarOverride!
        : (c.avatarUrl ?? '');

    final ImageProvider<Object> avatarProvider = avatarUrl.isNotEmpty
        ? NetworkImage(avatarUrl)
        : const AssetImage('assets/images/default_avatar.png');

    final commentText = (c.comment?.trim().isNotEmpty ?? false)
        ? c.comment!
        : '— ไม่มีข้อความรีวิว —';

    final isMine = c.isMine;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: _s(context, 18),
              backgroundColor: colorScheme.surfaceContainerHighest,
              backgroundImage: avatarProvider,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                userName,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              dateText,
              style: (textTheme.labelMedium ?? textTheme.bodySmall)
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            if (isMine &&
                showInlineActions &&
                (onEdit != null || onDelete != null))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    IconButton(
                      tooltip: 'แก้ไข',
                      iconSize: _s(context, 20),
                      constraints:
                          const BoxConstraints(minWidth: 44, minHeight: 44),
                      onPressed: () => onEdit!.call(c),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: 'ลบ',
                      iconSize: _s(context, 20),
                      constraints:
                          const BoxConstraints(minWidth: 44, minHeight: 44),
                      onPressed: () async {
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
                                    style: TextStyle(color: colorScheme.error)),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) onDelete!.call(c);
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 10),
        _RatingStars(rating: c.rating ?? 0),
        const SizedBox(height: 10),
        _ExpandableText(
          text: commentText,
          style: (textTheme.bodyMedium),
          toggleStyle: textTheme.bodyMedium?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// การ์ดแสดงรีวิว (ตัวหุ้ม)
class CommentCard extends StatelessWidget {
  final Comment comment;
  final ValueChanged<Comment>? onEdit;
  final ValueChanged<Comment>? onDelete;
  final String? nameOverride;
  final String? avatarOverride;
  final bool showInlineActions;
  final EdgeInsetsGeometry? margin;
  final Color? cardColor;

  const CommentCard({
    super.key,
    required this.comment,
    this.onEdit,
    this.onDelete,
    this.nameOverride,
    this.avatarOverride,
    this.showInlineActions = true,
    this.margin,
    this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Adaptive background: use container tones in dark, default cardColor / surface in light
    final Color bg = cardColor ??
        (isDark ? colorScheme.surfaceContainerLow : theme.cardColor);

    final borderColor =
        colorScheme.outlineVariant.withValues(alpha: isDark ? .25 : .35);
    final shadowClr = isDark
        ? Colors.black.withValues(alpha: 0.40)
        : Colors.black.withValues(alpha: 0.05);

    return Card(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bg,
      elevation: 0, // keep flat; rely on subtle border & shadow
      shadowColor: shadowClr,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: CommentContent(
          comment: comment,
          nameOverride: nameOverride,
          avatarOverride: avatarOverride,
          onEdit: onEdit,
          onDelete: onDelete,
          showInlineActions: showInlineActions,
        ),
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  final int rating;
  const _RatingStars({required this.rating});

  @override
  Widget build(BuildContext context) {
    final size = _s(context, 20);
    return Row(
      children: List.generate(5, (i) {
        final filled = i < rating;
        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 2),
          child: Icon(
            filled ? Icons.star : Icons.star_border,
            size: size,
            color: const Color(0xFFFFCC00),
          ),
        );
      }),
    );
  }
}

class _ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? toggleStyle;

  const _ExpandableText({required this.text, this.style, this.toggleStyle});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final base = widget.style ?? DefaultTextStyle.of(context).style;
        final tp = TextPainter(
          text: TextSpan(text: widget.text, style: base),
          textDirection: Directionality.of(context),
          maxLines: 3,
        )..layout(maxWidth: constraints.maxWidth);

        final isOverflow = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: base,
              maxLines: _isExpanded ? null : 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (isOverflow)
              GestureDetector(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    _isExpanded ? '...ย่อลง' : 'อ่านเพิ่มเติม...',
                    style: widget.toggleStyle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
