import 'package:distro_tracker_flutter/loading/add_items.dart';
import 'package:distro_tracker_flutter/loading/add_stock.dart';
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
      appBar: AppBar(title: const Text("Loading")),
      body: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddStock()),
                    ),
                child: Text("Add Stock"),
              ),
              ElevatedButton(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddItems()),
                    ),
                child: Text("Add Items"),
              ),
            ],
          ),
          Expanded(child: LoadingScreen()),
        ],
      ),
    );
  }
}
