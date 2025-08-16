// lib/screens/references_screen.dart
//
// 2025-08-02 – tune sizes & spacing for balance with app theme
//              (เลิก textScaler ทั้งหน้า → ปรับเป็นรายองค์ประกอบ)
// NOTE: เก็บคอมเมนต์ของเดิมไว้ด้านล่างที่เกี่ยวข้อง

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// ทำให้ข้อมูลอ้างอิงเป็น const + ใส่ type ชัดเจน เพื่อลดรีบิลด์/GC
const List<Map<String, String>> _nutritionReferences = [
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

const List<Map<String, String>> _bookReferences = [
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

class ReferencesScreen extends StatelessWidget {
  const ReferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ❌ (OLD) ขยายทั้งหน้าด้วย textScaler ทำให้ดู “ใหญ่แต่แน่น”
    // final mq = MediaQuery.of(context).copyWith(
    //   textScaler: const TextScaler.linear(1.10),
    // );
    // return MediaQuery(data: mq, child: ...);

    return Scaffold(
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
            children: [
              for (final ref in _nutritionReferences)
                _buildReferenceTile(
                  context,
                  title: ref['title']!,
                  subtitle: ref['subtitle']!,
                  url: ref['url']!,
                  imageAsset: ref['imageAsset'],
                ),
            ],
          ),

          // --- Section: ข้อมูลสูตรอาหาร ---
          _buildSection(
            context,
            icon: Icons.menu_book_rounded,
            title: 'ข้อมูลสูตรอาหาร',
            children: [
              for (final book in _bookReferences)
                _buildBookReferenceTile(
                  context,
                  imageAsset: book['imageAsset']!,
                  title: book['title']!,
                  author: book['author']!,
                ),
            ],
          ),

          // --- Section: ผู้จัดทำ ---
          _buildSection(
            context,
            icon: Icons.people_outline,
            title: 'ผู้จัดทำ',
            children: const [
              _PeopleTile(
                initials: 'ย',
                name: 'นายยศพล แสงอินทร์',
                role: 'นักศึกษาคณะวิศวกรรมคอมพิวเตอร์',
              ),
              Divider(height: 1),
              _PeopleTile(
                initials: 'ฉ',
                name: 'นายฉัตรดนัย ปูทอง',
                role: 'นักศึกษาคณะวิศวกรรมคอมพิวเตอร์',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper สำหรับเปิด URL (รองรับ web/mobile)
  Future<void> _launchURL(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    final mode =
        kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;

    if (!await launchUrl(uri, mode: mode)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถเปิดลิงก์ได้: $url')),
        );
      }
    }
  }

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
              // ไอคอนขนาดกำลังดี ไม่ดันบรรทัด
              Icon(icon, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 10),
              Text(title, style: textTheme.titleLarge),
            ],
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // รายการอ้างอิงที่มีลิงก์และรูปภาพ
  Widget _buildReferenceTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String url,
    String? imageAsset,
  }) {
    final txt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      leading: imageAsset != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.asset(
                imageAsset,
                width: 60, // เดิม 64 → ลดนิดให้บาลานซ์
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 60,
                  height: 60,
                  color: cs.surfaceVariant,
                  alignment: Alignment.center,
                  child: Icon(Icons.image_not_supported,
                      color: cs.onSurfaceVariant),
                ),
              ),
            )
          : null,
      // title ใช้ titleMedium + w600 + line-height อ่านสบาย
      title: Text(
        title,
        style: txt.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.15,
        ),
      ),
      // subtitle ใช้ bodySmall (16sp) สีอ่อน + line-height
      subtitle: Text(
        subtitle,
        style: txt.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
          height: 1.25,
        ),
      ),
      trailing: Icon(Icons.open_in_new,
          size: 18, color: cs.onSurfaceVariant.withOpacity(.9)),
      onTap: () => _launchURL(url, context),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
    );
  }

  // รายการอ้างอิงที่เป็นหนังสือ
  Widget _buildBookReferenceTile(
    BuildContext context, {
    required String imageAsset,
    required String title,
    required String author,
  }) {
    final txt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.asset(
              imageAsset,
              width: 76, // เดิม 80 → ลดเล็กน้อย
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 76,
                height: 100,
                color: cs.surfaceVariant,
                alignment: Alignment.center,
                child:
                    Icon(Icons.image_not_supported, color: cs.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: txt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.20,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ผู้แต่ง: $author',
                  style: txt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.30,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/*──────────────────────── People tile ───────────────────────*/

class _PeopleTile extends StatelessWidget {
  const _PeopleTile({
    required this.initials,
    required this.name,
    required this.role,
  });

  final String initials;
  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    return ListTile(
      leading: CircleAvatar(
        radius: 18, // เล็กลงให้สมดุลกับความสูงบรรทัด
        backgroundColor: cs.primary.withOpacity(.15),
        foregroundColor: cs.primary,
        child: Text(initials),
      ),
      title: Text(
        name,
        style: txt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        role,
        style: txt.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
          height: 1.30,
        ),
      ),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
    );
  }
}

/*──────────────────────── โค้ดเดิมที่เปลี่ยนไป ───────────────────────
1) มี MediaQuery textScaler(1.10) ครอบทั้งหน้า → เอาออก
   // final mq = MediaQuery.of(context).copyWith(
   //   textScaler: const TextScaler.linear(1.10),
   // );
   // return MediaQuery(data: mq, child: Scaffold(...));

2) ขนาดรูป/ไอคอน:
   - icon section: 24 → 22
   - รูป tile: 64 → 60
   - ปกหนังสือ: 80x104 → 76x100
   - trailing open_in_new: 24 → 18

3) ตัวอักษร:
   - title ของ tile ใช้ titleMedium + w600 + height 1.15/1.20
   - subtitle ใช้ bodySmall + height 1.25–1.30 (อ่านโล่งขึ้น)
   - คนทำงาน (_PeopleTile) ใช้ pattern เดียวกับรายการทั่วไป

4) padding:
   - ListTile contentPadding แนวตั้ง 10–12 เพื่อคลิกง่ายแต่ไม่แน่น
────────────────────────────────────────────────────────────*/
