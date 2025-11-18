import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StockViewer extends StatefulWidget {
  const StockViewer({super.key});

  @override
  State<StockViewer> createState() => _StockViewerState();
}

class _StockViewerState extends State<StockViewer> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedDistributionId;
  List<Map<String, dynamic>> _distributions = [];
  List<Map<String, dynamic>> _stockItems = [];
  List<Map<String, dynamic>> _filteredStock = [];
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDistributions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDistributions() async {
    try {
      final snapshot = await _firestore
          .collection('distributions')
          .where('status', isEqualTo: 'active')
          .get();

      setState(() {
        _distributions = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
      });
    } catch (e) {
      _showErrorSnackBar('Error loading distributions: $e');
    }
  }

  Future<void> _loadStockForDistribution(String distributionId) async {
    setState(() {
      _isLoading = true;
      _stockItems = [];
      _filteredStock = [];
    });

    try {
      // Get all loadings for this distribution
      final loadingsSnapshot = await _firestore
          .collection('loading')
          .where('distributionId', isEqualTo: distributionId)
          .where('status', isEqualTo: 'loaded')
          .get();

      // Get all unloadings for this distribution
      final unloadingsSnapshot = await _firestore
          .collection('unloading')
          .where('distributionId', isEqualTo: distributionId)
          .get();

      // Calculate stock for each item
      Map<String, Map<String, dynamic>> stockMap = {};

      // Add loaded items
      for (var loading in loadingsSnapshot.docs) {
        final data = loading.data();
        final items = data['items'] as List<dynamic>? ?? [];

        for (var item in items) {
          final itemId = item['itemId'] ?? item['stockDocId'];
          if (!stockMap.containsKey(itemId)) {
            stockMap[itemId] = {
              'itemId': itemId,
              'productCode': item['productCode'],
              'productName': item['productName'],
              'brand': item['brand'],
              'category': item['category'],
              'unitType': item['unitType'],
              'distributorPrice': item['distributorPrice'],
              'loaded': 0,
              'sold': 0,
              'returned': 0,
              'current': 0,
            };
          }
          stockMap[itemId]!['loaded'] =
              (stockMap[itemId]!['loaded'] as int) +
              (item['loadingQuantity'] as int? ?? 0);
        }
      }

      // Subtract unloaded/sold items
      for (var unloading in unloadingsSnapshot.docs) {
        final data = unloading.data();
        final sales = data['sales'] as List<dynamic>? ?? [];

        for (var sale in sales) {
          final itemId = sale['itemId'];
          if (stockMap.containsKey(itemId)) {
            final sold = sale['quantitySold'] as int? ?? 0;
            final returned = sale['quantityReturned'] as int? ?? 0;
            stockMap[itemId]!['sold'] =
                (stockMap[itemId]!['sold'] as int) + sold;
            stockMap[itemId]!['returned'] =
                (stockMap[itemId]!['returned'] as int) + returned;
          }
        }
      }

      // Calculate current stock
      stockMap.forEach((key, value) {
        value['current'] = value['loaded'] - value['sold'] + value['returned'];
      });

      setState(() {
        _stockItems = stockMap.values.toList();
        _filteredStock = _stockItems;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading stock: $e');
    }
  }

  void _filterStock(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredStock = _stockItems;
      } else {
        _filteredStock = _stockItems.where((item) {
          final productName =
              item['productName']?.toString().toLowerCase() ?? '';
          final productCode =
              item['productCode']?.toString().toLowerCase() ?? '';
          final brand = item['brand']?.toString().toLowerCase() ?? '';
          final category = item['category']?.toString().toLowerCase() ?? '';
          final search = query.toLowerCase();

          return productName.contains(search) ||
              productCode.contains(search) ||
              brand.contains(search) ||
              category.contains(search);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Stock Viewer',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_selectedDistributionId != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  _loadStockForDistribution(_selectedDistributionId!),
            ),
        ],
      ),
      body: Column(
        children: [
          // Distribution Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('distributions')
                  .where('status', isEqualTo: 'active')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final distributions = snapshot.data!.docs;

                return DropdownButtonFormField<String>(
                  value: _selectedDistributionId,
                  decoration: InputDecoration(
                    labelText: 'Select Distribution',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.business),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: distributions.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(data['name'] ?? 'Unknown'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDistributionId = value;
                    });
                    if (value != null) {
                      _loadStockForDistribution(value);
                    }
                  },
                );
              },
            ),
          ),

          const Divider(height: 1),

          if (_selectedDistributionId != null) ...[
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search stock items...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterStock('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: _filterStock,
              ),
            ),

            // Summary Cards
            if (_stockItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildSummaryCards(),
              ),

            const SizedBox(height: 16),

            // Stock List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredStock.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredStock.length,
                      itemBuilder: (context, index) {
                        final item = _filteredStock[index];
                        return _buildStockCard(item);
                      },
                    ),
            ),
          ] else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.business_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select a distribution to view stock',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalItems = _stockItems.length;
    final totalLoaded = _stockItems.fold<int>(
      0,
      (sum, item) => sum + (item['loaded'] as int),
    );
    final totalSold = _stockItems.fold<int>(
      0,
      (sum, item) => sum + (item['sold'] as int),
    );
    final totalCurrent = _stockItems.fold<int>(
      0,
      (sum, item) => sum + (item['current'] as int),
    );
    final totalValue = _stockItems.fold<double>(
      0,
      (sum, item) =>
          sum +
          ((item['current'] as int) *
              (item['distributorPrice'] as num? ?? 0).toDouble()),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Total Items',
                  '$totalItems',
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Loaded',
                  '$totalLoaded',
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildSummaryItem('Sold', '$totalSold', Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Current',
                  '$totalCurrent',
                  Colors.purple,
                ),
              ),
              Expanded(
                flex: 2,
                child: _buildSummaryItem(
                  'Total Value',
                  'Rs. ${totalValue.toStringAsFixed(2)}',
                  Colors.teal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildStockCard(Map<String, dynamic> item) {
    final loaded = item['loaded'] as int;
    final sold = item['sold'] as int;
    final returned = item['returned'] as int;
    final current = item['current'] as int;
    final distributorPrice =
        (item['distributorPrice'] as num?)?.toDouble() ?? 0.0;
    final currentValue = current * distributorPrice;

    final stockStatus = current > 10
        ? 'High'
        : current > 5
        ? 'Medium'
        : 'Low';
    final statusColor = current > 10
        ? Colors.green
        : current > 5
        ? Colors.orange
        : Colors.red;

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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    stockStatus,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip('Brand', item['brand'] ?? 'N/A', Colors.purple),
                _buildInfoChip(
                  'Category',
                  item['category'] ?? 'N/A',
                  Colors.orange,
                ),
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
                  _buildStockRow('Loaded:', loaded, Colors.blue),
                  const SizedBox(height: 4),
                  _buildStockRow('Sold:', sold, Colors.orange),
                  if (returned > 0) ...[
                    const SizedBox(height: 4),
                    _buildStockRow('Returned:', returned, Colors.teal),
                  ],
                  const Divider(height: 12),
                  _buildStockRow(
                    'Current Stock:',
                    current,
                    Colors.green,
                    isBold: true,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Current Value:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Rs. ${currentValue.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                          fontSize: 16,
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

  Widget _buildStockRow(
    String label,
    int value,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '$value',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color.withOpacity(0.8),
          ),
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
          color: color.withOpacity(0.8),
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
            _searchQuery.isNotEmpty ? 'No stock found' : 'No stock available',
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
