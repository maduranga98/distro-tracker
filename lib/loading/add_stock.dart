import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddStock extends StatefulWidget {
  const AddStock({super.key});

  @override
  State<AddStock> createState() => _AddStockState();
}

class _AddStockState extends State<AddStock> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController focUnitsController = TextEditingController();
  final TextEditingController batchNumberController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  // State variables
  String? _selectedSupplier;
  String? _selectedItemId;
  Map<String, dynamic>? _selectedItemData;
  bool _isLoading = false;
  bool _isLoadingItems = false;

  // Data from Firebase
  List<String> _suppliers = [];
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    quantityController.dispose();
    focUnitsController.dispose();
    batchNumberController.dispose();
    notesController.dispose();
    super.dispose();
  }

  // TODO: Uncomment when Firebase is added
  /// Loads initial data including suppliers and items from Firebase
  Future<void> _loadInitialData() async {
    await Future.wait([_loadSuppliers(), _loadItems()]);
  }

  /// Fetches all unique suppliers from Firebase items collection
  Future<void> _loadSuppliers() async {
    try {
      // TODO: Uncomment when Firebase is added
      final QuerySnapshot itemsSnapshot =
          await FirebaseFirestore.instance.collection('items').get();

      Set<String> uniqueSuppliers = {};
      for (var doc in itemsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['supplier'] != null) {
          uniqueSuppliers.add(data['supplier']);
        }
      }

      if (mounted) {
        setState(() {
          _suppliers = uniqueSuppliers.toList()..sort();
        });
      }

      // Temporary hardcoded data for development
      setState(() {
        _suppliers = [
          'Lanka Dairies PVT Ltd',
          'Lanka Milk Foods (CWE) PLC',
          'Ambewela Products (PVT) Ltd',
        ];
      });
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error loading suppliers: ${e.toString()}');
      }
    }
  }

  /// Fetches all items from Firebase items collection
  Future<void> _loadItems() async {
    setState(() {
      _isLoadingItems = true;
    });

    try {
      // TODO: Uncomment when Firebase is added
      final QuerySnapshot itemsSnapshot =
          await FirebaseFirestore.instance
              .collection('items')
              .orderBy('productName')
              .get();

      List<Map<String, dynamic>> items = [];
      for (var doc in itemsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Add document ID
        items.add(data);
      }

      if (mounted) {
        setState(() {
          _allItems = items;
          _isLoadingItems = false;
        });
      }

      // Temporary hardcoded data for development
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Simulate network delay

      if (mounted) {
        setState(() {
          // _allItems = [
          //   {
          //     'id': 'item_1',
          //     'productCode': '3081',
          //     'productName': 'DAILY MILK (CHOCOLATE) - 180ml x 24',
          //     'supplier': 'Lanka Dairies PVT Ltd',
          //     'category': 'Dairy',
          //     'brand': 'Daily Milk',
          //     'unitType': 'Case',
          //     'distributorPrice': 3024.00,
          //     'wholesalePrice': 3200.00,
          //     'mrp': 3500.00,
          //   },
          //   {
          //     'id': 'item_2',
          //     'productCode': '3085',
          //     'productName': 'DAILY MILK (STRAWBERRY) - 180ml x 24',
          //     'supplier': 'Lanka Dairies PVT Ltd',
          //     'category': 'Dairy',
          //     'brand': 'Daily Milk',
          //     'unitType': 'Case',
          //     'distributorPrice': 3024.00,
          //     'wholesalePrice': 3200.00,
          //     'mrp': 3500.00,
          //   },
          //   {
          //     'id': 'item_3',
          //     'productCode': '5029',
          //     'productName': 'MY JUICE (MANGO) - 1000ml x 12',
          //     'supplier': 'Lanka Milk Foods (CWE) PLC',
          //     'category': 'Beverages',
          //     'brand': 'My Juice',
          //     'unitType': 'Case',
          //     'distributorPrice': 5610.00,
          //     'wholesalePrice': 5800.00,
          //     'mrp': 6200.00,
          //   },
          //   {
          //     'id': 'item_4',
          //     'productCode': '047',
          //     'productName': 'AMBEWELA MILK (CHOCOLATE) - 150ml x 28',
          //     'supplier': 'Ambewela Products (PVT) Ltd',
          //     'category': 'Dairy',
          //     'brand': 'Ambewela',
          //     'unitType': 'Case',
          //     'distributorPrice': 2257.92,
          //     'wholesalePrice': 2400.00,
          //     'mrp': 2600.00,
          //   },
          // ];
          _isLoadingItems = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingItems = false;
        });
        _showErrorSnackBar('Error loading items: ${e.toString()}');
      }
    }
  }

  /// Filters items based on selected supplier
  void _filterItemsBySupplier(String? supplier) {
    if (supplier == null) {
      setState(() {
        _filteredItems = [];
      });
      return;
    }

    setState(() {
      _filteredItems =
          _allItems.where((item) => item['supplier'] == supplier).toList();
    });
  }

  /// Gets item data by ID
  Map<String, dynamic>? _getItemById(String itemId) {
    try {
      return _allItems.firstWhere((item) => item['id'] == itemId);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Add Stock",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Item Selection Section
              _buildSectionHeader("Item Selection"),
              const SizedBox(height: 16),
              _buildSupplierDropdown(),
              const SizedBox(height: 16),
              _buildItemDropdown(),

              // Item Information Card (shown when item is selected)
              if (_selectedItemData != null) ...[
                const SizedBox(height: 16),
                _buildItemInfoCard(),
              ],

              const SizedBox(height: 32),

              // Stock Information Section
              _buildSectionHeader("Stock Information"),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: quantityController,
                      label: "Quantity",
                      hint: "Enter quantity",
                      icon: Icons.inventory_outlined,
                      keyboardType: TextInputType.number,
                      isRequired: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: focUnitsController,
                      label: "FOC Units",
                      hint: "Free units",
                      icon: Icons.card_giftcard_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: batchNumberController,
                label: "Batch Number",
                hint: "Enter batch number",
                icon: Icons.numbers_outlined,
                isRequired: true,
              ),

              const SizedBox(height: 32),

              // Additional Information Section
              _buildSectionHeader("Additional Information"),
              const SizedBox(height: 16),
              _buildTextField(
                controller: notesController,
                label: "Notes",
                hint: "Additional notes (optional)",
                icon: Icons.note_outlined,
                maxLines: 3,
              ),

              const SizedBox(height: 40),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _clearForm,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey[400]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Clear",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _addStock,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Text(
                                "Add Stock",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemInfoCard() {
    if (_selectedItemData == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'Selected Item Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Product Code', _selectedItemData!['productCode']),
          _buildInfoRow('Category', _selectedItemData!['category'] ?? 'N/A'),
          _buildInfoRow('Brand', _selectedItemData!['brand'] ?? 'N/A'),
          _buildInfoRow('Unit Type', _selectedItemData!['unitType']),
          _buildInfoRow(
            'Distributor Price',
            'Rs. ${_selectedItemData!['distributorPrice']?.toStringAsFixed(2) ?? '0.00'}',
          ),
          _buildInfoRow(
            'MRP',
            'Rs. ${_selectedItemData!['mrp']?.toStringAsFixed(2) ?? '0.00'}',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildSupplierDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedSupplier,
      decoration: _buildInputDecoration(
        label: 'Supplier *',
        hint: 'Select supplier',
        icon: Icons.local_shipping_outlined,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Supplier is required';
        }
        return null;
      },
      items:
          _suppliers.map((String supplier) {
            return DropdownMenuItem<String>(
              value: supplier,
              child: Text(
                supplier,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedSupplier = newValue;
          _selectedItemId = null; // Reset item when supplier changes
          _selectedItemData = null;
        });
        _filterItemsBySupplier(newValue);
      },
      isExpanded: true,
    );
  }

  Widget _buildItemDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedItemId,
      decoration: _buildInputDecoration(
        label: 'Item *',
        hint:
            _selectedSupplier == null
                ? 'Select supplier first'
                : _isLoadingItems
                ? 'Loading items...'
                : 'Select item',
        icon: Icons.inventory_2_outlined,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Item is required';
        }
        return null;
      },
      items:
          _filteredItems.map((item) {
            return DropdownMenuItem<String>(
              value: item['id'],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${item['productCode']} - ${item['productName']}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        'Unit: ${item['unitType']}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• Brand: ${item['brand'] ?? 'N/A'}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
      onChanged:
          (_selectedSupplier == null || _isLoadingItems)
              ? null
              : (String? newValue) {
                setState(() {
                  _selectedItemId = newValue;
                  _selectedItemData =
                      newValue != null ? _getItemById(newValue) : null;
                });
              },
      isExpanded: true,
      selectedItemBuilder: (BuildContext context) {
        return _filteredItems.map((item) {
          return Container(
            alignment: Alignment.centerLeft,
            child: Text(
              '${item['productCode']} - ${item['productName']}',
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList();
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters:
          keyboardType == TextInputType.number
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
      validator:
          isRequired
              ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return '$label is required';
                }
                return null;
              }
              : null,
      decoration: _buildInputDecoration(
        label: label + (isRequired ? ' *' : ''),
        hint: hint,
        icon: icon,
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey[600]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(
        color: Colors.grey[700],
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(color: Colors.grey[400]),
    );
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    quantityController.clear();
    focUnitsController.clear();
    batchNumberController.clear();
    notesController.clear();

    setState(() {
      _selectedSupplier = null;
      _selectedItemId = null;
      _selectedItemData = null;
      _filteredItems = [];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Form cleared'),
        backgroundColor: Colors.grey[600],
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _addStock() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedItemData == null) {
      _showErrorSnackBar('Please select a valid item');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare stock data
      final stockData = {
        'itemId': _selectedItemId,
        'productCode': _selectedItemData!['productCode'],
        'productName': _selectedItemData!['productName'],
        'supplier': _selectedSupplier,
        'category': _selectedItemData!['category'],
        'brand': _selectedItemData!['brand'],
        'unitType': _selectedItemData!['unitType'],
        'quantity': int.tryParse(quantityController.text) ?? 0,
        'focUnits': int.tryParse(focUnitsController.text) ?? 0,
        'batchNumber': batchNumberController.text.trim(),
        'notes': notesController.text.trim(),
        'distributorPrice': _selectedItemData!['distributorPrice'],
        'totalValue':
            (_selectedItemData!['distributorPrice'] ?? 0.0) *
            (int.tryParse(quantityController.text) ?? 0),
        'status': 'active',
        'addedAt':
            DateTime.now(), // Will be replaced with FieldValue.serverTimestamp() in Firebase
      };

      await FirebaseFirestore.instance.collection('stock').add({
        ...stockData,
        'addedAt': FieldValue.serverTimestamp(),
      });

      await _updateItemStockQuantity(
        _selectedItemId!,
        int.tryParse(quantityController.text) ?? 0,
      );

      // Simulate API call for development
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      _showSuccessSnackBar('Stock added successfully!');
      _clearForm();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error adding stock: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Updates the current stock quantity for an item in the items collection
  Future<void> _updateItemStockQuantity(
    String itemId,
    int addedQuantity,
  ) async {
    try {
      // TODO: Uncomment when Firebase is added
      // final DocumentReference itemRef = FirebaseFirestore.instance
      //     .collection('items')
      //     .doc(itemId);

      // await FirebaseFirestore.instance.runTransaction((transaction) async {
      //   final DocumentSnapshot itemDoc = await transaction.get(itemRef);
      //
      //   if (itemDoc.exists) {
      //     final currentStock = itemDoc.data() as Map<String, dynamic>;
      //     final currentQuantity = currentStock['currentStock'] ?? 0;
      //     final newQuantity = currentQuantity + addedQuantity;
      //
      //     transaction.update(itemRef, {
      //       'currentStock': newQuantity,
      //       'lastStockUpdate': FieldValue.serverTimestamp(),
      //     });
      //   }
      // });
    } catch (e) {
      // Log error but don't throw - stock was added successfully
      debugPrint('Error updating item stock quantity: $e');
    }
  }

  /// Checks if a batch number already exists for the selected item
  Future<bool> _checkBatchNumberExists(
    String batchNumber,
    String itemId,
  ) async {
    try {
      // TODO: Uncomment when Firebase is added
      // final QuerySnapshot batchQuery = await FirebaseFirestore.instance
      //     .collection('stock')
      //     .where('itemId', isEqualTo: itemId)
      //     .where('batchNumber', isEqualTo: batchNumber)
      //     .where('status', isEqualTo: 'active')
      //     .get();

      // return batchQuery.docs.isNotEmpty;

      // For development, return false
      return false;
    } catch (e) {
      debugPrint('Error checking batch number: $e');
      return false;
    }
  }

  /// Shows success snackbar
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Shows error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
