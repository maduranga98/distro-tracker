import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NTBBankPaymentsScreen extends StatefulWidget {
  const NTBBankPaymentsScreen({super.key});

  @override
  State<NTBBankPaymentsScreen> createState() => _NTBBankPaymentsScreenState();
}

class _NTBBankPaymentsScreenState extends State<NTBBankPaymentsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedDistributionId;
  Map<String, dynamic>? _selectedDistributionConfig;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NTB Bank Payments'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          _buildDistributionSelector(),
          Expanded(
            child: _selectedDistributionId == null
                ? const Center(
                    child: Text(
                      'Please select a distribution to continue',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : _buildPaymentsView(),
          ),
        ],
      ),
      floatingActionButton: _selectedDistributionId != null
          ? FloatingActionButton(
              onPressed: () => _showAddPaymentDialog(),
              backgroundColor: Colors.deepPurple,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildDistributionSelector() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Distribution / Bank Account',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => _showConfigDialog(),
                  icon: const Icon(Icons.settings),
                  label: const Text('Configure'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('ntb_distributions')
                  .where('active', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final distributions = snapshot.data!.docs;

                if (distributions.isEmpty) {
                  return Column(
                    children: [
                      const Text(
                        'No distributions configured. Click "Configure" to add.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showConfigDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Distribution'),
                      ),
                    ],
                  );
                }

                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select Distribution',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedDistributionId,
                  items: distributions.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            data['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Bank Account: ${data['bankAccount'] ?? 'N/A'}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDistributionId = value;
                      if (value != null) {
                        _selectedDistributionConfig = distributions
                            .firstWhere((doc) => doc.id == value)
                            .data() as Map<String, dynamic>;
                      }
                    });
                  },
                );
              },
            ),
            if (_selectedDistributionConfig != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Bank Name',
                        _selectedDistributionConfig!['bankName'] ?? 'NTB Bank'),
                    _buildInfoRow('Account Number',
                        _selectedDistributionConfig!['bankAccount'] ?? ''),
                    _buildInfoRow('Credit Period',
                        '${_selectedDistributionConfig!['creditPeriod'] ?? 15} days'),
                    _buildInfoRow('Interest Rate',
                        '${_selectedDistributionConfig!['interestRate'] ?? 0.5}%'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildPaymentsView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('ntb_payments')
          .where('distributionId', isEqualTo: _selectedDistributionId)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No payments recorded yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Click the + button to add a payment',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return _buildPaymentsTable(snapshot.data!.docs);
      },
    );
  }

  Widget _buildPaymentsTable(List<QueryDocumentSnapshot> payments) {
    // Calculate cumulative credit
    double cumulativeCredit = 0;
    List<Map<String, dynamic>> paymentsWithCumulative = [];

    for (var payment in payments.reversed) {
      final data = payment.data() as Map<String, dynamic>;
      final creditValue = (data['creditValue'] ?? 0).toDouble();
      final totalDeposits = _calculateTotalDeposits(data);

      cumulativeCredit += creditValue - totalDeposits;

      paymentsWithCumulative.add({
        'id': payment.id,
        'data': data,
        'cumulative': cumulativeCredit,
      });
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.deepPurple.shade50),
            columns: const [
              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Cash (Rs.)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Cheque No.', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Cheque (Rs.)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Credit (Rs.)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Balance (Rs.)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: paymentsWithCumulative.reversed.map((item) {
              final data = item['data'] as Map<String, dynamic>;
              final cumulative = item['cumulative'] as double;
              final paymentId = item['id'] as String;

              final date = (data['date'] as Timestamp).toDate();
              final cashEntries = data['cashEntries'] as List<dynamic>? ?? [];
              final chequeEntries = data['chequeEntries'] as List<dynamic>? ?? [];
              final creditValue = (data['creditValue'] ?? 0).toDouble();

              // Create rows for each entry
              final maxEntries = cashEntries.length > chequeEntries.length
                  ? cashEntries.length
                  : chequeEntries.length;

              if (maxEntries == 0) {
                // Single row if no entries
                return DataRow(
                  cells: [
                    DataCell(Text(DateFormat('yyyy-MM-dd').format(date))),
                    const DataCell(Text('-')),
                    const DataCell(Text('-')),
                    const DataCell(Text('-')),
                    DataCell(Text(
                      creditValue.toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )),
                    DataCell(
                      Text(
                        cumulative.toStringAsFixed(2),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cumulative > 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showEditPaymentDialog(paymentId, data),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                            onPressed: () => _deletePayment(paymentId),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              // Return first row (we'll handle multiple entries differently)
              return DataRow(
                cells: [
                  DataCell(Text(DateFormat('yyyy-MM-dd').format(date))),
                  DataCell(Text(cashEntries.isNotEmpty
                      ? (cashEntries[0]['amount'] ?? 0).toStringAsFixed(2)
                      : '-')),
                  DataCell(Text(chequeEntries.isNotEmpty
                      ? (chequeEntries[0]['chequeNumber'] ?? '-')
                      : '-')),
                  DataCell(Text(chequeEntries.isNotEmpty
                      ? (chequeEntries[0]['amount'] ?? 0).toStringAsFixed(2)
                      : '-')),
                  DataCell(Text(
                    creditValue.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )),
                  DataCell(
                    Text(
                      cumulative.toStringAsFixed(2),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cumulative > 0 ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showEditPaymentDialog(paymentId, data),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () => _deletePayment(paymentId),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  double _calculateTotalDeposits(Map<String, dynamic> data) {
    double total = 0;
    final cashEntries = data['cashEntries'] as List<dynamic>? ?? [];
    final chequeEntries = data['chequeEntries'] as List<dynamic>? ?? [];

    for (var entry in cashEntries) {
      total += (entry['amount'] ?? 0).toDouble();
    }
    for (var entry in chequeEntries) {
      total += (entry['amount'] ?? 0).toDouble();
    }

    return total;
  }

  void _showConfigDialog([String? editId, Map<String, dynamic>? existingData]) {
    final nameController = TextEditingController(text: existingData?['name']);
    final bankNameController = TextEditingController(text: existingData?['bankName'] ?? 'NTB Bank');
    final accountController = TextEditingController(text: existingData?['bankAccount']);
    final creditPeriodController = TextEditingController(
        text: (existingData?['creditPeriod'] ?? 15).toString());
    final interestRateController = TextEditingController(
        text: (existingData?['interestRate'] ?? 0.5).toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(editId == null ? 'Add Distribution' : 'Edit Distribution'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Distribution Name *',
                  hintText: 'e.g., Couple 1, Couple 2',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bankNameController,
                decoration: const InputDecoration(
                  labelText: 'Bank Name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accountController,
                decoration: const InputDecoration(
                  labelText: 'Bank Account Number *',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: creditPeriodController,
                decoration: const InputDecoration(
                  labelText: 'Credit Period (days)',
                  hintText: '15',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: interestRateController,
                decoration: const InputDecoration(
                  labelText: 'Interest Rate (%)',
                  hintText: '0.5 or 1',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  accountController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all required fields'),
                  ),
                );
                return;
              }

              final data = {
                'name': nameController.text,
                'bankName': bankNameController.text,
                'bankAccount': accountController.text,
                'creditPeriod': int.tryParse(creditPeriodController.text) ?? 15,
                'interestRate':
                    double.tryParse(interestRateController.text) ?? 0.5,
                'active': true,
                'updatedAt': FieldValue.serverTimestamp(),
              };

              try {
                if (editId == null) {
                  data['createdAt'] = FieldValue.serverTimestamp();
                  await _firestore.collection('ntb_distributions').add(data);
                } else {
                  await _firestore
                      .collection('ntb_distributions')
                      .doc(editId)
                      .update(data);
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(editId == null
                          ? 'Distribution added successfully'
                          : 'Distribution updated successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text(editId == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  void _showAddPaymentDialog([String? editId, Map<String, dynamic>? existingData]) {
    final dateController = TextEditingController(
      text: existingData != null
          ? DateFormat('yyyy-MM-dd')
              .format((existingData['date'] as Timestamp).toDate())
          : DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    final creditValueController = TextEditingController(
      text: existingData?['creditValue']?.toString() ?? '',
    );

    List<Map<String, TextEditingController>> cashEntries = [];
    List<Map<String, TextEditingController>> chequeEntries = [];

    // Load existing entries if editing
    if (existingData != null) {
      final existingCash = existingData['cashEntries'] as List<dynamic>? ?? [];
      final existingCheques =
          existingData['chequeEntries'] as List<dynamic>? ?? [];

      for (var entry in existingCash) {
        cashEntries.add({
          'amount': TextEditingController(text: entry['amount'].toString()),
        });
      }

      for (var entry in existingCheques) {
        chequeEntries.add({
          'number': TextEditingController(text: entry['chequeNumber']),
          'amount': TextEditingController(text: entry['amount'].toString()),
        });
      }
    }

    // Add one default entry if none exist
    if (cashEntries.isEmpty) {
      cashEntries.add({'amount': TextEditingController()});
    }
    if (chequeEntries.isEmpty) {
      chequeEntries.add({
        'number': TextEditingController(),
        'amount': TextEditingController(),
      });
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(editId == null ? 'Add Payment' : 'Edit Payment'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: 'Date *',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        dateController.text =
                            DateFormat('yyyy-MM-dd').format(date);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: creditValueController,
                    decoration: const InputDecoration(
                      labelText: 'Credit Value (Rs.) *',
                      hintText: 'Amount to pay to bank',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Cash Deposits',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ...cashEntries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final controllers = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controllers['amount'],
                              decoration: InputDecoration(
                                labelText: 'Cash Amount ${index + 1} (Rs.)',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () {
                              setDialogState(() {
                                cashEntries.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  ElevatedButton.icon(
                    onPressed: () {
                      setDialogState(() {
                        cashEntries.add({'amount': TextEditingController()});
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Cash Entry'),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Cheque Deposits',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ...chequeEntries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final controllers = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: controllers['number'],
                              decoration: InputDecoration(
                                labelText: 'Cheque No. ${index + 1}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: controllers['amount'],
                              decoration: const InputDecoration(
                                labelText: 'Amount (Rs.)',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () {
                              setDialogState(() {
                                chequeEntries.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  ElevatedButton.icon(
                    onPressed: () {
                      setDialogState(() {
                        chequeEntries.add({
                          'number': TextEditingController(),
                          'amount': TextEditingController(),
                        });
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Cheque Entry'),
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
                if (dateController.text.isEmpty ||
                    creditValueController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill date and credit value'),
                    ),
                  );
                  return;
                }

                // Prepare cash entries
                final List<Map<String, dynamic>> cashEntriesData = [];
                for (var entry in cashEntries) {
                  final amount = double.tryParse(entry['amount']!.text);
                  if (amount != null && amount > 0) {
                    cashEntriesData.add({'amount': amount});
                  }
                }

                // Prepare cheque entries
                final List<Map<String, dynamic>> chequeEntriesData = [];
                for (var entry in chequeEntries) {
                  final amount = double.tryParse(entry['amount']!.text);
                  final number = entry['number']!.text;
                  if (amount != null && amount > 0 && number.isNotEmpty) {
                    chequeEntriesData.add({
                      'chequeNumber': number,
                      'amount': amount,
                    });
                  }
                }

                final data = {
                  'distributionId': _selectedDistributionId,
                  'date': Timestamp.fromDate(
                      DateFormat('yyyy-MM-dd').parse(dateController.text)),
                  'creditValue': double.parse(creditValueController.text),
                  'cashEntries': cashEntriesData,
                  'chequeEntries': chequeEntriesData,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                try {
                  if (editId == null) {
                    data['createdAt'] = FieldValue.serverTimestamp();
                    await _firestore.collection('ntb_payments').add(data);
                  } else {
                    await _firestore
                        .collection('ntb_payments')
                        .doc(editId)
                        .update(data);
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(editId == null
                            ? 'Payment added successfully'
                            : 'Payment updated successfully'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: Text(editId == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPaymentDialog(String paymentId, Map<String, dynamic> data) {
    _showAddPaymentDialog(paymentId, data);
  }

  void _deletePayment(String paymentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment'),
        content: const Text('Are you sure you want to delete this payment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firestore.collection('ntb_payments').doc(paymentId).delete();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
