import 'package:distro_tracker_flutter/loading/loading.dart';
import 'package:flutter/material.dart';

class Loadingui extends StatefulWidget {
  const Loadingui({super.key});

  @override
  State<Loadingui> createState() => _LoadinguiState();
}

class _LoadinguiState extends State<Loadingui> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Loading",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: LoadingScreen(),
    );
  }
}
