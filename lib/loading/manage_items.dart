import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageItems extends StatefulWidget {
  const ManageItems({super.key});

  @override
  State<ManageItems> createState() => _ManageItemsState();
}

class _ManageItemsState extends State<ManageItems> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _firestore
          .collection('items')
          .orderBy('productName')
          .get();

      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      setState(() {
        _items = items;
        _filteredItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading items: $e');
    }
  }

  void _filterItems(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredItems = _items;
      } else {
        _filteredItems = _items.where((item) {
          final productName = item['productName']?.toString().toLowerCase() ?? '';
          final productCode = item['productCode']?.toString().toLowerCase() ?? '';
          final brand = item['brand']?.toString().toLowerCase() ?? '';
          final category = item['category']?.toString().toLowerCase() ?? '';
          final supplier = item['supplier']?.toString().toLowerCase() ?? '';
          final search = query.toLowerCase();

          return productName.contains(search) ||
              productCode.contains(search) ||
              brand.contains(search) ||
              category.contains(search) ||
              supplier.contains(search);
        }).toList();
      }
    });
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditItemScreen(item: item),
      ),
    );

    if (result == true) {
      _loadItems();
    }
  }

  Future<void> _deleteItem(String itemId, String itemName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "$itemName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('items').doc(itemId).delete();
        _showSuccessSnackBar('Item deleted successfully');
        _loadItems();
      } catch (e) {
        _showErrorSnackBar('Error deleting item: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Manage Items',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadItems,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterItems('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: _filterItems,
            ),
          ),

          // Items Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  '${_filteredItems.length} items',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Items List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredItems.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          return _buildItemCard(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final sellingPrice = (item['sellingPrice'] ?? 0).toDouble();
    final distributorPrice = (item['distributorPrice'] ?? 0).toDouble();
    final mrp = (item['mrp'] ?? 0).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _editItem(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['productCode']?.toString() ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['productName']?.toString() ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editItem(item),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteItem(
                          item['id'],
                          item['productName'] ?? '',
                        ),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip('Brand', item['brand'] ?? 'N/A', Colors.purple),
                  _buildInfoChip('Category', item['category'] ?? 'N/A', Colors.orange),
                  _buildInfoChip('Supplier', item['supplier'] ?? 'N/A', Colors.teal),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Distributor Price:'),
                        Text(
                          'Rs. ${distributorPrice.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Selling Price:'),
                        Text(
                          'Rs. ${sellingPrice.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('MRP:'),
                        Text(
                          'Rs. ${mrp.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color[700],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No items found' : 'No items available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

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
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

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
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class EditItemScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const EditItemScreen({super.key, required this.item});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TextEditingController _productNameController;
  late TextEditingController _productCodeController;
  late TextEditingController _brandController;
  late TextEditingController _categoryController;
  late TextEditingController _supplierController;
  late TextEditingController _unitTypeController;
  late TextEditingController _unitsPerCaseController;
  late TextEditingController _focController;
  late TextEditingController _distributorMarginController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _mrpController;
  late TextEditingController _distributorPriceController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _productNameController = TextEditingController(text: widget.item['productName'] ?? '');
    _productCodeController = TextEditingController(text: widget.item['productCode'] ?? '');
    _brandController = TextEditingController(text: widget.item['brand'] ?? '');
    _categoryController = TextEditingController(text: widget.item['category'] ?? '');
    _supplierController = TextEditingController(text: widget.item['supplier'] ?? '');
    _unitTypeController = TextEditingController(text: widget.item['unitType'] ?? 'pcs');
    _unitsPerCaseController = TextEditingController(text: (widget.item['unitsPerCase'] ?? 0).toString());
    _focController = TextEditingController(text: (widget.item['foc'] ?? 0).toString());
    _distributorMarginController = TextEditingController(text: (widget.item['distributorMargin'] ?? 0).toString());
    _sellingPriceController = TextEditingController(text: (widget.item['sellingPrice'] ?? 0).toString());
    _mrpController = TextEditingController(text: (widget.item['mrp'] ?? 0).toString());
    _distributorPriceController = TextEditingController(text: (widget.item['distributorPrice'] ?? 0).toString());
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _productCodeController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    _supplierController.dispose();
    _unitTypeController.dispose();
    _unitsPerCaseController.dispose();
    _focController.dispose();
    _distributorMarginController.dispose();
    _sellingPriceController.dispose();
    _mrpController.dispose();
    _distributorPriceController.dispose();
    super.dispose();
  }

  void _calculateDistributorPrice() {
    final sellingPrice = double.tryParse(_sellingPriceController.text) ?? 0.0;
    final marginPercentage = double.tryParse(_distributorMarginController.text) ?? 0.0;
    final distributorPrice = sellingPrice * (1 - (marginPercentage / 100));
    _distributorPriceController.text = distributorPrice.toStringAsFixed(2);
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final itemData = {
        'productName': _productNameController.text.trim(),
        'productCode': _productCodeController.text.trim(),
        'brand': _brandController.text.trim(),
        'category': _categoryController.text.trim(),
        'supplier': _supplierController.text.trim(),
        'unitType': _unitTypeController.text.trim(),
        'unitsPerCase': int.tryParse(_unitsPerCaseController.text) ?? 0,
        'foc': int.tryParse(_focController.text) ?? 0,
        'distributorMargin': double.tryParse(_distributorMarginController.text) ?? 0.0,
        'distributorPrice': double.tryParse(_distributorPriceController.text) ?? 0.0,
        'sellingPrice': double.tryParse(_sellingPriceController.text) ?? 0.0,
        'mrp': double.tryParse(_mrpController.text) ?? 0.0,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('items').doc(widget.item['id']).update(itemData);

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Item updated successfully'),
            ],
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating item: $e'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Edit Item',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Information
              _buildSectionTitle('Product Information'),
              _buildTextField(
                controller: _productNameController,
                label: 'Product Name',
                icon: Icons.inventory_2,
                required: true,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _productCodeController,
                label: 'Product Code',
                icon: Icons.qr_code,
                required: true,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _brandController,
                label: 'Brand',
                icon: Icons.branding_watermark,
                required: true,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _categoryController,
                label: 'Category',
                icon: Icons.category,
                required: true,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _supplierController,
                label: 'Supplier',
                icon: Icons.local_shipping,
                required: true,
              ),

              const SizedBox(height: 24),

              // Pricing Information
              _buildSectionTitle('Pricing Information'),
              _buildTextField(
                controller: _sellingPriceController,
                label: 'Selling Price',
                icon: Icons.attach_money,
                keyboardType: TextInputType.number,
                required: true,
                onChanged: (value) => _calculateDistributorPrice(),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _distributorMarginController,
                label: 'Distributor Margin (%)',
                icon: Icons.percent,
                keyboardType: TextInputType.number,
                required: true,
                onChanged: (value) => _calculateDistributorPrice(),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _distributorPriceController,
                label: 'Distributor Price (Auto-calculated)',
                icon: Icons.calculate,
                keyboardType: TextInputType.number,
                enabled: false,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _mrpController,
                label: 'MRP',
                icon: Icons.price_tag,
                keyboardType: TextInputType.number,
                required: true,
              ),

              const SizedBox(height: 24),

              // Unit Information
              _buildSectionTitle('Unit Information'),
              _buildTextField(
                controller: _unitTypeController,
                label: 'Unit Type',
                icon: Icons.scale,
                required: true,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _unitsPerCaseController,
                label: 'Units Per Case',
                icon: Icons.inventory,
                keyboardType: TextInputType.number,
                required: true,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _focController,
                label: 'FOC (Free of Cost)',
                icon: Icons.card_giftcard,
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 32),

              // Save Button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool required = false,
    bool enabled = true,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label + (required ? ' *' : ''),
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[200],
      ),
      keyboardType: keyboardType,
      enabled: enabled,
      onChanged: onChanged,
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'This field is required';
              }
              return null;
            }
          : null,
    );
  }
}
