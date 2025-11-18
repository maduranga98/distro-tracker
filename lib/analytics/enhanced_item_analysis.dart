import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EnhancedItemAnalysis extends StatefulWidget {
  const EnhancedItemAnalysis({super.key});

  @override
  State<EnhancedItemAnalysis> createState() => _EnhancedItemAnalysisState();
}

class _EnhancedItemAnalysisState extends State<EnhancedItemAnalysis>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;
  DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime endDate = DateTime.now();
  bool _isLoading = false;

  List<Map<String, dynamic>> _itemPerformanceData = [];
  List<Map<String, dynamic>> _profitabilityData = [];
  List<Map<String, dynamic>> _inventoryTurnoverData = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAnalysisData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalysisData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadItemPerformance(),
        _loadProfitabilityData(),
        _loadInventoryTurnover(),
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
          SnackBar(content: Text('Error loading data: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadItemPerformance() async {
    final unloadingSnapshot = await _firestore
        .collection('unloading')
        .where('unloadedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('unloadedAt', isLessThan: Timestamp.fromDate(endDate))
        .get();

    Map<String, Map<String, dynamic>> itemsMap = {};

    for (var doc in unloadingSnapshot.docs) {
      final data = doc.data();
      final items = data['items'] as List<dynamic>? ?? [];

      for (var item in items) {
        final itemMap = item as Map<String, dynamic>;
        final itemId = itemMap['itemId'] ?? 'unknown';
        final quantity = ((itemMap['quantity'] ?? 0) as num).toDouble();
        final sellingPrice =
            ((itemMap['sellingPrice'] ?? 0) as num).toDouble();
        final distributorPrice =
            ((itemMap['distributorPrice'] ?? 0) as num).toDouble();
        final freeIssues =
            ((itemMap['freeIssues'] ?? 0) as num).toDouble();
        final returns = ((itemMap['returns'] ?? 0) as num).toDouble();
        final damaged = ((itemMap['damaged'] ?? 0) as num).toDouble();

        final revenue = quantity * sellingPrice;
        final cost = (quantity + freeIssues) * distributorPrice;

        if (!itemsMap.containsKey(itemId)) {
          itemsMap[itemId] = {
            'itemId': itemId,
            'productName': itemMap['productName'] ?? 'Unknown',
            'productCode': itemMap['productCode'] ?? '',
            'totalQuantity': 0.0,
            'totalRevenue': 0.0,
            'totalCost': 0.0,
            'totalFreeIssues': 0.0,
            'totalReturns': 0.0,
            'totalDamaged': 0.0,
            'transactionCount': 0,
            'unitsPerCase': itemMap['unitsPerCase'] ?? 1,
          };
        }

        itemsMap[itemId]!['totalQuantity'] =
            ((itemsMap[itemId]!['totalQuantity'] as num).toDouble()) +
                quantity;
        itemsMap[itemId]!['totalRevenue'] =
            ((itemsMap[itemId]!['totalRevenue'] as num).toDouble()) +
                revenue;
        itemsMap[itemId]!['totalCost'] =
            ((itemsMap[itemId]!['totalCost'] as num).toDouble()) + cost;
        itemsMap[itemId]!['totalFreeIssues'] =
            ((itemsMap[itemId]!['totalFreeIssues'] as num).toDouble()) +
                freeIssues;
        itemsMap[itemId]!['totalReturns'] =
            ((itemsMap[itemId]!['totalReturns'] as num).toDouble()) +
                returns;
        itemsMap[itemId]!['totalDamaged'] =
            ((itemsMap[itemId]!['totalDamaged'] as num).toDouble()) +
                damaged;
        itemsMap[itemId]!['transactionCount'] =
            ((itemsMap[itemId]!['transactionCount'] as num).toInt()) + 1;
      }
    }

    // Calculate additional metrics
    final itemsList = itemsMap.values.map((item) {
      final revenue = (item['totalRevenue'] as num).toDouble();
      final cost = (item['totalCost'] as num).toDouble();
      final profit = revenue - cost;
      final margin = revenue > 0 ? (profit / revenue) * 100 : 0;
      final quantity = (item['totalQuantity'] as num).toDouble();
      final returns = (item['totalReturns'] as num).toDouble();
      final damaged = (item['totalDamaged'] as num).toDouble();
      final returnRate =
          quantity > 0 ? ((returns + damaged) / quantity) * 100 : 0;

      return {
        ...item,
        'profit': profit,
        'margin': margin,
        'returnRate': returnRate,
      };
    }).toList();

    itemsList.sort((a, b) => ((b['totalRevenue'] as num).toDouble())
        .compareTo((a['totalRevenue'] as num).toDouble()));

    _itemPerformanceData = itemsList;
  }

  Future<void> _loadProfitabilityData() async {
    // Reuse performance data and sort by profit margin
    final profitableItems = _itemPerformanceData.map((item) {
      return {...item};
    }).toList();

    profitableItems.sort((a, b) => ((b['margin'] as num).toDouble())
        .compareTo((a['margin'] as num).toDouble()));

    _profitabilityData = profitableItems;
  }

  Future<void> _loadInventoryTurnover() async {
    // Get current stock levels
    final stockSnapshot = await _firestore
        .collection('stock')
        .where('status', isEqualTo: 'active')
        .get();

    Map<String, Map<String, dynamic>> stockMap = {};

    for (var doc in stockSnapshot.docs) {
      final data = doc.data();
      final itemId = data['itemId'];
      final quantity = ((data['quantity'] ?? 0) as num).toDouble();

      if (!stockMap.containsKey(itemId)) {
        stockMap[itemId] = {
          'itemId': itemId,
          'productName': data['productName'] ?? 'Unknown',
          'productCode': data['productCode'] ?? '',
          'currentStock': 0.0,
        };
      }

      stockMap[itemId]!['currentStock'] =
          ((stockMap[itemId]!['currentStock'] as num).toDouble()) +
              quantity;
    }

    // Combine with sales data
    final turnoverList = <Map<String, dynamic>>[];

    for (var item in _itemPerformanceData) {
      final itemId = item['itemId'];
      final totalSold = (item['totalQuantity'] as num).toDouble();
      final currentStock =
          (stockMap[itemId]?['currentStock'] ?? 0.0) as num;

      final periodDays = endDate.difference(startDate).inDays;
      final avgDailySales = periodDays > 0 ? totalSold / periodDays : 0;
      final daysOfStock = avgDailySales > 0
          ? currentStock.toDouble() / avgDailySales
          : double.infinity;
      final turnoverRatio = currentStock > 0
          ? totalSold / currentStock.toDouble()
          : 0.0;

      turnoverList.add({
        'itemId': itemId,
        'productName': item['productName'],
        'productCode': item['productCode'],
        'currentStock': currentStock.toDouble(),
        'totalSold': totalSold,
        'avgDailySales': avgDailySales,
        'daysOfStock': daysOfStock.isFinite ? daysOfStock : 999.0,
        'turnoverRatio': turnoverRatio,
        'unitsPerCase': item['unitsPerCase'],
      });
    }

    // Sort by turnover ratio (highest first)
    turnoverList.sort((a, b) => ((b['turnoverRatio'] as num).toDouble())
        .compareTo((a['turnoverRatio'] as num).toDouble()));

    _inventoryTurnoverData = turnoverList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Enhanced Item Analysis',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _showDateRangeDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Performance'),
            Tab(text: 'Profitability'),
            Tab(text: 'Inventory'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPerformanceTab(),
                _buildProfitabilityTab(),
                _buildInventoryTab(),
              ],
            ),
    );
  }

  Widget _buildPerformanceTab() {
    if (_itemPerformanceData.isEmpty) {
      return _buildEmptyState('No performance data available');
    }

    return Column(
      children: [
        _buildPerformanceSummary(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _itemPerformanceData.length,
            itemBuilder: (context, index) {
              final item = _itemPerformanceData[index];
              return _buildPerformanceCard(item, index + 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfitabilityTab() {
    if (_profitabilityData.isEmpty) {
      return _buildEmptyState('No profitability data available');
    }

    return Column(
      children: [
        _buildProfitabilitySummary(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _profitabilityData.length,
            itemBuilder: (context, index) {
              final item = _profitabilityData[index];
              return _buildProfitabilityCard(item, index + 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryTab() {
    if (_inventoryTurnoverData.isEmpty) {
      return _buildEmptyState('No inventory data available');
    }

    return Column(
      children: [
        _buildInventorySummary(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _inventoryTurnoverData.length,
            itemBuilder: (context, index) {
              final item = _inventoryTurnoverData[index];
              return _buildInventoryCard(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceSummary() {
    final totalRevenue = _itemPerformanceData.fold<double>(
      0,
      (sum, item) => sum + ((item['totalRevenue'] as num).toDouble()),
    );
    final totalQuantity = _itemPerformanceData.fold<double>(
      0,
      (sum, item) => sum + ((item['totalQuantity'] as num).toDouble()),
    );
    final avgRevenuePerItem =
        _itemPerformanceData.isNotEmpty ? totalRevenue / _itemPerformanceData.length : 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[400]!, Colors.indigo[600]!],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Period: ${_formatDate(startDate)} - ${_formatDate(endDate)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryMetric(
                  'Total Items', _itemPerformanceData.length.toString()),
              _buildSummaryMetric(
                  'Total Revenue', 'Rs. ${totalRevenue.toStringAsFixed(0)}'),
              _buildSummaryMetric('Total Qty', totalQuantity.toStringAsFixed(0)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Avg Revenue/Item: ',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  'Rs. ${avgRevenuePerItem.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitabilitySummary() {
    final topProfitable = _profitabilityData.take(5).toList();
    final totalProfit = _profitabilityData.fold<double>(
      0,
      (sum, item) => sum + ((item['profit'] as num).toDouble()),
    );
    final avgMargin = _profitabilityData.isNotEmpty
        ? _profitabilityData.fold<double>(
                0, (sum, item) => sum + ((item['margin'] as num).toDouble())) /
            _profitabilityData.length
        : 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[400]!, Colors.green[600]!],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryMetric(
                  'Total Profit', 'Rs. ${totalProfit.toStringAsFixed(0)}'),
              _buildSummaryMetric(
                  'Avg Margin', '${avgMargin.toStringAsFixed(1)}%'),
              _buildSummaryMetric(
                  'Top Items', topProfitable.length.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInventorySummary() {
    final fastMoving =
        _inventoryTurnoverData.where((item) => (item['turnoverRatio'] as num) > 5).length;
    final slowMoving =
        _inventoryTurnoverData.where((item) => (item['turnoverRatio'] as num) < 1).length;
    final avgTurnover = _inventoryTurnoverData.isNotEmpty
        ? _inventoryTurnoverData.fold<double>(
                0,
                (sum, item) =>
                    sum + ((item['turnoverRatio'] as num).toDouble())) /
            _inventoryTurnoverData.length
        : 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal[400]!, Colors.teal[600]!],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryMetric('Fast Moving', fastMoving.toString()),
              _buildSummaryMetric('Slow Moving', slowMoving.toString()),
              _buildSummaryMetric(
                  'Avg Turnover', avgTurnover.toStringAsFixed(1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPerformanceCard(Map<String, dynamic> item, int rank) {
    final revenue = (item['totalRevenue'] as num).toDouble();
    final quantity = (item['totalQuantity'] as num).toDouble();
    final profit = (item['profit'] as num).toDouble();
    final margin = (item['margin'] as num).toDouble();
    final transactions = (item['transactionCount'] as num).toInt();
    final returnRate = (item['returnRate'] as num).toDouble();

    final isTop = rank <= 3;
    final rankColor = isTop ? Colors.amber : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isTop ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            isTop ? BorderSide(color: rankColor, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isTop)
                  Icon(rank == 1 ? Icons.emoji_events : Icons.star,
                      color: rankColor, size: 20),
                if (isTop) const SizedBox(width: 8),
                Text(
                  '#$rank',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: rankColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['productName'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        item['productCode'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: margin >= 20
                        ? Colors.green[100]
                        : margin >= 10
                            ? Colors.orange[100]
                            : Colors.red[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${margin.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: margin >= 20
                          ? Colors.green[700]
                          : margin >= 10
                              ? Colors.orange[700]
                              : Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricColumn('Revenue',
                    'Rs. ${revenue.toStringAsFixed(2)}', Colors.green),
                _buildMetricColumn(
                    'Profit', 'Rs. ${profit.toStringAsFixed(2)}', Colors.blue),
                _buildMetricColumn(
                    'Quantity', quantity.toStringAsFixed(0), Colors.orange),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSmallMetric('Transactions', transactions.toString()),
                  _buildSmallMetric(
                      'Return Rate', '${returnRate.toStringAsFixed(1)}%'),
                  _buildSmallMetric('Avg/Transaction',
                      'Rs. ${(transactions > 0 ? revenue / transactions : 0).toStringAsFixed(0)}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitabilityCard(Map<String, dynamic> item, int rank) {
    final profit = (item['profit'] as num).toDouble();
    final margin = (item['margin'] as num).toDouble();
    final revenue = (item['totalRevenue'] as num).toDouble();
    final cost = (item['totalCost'] as num).toDouble();

    Color marginColor;
    if (margin >= 20) {
      marginColor = Colors.green;
    } else if (margin >= 10) {
      marginColor = Colors.orange;
    } else if (margin >= 0) {
      marginColor = Colors.grey;
    } else {
      marginColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: marginColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: marginColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['productName'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        item['productCode'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${margin.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: marginColor,
                      ),
                    ),
                    Text(
                      'Margin',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricColumn(
                    'Revenue', 'Rs. ${revenue.toStringAsFixed(2)}', Colors.green),
                _buildMetricColumn(
                    'Cost', 'Rs. ${cost.toStringAsFixed(2)}', Colors.red),
                _buildMetricColumn('Profit',
                    'Rs. ${profit.toStringAsFixed(2)}', Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final currentStock = (item['currentStock'] as num).toDouble();
    final totalSold = (item['totalSold'] as num).toDouble();
    final avgDailySales = (item['avgDailySales'] as num).toDouble();
    final daysOfStock = (item['daysOfStock'] as num).toDouble();
    final turnoverRatio = (item['turnoverRatio'] as num).toDouble();

    Color statusColor;
    String status;
    if (turnoverRatio > 5) {
      statusColor = Colors.green;
      status = 'Fast Moving';
    } else if (turnoverRatio > 2) {
      statusColor = Colors.blue;
      status = 'Normal';
    } else if (turnoverRatio > 1) {
      statusColor = Colors.orange;
      status = 'Slow';
    } else {
      statusColor = Colors.red;
      status = 'Very Slow';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        item['productName'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        item['productCode'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricColumn('Current Stock',
                    currentStock.toStringAsFixed(0), Colors.blue),
                _buildMetricColumn(
                    'Total Sold', totalSold.toStringAsFixed(0), Colors.green),
                _buildMetricColumn('Turnover',
                    '${turnoverRatio.toStringAsFixed(1)}x', Colors.purple),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSmallMetric('Avg Daily Sales',
                      '${avgDailySales.toStringAsFixed(1)} pcs'),
                  _buildSmallMetric('Days of Stock',
                      daysOfStock < 999 ? '${daysOfStock.toStringAsFixed(1)} days' : 'N/A'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
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

  Widget _buildSmallMetric(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
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
      _loadAnalysisData();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
