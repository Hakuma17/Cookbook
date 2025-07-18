// lib/screens/references_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ReferencesScreen extends StatelessWidget {
  const ReferencesScreen({Key? key}) : super(key: key);

  // Helper สำหรับเปิด URL
  Future<void> _launchURL(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถเปิดลิงก์ได้: $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ข้อมูลอ้างอิง'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Section: ข้อมูลโภชนาการ
          _buildSection(
            context,
            icon: Icons.health_and_safety_outlined,
            title: 'ข้อมูลโภชนาการ',
            children: [
              _buildReferenceTile(
                context,
                title: 'ตารางแสดงคุณค่าทางโภชนาการของอาหารไทย',
                subtitle: 'กรมอนามัย กระทรวงสาธารณสุข',
                url:
                    'https://nutrition2.anamai.moph.go.th/th/thai-food-composition-table/download?id=61523&mid=31993&mkey=m_document&lang=th&did=18032',
                imageAsset:
                    'assets/images/Department_of_health.png', // รูปจากกรมอนามัย
              ),
              const Divider(height: 1),
              _buildReferenceTile(
                context,
                title: 'Thai Food Composition Tables',
                subtitle: 'สถาบันโภชนาการ มหาวิทยาลัยมหิดล (INMU)',
                url: 'https://inmu.mahidol.ac.th/thaifcd/home',
                imageAsset:
                    'assets/images/mahidol_Referange.jpg', // รูปจากมหิดล
              ),
            ],
          ),

          // Section: ข้อมูลสูตรอาหาร
          _buildSection(
            context,
            icon: Icons.menu_book_rounded,
            title: 'ข้อมูลสูตรอาหาร',
            children: [
              _buildBookReferenceTile(
                context,
                imageAsset: 'assets/images/Pimwit.jpg',
                title: 'เมนูเด็ด...อาหารจานเดียว',
                author: 'พิมพ์วิชญ์ โภคาสุวิบุลย์',
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildBookReferenceTile(
                context,
                imageAsset: 'assets/images/Yodying.jpg',
                title: 'ตำรับเด็ด อาหารตามสั่ง ทำกินอร่อยง่าย ทำขายยิ่งรวย',
                author: 'ยอดยิ่ง ถาวรไทย',
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildBookReferenceTile(
                context,
                imageAsset: 'assets/images/Nidda.jpg',
                title:
                    'อาหารไทย สูตรจริงที่ทำได้ ทำง่าย มีภาพแสดงขั้นตอนการปรุง',
                author: 'นิดาห์ หงษ์วิวัตน์',
              ),
            ],
          ),

          // Section: ผู้จัดทำ
          _buildSection(context,
              icon: Icons.person_pin_rounded,
              title: 'ผู้จัดทำ',
              children: [
                ListTile(
                  title: Text('นายยศพล แสงอินทร์',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('นักศึกษาคณะวิศวกรรมคอมพิวเตอร์',
                      style: TextStyle(color: Colors.grey[600])),
                ),
                ListTile(
                  title: Text('ฉัตรดนัย ปูทอง',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('นักศึกษาคณะวิศวกรรมคอมพิวเตอร์',
                      style: TextStyle(color: Colors.grey[600])),
                ),
              ]),
        ],
      ),
    );
  }

  // Helper Widget สำหรับสร้างแต่ละ Section
  Widget _buildSection(BuildContext context,
      {required IconData icon,
      required String title,
      required List<Widget> children}) {
    final titleStyle = Theme.of(context)
        .textTheme
        .titleLarge
        ?.copyWith(fontWeight: FontWeight.w600, fontSize: 18);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
          child: Row(
            children: [
              Icon(icon, color: Colors.grey[800], size: 22),
              const SizedBox(width: 8),
              Text(title, style: titleStyle),
            ],
          ),
        ),
        Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 24.0),
          clipBehavior: Clip.antiAlias, // ทำให้มุมโค้งมีผลกับ Child
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
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
    return ListTile(
      leading: imageAsset != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.asset(imageAsset,
                  width: 56, height: 56, fit: BoxFit.cover),
            )
          : null,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      trailing: const Icon(Icons.open_in_new, color: Colors.grey),
      onTap: () => _launchURL(url, context),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
    );
  }

  // Helper สำหรับรายการอ้างอิงที่เป็นหนังสือ
  Widget _buildBookReferenceTile(
    BuildContext context, {
    required String imageAsset,
    required String title,
    required String author,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.asset(
              imageAsset,
              width: 70,
              height: 90,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'ผู้แต่ง: $author',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
