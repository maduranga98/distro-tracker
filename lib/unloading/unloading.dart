import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UnloadingScreen extends StatefulWidget {
  const UnloadingScreen({super.key});

  @override
  State<UnloadingScreen> createState() => _UnloadingScreenState();
}

class _UnloadingScreenState extends State<UnloadingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Unloading',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('loading')
            .where('status', isEqualTo: 'loaded')
            .orderBy('loadedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final loadings = snapshot.data?.docs ?? [];

          if (loadings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.download_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No loaded items',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Load items first to proceed with unloading',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: loadings.length,
            itemBuilder: (context, index) {
              final doc = loadings[index];
              final data = doc.data() as Map<String, dynamic>;
              final vehicleId = data['vehicleId'] ?? '';
              final distributionId = data['distributionId'] ?? '';
              final loadingDate = data['loadingDate'] as Timestamp?;
              final totalItems = data['totalItems'] ?? 0;
              final totalQuantity = data['totalQuantity'] ?? 0;
              final totalValue = data['totalValue'] ?? 0.0;

              return FutureBuilder<Map<String, String>>(
                future: _getVehicleAndDistributionInfo(vehicleId, distributionId),
                builder: (context, infoSnapshot) {
                  final vehicleName =
                      infoSnapshot.data?['vehicleName'] ?? 'Loading...';
                  final distributionName =
                      infoSnapshot.data?['distributionName'] ?? 'Loading...';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () => _showUnloadingDialog(doc.id, data),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.local_shipping,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vehicleName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        distributionName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 16),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildInfoChip(
                                  Icons.inventory_2,
                                  '$totalItems items',
                                ),
                                _buildInfoChip(
                                  Icons.numbers,
                                  '$totalQuantity qty',
                                ),
                                _buildInfoChip(
                                  Icons.attach_money,
                                  'Rs. ${totalValue.toStringAsFixed(2)}',
                                ),
                              ],
                            ),
                            if (loadingDate != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Loaded: ${_formatDate(loadingDate.toDate())}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>> _getVehicleAndDistributionInfo(
    String vehicleId,
    String distributionId,
  ) async {
    try {
      final vehicleDoc = await _firestore.collection('vehicles').doc(vehicleId).get();
      final distributionDoc =
          await _firestore.collection('distributions').doc(distributionId).get();

      return {
        'vehicleName':
            (vehicleDoc.data()?['vehicleName'] ?? 'Unknown') as String,
        'distributionName':
            (distributionDoc.data()?['name'] ?? 'Unknown') as String,
      };
    } catch (e) {
      return {'vehicleName': 'Unknown', 'distributionName': 'Unknown'};
    }
  }

  void _showUnloadingDialog(String loadingDocId, Map<String, dynamic> loadingData) {
    final items = loadingData['items'] as List<dynamic>? ?? [];
    final discountController = TextEditingController();
    final freeIssuesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Calculate totals
    int totalLoadedQty = 0;
    int totalFreeIssues = 0;
    double totalValue = 0.0;

    for (var item in items) {
      final itemMap = item as Map<String, dynamic>;
      totalLoadedQty += (itemMap['loadingQuantity'] as int?) ?? 0;
      totalFreeIssues += (itemMap['freeIssues'] as int?) ?? 0;
      final qty = (itemMap['loadingQuantity'] as int?) ?? 0;
      final price = (itemMap['distributorPrice'] as num?)?.toDouble() ?? 0.0;
      totalValue += qty * price;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Unloading'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Summary Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Loading Summary',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Divider(height: 16),
                      _buildSummaryRow('Total Items:', '${items.length}'),
                      _buildSummaryRow('Total Quantity:', '$totalLoadedQty'),
                      _buildSummaryRow('Free Issues Loaded:', '$totalFreeIssues'),
                      _buildSummaryRow(
                        'Total Value:',
                        'Rs. ${totalValue.toStringAsFixed(2)}',
                        isBold: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Items List
                const Text(
                  'Items:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...items.map((item) {
                  final itemMap = item as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  itemMap['productName'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${itemMap['loadingQuantity']} units',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if ((itemMap['freeIssues'] ?? 0) > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Free: ${itemMap['freeIssues']}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Manual Entries
                const Text(
                  'Enter Additional Details:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: discountController,
                  decoration: const InputDecoration(
                    labelText: 'Total Discounts Given',
                    hintText: '0.00',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.discount),
                    prefixText: 'Rs. ',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (double.tryParse(value) == null) {
                        return 'Enter valid amount';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: freeIssuesController,
                  decoration: const InputDecoration(
                    labelText: 'Additional Free Issues Given',
                    hintText: '0',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.card_giftcard),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (int.tryParse(value) == null) {
                        return 'Enter valid number';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Final Calculation
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sales Calculation',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Divider(height: 16),
                      _buildSummaryRow('Items Sold:', '$totalLoadedQty units'),
                      _buildSummaryRow(
                        'Free Issues:',
                        '$totalFreeIssues (from loading)',
                      ),
                      _buildSummaryRow(
                        'Sales Value:',
                        'Rs. ${totalValue.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Note: Discounts and additional free issues will be recorded separately.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final discounts = double.tryParse(discountController.text) ?? 0.0;
                final additionalFreeIssues =
                    int.tryParse(freeIssuesController.text) ?? 0;

                await _saveUnloading(
                  loadingDocId: loadingDocId,
                  loadingData: loadingData,
                  discounts: discounts,
                  additionalFreeIssues: additionalFreeIssues,
                );

                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete Unloading'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveUnloading({
    required String loadingDocId,
    required Map<String, dynamic> loadingData,
    required double discounts,
    required int additionalFreeIssues,
  }) async {
    try {
      final items = loadingData['items'] as List<dynamic>;
      int totalSoldQty = 0;
      int totalFreeIssuesFromLoading = 0;

      for (var item in items) {
        final itemMap = item as Map<String, dynamic>;
        totalSoldQty += (itemMap['loadingQuantity'] as int?) ?? 0;
        totalFreeIssuesFromLoading += (itemMap['freeIssues'] as int?) ?? 0;
      }

      final unloadingData = {
        'loadingDocId': loadingDocId,
        'vehicleId': loadingData['vehicleId'],
        'distributionId': loadingData['distributionId'],
        'loadingDate': loadingData['loadingDate'],
        'unloadingDate': Timestamp.now(),
        'items': items,
        'totalItems': loadingData['totalItems'],
        'totalQuantity': totalSoldQty,
        'totalFreeIssues': totalFreeIssuesFromLoading + additionalFreeIssues,
        'freeIssuesFromLoading': totalFreeIssuesFromLoading,
        'additionalFreeIssues': additionalFreeIssues,
        'totalValue': loadingData['totalValue'],
        'totalDiscounts': discounts,
        'netValue': (loadingData['totalValue'] as num).toDouble() - discounts,
        'unloadedAt': FieldValue.serverTimestamp(),
        'status': 'completed',
      };

      await _firestore.collection('unloading').add(unloadingData);

      // Update loading status to completed
      await _firestore
          .collection('loading')
          .doc(loadingDocId)
          .update({'status': 'completed'});

      // Return stock to inventory for remaining items (if any)
      // In this case, all items are sold, so no need to return stock

      _showSnackBar('Unloading completed successfully', Colors.green);
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
