// lib/widgets/comment_input_field.dart

import 'package:flutter/material.dart';

/// CommentInputField
/// กล่องให้กดเพื่อแสดงความคิดเห็น (ตามดีไซน์ Frame 27)
class CommentInputField extends StatelessWidget {
  /// เมื่อกดกล่องนี้
  final VoidCallback onTap;

  const CommentInputField({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      // ชิดขอบซ้าย–ขวา 16px ตาม mock-up
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          height: 54, // ตาม Frame 27
          padding: const EdgeInsets.symmetric(
            vertical: 16, // ตาม mock-up
            horizontal: 12, // ตาม mock-up
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: const Color(0xFF828282), // ขอบตาม mock-up
              width: 1, // 1px
            ),
            borderRadius: BorderRadius.circular(12), // radius 12px
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Icon(
                Icons.mode_edit_outline,
                size: 20, // ขนาด 20px ตาม mock-up
                color: Color(0xFF838383), // สี #838383
              ),
              SizedBox(width: 4), // gap 4px
              Text(
                'แสดงความคิดเห็น',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12, // font-size 12px
                  fontWeight: FontWeight.w600,
                  height: 22 / 12, // line-height 22px
                  color: Color(0xFF838383),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
