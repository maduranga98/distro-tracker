import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AddInvoice extends StatefulWidget {
  final String? invoiceId;

  const AddInvoice({Key? key, this.invoiceId}) : super(key: key);

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
  bool _isEditMode = false;
  List<Map<String, dynamic>> _originalInvoiceItems = [];
  double _totalValue = 0.0;
  double _totalProfit = 0.0;
  int _totalQuantity = 0;
  int _totalFOC = 0;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.invoiceId != null;
    _loadDistributions();
    _loadSuppliers();
    _loadItems();
    if (_isEditMode) {
      _loadInvoice();
    }
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
            'unitsPerCase': (data['unitsPerCase'] ?? 1).toInt(),
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

  Future<void> _loadInvoice() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final doc = await FirebaseFirestore.instance
          .collection('invoices')
          .doc(widget.invoiceId)
          .get();

      if (!doc.exists) {
        _showError('Invoice not found');
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      final invoiceData = doc.data() as Map<String, dynamic>;

      setState(() {
        _invoiceNumberController.text = invoiceData['invoiceNumber'] ?? '';
        _selectedDistribution = invoiceData['distributionId'];
        _selectedSupplier = invoiceData['supplier'];
        _invoiceDate = (invoiceData['invoiceDate'] as Timestamp).toDate();

        // Load invoice items
        final items = (invoiceData['items'] as List<dynamic>?) ?? [];
        _invoiceItems = items.asMap().entries.map((entry) {
          final item = Map<String, dynamic>.from(entry.value as Map);
          // Add unique key if not present (for existing invoices)
          if (!item.containsKey('_uniqueKey')) {
            item['_uniqueKey'] = '${item['itemId']}_${entry.key}_${DateTime.now().millisecondsSinceEpoch}';
          }
          return item;
        }).toList();

        // Store a copy of the original items for comparison
        _originalInvoiceItems = _invoiceItems.map((item) {
          return Map<String, dynamic>.from(item);
        }).toList();

        _calculateTotals();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error loading invoice: $e');
      if (mounted) {
        Navigator.pop(context);
      }
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
      // Insert at the beginning of the list so it appears at the top
      _invoiceItems.insert(0, {
        'itemId': item['id'],
        'productCode': item['productCode'],
        'productName': item['productName'],
        'brand': item['brand'],
        'category': item['category'],
        'unitType': item['unitType'],
        'unitsPerCase': item['unitsPerCase'] ?? 1,
        'cases': null,
        'pieces': null,
        'quantity': 0,
        'focCases': null,
        'focPieces': null,
        'focQuantity': 0,
        'casePrice': null,
        'purchasePrice': null,
        'sellingPrice': item['sellingPrice'],
        'mrp': item['mrp'],
        'margin': 0.0,
        'marginPercentage': 0.0,
        'lineTotal': 0.0,
        'lineProfit': 0.0,
        // Add a unique key for this item to prevent Flutter from reusing widgets
        '_uniqueKey': '${item['id']}_${DateTime.now().millisecondsSinceEpoch}',
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

      // Auto-calculate per-unit purchase price from case price
      if (field == 'casePrice') {
        final unitsPerCase = (_invoiceItems[index]['unitsPerCase'] ?? 1).toInt();
        final casePrice = value;
        if (casePrice != null && casePrice > 0 && unitsPerCase > 0) {
          _invoiceItems[index]['purchasePrice'] = casePrice / unitsPerCase;
        }
      }

      // Auto-calculate quantity from cases and pieces
      if (field == 'cases' || field == 'pieces') {
        final unitsPerCase = (_invoiceItems[index]['unitsPerCase'] ?? 1).toInt();
        final cases = (_invoiceItems[index]['cases'] ?? 0).toInt();
        final pieces = (_invoiceItems[index]['pieces'] ?? 0).toInt();
        _invoiceItems[index]['quantity'] = (cases * unitsPerCase) + pieces;
      }

      // Auto-calculate FOC quantity from FOC cases and pieces
      if (field == 'focCases' || field == 'focPieces') {
        final unitsPerCase = (_invoiceItems[index]['unitsPerCase'] ?? 1).toInt();
        final focCases = (_invoiceItems[index]['focCases'] ?? 0).toInt();
        final focPieces = (_invoiceItems[index]['focPieces'] ?? 0).toInt();
        _invoiceItems[index]['focQuantity'] = (focCases * unitsPerCase) + focPieces;
      }

      // Calculate margin and totals when prices change
      if (field == 'purchasePrice' ||
          field == 'sellingPrice' ||
          field == 'quantity' ||
          field == 'cases' ||
          field == 'pieces' ||
          field == 'casePrice') {
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

    // Validate that all items have quantity or free issues, and purchase price
    for (var item in _invoiceItems) {
      final quantity = (item['quantity'] ?? 0);
      final focQuantity = (item['focQuantity'] ?? 0);

      // Allow items with only free issues (no quantity required if FOC exists)
      if (quantity <= 0 && focQuantity <= 0) {
        _showError('All items must have either a quantity or free issues greater than 0');
        return;
      }

      // Purchase price is required only if there's a paid quantity
      if (quantity > 0 && (item['purchasePrice'] ?? 0) <= 0) {
        _showError('Items with quantity must have a purchase price greater than 0');
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final distributionName = _distributions.firstWhere(
        (d) => d['id'] == _selectedDistribution,
        orElse: () => {'name': 'Unknown'},
      )['name'];

      // Convert null values to 0 for all items before saving
      final itemsToSave = _invoiceItems.map((item) {
        return {
          ...item,
          'cases': item['cases'] ?? 0,
          'pieces': item['pieces'] ?? 0,
          'focCases': item['focCases'] ?? 0,
          'focPieces': item['focPieces'] ?? 0,
          'casePrice': item['casePrice'] ?? 0.0,
          'purchasePrice': item['purchasePrice'] ?? 0.0,
        };
      }).toList();

      final invoiceData = {
        'invoiceNumber': _invoiceNumberController.text,
        'distributionId': _selectedDistribution,
        'distributionName': distributionName,
        'supplier': _selectedSupplier,
        'invoiceDate': Timestamp.fromDate(_invoiceDate),
        'items': itemsToSave,
        'totalQuantity': _totalQuantity,
        'totalFOC': _totalFOC,
        'totalValue': _totalValue,
        'totalProfit': _totalProfit,
        'status': 'received',
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      String invoiceId;

      if (_isEditMode) {
        // Update existing invoice
        invoiceId = widget.invoiceId!;
        await FirebaseFirestore.instance
            .collection('invoices')
            .doc(invoiceId)
            .update(invoiceData);

        // Delete all existing stock entries for this invoice
        final stockQuery = await FirebaseFirestore.instance
            .collection('stock')
            .where('invoiceId', isEqualTo: invoiceId)
            .get();

        final batch = FirebaseFirestore.instance.batch();
        for (var doc in stockQuery.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        // Create new stock entries for all current items
        for (var item in _invoiceItems) {
          await _updateStock(item, invoiceId);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        // Create new invoice
        invoiceData['createdAt'] = FieldValue.serverTimestamp();
        final invoiceRef = await FirebaseFirestore.instance
            .collection('invoices')
            .add(invoiceData);
        invoiceId = invoiceRef.id;

        // Create stock entries for each item in the invoice
        for (var item in _invoiceItems) {
          await _updateStock(item, invoiceId);
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
      final distributionName = _distributions.firstWhere(
        (d) => d['id'] == _selectedDistribution,
        orElse: () => {'name': 'Unknown'},
      )['name'];

      // Add stock entry for this distribution
      await FirebaseFirestore.instance.collection('stock').add({
        'itemId': item['itemId'],
        'productCode': item['productCode'],
        'productName': item['productName'],
        'brand': item['brand'],
        'category': item['category'],
        'distributionId': _selectedDistribution,
        'distributionName': distributionName,
        'supplier': _selectedSupplier,
        'quantity': item['quantity'] ?? 0,
        'focUnits': item['focQuantity'] ?? 0,
        'casePrice': item['casePrice'] ?? 0.0,
        'purchasePrice': item['purchasePrice'] ?? 0.0,
        'sellingPrice': item['sellingPrice'] ?? 0.0,
        'mrp': item['mrp'] ?? 0.0,
        'margin': item['margin'] ?? 0.0,
        'marginPercentage': item['marginPercentage'] ?? 0.0,
        'totalValue': item['lineTotal'] ?? 0.0,
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
        title: Text(_isEditMode ? 'Edit Invoice' : 'Receive Invoice'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stepper Header
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      _buildStepIndicator(0, 'Details', Icons.receipt),
                      _buildStepConnector(),
                      _buildStepIndicator(1, 'Items', Icons.inventory_2),
                      _buildStepConnector(),
                      _buildStepIndicator(2, 'Review', Icons.check_circle),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Content based on current step
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: IndexedStack(
                      index: _currentStep,
                      children: [
                        // Step 0: Invoice Details
                        _buildInvoiceDetailsStep(),

                        // Step 1: Add Items
                        _buildAddItemsStep(),

                        // Step 2: Review
                        _buildReviewStep(),
                      ],
                    ),
                  ),
                ),

                // Navigation Buttons
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (_currentStep > 0)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _currentStep--;
                              });
                            },
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      if (_currentStep > 0) const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _currentStep == 2
                              ? _saveInvoice
                              : _canProceedToNextStep()
                                  ? () {
                                      setState(() {
                                        _currentStep++;
                                      });
                                    }
                                  : null,
                          icon: Icon(_currentStep == 2 ? Icons.save : Icons.arrow_forward),
                          label: Text(
                            _currentStep == 2 ? 'Save Invoice' : 'Next',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 0:
        return _selectedDistribution != null &&
            _selectedSupplier != null &&
            _invoiceNumberController.text.isNotEmpty;
      case 1:
        return _invoiceItems.isNotEmpty;
      default:
        return false;
    }
  }

  Widget _buildStepIndicator(int step, String label, IconData icon) {
    final isActive = step == _currentStep;
    final isCompleted = step < _currentStep;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green[600]
                  : isActive
                      ? Colors.blue[600]
                      : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? Colors.blue[600] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector() {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20),
        color: Colors.grey[300],
      ),
    );
  }

  Widget _buildInvoiceDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invoice Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the basic invoice details',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        DateFormat('yyyy-MM-dd').format(_invoiceDate),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddItemsStep() {
    return Column(
      children: [
        // Search Section
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Items to Invoice',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search Items',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search by name, code, or brand',
                ),
                onChanged: _filterItems,
              ),
              const SizedBox(height: 8),
              if (_searchController.text.isNotEmpty &&
                  _filteredItems.isNotEmpty)
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.3,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          item['productName'],
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          '${item['productCode']} - ${item['brand']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                          'Rs. ${item['mrp'].toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        onTap: () => _addItemToInvoice(item),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),

        // Separator between search and items list
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(
              top: BorderSide(color: Colors.grey[300]!, width: 2),
              bottom: BorderSide(color: Colors.grey[300]!, width: 2),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.list_alt, size: 20, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'Items Added to Invoice (${_invoiceItems.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
              const Spacer(),
              if (_invoiceItems.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _invoiceItems.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Items List
        Expanded(
          child: _invoiceItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No items added',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Search and add items to the invoice',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    bottom: 16.0,
                  ),
                  itemCount: _invoiceItems.length,
                  itemBuilder: (context, index) {
                    return _buildInvoiceItem(index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Card
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('Items', '${_invoiceItems.length}',
                        Icons.inventory_2),
                    _buildSummaryItem('Qty', '$_totalQuantity', Icons.numbers),
                    _buildSummaryItem('FOC', '$_totalFOC', Icons.card_giftcard),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Total Value',
                            style: TextStyle(fontSize: 14)),
                        Text(
                          'Rs. ${_totalValue.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Total Profit',
                            style: TextStyle(fontSize: 14)),
                        Text(
                          'Rs. ${_totalProfit.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _totalProfit >= 0
                                ? Colors.green[700]
                                : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Invoice Details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Invoice Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Invoice Number', _invoiceNumberController.text),
                  _buildDetailRow(
                    'Distribution',
                    _distributions.firstWhere(
                      (d) => d['id'] == _selectedDistribution,
                      orElse: () => {'name': 'Unknown'},
                    )['name'] as String,
                  ),
                  _buildDetailRow('Supplier', _selectedSupplier ?? ''),
                  _buildDetailRow(
                    'Date',
                    DateFormat('yyyy-MM-dd').format(_invoiceDate),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Items List
          const Text(
            'Invoice Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _invoiceItems.length,
            itemBuilder: (context, index) {
              final item = _invoiceItems[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['productName'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () {
                              setState(() {
                                _currentStep = 1;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Qty: ${item['cases']}C + ${item['pieces']}P = ${item['quantity']}',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'FOC: ${item['focCases']}C + ${item['focPieces']}P = ${item['focQuantity']}',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Rs. ${item['lineTotal'].toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700],
                            ),
                          ),
                          Text(
                            'Margin: ${item['marginPercentage'].toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue[600], size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.blue[600])),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceItem(int index) {
    final item = _invoiceItems[index];
    final unitsPerCase = (item['unitsPerCase'] ?? 1).toInt();

    return Card(
      key: ValueKey(item['_uniqueKey'] ?? '${item['itemId']}_$index'),
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
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      Text(
                        '${item['productCode']} - ${item['brand']} ($unitsPerCase pcs/case)',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _removeItem(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(height: 16),
            // Quantity Section
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quantity',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('${item['_uniqueKey']}_cases'),
                          initialValue: item['cases']?.toString() ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Cases',
                            hintText: '0',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            _updateItemField(
                              index,
                              'cases',
                              value.isEmpty ? null : (int.tryParse(value) ?? 0),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('${item['_uniqueKey']}_pieces'),
                          initialValue: item['pieces']?.toString() ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Pieces',
                            hintText: '0',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            _updateItemField(
                              index,
                              'pieces',
                              value.isEmpty ? null : (int.tryParse(value) ?? 0),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              '${item['quantity']}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // FOC Section
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Free of Cost (FOC)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('${item['_uniqueKey']}_focCases'),
                          initialValue: item['focCases']?.toString() ?? '',
                          decoration: const InputDecoration(
                            labelText: 'FOC Cases',
                            hintText: '0',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            _updateItemField(
                              index,
                              'focCases',
                              value.isEmpty ? null : (int.tryParse(value) ?? 0),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('${item['_uniqueKey']}_focPieces'),
                          initialValue: item['focPieces']?.toString() ?? '',
                          decoration: const InputDecoration(
                            labelText: 'FOC Pieces',
                            hintText: '0',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            _updateItemField(
                              index,
                              'focPieces',
                              value.isEmpty ? null : (int.tryParse(value) ?? 0),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              '${item['focQuantity']}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[900],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Pricing
            Column(
              children: [
                // Case Price (new feature)
                TextFormField(
                  key: ValueKey('${item['_uniqueKey']}_casePrice'),
                  initialValue: item['casePrice']?.toString() ?? '',
                  decoration: InputDecoration(
                    labelText: 'Case Price',
                    hintText: '0.00',
                    helperText: 'Price per case (will auto-calculate per unit price)',
                    helperMaxLines: 2,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixText: 'Rs. ',
                    fillColor: Colors.green[50],
                    filled: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    _updateItemField(
                      index,
                      'casePrice',
                      value.isEmpty ? null : (double.tryParse(value)),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('${item['_uniqueKey']}_purchasePrice'),
                        initialValue: item['purchasePrice']?.toString() ?? '',
                        decoration: InputDecoration(
                          labelText: 'Purchase Price (per unit)',
                          hintText: '0.00',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          prefixText: 'Rs. ',
                          fillColor: (item['casePrice'] != null && item['casePrice'] > 0)
                              ? Colors.green[50]
                              : null,
                          filled: (item['casePrice'] != null && item['casePrice'] > 0),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        enabled: (item['casePrice'] == null || item['casePrice'] == 0),
                        onChanged: (value) {
                          _updateItemField(
                            index,
                            'purchasePrice',
                            value.isEmpty ? null : (double.tryParse(value)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('${item['_uniqueKey']}_sellingPrice'),
                        initialValue: item['sellingPrice']?.toString() ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Selling Price',
                          hintText: '0.00',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixText: 'Rs. ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          _updateItemField(
                            index,
                            'sellingPrice',
                            value.isEmpty ? null : (double.tryParse(value)),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Summary
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Line Total',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                      Text(
                        'Rs. ${item['lineTotal'].toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Margin',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                      Text(
                        '${item['marginPercentage'].toStringAsFixed(1)}% (Rs. ${item['lineProfit'].toStringAsFixed(2)})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: item['lineProfit'] >= 0
                              ? Colors.green[700]
                              : Colors.red[700],
                        ),
                      ),
                    ],
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
