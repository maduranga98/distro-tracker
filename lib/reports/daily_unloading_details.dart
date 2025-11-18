import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DailyUnloadingDetailsScreen extends StatefulWidget {
  const DailyUnloadingDetailsScreen({super.key});

  @override
  State<DailyUnloadingDetailsScreen> createState() =>
      _DailyUnloadingDetailsScreenState();
}

class _DailyUnloadingDetailsScreenState
    extends State<DailyUnloadingDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime selectedDate = DateTime.now();
  String? selectedVehicleId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Daily Unloading Details',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Date and Vehicle Filter
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Select Date'),
                    subtitle: Text(_formatDate(selectedDate)),
                    trailing: const Icon(Icons.arrow_drop_down),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          selectedDate = date;
                        });
                      }
                    },
                  ),
                  const Divider(),
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('vehicles')
                        .where('status', isEqualTo: 'active')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }

                      final vehicles = snapshot.data!.docs;

                      return DropdownButtonFormField<String>(
                        value: selectedVehicleId,
                        decoration: const InputDecoration(
                          labelText: 'Select Vehicle (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.local_shipping),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Vehicles'),
                          ),
                          ...vehicles.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return DropdownMenuItem(
                              value: doc.id,
                              child: Text(data['vehicleName'] ?? 'Unknown'),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedVehicleId = value;
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Unloadings List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getUnloadingsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final unloadings = snapshot.data?.docs ?? [];

                if (unloadings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No unloadings found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select a different date or vehicle',
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: unloadings.length,
                  itemBuilder: (context, index) {
                    final doc = unloadings[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildUnloadingCard(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getUnloadingsStream() {
    final startOfDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    var query = _firestore
        .collection('unloading')
        .where('unloadedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('unloadedAt', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('unloadedAt', descending: true);

    if (selectedVehicleId != null) {
      query = query.where('vehicleId', isEqualTo: selectedVehicleId) as Query<Map<String, dynamic>>;
    }

    return query.snapshots();
  }

  Widget _buildUnloadingCard(String docId, Map<String, dynamic> data) {
    final vehicleId = data['vehicleId'] ?? '';
    final distributionId = data['distributionId'] ?? '';
    final unloadedAt = (data['unloadedAt'] as Timestamp?)?.toDate();
    final netValue = (data['netValue'] ?? data['totalValue'] ?? 0.0) as num;
    final totalQuantity = (data['totalQuantity'] ?? 0) as num;

    return FutureBuilder<Map<String, String>>(
      future: _getVehicleAndDistributionInfo(vehicleId, distributionId),
      builder: (context, infoSnapshot) {
        final vehicleName = infoSnapshot.data?['vehicleName'] ?? 'Loading...';
        final distributionName =
            infoSnapshot.data?['distributionName'] ?? 'Loading...';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.local_shipping,
                color: Colors.indigo,
              ),
            ),
            title: Text(
              vehicleName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  distributionName,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unloadedAt != null
                      ? 'Unloaded: ${_formatDateTime(unloadedAt)}'
                      : 'Time not available',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rs. ${netValue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text(
                  '$totalQuantity units',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDetailsSection(data),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailsSection(Map<String, dynamic> data) {
    final items = data['items'] as List<dynamic>? ?? [];
    final expenses = data['expenses'] as List<dynamic>? ?? [];
    final payments = data['payments'] as Map<String, dynamic>?;
    final morningWeather = data['morningWeather'] ?? 'Not recorded';
    final unloadingWeather = data['unloadingWeather'] ?? 'Not recorded';

    final grossValue = (data['grossValue'] ?? data['totalValue'] ?? 0.0) as num;
    final totalDiscounts = (data['totalDiscounts'] ?? 0.0) as num;
    final netValue = (data['netValue'] ?? grossValue) as num;
    final totalExpenses = (data['totalExpenses'] ?? 0.0) as num;
    final balance = (data['balance'] ?? 0.0) as num;

    final totalReturns = (data['totalReturns'] ?? 0) as num;
    final totalDamaged = (data['totalDamaged'] ?? 0) as num;
    final totalFreeIssues = (data['totalFreeIssues'] ?? 0) as num;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Weather Info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.wb_sunny, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text(
                    'Weather Conditions',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Morning: $morningWeather',
                  style: const TextStyle(fontSize: 12)),
              Text('Unloading: $unloadingWeather',
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Items Section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  const Text(
                    'Items',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const Divider(height: 16),
              ...items.map((item) {
                final itemMap = item as Map<String, dynamic>;
                final productName = itemMap['productName'] ?? 'Unknown';
                final loadingQty = (itemMap['loadingQuantity'] ?? 0) as num;
                final returns = (itemMap['returns'] ?? 0) as num;
                final damaged = (itemMap['damaged'] ?? 0) as num;
                final actualSold = (itemMap['actualSold'] ?? loadingQty) as num;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Loaded: $loadingQty | Sold: $actualSold | Returns: $returns | Damaged: $damaged',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Returns:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('$totalReturns units',
                      style: const TextStyle(fontSize: 12, color: Colors.orange)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Damaged:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('$totalDamaged units',
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Free Issues:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('$totalFreeIssues units',
                      style: const TextStyle(fontSize: 12, color: Colors.purple)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Payments Section
        if (payments != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.payment, size: 16, color: Colors.teal),
                    const SizedBox(width: 8),
                    const Text(
                      'Payments',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const Divider(height: 16),
                _buildPaymentRow(
                    'Cash Received', payments['cash'] ?? 0.0, Colors.green),
                _buildPaymentRow(
                    'Cheque Received', payments['cheque'] ?? 0.0, Colors.purple),
                _buildPaymentRow('Old Credit Received',
                    payments['creditReceived'] ?? 0.0, Colors.blue),
                _buildPaymentRow('New Credit Given', payments['credit'] ?? 0.0,
                    Colors.orange),
                if (payments['chequeNumber'] != null &&
                    payments['chequeNumber'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Cheque #: ${payments['chequeNumber']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Expenses Section
        if (expenses.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.money_off, size: 16, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    const Text(
                      'Trip Expenses',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const Divider(height: 16),
                ...expenses.map((expense) {
                  final expenseMap = expense as Map<String, dynamic>;
                  final type = expenseMap['type'] ?? 'Unknown';
                  final amount = (expenseMap['amount'] ?? 0.0) as num;
                  final description = expenseMap['description'] ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                type.toString().toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (description.isNotEmpty)
                                Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          'Rs. ${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Expenses:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('Rs. ${totalExpenses.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Financial Summary
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.indigo[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calculate, size: 16, color: Colors.indigo),
                  const SizedBox(width: 8),
                  const Text(
                    'Financial Summary',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const Divider(height: 16),
              _buildSummaryRow('Gross Sales', 'Rs. ${grossValue.toStringAsFixed(2)}'),
              _buildSummaryRow('Discounts', '- Rs. ${totalDiscounts.toStringAsFixed(2)}'),
              _buildSummaryRow('Net Sales', 'Rs. ${netValue.toStringAsFixed(2)}',
                  isBold: true),
              const Divider(height: 16),
              _buildSummaryRow('Trip Expenses', 'Rs. ${totalExpenses.toStringAsFixed(2)}'),
              const Divider(height: 16),
              _buildSummaryRow(
                'Balance',
                'Rs. ${balance.toStringAsFixed(2)}',
                isBold: true,
                color: balance >= 0 ? Colors.green : Colors.red,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentRow(String label, dynamic value, Color color) {
    final amount = (value ?? 0.0) as num;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            'Rs. ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {bool isBold = false, Color? color}) {
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
              color: color,
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
      final results = await Future.wait([
        _firestore.collection('vehicles').doc(vehicleId).get(),
        _firestore.collection('distributions').doc(distributionId).get(),
      ]);

      final vehicleDoc = results[0];
      final distributionDoc = results[1];

      return {
        'vehicleName': vehicleDoc.exists
            ? (vehicleDoc.data()?['vehicleName'] ?? 'Unknown Vehicle')
            : 'Unknown Vehicle',
        'distributionName': distributionDoc.exists
            ? (distributionDoc.data()?['name'] ?? 'Unknown Distribution')
            : 'Unknown Distribution',
      };
    } catch (e) {
      return {
        'vehicleName': 'Error loading vehicle',
        'distributionName': 'Error loading distribution'
      };
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }
}
