import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DailyReportsScreen extends StatefulWidget {
  const DailyReportsScreen({super.key});

  @override
  State<DailyReportsScreen> createState() => _DailyReportsScreenState();
}

class _DailyReportsScreenState extends State<DailyReportsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime selectedDate = DateTime.now();
  String? selectedVehicleId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Daily Reports',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date and Vehicle Filter
            Card(
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

                        if (vehicles.isEmpty) {
                          return const Text(
                            'No vehicles available',
                            style: TextStyle(color: Colors.red),
                          );
                        }

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

            const SizedBox(height: 24),

            // Sales Summary
            _buildSummaryCard(
              title: 'Sales Summary',
              icon: Icons.trending_up,
              color: Colors.green,
              child: FutureBuilder<Map<String, dynamic>>(
                future: _getSalesSummary(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data!;
                  return Column(
                    children: [
                      _buildSummaryItem(
                        'Net Sales Value',
                        'Rs. ${data['totalSales'].toStringAsFixed(2)}',
                        Colors.green,
                      ),
                      _buildSummaryItem(
                        'Total Items Sold',
                        '${data['totalItemsSold']}',
                        Colors.blue,
                      ),
                      _buildSummaryItem(
                        'Total Returns',
                        '${data['totalReturns']}',
                        Colors.orange,
                      ),
                      _buildSummaryItem(
                        'Total Damaged',
                        '${data['totalDamaged']}',
                        Colors.red,
                      ),
                      _buildSummaryItem(
                        'Total Discounts',
                        'Rs. ${data['totalDiscounts'].toStringAsFixed(2)}',
                        Colors.deepOrange,
                      ),
                      _buildSummaryItem(
                        'Free Issues Given',
                        '${data['totalFreeIssues']}',
                        Colors.purple,
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Expenses Summary
            _buildSummaryCard(
              title: 'Expenses Summary',
              icon: Icons.money_off,
              color: Colors.red,
              child: FutureBuilder<Map<String, dynamic>>(
                future: _getExpensesSummary(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data!;
                  return Column(
                    children: [
                      _buildSummaryItem(
                        'Total Expenses',
                        'Rs. ${data['totalExpenses'].toStringAsFixed(2)}',
                        Colors.red,
                      ),
                      _buildSummaryItem(
                        'Fuel Expenses',
                        'Rs. ${data['fuelExpenses'].toStringAsFixed(2)}',
                        Colors.orange,
                      ),
                      _buildSummaryItem(
                        'Salary Expenses',
                        'Rs. ${data['salaryExpenses'].toStringAsFixed(2)}',
                        Colors.deepOrange,
                      ),
                      _buildSummaryItem(
                        'Other Expenses',
                        'Rs. ${data['otherExpenses'].toStringAsFixed(2)}',
                        Colors.grey,
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Payments Summary
            _buildSummaryCard(
              title: 'Payments Summary',
              icon: Icons.payment,
              color: Colors.teal,
              child: FutureBuilder<Map<String, dynamic>>(
                future: _getPaymentsSummary(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data!;
                  return Column(
                    children: [
                      _buildSummaryItem(
                        'Total Payments',
                        'Rs. ${data['totalPayments'].toStringAsFixed(2)}',
                        Colors.teal,
                      ),
                      _buildSummaryItem(
                        'Cash',
                        'Rs. ${data['cash'].toStringAsFixed(2)}',
                        Colors.green,
                      ),
                      _buildSummaryItem(
                        'Credits',
                        'Rs. ${data['credits'].toStringAsFixed(2)}',
                        Colors.orange,
                      ),
                      _buildSummaryItem(
                        'Credits Received',
                        'Rs. ${data['creditsReceived'].toStringAsFixed(2)}',
                        Colors.blue,
                      ),
                      _buildSummaryItem(
                        'Cheques',
                        'Rs. ${data['cheques'].toStringAsFixed(2)}',
                        Colors.purple,
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Net Summary
            _buildSummaryCard(
              title: 'Net Summary',
              icon: Icons.account_balance,
              color: Colors.indigo,
              child: FutureBuilder<Map<String, dynamic>>(
                future: _getNetSummary(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data!;
                  final netProfit = data['netProfit'];
                  return Column(
                    children: [
                      _buildSummaryItem(
                        'Total Revenue',
                        'Rs. ${data['totalRevenue'].toStringAsFixed(2)}',
                        Colors.green,
                      ),
                      _buildSummaryItem(
                        'Total Expenses',
                        'Rs. ${data['totalExpenses'].toStringAsFixed(2)}',
                        Colors.red,
                      ),
                      const Divider(thickness: 2),
                      _buildSummaryItem(
                        'Net Profit/Loss',
                        'Rs. ${netProfit.toStringAsFixed(2)}',
                        netProfit >= 0 ? Colors.green : Colors.red,
                        isLarge: true,
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    Color color, {
    bool isLarge = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isLarge ? 16 : 14,
              fontWeight: isLarge ? FontWeight.bold : FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isLarge ? 18 : 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _getSalesSummary() async {
    // Get date range for the selected day
    final startOfDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    var query = _firestore
        .collection('unloading')
        .where(
          'unloadedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('unloadedAt', isLessThan: Timestamp.fromDate(endOfDay));

    if (selectedVehicleId != null) {
      query = query.where('vehicleId', isEqualTo: selectedVehicleId);
    }

    final snapshot = await query.get();

    double totalSales = 0;
    int totalItemsSold = 0;
    double totalDiscounts = 0;
    int totalFreeIssues = 0;
    int totalReturns = 0;
    int totalDamaged = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();

      // Use netValue if available (enhanced unloading), otherwise use totalValue
      final salesValue = (data['netValue'] ?? data['totalValue'] ?? 0.0) as num;
      totalSales += salesValue.toDouble();

      totalItemsSold += ((data['totalQuantity'] ?? 0) as num).toInt();
      totalDiscounts += ((data['totalDiscounts'] ?? 0.0) as num).toDouble();
      totalFreeIssues += ((data['totalFreeIssues'] ?? 0) as num).toInt();
      totalReturns += ((data['totalReturns'] ?? 0) as num).toInt();
      totalDamaged += ((data['totalDamaged'] ?? 0) as num).toInt();
    }

    return {
      'totalSales': totalSales,
      'totalItemsSold': totalItemsSold,
      'totalDiscounts': totalDiscounts,
      'totalFreeIssues': totalFreeIssues,
      'totalReturns': totalReturns,
      'totalDamaged': totalDamaged,
    };
  }

  Future<Map<String, dynamic>> _getExpensesSummary() async {
    final startOfDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    double totalExpenses = 0;
    double fuelExpenses = 0;
    double salaryExpenses = 0;
    double otherExpenses = 0;

    // Get expenses from unloading collection (new structure)
    var unloadingQuery = _firestore
        .collection('unloading')
        .where('unloadedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('unloadedAt', isLessThan: Timestamp.fromDate(endOfDay));

    if (selectedVehicleId != null) {
      unloadingQuery = unloadingQuery.where('vehicleId', isEqualTo: selectedVehicleId);
    }

    final unloadingSnapshot = await unloadingQuery.get();

    for (var doc in unloadingSnapshot.docs) {
      final data = doc.data();
      final expenses = data['expenses'] as List<dynamic>?;

      if (expenses != null) {
        for (var expense in expenses) {
          final expenseMap = expense as Map<String, dynamic>;
          final amount = (expenseMap['amount'] ?? 0.0) as num;
          final type = expenseMap['type'] ?? '';

          totalExpenses += amount.toDouble();

          if (type == 'fuel') {
            fuelExpenses += amount.toDouble();
          } else if (type == 'salary') {
            salaryExpenses += amount.toDouble();
          } else {
            otherExpenses += amount.toDouble();
          }
        }
      }

      // Also add totalExpenses field if available
      final totalExp = (data['totalExpenses'] ?? 0.0) as num;
      if (totalExp > 0 && (expenses == null || expenses.isEmpty)) {
        totalExpenses += totalExp.toDouble();
        otherExpenses += totalExp.toDouble();
      }
    }

    // Also check old expenses collection for backward compatibility
    var expensesQuery = _firestore
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay));

    if (selectedVehicleId != null) {
      expensesQuery = expensesQuery.where('vehicleId', isEqualTo: selectedVehicleId);
    }

    final expensesSnapshot = await expensesQuery.get();

    for (var doc in expensesSnapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] ?? 0.0) as num;
      final type = data['expenseType'] ?? '';

      totalExpenses += amount.toDouble();

      if (type == 'fuel') {
        fuelExpenses += amount.toDouble();
      } else if (type == 'salary') {
        salaryExpenses += amount.toDouble();
      } else {
        otherExpenses += amount.toDouble();
      }
    }

    return {
      'totalExpenses': totalExpenses,
      'fuelExpenses': fuelExpenses,
      'salaryExpenses': salaryExpenses,
      'otherExpenses': otherExpenses,
    };
  }

  Future<Map<String, dynamic>> _getPaymentsSummary() async {
    final startOfDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Get payments from unloading collection (new structure)
    var unloadingQuery = _firestore
        .collection('unloading')
        .where('unloadedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('unloadedAt', isLessThan: Timestamp.fromDate(endOfDay));

    if (selectedVehicleId != null) {
      unloadingQuery = unloadingQuery.where('vehicleId', isEqualTo: selectedVehicleId);
    }

    final unloadingSnapshot = await unloadingQuery.get();

    double totalPayments = 0;
    double cash = 0;
    double credits = 0;
    double creditsReceived = 0;
    double cheques = 0;

    // Get payments from unloading records (new enhanced structure)
    for (var doc in unloadingSnapshot.docs) {
      final data = doc.data();
      final payments = data['payments'] as Map<String, dynamic>?;

      if (payments != null) {
        final cashAmount = (payments['cash'] ?? 0.0) as num;
        final creditAmount = (payments['credit'] ?? 0.0) as num;
        final creditReceivedAmount = (payments['creditReceived'] ?? 0.0) as num;
        final chequeAmount = (payments['cheque'] ?? 0.0) as num;

        cash += cashAmount.toDouble();
        credits += creditAmount.toDouble();
        creditsReceived += creditReceivedAmount.toDouble();
        cheques += chequeAmount.toDouble();
        totalPayments += cashAmount.toDouble() + creditReceivedAmount.toDouble() + chequeAmount.toDouble();
      }
    }

    // Also check old payments collection for backward compatibility
    var paymentsQuery = _firestore
        .collection('payments')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay));

    if (selectedVehicleId != null) {
      paymentsQuery = paymentsQuery.where('vehicleId', isEqualTo: selectedVehicleId);
    }

    final paymentsSnapshot = await paymentsQuery.get();

    for (var doc in paymentsSnapshot.docs) {
      final data = doc.data();

      // New structure from enhanced unloading
      if (data.containsKey('cash')) {
        final cashAmount = (data['cash'] ?? 0.0) as num;
        final creditAmount = (data['credit'] ?? 0.0) as num;
        final creditReceivedAmount = (data['creditReceived'] ?? 0.0) as num;
        final chequeAmount = (data['cheque'] ?? 0.0) as num;

        cash += cashAmount.toDouble();
        credits += creditAmount.toDouble();
        creditsReceived += creditReceivedAmount.toDouble();
        cheques += chequeAmount.toDouble();
        totalPayments += cashAmount.toDouble() + creditReceivedAmount.toDouble() + chequeAmount.toDouble();
      } else {
        // Old structure (if any)
        final amount = (data['amount'] ?? 0.0) as num;
        final type = data['paymentType'] ?? '';

        totalPayments += amount.toDouble();

        if (type == 'cash') {
          cash += amount.toDouble();
        } else if (type == 'credit') {
          credits += amount.toDouble();
        } else if (type == 'credit_received') {
          creditsReceived += amount.toDouble();
        } else if (type == 'cheque') {
          cheques += amount.toDouble();
        }
      }
    }

    return {
      'totalPayments': totalPayments,
      'cash': cash,
      'credits': credits,
      'creditsReceived': creditsReceived,
      'cheques': cheques,
    };
  }

  Future<Map<String, dynamic>> _getNetSummary() async {
    final sales = await _getSalesSummary();
    final expenses = await _getExpensesSummary();

    final totalRevenue = sales['totalSales'];
    final totalExpenses = expenses['totalExpenses'];
    final netProfit = totalRevenue - totalExpenses;

    return {
      'totalRevenue': totalRevenue,
      'totalExpenses': totalExpenses,
      'netProfit': netProfit,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
