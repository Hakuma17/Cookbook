import 'package:flutter/material.dart';

class ErrorPage extends StatelessWidget {
  final String message;
  const ErrorPage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เกิดข้อผิดพลาด')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  color: Theme.of(context).colorScheme.error, size: 80),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.home_outlined),
                label: const Text('กลับหน้าหลัก'),
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
