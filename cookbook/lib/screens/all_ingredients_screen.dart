import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ingredient.dart';
import '../services/api_service.dart';
import '../widgets/ingredient_card.dart';
import 'login_screen.dart';

class AllIngredientsScreen extends StatefulWidget {
  const AllIngredientsScreen({super.key});

  @override
  State<AllIngredientsScreen> createState() => _AllIngredientsScreenState();
}

class _AllIngredientsScreenState extends State<AllIngredientsScreen> {
  late Future<List<Ingredient>> _futureIngredients;
  List<Ingredient> _allIngredients = [];
  List<Ingredient> _filteredIngredients = [];

  final TextEditingController _searchController = TextEditingController();

  String? _username; // ← ชื่อผู้ใช้จาก SharedPreferences
  String? _profileImage; // ← URL รูปผู้ใช้จาก SharedPreferences

  @override
  void initState() {
    super.initState();
    _loadUserInfo(); // โหลดข้อมูลผู้ใช้
    _loadIngredients(); // โหลดวัตถุดิบ
  }

  // โหลดข้อมูลผู้ใช้จาก SharedPreferences
  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('profileName') ?? 'ผู้ใช้';
      _profileImage = prefs.getString('profileImage');
    });
  }

  // โหลดวัตถุดิบจาก API
  void _loadIngredients() {
    _futureIngredients = ApiService.fetchIngredients();
    _futureIngredients.then((data) {
      setState(() {
        _allIngredients = data;
        _filteredIngredients = data;
      });
    });
  }

  // ค้นหาวัตถุดิบ
  void _searchIngredients(String query) {
    setState(() {
      _filteredIngredients = _allIngredients.where((ingredient) {
        return ingredient.name.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeaderBar(), // Header ผู้ใช้
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: TextField(
                controller: _searchController,
                onChanged: _searchIngredients,
                decoration: InputDecoration(
                  hintText: 'คุณอยากหาวัตถุดิบอะไร?',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'วัตถุดิบ',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Noto Sans Thai',
                    color: Color(0xFF0A2533),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: _buildGrid(), // วัตถุดิบแบบ Grid
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Header Bar ที่มีโปรไฟล์ + ชื่อ + ปุ่ม Logout
  Widget _buildHeaderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE1E1E1), width: 1.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          // แสดงรูปโปรไฟล์ ถ้ามี URL
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey[300],
            backgroundImage: (_profileImage?.isNotEmpty ?? false)
                ? NetworkImage(_profileImage!)
                : const AssetImage('assets/images/profile.jpg')
                    as ImageProvider,
            child: (_profileImage?.isEmpty ?? true)
                ? const Icon(Icons.person, color: Colors.white, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          // ชื่อผู้ใช้
          Expanded(
            child: Text(
              'สวัสดี ${_username ?? ''}',
              style: const TextStyle(
                fontSize: 17.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // ปุ่ม Logout
          IconButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear(); // ล้าง session
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            icon: const Icon(Icons.logout),
            color: Colors.grey[700],
          ),
        ],
      ),
    );
  }

  // แสดงวัตถุดิบแบบ GridView
  Widget _buildGrid() {
    return FutureBuilder<List<Ingredient>>(
      future: _futureIngredients,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || _filteredIngredients.isEmpty) {
          return const Center(child: Text('ไม่พบวัตถุดิบ'));
        }

        return GridView.builder(
          itemCount: _filteredIngredients.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) {
            return IngredientCard(ingredient: _filteredIngredients[index]);
          },
        );
      },
    );
  }
}
