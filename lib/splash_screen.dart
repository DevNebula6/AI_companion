import 'package:flutter/material.dart';

class AppLoadingScreen extends StatelessWidget {
  const AppLoadingScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.grey[100],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}