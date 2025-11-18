import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:distro_tracker_flutter/analytics/item_performance.dart';
import 'package:distro_tracker_flutter/analytics/route_distribution_performance.dart';
import 'package:distro_tracker_flutter/analytics/inventory_recommendations.dart';

class BusinessAnalyticsDashboard extends StatefulWidget {
  const BusinessAnalyticsDashboard({super.key});

  @override
  State<BusinessAnalyticsDashboard> createState() =>
      _BusinessAnalyticsDashboardState();
}

class _BusinessAnalyticsDashboardState extends State<BusinessAnalyticsDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime endDate = DateTime.now();
  bool _isLoading = false;

  Map<String, dynamic> _overallMetrics = {};
  List<Map<String, dynamic>> _topSellingItems = [];
  List<Map<String, dynamic>> _slowMovingItems = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadOverallMetrics(),
        _loadTopSellingItems(),
        _loadSlowMovingItems(),
      ]);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadOverallMetrics() async {
    // Get unloading data
    final unloadingSnapshot = await _firestore
        .collection('unloading')
        .where('unloadedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('unloadedAt', isLessThan: Timestamp.fromDate(endDate))
        .get();

    double totalRevenue = 0;
    double totalExpenses = 0;
    int totalOrders = 0;
    int totalQuantitySold = 0;
    double totalDiscounts = 0;
    int totalReturns = 0;
    Set<String> uniqueItems = {};
    Set<String> uniqueRoutes = {};
    Set<String> uniqueDistributions = {};

    for (var doc in unloadingSnapshot.docs) {
      final data = doc.data();
      totalRevenue += ((data['netValue'] ?? data['totalValue'] ?? 0) as num).toDouble();
      totalExpenses += ((data['totalExpenses'] ?? 0) as num).toDouble();
      totalOrders++;
      totalQuantitySold += ((data['totalQuantity'] ?? 0) as num).toInt();
      totalDiscounts += ((data['totalDiscounts'] ?? 0) as num).toDouble();
      totalReturns += ((data['totalReturns'] ?? 0) as num).toInt();

      if (data['routeId'] != null) uniqueRoutes.add(data['routeId']);
      if (data['distributionId'] != null) uniqueDistributions.add(data['distributionId']);

      final items = data['items'] as List<dynamic>? ?? [];
      for (var item in items) {
        final itemId = (item as Map<String, dynamic>)['itemId'];
        if (itemId != null) uniqueItems.add(itemId);
      }
    }

    // Get current stock value
    final stockSnapshot = await _firestore
        .collection('stock')
        .where('status', isEqualTo: 'active')
        .get();

    double stockValue = 0;
    int totalStockQuantity = 0;

    for (var doc in stockSnapshot.docs) {
      final data = doc.data();
      final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
      final price = (data['distributorPrice'] as num?)?.toDouble() ?? 0;
      stockValue += quantity * price;
      totalStockQuantity += quantity.toInt();
    }

    final netProfit = totalRevenue - totalExpenses;
    final profitMargin = totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0;
    final avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0;

    _overallMetrics = {
      'totalRevenue': totalRevenue,
      'totalExpenses': totalExpenses,
      'netProfit': netProfit,
      'profitMargin': profitMargin,
      'totalOrders': totalOrders,
      'totalQuantitySold': totalQuantitySold,
      'totalDiscounts': totalDiscounts,
      'totalReturns': totalReturns,
      'avgOrderValue': avgOrderValue,
      'uniqueItems': uniqueItems.length,
      'uniqueRoutes': uniqueRoutes.length,
      'uniqueDistributions': uniqueDistributions.length,
      'stockValue': stockValue,
      'totalStockQuantity': totalStockQuantity,
    };
  }

  Future<void> _loadTopSellingItems() async {
    final unloadingSnapshot = await _firestore
        .collection('unloading')
        .where('unloadedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('unloadedAt', isLessThan: Timestamp.fromDate(endDate))
        .get();

    Map<String, Map<String, dynamic>> itemsMap = {};

    for (var doc in unloadingSnapshot.docs) {
      final data = doc.data();
      final items = data['items'] as List<dynamic>? ?? [];

      for (var item in items) {
        final itemMap = item as Map<String, dynamic>;
        final itemId = itemMap['itemId'] ?? 'unknown';
        final quantity = (itemMap['quantity'] ?? 0) as num;
        final value = ((itemMap['sellingPrice'] ?? itemMap['distributorPrice'] ?? 0) as num).toDouble() * quantity.toDouble();

        if (!itemsMap.containsKey(itemId)) {
          itemsMap[itemId] = {
            'itemId': itemId,
            'productName': itemMap['productName'] ?? 'Unknown',
            'productCode': itemMap['productCode'] ?? '',
            'totalQuantity': 0,
            'totalValue': 0.0,
          };
        }

        itemsMap[itemId]!['totalQuantity'] =
            ((itemsMap[itemId]!['totalQuantity'] as num).toDouble()) + quantity.toDouble();
        itemsMap[itemId]!['totalValue'] =
            ((itemsMap[itemId]!['totalValue'] as num).toDouble()) + value;
      }
    }

    final itemsList = itemsMap.values.toList();
    itemsList.sort((a, b) => ((b['totalValue'] as num).toDouble()).compareTo((a['totalValue'] as num).toDouble()));

    _topSellingItems = itemsList.take(5).toList();
  }

  Future<void> _loadSlowMovingItems() async {
    // Get all items from stock
    final stockSnapshot = await _firestore
        .collection('stock')
        .where('status', isEqualTo: 'active')
        .get();

    // Get sales data
    final unloadingSnapshot = await _firestore
        .collection('unloading')
        .where('unloadedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('unloadedAt', isLessThan: Timestamp.fromDate(endDate))
        .get();

    Map<String, int> salesMap = {};

    for (var doc in unloadingSnapshot.docs) {
      final data = doc.data();
      final items = data['items'] as List<dynamic>? ?? [];

      for (var item in items) {
        final itemMap = item as Map<String, dynamic>;
        final itemId = itemMap['itemId'] ?? 'unknown';
        final quantity = (itemMap['quantity'] ?? 0) as num;

        salesMap[itemId] = (salesMap[itemId] ?? 0) + quantity.toInt();
      }
    }

    List<Map<String, dynamic>> slowItems = [];

    for (var doc in stockSnapshot.docs) {
      final data = doc.data();
      final itemId = data['itemId'];
      final currentStock = (data['quantity'] as num?)?.toInt() ?? 0;
      final productName = data['productName'] ?? 'Unknown';
      final productCode = data['productCode'] ?? '';

      final totalSold = salesMap[itemId] ?? 0;

      if (currentStock > 0) {
        slowItems.add({
          'itemId': itemId,
          'productName': productName,
          'productCode': productCode,
          'currentStock': currentStock,
          'totalSold': totalSold,
        });
      }
    }

    // Sort by lowest sales
    slowItems.sort((a, b) => ((a['totalSold'] as num).toInt()).compareTo((b['totalSold'] as num).toInt()));

    _slowMovingItems = slowItems.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Business Analytics',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _showDateRangeDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Range Info
                    Text(
                      'Period: ${_formatDate(startDate)} - ${_formatDate(endDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Actions
                    _buildQuickActions(),

                    const SizedBox(height: 24),

                    // Financial Metrics
                    _buildSectionTitle('Financial Overview'),
                    const SizedBox(height: 12),
                    _buildFinancialMetrics(),

                    const SizedBox(height: 24),

                    // Operational Metrics
                    _buildSectionTitle('Operational Metrics'),
                    const SizedBox(height: 12),
                    _buildOperationalMetrics(),

                    const SizedBox(height: 24),

                    // Top Selling Items
                    _buildSectionTitle('Top 5 Selling Items'),
                    const SizedBox(height: 12),
                    _buildTopSellingItems(),

                    const SizedBox(height: 24),

                    // Slow Moving Items
                    _buildSectionTitle('Slow Moving Items'),
                    const SizedBox(height: 12),
                    _buildSlowMovingItems(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Quick Actions'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Item Performance',
                Icons.inventory_2,
                Colors.indigo,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ItemPerformanceScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Route & Distribution',
                Icons.route,
                Colors.purple,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RouteDistributionPerformanceScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          'Order Recommendations',
          Icons.shopping_cart,
          Colors.teal,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const InventoryRecommendationsScreen(),
              ),
            );
          },
          isWide: true,
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isWide = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildFinancialMetrics() {
    final totalRevenue = (_overallMetrics['totalRevenue'] ?? 0.0) as double;
    final totalExpenses = (_overallMetrics['totalExpenses'] ?? 0.0) as double;
    final netProfit = (_overallMetrics['netProfit'] ?? 0.0) as double;
    final profitMargin = (_overallMetrics['profitMargin'] ?? 0.0) as double;
    final avgOrderValue = (_overallMetrics['avgOrderValue'] ?? 0.0) as double;
    final totalDiscounts = (_overallMetrics['totalDiscounts'] ?? 0.0) as double;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildMetricRow(
              'Total Revenue',
              'Rs. ${totalRevenue.toStringAsFixed(2)}',
              Icons.monetization_on,
              Colors.green,
            ),
            const Divider(height: 24),
            _buildMetricRow(
              'Total Expenses',
              'Rs. ${totalExpenses.toStringAsFixed(2)}',
              Icons.money_off,
              Colors.red,
            ),
            const Divider(height: 24),
            _buildMetricRow(
              'Net Profit',
              'Rs. ${netProfit.toStringAsFixed(2)}',
              Icons.account_balance,
              netProfit >= 0 ? Colors.green : Colors.red,
              subtitle: 'Margin: ${profitMargin.toStringAsFixed(1)}%',
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildSmallMetric(
                    'Avg Order',
                    'Rs. ${avgOrderValue.toStringAsFixed(2)}',
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSmallMetric(
                    'Total Discounts',
                    'Rs. ${totalDiscounts.toStringAsFixed(2)}',
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationalMetrics() {
    final totalOrders = (_overallMetrics['totalOrders'] ?? 0) as int;
    final totalQuantitySold = (_overallMetrics['totalQuantitySold'] ?? 0) as int;
    final totalReturns = (_overallMetrics['totalReturns'] ?? 0) as int;
    final uniqueItems = (_overallMetrics['uniqueItems'] ?? 0) as int;
    final uniqueRoutes = (_overallMetrics['uniqueRoutes'] ?? 0) as int;
    final stockValue = (_overallMetrics['stockValue'] ?? 0.0) as double;
    final totalStockQuantity = (_overallMetrics['totalStockQuantity'] ?? 0) as int;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildMetricBox(
                    'Total Orders',
                    totalOrders.toString(),
                    Icons.receipt,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricBox(
                    'Items Sold',
                    totalQuantitySold.toString(),
                    Icons.shopping_cart,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricBox(
                    'Active Routes',
                    uniqueRoutes.toString(),
                    Icons.route,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricBox(
                    'Products',
                    uniqueItems.toString(),
                    Icons.inventory_2,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildMetricRow(
              'Current Stock Value',
              'Rs. ${stockValue.toStringAsFixed(2)}',
              Icons.warehouse,
              Colors.teal,
              subtitle: '$totalStockQuantity pieces',
            ),
            if (totalReturns > 0) ...[
              const Divider(height: 24),
              _buildMetricRow(
                'Total Returns',
                totalReturns.toString(),
                Icons.keyboard_return,
                Colors.red,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(
    String label,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSmallMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTopSellingItems() {
    if (_topSellingItems.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No sales data available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _topSellingItems.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _topSellingItems[index];
          final rank = index + 1;
          final medalColor = rank == 1
              ? Colors.amber
              : rank == 2
                  ? Colors.grey[400]
                  : rank == 3
                      ? Colors.brown[300]
                      : Colors.grey[300];

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: medalColor,
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              item['productName'],
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(item['productCode']),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rs. ${(item['totalValue'] as num).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text(
                  '${item['totalQuantity']} pcs',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlowMovingItems() {
    if (_slowMovingItems.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No slow moving items',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _slowMovingItems.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _slowMovingItems[index];

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange[100],
              child: Icon(Icons.warning, color: Colors.orange[700], size: 20),
            ),
            title: Text(
              item['productName'],
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(item['productCode']),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Stock: ${item['currentStock']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Sold: ${item['totalSold']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDateRangeDialog() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: startDate, end: endDate),
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      _loadAnalytics();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
