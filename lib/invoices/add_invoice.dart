import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AddInvoice extends StatefulWidget {
  const AddInvoice({Key? key}) : super(key: key);

  @override
  _AddInvoiceState createState() => _AddInvoiceState();
}

class _AddInvoiceState extends State<AddInvoice> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _invoiceNumberController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  DateTime _invoiceDate = DateTime.now();
  String? _selectedDistribution;
  String? _selectedSupplier;
  List<Map<String, dynamic>> _distributions = [];
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  List<Map<String, dynamic>> _invoiceItems = [];

  bool _isLoading = false;
  double _totalValue = 0.0;
  double _totalProfit = 0.0;
  int _totalQuantity = 0;
  int _totalFOC = 0;

  @override
  void initState() {
    super.initState();
    _loadDistributions();
    _loadSuppliers();
    _loadItems();
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
      _showError('Error loading distributions: $e');
    }
  }

  Future<void> _loadSuppliers() async {
    // Load unique suppliers from items collection
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
      _showError('Error loading suppliers: $e');
    }
  }

  Future<void> _loadItems() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('items')
          .get();

      setState(() {
        _items = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'productCode': data['productCode'] ?? '',
            'productName': data['productName'] ?? '',
            'brand': data['brand'] ?? '',
            'category': data['category'] ?? '',
            'supplier': data['supplier'] ?? '',
            'unitType': data['unitType'] ?? 'pcs',
            'distributorPrice': (data['distributorPrice'] ?? 0).toDouble(),
            'sellingPrice': (data['sellingPrice'] ?? data['distributorPrice'] ?? 0).toDouble(),
            'mrp': (data['mrp'] ?? 0).toDouble(),
          };
        }).toList();
        _filteredItems = List.from(_items);
      });
    } catch (e) {
      _showError('Error loading items: $e');
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(_items);
      } else {
        _filteredItems = _items.where((item) {
          final searchLower = query.toLowerCase();
          return (item['productName'] as String).toLowerCase().contains(
                searchLower,
              ) ||
              (item['productCode'] as String).toLowerCase().contains(
                searchLower,
              ) ||
              (item['brand'] as String).toLowerCase().contains(searchLower);
        }).toList();
      }
    });
  }

  void _addItemToInvoice(Map<String, dynamic> item) {
    setState(() {
      _invoiceItems.add({
        'itemId': item['id'],
        'productCode': item['productCode'],
        'productName': item['productName'],
        'brand': item['brand'],
        'category': item['category'],
        'unitType': item['unitType'],
        'quantity': 0,
        'focQuantity': 0,
        'purchasePrice': 0.0,
        'sellingPrice': item['sellingPrice'],
        'mrp': item['mrp'],
        'margin': 0.0,
        'marginPercentage': 0.0,
        'lineTotal': 0.0,
        'lineProfit': 0.0,
      });
      _searchController.clear();
      _filteredItems = List.from(_items);
    });
  }

  void _removeItem(int index) {
    setState(() {
      _invoiceItems.removeAt(index);
      _calculateTotals();
    });
  }

  void _updateItemField(int index, String field, dynamic value) {
    setState(() {
      _invoiceItems[index][field] = value;

      // Calculate margin and totals when prices change
      if (field == 'purchasePrice' ||
          field == 'sellingPrice' ||
          field == 'quantity') {
        final purchasePrice = (_invoiceItems[index]['purchasePrice'] ?? 0)
            .toDouble();
        final sellingPrice = (_invoiceItems[index]['sellingPrice'] ?? 0)
            .toDouble();
        final quantity = (_invoiceItems[index]['quantity'] ?? 0).toInt();

        final margin = sellingPrice - purchasePrice;
        final marginPercentage = purchasePrice > 0
            ? (margin / purchasePrice * 100)
            : 0.0;
        final lineTotal = purchasePrice * quantity;
        final lineProfit = margin * quantity;

        _invoiceItems[index]['margin'] = margin;
        _invoiceItems[index]['marginPercentage'] = marginPercentage;
        _invoiceItems[index]['lineTotal'] = lineTotal;
        _invoiceItems[index]['lineProfit'] = lineProfit;
      }

      _calculateTotals();
    });
  }

  void _calculateTotals() {
    double totalValue = 0.0;
    double totalProfit = 0.0;
    int totalQuantity = 0;
    int totalFOC = 0;

    for (var item in _invoiceItems) {
      totalValue += (item['lineTotal'] ?? 0).toDouble();
      totalProfit += (item['lineProfit'] ?? 0).toDouble();
      totalQuantity += ((item['quantity'] ?? 0) as num).toInt();
      totalFOC += ((item['focQuantity'] ?? 0) as num).toInt();
    }

    setState(() {
      _totalValue = totalValue;
      _totalProfit = totalProfit;
      _totalQuantity = totalQuantity;
      _totalFOC = totalFOC;
    });
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDistribution == null) {
      _showError('Please select a distribution');
      return;
    }

    if (_selectedSupplier == null) {
      _showError('Please select a supplier');
      return;
    }

    if (_invoiceItems.isEmpty) {
      _showError('Please add at least one item to the invoice');
      return;
    }

    // Validate that all items have quantity and purchase price
    for (var item in _invoiceItems) {
      if ((item['quantity'] ?? 0) <= 0) {
        _showError('All items must have a quantity greater than 0');
        return;
      }
      if ((item['purchasePrice'] ?? 0) <= 0) {
        _showError('All items must have a purchase price greater than 0');
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Save invoice to Firestore
      final invoiceRef = await FirebaseFirestore.instance
          .collection('invoices')
          .add({
            'invoiceNumber': _invoiceNumberController.text,
            'distributionId': _selectedDistribution,
            'distributionName': _distributions.firstWhere(
              (d) => d['id'] == _selectedDistribution,
            )['name'],
            'supplier': _selectedSupplier,
            'invoiceDate': Timestamp.fromDate(_invoiceDate),
            'items': _invoiceItems,
            'totalQuantity': _totalQuantity,
            'totalFOC': _totalFOC,
            'totalValue': _totalValue,
            'totalProfit': _totalProfit,
            'status': 'received',
            'createdAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      // Update stock for each item in the invoice
      for (var item in _invoiceItems) {
        await _updateStock(item, invoiceRef.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Error saving invoice: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStock(Map<String, dynamic> item, String invoiceId) async {
    try {
      // Add stock entry for this distribution
      await FirebaseFirestore.instance.collection('stock').add({
        'itemId': item['itemId'],
        'productCode': item['productCode'],
        'productName': item['productName'],
        'brand': item['brand'],
        'category': item['category'],
        'distributionId': _selectedDistribution,
        'distributionName': _distributions.firstWhere(
          (d) => d['id'] == _selectedDistribution,
        )['name'],
        'supplier': _selectedSupplier,
        'quantity': item['quantity'],
        'focUnits': item['focQuantity'] ?? 0,
        'purchasePrice': item['purchasePrice'],
        'sellingPrice': item['sellingPrice'],
        'mrp': item['mrp'],
        'margin': item['margin'],
        'marginPercentage': item['marginPercentage'],
        'totalValue': item['lineTotal'],
        'invoiceId': invoiceId,
        'invoiceNumber': _invoiceNumberController.text,
        'status': 'active',
        'addedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating stock: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _invoiceDate) {
      setState(() {
        _invoiceDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Invoice'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Invoice Header Section
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Invoice Details',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _invoiceNumberController,
                                    decoration: const InputDecoration(
                                      labelText: 'Invoice Number',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.receipt),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter invoice number';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                    value: _selectedDistribution,
                                    decoration: const InputDecoration(
                                      labelText: 'Distribution',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.business),
                                    ),
                                    items: _distributions.map((dist) {
                                      return DropdownMenuItem<String>(
                                        value: dist['id'] as String?,
                                        child: Text(dist['name'] as String),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedDistribution = value;
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null) {
                                        return 'Please select a distribution';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                    value: _selectedSupplier,
                                    decoration: const InputDecoration(
                                      labelText: 'Supplier',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.local_shipping),
                                    ),
                                    items: _suppliers.map((supplier) {
                                      return DropdownMenuItem<String>(
                                        value: supplier['name'] as String?,
                                        child: Text(supplier['name'] as String),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedSupplier = value;
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null) {
                                        return 'Please select a supplier';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  InkWell(
                                    onTap: () => _selectDate(context),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Invoice Date',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.calendar_today),
                                      ),
                                      child: Text(
                                        DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(_invoiceDate),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Add Item Section
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Add Items',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _searchController,
                                    decoration: const InputDecoration(
                                      labelText: 'Search Items',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.search),
                                      hintText:
                                          'Search by name, code, or brand',
                                    ),
                                    onChanged: _filterItems,
                                  ),
                                  const SizedBox(height: 8),
                                  if (_searchController.text.isNotEmpty &&
                                      _filteredItems.isNotEmpty)
                                    Container(
                                      constraints: const BoxConstraints(
                                        maxHeight: 200,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: _filteredItems.length,
                                        itemBuilder: (context, index) {
                                          final item = _filteredItems[index];
                                          return ListTile(
                                            title: Text(item['productName']),
                                            subtitle: Text(
                                              '${item['productCode']} - ${item['brand']}',
                                            ),
                                            trailing: Text(
                                              'Rs. ${item['mrp'].toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            onTap: () =>
                                                _addItemToInvoice(item),
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Invoice Items List
                          if (_invoiceItems.isNotEmpty) ...[
                            const Text(
                              'Invoice Items',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _invoiceItems.length,
                              itemBuilder: (context, index) {
                                return _buildInvoiceItem(index);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Summary and Save Button
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Items: ${_invoiceItems.length}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                Text(
                                  'Total Qty: $_totalQuantity | FOC: $_totalFOC',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Total Value: Rs. ${_totalValue.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Total Profit: Rs. ${_totalProfit.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _totalProfit >= 0
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveInvoice,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Save Invoice',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInvoiceItem(int index) {
    final item = _invoiceItems[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['productName'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${item['productCode']} - ${item['brand']}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item['quantity'].toString(),
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _updateItemField(
                        index,
                        'quantity',
                        int.tryParse(value) ?? 0,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: item['focQuantity'].toString(),
                    decoration: const InputDecoration(
                      labelText: 'FOC',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _updateItemField(
                        index,
                        'focQuantity',
                        int.tryParse(value) ?? 0,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item['purchasePrice'].toString(),
                    decoration: const InputDecoration(
                      labelText: 'Purchase Price',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixText: 'Rs. ',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _updateItemField(
                        index,
                        'purchasePrice',
                        double.tryParse(value) ?? 0.0,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: item['sellingPrice'].toString(),
                    decoration: const InputDecoration(
                      labelText: 'Selling Price',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixText: 'Rs. ',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _updateItemField(
                        index,
                        'sellingPrice',
                        double.tryParse(value) ?? 0.0,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item['mrp'].toString(),
                    decoration: const InputDecoration(
                      labelText: 'MRP',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixText: 'Rs. ',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _updateItemField(
                        index,
                        'mrp',
                        double.tryParse(value) ?? 0.0,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: item['marginPercentage'] >= 0
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: item['marginPercentage'] >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Margin',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          '${item['marginPercentage'].toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: item['marginPercentage'] >= 0
                                ? Colors.green[700]
                                : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Line Total: Rs. ${item['lineTotal'].toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Profit: Rs. ${item['lineProfit'].toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: item['lineProfit'] >= 0
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
