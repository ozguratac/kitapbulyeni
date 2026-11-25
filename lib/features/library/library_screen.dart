import 'package:flutter/material.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kitaplık')),
      body: const Center(child: Text("Aşama 5'te yapılacak")),
    );
  }
}
