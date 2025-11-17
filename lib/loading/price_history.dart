import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PriceHistory extends StatefulWidget {
  const PriceHistory({super.key});

  @override
  State<PriceHistory> createState() => _PriceHistoryState();
}

class _PriceHistoryState extends State<PriceHistory> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _priceHistory = [];
  List<Map<String, dynamic>> _filteredHistory = [];
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  String? _selectedItemId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadPriceHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    try {
      final snapshot = await _firestore.collection('items').orderBy('productName').get();
      setState(() {
        _items = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      });
    } catch (e) {
      _showErrorSnackBar('Error loading items: $e');
    }
  }

  Future<void> _loadPriceHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _firestore
          .collection('price_history')
          .orderBy('changedAt', descending: true)
          .limit(100)
          .get();

      final history = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      setState(() {
        _priceHistory = history;
        _filteredHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading price history: $e');
    }
  }

  void _filterHistory() {
    setState(() {
      _filteredHistory = _priceHistory.where((item) {
        final matchesItem = _selectedItemId == null || item['itemId'] == _selectedItemId;
        final productName = item['productName']?.toString().toLowerCase() ?? '';
        final productCode = item['productCode']?.toString().toLowerCase() ?? '';
        final supplier = item['supplier']?.toString().toLowerCase() ?? '';
        final search = _searchQuery.toLowerCase();

        final matchesSearch = _searchQuery.isEmpty ||
            productName.contains(search) ||
            productCode.contains(search) ||
            supplier.contains(search);

        return matchesItem && matchesSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Price History',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPriceHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Item Filter
                DropdownButtonFormField<String>(
                  value: _selectedItemId,
                  decoration: InputDecoration(
                    labelText: 'Filter by Item',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.inventory_2),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Items'),
                    ),
                    ..._items.map((item) {
                      return DropdownMenuItem(
                        value: item['id'],
                        child: Text(
                          '${item['productCode']} - ${item['productName']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedItemId = value;
                    });
                    _filterHistory();
                  },
                ),
                const SizedBox(height: 12),
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, code, supplier...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                              _filterHistory();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _filterHistory();
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Results count
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Text(
                  '${_filteredHistory.length} price changes',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // History List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredHistory.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredHistory.length,
                        itemBuilder: (context, index) {
                          final item = _filteredHistory[index];
                          return _buildHistoryCard(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final prevPurchasePrice = (item['previousPurchasePrice'] as num?)?.toDouble() ?? 0.0;
    final newPurchasePrice = (item['newPurchasePrice'] as num?)?.toDouble() ?? 0.0;
    final prevSellingPrice = (item['previousSellingPrice'] as num?)?.toDouble() ?? 0.0;
    final newSellingPrice = (item['newSellingPrice'] as num?)?.toDouble() ?? 0.0;

    final purchasePriceChange = newPurchasePrice - prevPurchasePrice;
    final sellingPriceChange = newSellingPrice - prevSellingPrice;

    final timestamp = item['changedAt'] as Timestamp?;
    final date = timestamp != null
        ? DateFormat('MMM dd, yyyy hh:mm a').format(timestamp.toDate())
        : 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                Icon(
                  purchasePriceChange > 0 || sellingPriceChange > 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: purchasePriceChange > 0 || sellingPriceChange > 0
                      ? Colors.red
                      : Colors.green,
                  size: 28,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip('Supplier', item['supplier'] ?? 'N/A', Colors.teal),
                _buildInfoChip('Batch', item['batchNumber'] ?? 'N/A', Colors.purple),
                _buildInfoChip('Qty', item['quantity']?.toString() ?? '0', Colors.orange),
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
                  _buildPriceChangeRow(
                    'Purchase Price:',
                    prevPurchasePrice,
                    newPurchasePrice,
                    purchasePriceChange,
                  ),
                  const SizedBox(height: 8),
                  _buildPriceChangeRow(
                    'Selling Price:',
                    prevSellingPrice,
                    newSellingPrice,
                    sellingPriceChange,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            if (item['changeReason'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Reason: ${item['changeReason']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPriceChangeRow(
    String label,
    double prevPrice,
    double newPrice,
    double change,
  ) {
    final changePercent = prevPrice > 0 ? ((change / prevPrice) * 100) : 0.0;
    final isIncrease = change > 0;
    final changeColor = isIncrease ? Colors.red : change < 0 ? Colors.green : Colors.grey;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Row(
          children: [
            Text(
              'Rs. ${prevPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 14),
            const SizedBox(width: 8),
            Text(
              'Rs. ${newPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (change != 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: changeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${isIncrease ? '+' : ''}${change.toStringAsFixed(2)} (${isIncrease ? '+' : ''}${changePercent.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: changeColor[700],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
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
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedItemId != null
                ? 'No price changes found'
                : 'No price history available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Price changes will appear here when items are added with different prices',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
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
