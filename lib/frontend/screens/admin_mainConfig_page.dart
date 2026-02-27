import 'package:flutter/material.dart';

class AdminMainConfigPage extends StatefulWidget {
  const AdminMainConfigPage({super.key});

  @override
  State<AdminMainConfigPage> createState() => _AdminMainConfigPageState();
}

class _AdminMainConfigPageState extends State<AdminMainConfigPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Main Configuration',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: Container(
        color: Colors.grey[50],
        child: const Center(
          child: Text('Main Configuration'),
        ),
      ),
    );
  }
}
