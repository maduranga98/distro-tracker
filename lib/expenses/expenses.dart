import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Expenses',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('expenses')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final expenses = snapshot.data?.docs ?? [];

          if (expenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.money_off_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No expenses recorded',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first expense entry',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final doc = expenses[index];
              final data = doc.data() as Map<String, dynamic>;
              final expenseType = data['expenseType'] ?? 'Unknown';
              final amount = data['amount'] ?? 0.0;
              final date = data['date'] as Timestamp?;
              final vehicleId = data['vehicleId'] ?? '';
              final description = data['description'] ?? '';

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('vehicles').doc(vehicleId).get(),
                builder: (context, vehicleSnapshot) {
                  final vehicleName = vehicleSnapshot.hasData
                      ? (vehicleSnapshot.data?.data()
                          as Map<String, dynamic>?)?['vehicleName'] ?? 'Unknown'
                      : 'Loading...';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          expenseType == 'fuel'
                              ? Icons.local_gas_station
                              : expenseType == 'salary'
                                  ? Icons.account_balance_wallet
                                  : Icons.money_off,
                          color: Colors.deepOrange,
                        ),
                      ),
                      title: Text(
                        expenseType.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Rs. ${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.red[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            vehicleName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          if (date != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(date.toDate()),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: PopupMenuButton(
                        icon: const Icon(Icons.more_vert),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteExpense(doc.id);
                          }
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        backgroundColor: Colors.deepOrange,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  void _showAddExpenseDialog() {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedVehicleId;
    String selectedExpenseType = 'fuel';
    DateTime selectedDate = DateTime.now();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Expense'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                          'Please add a vehicle first',
                          style: TextStyle(color: Colors.red),
                        );
                      }

                      return DropdownButtonFormField<String>(
                        value: selectedVehicleId,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.local_shipping),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vehicle is required';
                          }
                          return null;
                        },
                        items: vehicles.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text(data['vehicleName'] ?? 'Unknown'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedVehicleId = value;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedExpenseType,
                    decoration: const InputDecoration(
                      labelText: 'Expense Type *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'fuel',
                        child: Text('Fuel'),
                      ),
                      DropdownMenuItem(
                        value: 'salary',
                        child: Text('Salary'),
                      ),
                      DropdownMenuItem(
                        value: 'other',
                        child: Text('Other'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedExpenseType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount *',
                      hintText: '0.00',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.money),
                      prefixText: 'Rs. ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Amount is required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Enter valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Date'),
                    subtitle: Text(_formatDate(selectedDate)),
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Optional notes',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 2,
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
                  await _saveExpense(
                    vehicleId: selectedVehicleId!,
                    expenseType: selectedExpenseType,
                    amount: double.parse(amountController.text),
                    date: selectedDate,
                    description: descriptionController.text.trim(),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveExpense({
    required String vehicleId,
    required String expenseType,
    required double amount,
    required DateTime date,
    required String description,
  }) async {
    try {
      await _firestore.collection('expenses').add({
        'vehicleId': vehicleId,
        'expenseType': expenseType,
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _showSnackBar('Expense added successfully', Colors.green);
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _deleteExpense(String expenseId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('expenses').doc(expenseId).delete();
        _showSnackBar('Expense deleted successfully', Colors.green);
      } catch (e) {
        _showSnackBar('Error: ${e.toString()}', Colors.red);
      }
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
