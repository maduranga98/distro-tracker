import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'add_invoice.dart';
import 'invoice_details.dart';

class InvoiceList extends StatefulWidget {
  const InvoiceList({Key? key}) : super(key: key);

  @override
  _InvoiceListState createState() => _InvoiceListState();
}

class _InvoiceListState extends State<InvoiceList> {
  String? _selectedDistribution;
  String? _selectedSupplier;
  DateTime? _startDate;
  DateTime? _endDate;

  List<Map<String, dynamic>> _distributions = [];
  List<Map<String, dynamic>> _suppliers = [];

  double _totalInvoiceValue = 0.0;
  double _totalProfit = 0.0;
  int _totalInvoices = 0;

  @override
  void initState() {
    super.initState();
    _loadDistributions();
    _loadSuppliers();
  }

  Future<void> _loadDistributions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('distributions')
          .where('status', isEqualTo: 'active')
          .get();

      setState(() {
        _distributions = snapshot.docs.map((doc) {
          return {'id': doc.id, 'name': doc['name'] ?? ''};
        }).toList();
      });
    } catch (e) {
      print('Error loading distributions: $e');
    }
  }

  Future<void> _loadSuppliers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('items')
          .get();

      Set<String> supplierSet = {};
      for (var doc in snapshot.docs) {
        if (doc['supplier'] != null) {
          supplierSet.add(doc['supplier']);
        }
      }

      setState(() {
        _suppliers = supplierSet.map((s) => {'name': s}).toList();
        _suppliers.sort((a, b) => a['name'].compareTo(b['name']));
      });
    } catch (e) {
      print('Error loading suppliers: $e');
    }
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('invoices')
        .orderBy('invoiceDate', descending: true);

    if (_selectedDistribution != null) {
      query = query.where('distributionId', isEqualTo: _selectedDistribution);
    }

    if (_selectedSupplier != null) {
      query = query.where('supplier', isEqualTo: _selectedSupplier);
    }

    if (_startDate != null) {
      query = query.where(
        'invoiceDate',
        isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!),
      );
    }

    if (_endDate != null) {
      final endOfDay = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        23,
        59,
        59,
      );
      query = query.where(
        'invoiceDate',
        isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
      );
    }

    return query;
  }

  void _calculateTotals(List<QueryDocumentSnapshot> docs) {
    double totalValue = 0.0;
    double totalProfit = 0.0;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalValue += (data['totalValue'] ?? 0).toDouble();
      totalProfit += (data['totalProfit'] ?? 0).toDouble();
    }

    setState(() {
      _totalInvoiceValue = totalValue;
      _totalProfit = totalProfit;
      _totalInvoices = docs.length;
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedDistribution = null;
      _selectedSupplier = null;
      _startDate = null;
      _endDate = null;
    });
  }

  void _deleteInvoice(String invoiceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text(
          'Are you sure you want to delete this invoice? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('invoices')
            .doc(invoiceId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting invoice: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters Summary
          if (_selectedDistribution != null ||
              _selectedSupplier != null ||
              _startDate != null ||
              _endDate != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue.withOpacity(0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Active Filters:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Clear All'),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (_selectedDistribution != null)
                        Chip(
                          label: Text(
                            _distributions.firstWhere(
                              (d) => d['id'] == _selectedDistribution,
                              orElse: () => {'name': 'Unknown'},
                            )['name'],
                          ),
                          onDeleted: () {
                            setState(() {
                              _selectedDistribution = null;
                            });
                          },
                        ),
                      if (_selectedSupplier != null)
                        Chip(
                          label: Text(_selectedSupplier!),
                          onDeleted: () {
                            setState(() {
                              _selectedSupplier = null;
                            });
                          },
                        ),
                      if (_startDate != null && _endDate != null)
                        Chip(
                          label: Text(
                            '${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}',
                          ),
                          onDeleted: () {
                            setState(() {
                              _startDate = null;
                              _endDate = null;
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          // Summary Cards
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Invoices',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            _totalInvoices.toString(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Value',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            'Rs. ${_totalInvoiceValue.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Profit',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            'Rs. ${_totalProfit.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Invoice List
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _buildQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final invoices = snapshot.data?.docs ?? [];

                // Calculate totals only once when data changes
                if (snapshot.hasData) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _calculateTotals(invoices);
                    }
                  });
                }

                if (invoices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No invoices found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add your first invoice',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: invoices.length,
                  itemBuilder: (context, index) {
                    final invoice = invoices[index].data();
                    final invoiceId = invoices[index].id;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  InvoiceDetails(invoiceId: invoiceId),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    invoice['invoiceNumber'] ?? 'N/A',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  PopupMenuButton(
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'view',
                                        child: Row(
                                          children: [
                                            Icon(Icons.visibility, size: 20),
                                            SizedBox(width: 8),
                                            Text('View Details'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete,
                                              size: 20,
                                              color: Colors.red,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onSelected: (value) {
                                      if (value == 'view') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                InvoiceDetails(
                                                  invoiceId: invoiceId,
                                                ),
                                          ),
                                        );
                                      } else if (value == 'delete') {
                                        _deleteInvoice(invoiceId);
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.business,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    invoice['distributionName'] ?? 'N/A',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.local_shipping,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    invoice['supplier'] ?? 'N/A',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(
                                      (invoice['invoiceDate'] as Timestamp)
                                          .toDate(),
                                    ),
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Items: ${(invoice['items'] as List).length}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      Text(
                                        'Qty: ${invoice['totalQuantity']} | FOC: ${invoice['totalFOC']}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Rs. ${(invoice['totalValue'] ?? 0).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      Text(
                                        'Profit: Rs. ${(invoice['totalProfit'] ?? 0).toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              (invoice['totalProfit'] ?? 0) >= 0
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddInvoice()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Filter Invoices'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Distribution',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  DropdownButton<String>(
                    value: _selectedDistribution,
                    isExpanded: true,
                    hint: const Text('All Distributions'),
                    items: _distributions.map((dist) {
                      return DropdownMenuItem<String>(
                        value: dist['id'] as String?,
                        child: Text(dist['name'] as String),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedDistribution = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Supplier',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  DropdownButton<String>(
                    value: _selectedSupplier,
                    isExpanded: true,
                    hint: const Text('All Suppliers'),
                    items: _suppliers.map((supplier) {
                      return DropdownMenuItem<String>(
                        value: supplier['name'] as String?,
                        child: Text(supplier['name'] as String),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedSupplier = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Date Range',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _selectDateRange(context);
                      _showFilterDialog(context);
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _startDate != null && _endDate != null
                          ? '${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}'
                          : 'Select Date Range',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _clearFilters();
                  Navigator.pop(context);
                },
                child: const Text('Clear All'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {});
                  Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }
}
