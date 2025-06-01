import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Unloading extends StatefulWidget {
  const Unloading({super.key});

  @override
  State<Unloading> createState() => _UnloadingState();
}

class _UnloadingState extends State<Unloading> {
  // State variables
  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _loadedItems = [];
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

  /// Loads items that are currently loaded (available for unloading)
  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all loading records that haven't been fully unloaded
      final QuerySnapshot loadingSnapshot =
          await FirebaseFirestore.instance
              .collection('loading')
              .where('status', isEqualTo: 'loaded')
              .orderBy('loadedAt', descending: true)
              .get();

      List<Map<String, dynamic>> loadedItems = [];

      for (var loadingDoc in loadingSnapshot.docs) {
        final loadingData = loadingDoc.data() as Map<String, dynamic>;
        final items = loadingData['items'] as List<dynamic>? ?? [];

        for (var item in items) {
          final itemMap = item as Map<String, dynamic>;

          // Check if item still has unloaded quantity
          final loadingQuantity = (itemMap['loadingQuantity'] as int?) ?? 0;
          final unloadedQuantity = await _getUnloadedQuantity(
            loadingDoc.id,
            itemMap['itemId'] as String,
          );
          final availableForUnloading = loadingQuantity - unloadedQuantity;

          if (availableForUnloading > 0) {
            final enrichedItem = {
              ...itemMap,
              'loadingDocId': loadingDoc.id,
              'loadedAt': loadingData['loadedAt'],
              'availableForUnloading': availableForUnloading,
              'originalLoadingQuantity': loadingQuantity,
              'alreadyUnloaded': unloadedQuantity,
            };
            loadedItems.add(enrichedItem);
          }
        }
      }

      setState(() {
        _loadedItems = loadedItems;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading items: ${e.toString()}');
    }
  }

  /// Gets the total quantity already unloaded for a specific item from a loading batch
  Future<int> _getUnloadedQuantity(String loadingDocId, String itemId) async {
    try {
      final QuerySnapshot unloadingSnapshot =
          await FirebaseFirestore.instance
              .collection('unloading')
              .where('loadingDocId', isEqualTo: loadingDocId)
              .get();

      int totalUnloaded = 0;
      for (var doc in unloadingSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];

        for (var item in items) {
          final itemMap = item as Map<String, dynamic>;
          if (itemMap['itemId'] == itemId) {
            totalUnloaded += (itemMap['unloadingQuantity'] as int?) ?? 0;
          }
        }
      }
      return totalUnloaded;
    } catch (e) {
      debugPrint('Error getting unloaded quantity: $e');
      return 0;
    }
  }

  /// Filters items based on search query
  List<Map<String, dynamic>> get _filteredItems {
    if (_searchQuery.isEmpty) {
      return _loadedItems;
    }

    return _loadedItems.where((item) {
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

  /// Updates unloading quantity for an item
  void _updateItemQuantity(String itemKey, int quantity) {
    setState(() {
      final existingIndex = _selectedItems.indexWhere(
        (item) => '${item['loadingDocId']}_${item['itemId']}' == itemKey,
      );

      if (quantity > 0) {
        final itemData = _loadedItems.firstWhere(
          (item) => '${item['loadingDocId']}_${item['itemId']}' == itemKey,
        );
        final selectedItem = {...itemData, 'unloadingQuantity': quantity};

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

  /// Gets the current unloading quantity for an item
  int _getUnloadingQuantity(String itemKey) {
    final selectedItem = _selectedItems.firstWhere(
      (item) => '${item['loadingDocId']}_${item['itemId']}' == itemKey,
      orElse: () => <String, dynamic>{},
    );
    return (selectedItem['unloadingQuantity'] as int?) ?? 0;
  }

  /// Calculates total value of selected items for unloading
  double get _totalValue {
    return _selectedItems.fold(0.0, (sum, item) {
      final distributorPrice =
          (item['distributorPrice'] as num?)?.toDouble() ?? 0.0;
      final quantity = (item['unloadingQuantity'] as int?) ?? 0;
      return sum + (distributorPrice * quantity);
    });
  }

  /// Calculates total quantity of selected items for unloading
  int get _totalQuantity {
    return _selectedItems.fold<int>(
      0,
      (sum, item) => sum + ((item['unloadingQuantity'] as int?) ?? 0),
    );
  }

  /// Saves the unloading data
  Future<void> _saveUnloading() async {
    if (_selectedItems.isEmpty) {
      _showErrorSnackBar('Please select at least one item');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final unloadingData = {
        'items':
            _selectedItems
                .map(
                  (item) => {
                    'itemId': item['itemId'],
                    'stockDocId': item['stockDocId'],
                    'loadingDocId': item['loadingDocId'],
                    'productCode': item['productCode'],
                    'productName': item['productName'],
                    'batchNumber': item['batchNumber'],
                    'brand': item['brand'],
                    'category': item['category'],
                    'unitType': item['unitType'],
                    'unloadingQuantity': item['unloadingQuantity'],
                    'distributorPrice': item['distributorPrice'],
                    'totalValue':
                        ((item['distributorPrice'] as num?)?.toDouble() ??
                            0.0) *
                        ((item['unloadingQuantity'] as int?) ?? 0),
                    'expiryDate': item['expiryDate'],
                    'supplier': item['supplier'],
                    'originalLoadingQuantity': item['originalLoadingQuantity'],
                    'loadedAt': item['loadedAt'],
                  },
                )
                .toList(),
        'totalItems': _selectedItems.length,
        'totalQuantity': _totalQuantity,
        'totalValue': _totalValue,
        'unloadedAt': FieldValue.serverTimestamp(),
        'status': 'unloaded',
        'loadingDocId':
            _selectedItems
                .first['loadingDocId'], // Primary loading doc reference
      };

      await FirebaseFirestore.instance
          .collection('unloading')
          .add(unloadingData);

      // Update stock quantities (add back to stock)
      for (final item in _selectedItems) {
        await _updateStockQuantity(
          item['stockDocId'] as String,
          (item['unloadingQuantity'] as int?) ?? 0,
        );
      }

      if (!mounted) return;

      _showSuccessSnackBar('Unloading saved successfully!');

      // Clear selections
      setState(() {
        _selectedItems.clear();
      });

      // Reload items to reflect updated quantities
      _loadItems();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error saving unloading: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Updates stock quantity after unloading (adds back to stock)
  Future<void> _updateStockQuantity(
    String stockDocId,
    int unloadedQuantity,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('stock')
          .doc(stockDocId)
          .update({
            'quantity': FieldValue.increment(unloadedQuantity),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error updating stock: $e');
    }
  }

  /// Formats date for display
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year}';
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Unloading Items',
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
                hintText: 'Search loaded items...',
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
                  borderSide: BorderSide(color: Colors.orange[600]!, width: 2),
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
                  onPressed: _isSaving ? null : _saveUnloading,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
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
                            'Save Unloading (${_selectedItems.length} items)',
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
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            'Items',
            '${_selectedItems.length}',
            Icons.unarchive,
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
        Icon(icon, color: Colors.orange[600], size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.orange[800],
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.orange[600])),
      ],
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final itemKey = '${item['loadingDocId']}_${item['itemId']}';
    final currentQuantity = _getUnloadingQuantity(itemKey);
    final availableForUnloading = (item['availableForUnloading'] as int?) ?? 0;
    final alreadyUnloaded = (item['alreadyUnloaded'] as int?) ?? 0;
    final originalLoading = (item['originalLoadingQuantity'] as int?) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!, width: 1),
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
            // Loading Info Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_shipping,
                    size: 16,
                    color: Colors.orange[700],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Loaded: ${_formatDate(item['loadedAt'])}',
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
                          color: Colors.orange[600],
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
                        availableForUnloading > 20
                            ? Colors.green[100]
                            : availableForUnloading > 5
                            ? Colors.orange[100]
                            : Colors.red[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Available: $availableForUnloading',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color:
                          availableForUnloading > 20
                              ? Colors.green[700]
                              : availableForUnloading > 5
                              ? Colors.orange[700]
                              : Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Loading Progress
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Original Loading:',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        '$originalLoading',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (alreadyUnloaded > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Already Unloaded:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '$alreadyUnloaded',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.red[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Available for Unloading:',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        '$availableForUnloading',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
                  'Unloading Quantity:',
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
                                  itemKey,
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
                            currentQuantity < availableForUnloading
                                ? () => _updateItemQuantity(
                                  itemKey,
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
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange[200]!),
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
                        color: Colors.orange[700],
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
          Icon(Icons.unarchive_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No items found'
                : 'No items available for unloading',
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
                : 'Load some items first to make them available for unloading',
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
