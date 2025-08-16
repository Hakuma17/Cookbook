// lib/screens/references_screen.dart
//
// 2025-08-02 – bump in-screen typography & paddings
//               (ใหญ่ขึ้นเฉพาะหน้านี้ ไม่กระทบหน้าทั้งแอป)

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ReferencesScreen extends StatelessWidget {
  const ReferencesScreen({super.key});

  // ✅ 1. ย้าย Helper สำหรับเปิด URL มาไว้ใน build method หรือแยกเป็น utility
  //    เพื่อให้เข้าถึง context ได้ง่ายขึ้นเมื่อต้องการแสดง SnackBar

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Data for references, making the build method cleaner
    final nutritionReferences = [
      {
        'title': 'ตารางแสดงคุณค่าทางโภชนาการของอาหารไทย',
        'subtitle': 'กรมอนามัย กระทรวงสาธารณสุข',
        'url':
            'https://nutrition2.anamai.moph.go.th/th/thai-food-composition-table/download?id=61523&mid=31993&mkey=m_document&lang=th&did=18032',
        'imageAsset': 'assets/images/Department_of_health.png',
      },
      {
        'title': 'Thai Food Composition Tables',
        'subtitle': 'สถาบันโภชนาการ มหาวิทยาลัยมหิดล (INMU)',
        'url': 'https://inmu.mahidol.ac.th/thaifcd',
        'imageAsset': 'assets/images/mahidol_Referange.jpg',
      },
    ];

    final bookReferences = [
      {
        'imageAsset': 'assets/images/Pimwit.jpg',
        'title': 'เมนูเด็ด...อาหารจานเดียว',
        'author': 'พิมพ์วิชญ์ โภคาสุวิบุลย์',
      },
      {
        'imageAsset': 'assets/images/Yodying.jpg',
        'title': 'ตำรับเด็ด อาหารตามสั่ง ทำกินอร่อยง่าย ทำขายยิ่งรวย',
        'author': 'ยอดยิ่ง ถาวรไทย',
      },
      {
        'imageAsset': 'assets/images/Nidda.jpg',
        'title': 'อาหารไทย สูตรจริงที่ทำได้ ทำง่าย มีภาพแสดงขั้นตอนการปรุง',
        'author': 'นิดาห์ หงษ์วิวัตน์',
      },
    ];

    // ⭐ เพิ่ม text scale เฉพาะหน้านี้อีกนิด (≈ 10%) ให้ดูอ่านง่ายขึ้น
    final mq = MediaQuery.of(context).copyWith(
      textScaler: const TextScaler.linear(1.10),
    );

    return MediaQuery(
      data: mq,
      child: Scaffold(
        // ✅ 2. AppBar จะดึงสไตล์มาจาก Theme ที่กำหนดใน main.dart โดยอัตโนมัติ
        appBar: AppBar(
          title: const Text('ข้อมูลอ้างอิง'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // --- Section: ข้อมูลโภชนาการ ---
            _buildSection(
              context,
              icon: Icons.health_and_safety_outlined,
              title: 'ข้อมูลโภชนาการ',
              children: List.generate(nutritionReferences.length, (index) {
                final ref = nutritionReferences[index];
                return _buildReferenceTile(
                  context,
                  title: ref['title']!,
                  subtitle: ref['subtitle']!,
                  url: ref['url']!,
                  imageAsset: ref['imageAsset'],
                );
              }).toList(),
            ),

            // --- Section: ข้อมูลสูตรอาหาร ---
            _buildSection(
              context,
              icon: Icons.menu_book_rounded,
              title: 'ข้อมูลสูตรอาหาร',
              children: List.generate(bookReferences.length, (index) {
                final book = bookReferences[index];
                return _buildBookReferenceTile(
                  context,
                  imageAsset: book['imageAsset']!,
                  title: book['title']!,
                  author: book['author']!,
                );
              }).toList(),
            ),

            // --- Section: ผู้จัดทำ ---
            _buildSection(
              context,
              icon: Icons.people_outline,
              title: 'ผู้จัดทำ',
              children: const [
                ListTile(
                  leading: CircleAvatar(child: Text('ย')), // ตัวอย่าง Avatar
                  title: Text('นายยศพล แสงอินทร์'),
                  subtitle: Text('นักศึกษาคณะวิศวกรรมคอมพิวเตอร์'),
                ),
                ListTile(
                  leading: CircleAvatar(child: Text('ฉ')), // ตัวอย่าง Avatar
                  title: Text('นายฉัตรดนัย ปูทอง'),
                  subtitle: Text('นักศึกษาคณะวิศวกรรมคอมพิวเตอร์'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper สำหรับเปิด URL
  Future<void> _launchURL(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถเปิดลิงก์ได้: $url')),
        );
      }
    }
  }

  // ✅ 3. Refactor Helper Widgets ให้ใช้ Theme และสะอาดขึ้น
  // Helper Widget สำหรับสร้างแต่ละ Section
  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4.0, 8.0, 0, 12.0),
          child: Row(
            children: [
              // ⭐ ไอคอนใหญ่ขึ้นเล็กน้อย
              Icon(icon, color: theme.colorScheme.primary, size: 26),
              const SizedBox(width: 12),
              Text(title, style: textTheme.titleLarge),
            ],
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            // --- ⭐️ จุดที่แก้ไข ⭐️ ---
            // เปลี่ยนจากการใช้ ListView.separated ที่ผิดพลาด
            // มาใช้ for loop เพื่อสร้างรายการ Widget และ Divider สลับกัน
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                // เพิ่ม Divider ถ้าหากยังไม่ใช่ item สุดท้าย
                if (i < children.length - 1) const Divider(height: 1),
              ],
            ],
            // -------------------------
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // Helper สำหรับรายการอ้างอิงที่มีลิงก์และรูปภาพ
  Widget _buildReferenceTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String url,
    String? imageAsset,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: imageAsset != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.asset(
                imageAsset,
                // ⭐ รูปใหญ่ขึ้นเพื่อบาลานซ์กับตัวอักษร
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            )
          : null,
      // ⭐ title ใช้ titleMedium (≈20sp) + หนาขึ้น
      title: Text(
        title,
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      // ⭐ subtitle ขยับเป็น bodyMedium (≈18sp) และใช้สีอ่อนลง
      subtitle: Text(
        subtitle,
        style:
            textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => _launchURL(url, context),
      // ⭐ padding แนวตั้งมากขึ้นให้คลิกง่าย
      contentPadding:
          const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
    );
  }

  // Helper สำหรับรายการอ้างอิงที่เป็นหนังสือ
  Widget _buildBookReferenceTile(
    BuildContext context, {
    required String imageAsset,
    required String title,
    required String author,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.asset(
              imageAsset,
              // ⭐ รูปหนังสือใหญ่ขึ้นเล็กน้อย
              width: 80,
              height: 104,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ⭐ ชื่อหนังสือใช้ titleMedium
                Text(title, style: textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'ผู้แต่ง: $author',
                  // ⭐ คำอธิบายใช้ bodyMedium สีอ่อนลง
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
