import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  // State variables
  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _selectedItems = [];
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

  /// Loads items from Firebase with current stock
  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot itemsSnapshot =
          await FirebaseFirestore.instance
              .collection('stock')
              .where('status', isEqualTo: 'active')
              .where('quantity', isGreaterThan: 0)
              .orderBy('quantity')
              .orderBy('productName')
              .get();

      List<Map<String, dynamic>> items = [];
      for (var doc in itemsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        items.add(data);
      }

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading items: ${e.toString()}');
    }
  }

  /// Filters items based on search query
  List<Map<String, dynamic>> get _filteredItems {
    if (_searchQuery.isEmpty) {
      return _items;
    }

    return _items.where((item) {
      final productName = item['productName']?.toString().toLowerCase() ?? '';
      final productCode = item['productCode']?.toString().toLowerCase() ?? '';
      final brand = item['brand']?.toString().toLowerCase() ?? '';
      final batchNumber = item['batchNumber']?.toString().toLowerCase() ?? '';
      final category = item['category']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return productName.contains(query) ||
          productCode.contains(query) ||
          brand.contains(query) ||
          batchNumber.contains(query) ||
          category.contains(query);
    }).toList();
  }

  /// Updates quantity for an item
  void _updateItemQuantity(String itemId, int quantity) {
    setState(() {
      final existingIndex = _selectedItems.indexWhere(
        (item) => item['id'] == itemId,
      );

      if (quantity > 0) {
        final itemData = _items.firstWhere((item) => item['id'] == itemId);
        final selectedItem = {...itemData, 'loadingQuantity': quantity};

        if (existingIndex >= 0) {
          _selectedItems[existingIndex] = selectedItem;
        } else {
          _selectedItems.add(selectedItem);
        }
      } else {
        if (existingIndex >= 0) {
          _selectedItems.removeAt(existingIndex);
        }
      }
    });
  }

  /// Gets the current loading quantity for an item
  int _getLoadingQuantity(String itemId) {
    final selectedItem = _selectedItems.firstWhere(
      (item) => item['id'] == itemId,
      orElse: () => <String, dynamic>{},
    );
    return (selectedItem['loadingQuantity'] as int?) ?? 0;
  }

  /// Calculates total value of selected items
  double get _totalValue {
    return _selectedItems.fold(0.0, (sum, item) {
      final distributorPrice =
          (item['distributorPrice'] as num?)?.toDouble() ?? 0.0;
      final quantity = (item['loadingQuantity'] as int?) ?? 0;
      return sum + (distributorPrice * quantity);
    });
  }

  /// Calculates total quantity of selected items
  int get _totalQuantity {
    return _selectedItems.fold<int>(
      0,
      (sum, item) => sum + ((item['loadingQuantity'] as int?) ?? 0),
    );
  }

  /// Saves the loading data
  Future<void> _saveLoading() async {
    if (_selectedItems.isEmpty) {
      _showErrorSnackBar('Please select at least one item');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final loadingData = {
        'items':
            _selectedItems
                .map(
                  (item) => {
                    'itemId':
                        item['itemId'], // Using existing itemId from stock
                    'stockDocId':
                        item['id'], // Document ID from stock collection
                    'productCode': item['productCode'],
                    'productName': item['productName'],
                    'batchNumber': item['batchNumber'],
                    'brand': item['brand'],
                    'category': item['category'],
                    'unitType': item['unitType'],
                    'loadingQuantity': item['loadingQuantity'],
                    'distributorPrice': item['distributorPrice'],
                    'totalValue':
                        ((item['distributorPrice'] as num?)?.toDouble() ??
                            0.0) *
                        ((item['loadingQuantity'] as int?) ?? 0),
                    'expiryDate': item['expiryDate'],
                    'supplier': item['supplier'],
                  },
                )
                .toList(),
        'totalItems': _selectedItems.length,
        'totalQuantity': _totalQuantity,
        'totalValue': _totalValue,
        'loadedAt': FieldValue.serverTimestamp(),
        'status': 'loaded',
      };

      await FirebaseFirestore.instance.collection('loading').add(loadingData);

      // Update stock quantities
      for (final item in _selectedItems) {
        await _updateStockQuantity(
          item['id'] as String,
          (item['loadingQuantity'] as int?) ?? 0,
        );
      }

      if (!mounted) return;

      _showSuccessSnackBar('Loading saved successfully!');

      // Clear selections
      setState(() {
        _selectedItems.clear();
      });

      // Reload items to reflect updated stock
      _loadItems();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error saving loading: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Updates stock quantity after loading
  Future<void> _updateStockQuantity(
    String stockDocId,
    int loadedQuantity,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('stock')
          .doc(stockDocId)
          .update({
            'quantity': FieldValue.increment(-loadedQuantity),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error updating stock: $e');
    }
  }

  /// Formats expiry date for display
  String _formatExpiryDate(dynamic expiryDate) {
    if (expiryDate == null) return 'N/A';

    try {
      if (expiryDate is Timestamp) {
        final date = expiryDate.toDate();
        return '${date.day}/${date.month}/${date.year}';
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  /// Checks if item is expiring soon (within 30 days)
  bool _isExpiringSoon(dynamic expiryDate) {
    if (expiryDate == null) return false;

    try {
      if (expiryDate is Timestamp) {
        final date = expiryDate.toDate();
        final now = DateTime.now();
        final difference = date.difference(now).inDays;
        return difference <= 30 && difference >= 0;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Loading Items',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, code, brand, batch...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                        : null,
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
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Summary Card
                  if (_selectedItems.isNotEmpty) _buildSummaryCard(),

                  // Items List
                  Expanded(
                    child:
                        _filteredItems.isEmpty
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
      bottomNavigationBar:
          _selectedItems.isNotEmpty
              ? Container(
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
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveLoading,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isSaving
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : Text(
                            'Save Loading (${_selectedItems.length} items)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              )
              : null,
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            'Items',
            '${_selectedItems.length}',
            Icons.inventory_2,
          ),
          _buildSummaryItem('Quantity', '$_totalQuantity', Icons.numbers),
          _buildSummaryItem(
            'Value',
            'Rs.${_totalValue.toStringAsFixed(2)}',
            Icons.attach_money,
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

  Widget _buildItemCard(Map<String, dynamic> item) {
    final currentQuantity = _getLoadingQuantity(item['id'] as String);
    final maxStock = (item['quantity'] as int?) ?? 0;
    final isExpiringSoon = _isExpiringSoon(item['expiryDate']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            isExpiringSoon
                ? Border.all(color: Colors.orange[300]!, width: 1.5)
                : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with expiry warning
            if (isExpiringSoon) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning, size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Expiring Soon',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Product Info
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        maxStock > 50
                            ? Colors.green[100]
                            : maxStock > 20
                            ? Colors.orange[100]
                            : Colors.red[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Stock: $maxStock',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color:
                          maxStock > 50
                              ? Colors.green[700]
                              : maxStock > 20
                              ? Colors.orange[700]
                              : Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Details Grid
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(
                          'Brand',
                          item['brand']?.toString() ?? 'N/A',
                        ),
                      ),
                      Expanded(
                        child: _buildDetailItem(
                          'Category',
                          item['category']?.toString() ?? 'N/A',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(
                          'Batch',
                          item['batchNumber']?.toString() ?? 'N/A',
                        ),
                      ),
                      Expanded(
                        child: _buildDetailItem(
                          'Unit',
                          item['unitType']?.toString() ?? 'N/A',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(
                          'Expiry',
                          _formatExpiryDate(item['expiryDate']),
                        ),
                      ),
                      Expanded(
                        child: _buildDetailItem(
                          'Supplier',
                          item['supplier']?.toString() ?? 'N/A',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Price per unit:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(
                  'Rs.${((item['distributorPrice'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Quantity Controls
            Row(
              children: [
                const Text(
                  'Loading Quantity:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed:
                            currentQuantity > 0
                                ? () => _updateItemQuantity(
                                  item['id'] as String,
                                  currentQuantity - 1,
                                )
                                : null,
                        icon: const Icon(Icons.remove),
                        iconSize: 18,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                      Container(
                        width: 60,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '$currentQuantity',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed:
                            currentQuantity < maxStock
                                ? () => _updateItemQuantity(
                                  item['id'] as String,
                                  currentQuantity + 1,
                                )
                                : null,
                        icon: const Icon(Icons.add),
                        iconSize: 18,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Total for this item
            if (currentQuantity > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Value:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Rs.${(((item['distributorPrice'] as num?)?.toDouble() ?? 0.0) * currentQuantity).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
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
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search'
                : 'Add some items to your inventory first',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
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
    print(message);
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
