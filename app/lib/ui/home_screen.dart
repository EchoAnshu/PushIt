import 'package:flutter/material.dart';

import 'solo_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Push-Up Battle')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SoloScreen()),
                );
              },
              child: const Text('Solo Practice'),
            ),
            const SizedBox(height: 16),
            const FilledButton(
              onPressed: null,
              child: Text('LAN Battle (coming soon)'),
            ),
          ],
        ),
      ),
    );
  }
}
