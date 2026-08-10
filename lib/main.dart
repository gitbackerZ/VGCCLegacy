import 'package:flutter/material.dart';
import 'screens/damage_calculator.dart';
import 'screens/team_builder.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VGC M-B Companion',
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VGC M-B Companion')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              button: true,
              label: 'Open Damage Calculator',
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DamageCalculatorScreen()),
                ),
                child: const Text('Damage Calculator'),
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              button: true,
              label: 'Open Team Builder',
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TeamBuilderScreen()),
                ),
                child: const Text('Team Builder'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}