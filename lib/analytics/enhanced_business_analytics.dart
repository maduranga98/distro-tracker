import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EnhancedBusinessAnalytics extends StatefulWidget {
  const EnhancedBusinessAnalytics({super.key});

  @override
  State<EnhancedBusinessAnalytics> createState() =>
      _EnhancedBusinessAnalyticsState();
}

class _EnhancedBusinessAnalyticsState extends State<EnhancedBusinessAnalytics>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;
  DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime endDate = DateTime.now();
  bool _isLoading = false;

  Map<String, dynamic> _currentPeriodMetrics = {};
  Map<String, dynamic> _previousPeriodMetrics = {};
  List<Map<String, dynamic>> _dailyTrends = [];
  Map<String, dynamic> _profitabilityAnalysis = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadEnhancedAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEnhancedAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadCurrentPeriodMetrics(),
        _loadPreviousPeriodMetrics(),
        _loadDailyTrends(),
        _loadProfitabilityAnalysis(),
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
          SnackBar(
              content: Text('Error loading analytics: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadCurrentPeriodMetrics() async {
    final snapshot = await _firestore
        .collection('unloading')
        .where('unloadedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('unloadedAt', isLessThan: Timestamp.fromDate(endDate))
        .get();

    double totalRevenue = 0;
    double totalExpenses = 0;
    int totalOrders = 0;
    int totalQuantity = 0;
    double totalDiscounts = 0;
    double totalFreeIssues = 0;
    int totalReturns = 0;
    int totalDamaged = 0;
    Set<String> uniqueCustomers = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      totalRevenue +=
          ((data['netValue'] ?? data['totalValue'] ?? 0) as num).toDouble();
      totalExpenses += ((data['totalExpenses'] ?? 0) as num).toDouble();
      totalOrders++;
      totalQuantity += ((data['totalQuantity'] ?? 0) as num).toInt();
      totalDiscounts += ((data['totalDiscounts'] ?? 0) as num).toDouble();
      totalReturns += ((data['totalReturns'] ?? 0) as num).toInt();

      if (data['customerId'] != null) {
        uniqueCustomers.add(data['customerId']);
      }

      final items = data['items'] as List<dynamic>? ?? [];
      for (var item in items) {
        final itemMap = item as Map<String, dynamic>;
        totalFreeIssues +=
            ((itemMap['freeIssues'] ?? 0) as num).toDouble();
        totalDamaged += ((itemMap['damaged'] ?? 0) as num).toInt();
      }
    }

    final netProfit = totalRevenue - totalExpenses;
    final profitMargin =
        totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0;
    final avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0;

    _currentPeriodMetrics = {
      'totalRevenue': totalRevenue,
      'totalExpenses': totalExpenses,
      'netProfit': netProfit,
      'profitMargin': profitMargin,
      'totalOrders': totalOrders,
      'totalQuantity': totalQuantity,
      'totalDiscounts': totalDiscounts,
      'totalFreeIssues': totalFreeIssues,
      'totalReturns': totalReturns,
      'totalDamaged': totalDamaged,
      'avgOrderValue': avgOrderValue,
      'uniqueCustomers': uniqueCustomers.length,
    };
  }

  Future<void> _loadPreviousPeriodMetrics() async {
    final periodLength = endDate.difference(startDate).inDays;
    final previousStart = startDate.subtract(Duration(days: periodLength));
    final previousEnd = startDate;

    final snapshot = await _firestore
        .collection('unloading')
        .where('unloadedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(previousStart))
        .where('unloadedAt', isLessThan: Timestamp.fromDate(previousEnd))
        .get();

    double totalRevenue = 0;
    double totalExpenses = 0;
    int totalOrders = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      totalRevenue +=
          ((data['netValue'] ?? data['totalValue'] ?? 0) as num).toDouble();
      totalExpenses += ((data['totalExpenses'] ?? 0) as num).toDouble();
      totalOrders++;
    }

    final netProfit = totalRevenue - totalExpenses;

    _previousPeriodMetrics = {
      'totalRevenue': totalRevenue,
      'totalExpenses': totalExpenses,
      'netProfit': netProfit,
      'totalOrders': totalOrders,
    };
  }

  Future<void> _loadDailyTrends() async {
    final snapshot = await _firestore
        .collection('unloading')
        .where('unloadedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('unloadedAt', isLessThan: Timestamp.fromDate(endDate))
        .get();

    Map<String, Map<String, dynamic>> dailyData = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final unloadedAt = (data['unloadedAt'] as Timestamp).toDate();
      final dateKey =
          '${unloadedAt.year}-${unloadedAt.month.toString().padLeft(2, '0')}-${unloadedAt.day.toString().padLeft(2, '0')}';

      if (!dailyData.containsKey(dateKey)) {
        dailyData[dateKey] = {
          'date': dateKey,
          'revenue': 0.0,
          'expenses': 0.0,
          'orders': 0,
          'quantity': 0,
        };
      }

      dailyData[dateKey]!['revenue'] = ((dailyData[dateKey]!['revenue'] as num)
              .toDouble()) +
          ((data['netValue'] ?? data['totalValue'] ?? 0) as num).toDouble();
      dailyData[dateKey]!['expenses'] = ((dailyData[dateKey]!['expenses']
                  as num)
              .toDouble()) +
          ((data['totalExpenses'] ?? 0) as num).toDouble();
      dailyData[dateKey]!['orders'] =
          ((dailyData[dateKey]!['orders'] as num).toInt()) + 1;
      dailyData[dateKey]!['quantity'] = ((dailyData[dateKey]!['quantity']
                  as num)
              .toInt()) +
          ((data['totalQuantity'] ?? 0) as num).toInt();
    }

    _dailyTrends = dailyData.values.toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  }

  Future<void> _loadProfitabilityAnalysis() async {
    final snapshot = await _firestore
        .collection('unloading')
        .where('unloadedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('unloadedAt', isLessThan: Timestamp.fromDate(endDate))
        .get();

    double totalCostOfGoods = 0;
    double totalSellingPrice = 0;
    double totalDiscountImpact = 0;
    double totalFreeIssueImpact = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final items = data['items'] as List<dynamic>? ?? [];

      for (var item in items) {
        final itemMap = item as Map<String, dynamic>;
        final quantity = ((itemMap['quantity'] ?? 0) as num).toDouble();
        final distributorPrice =
            ((itemMap['distributorPrice'] ?? 0) as num).toDouble();
        final sellingPrice =
            ((itemMap['sellingPrice'] ?? distributorPrice) as num).toDouble();
        final freeIssues =
            ((itemMap['freeIssues'] ?? 0) as num).toDouble();

        totalCostOfGoods += (quantity + freeIssues) * distributorPrice;
        totalSellingPrice += quantity * sellingPrice;
        totalFreeIssueImpact += freeIssues * distributorPrice;
      }

      totalDiscountImpact +=
          ((data['totalDiscounts'] ?? 0) as num).toDouble();
    }

    final grossProfit = totalSellingPrice - totalCostOfGoods;
    final grossMargin =
        totalSellingPrice > 0 ? (grossProfit / totalSellingPrice) * 100 : 0;

    _profitabilityAnalysis = {
      'totalCostOfGoods': totalCostOfGoods,
      'totalSellingPrice': totalSellingPrice,
      'grossProfit': grossProfit,
      'grossMargin': grossMargin,
      'totalDiscountImpact': totalDiscountImpact,
      'totalFreeIssueImpact': totalFreeIssueImpact,
      'netProfit': (_currentPeriodMetrics['netProfit'] ?? 0.0) as double,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Enhanced Business Analytics',
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Trends'),
            Tab(text: 'Profitability'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildTrendsTab(),
                _buildProfitabilityTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadEnhancedAnalytics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateRangeInfo(),
            const SizedBox(height: 16),
            _buildComparisonCards(),
            const SizedBox(height: 24),
            _buildSectionTitle('Key Metrics'),
            const SizedBox(height: 12),
            _buildKeyMetricsGrid(),
            const SizedBox(height: 24),
            _buildSectionTitle('Performance Indicators'),
            const SizedBox(height: 12),
            _buildPerformanceIndicators(),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsTab() {
    if (_dailyTrends.isEmpty) {
      return _buildEmptyState('No trend data available');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTrendsSummary(),
        const SizedBox(height: 16),
        _buildSectionTitle('Daily Performance'),
        const SizedBox(height: 12),
        ..._dailyTrends.map((day) => _buildDayCard(day)).toList(),
      ],
    );
  }

  Widget _buildProfitabilityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Profitability Analysis'),
          const SizedBox(height: 12),
          _buildProfitabilityMetrics(),
          const SizedBox(height: 24),
          _buildSectionTitle('Cost Breakdown'),
          const SizedBox(height: 12),
          _buildCostBreakdown(),
          const SizedBox(height: 24),
          _buildSectionTitle('Impact Analysis'),
          const SizedBox(height: 12),
          _buildImpactAnalysis(),
        ],
      ),
    );
  }

  Widget _buildDateRangeInfo() {
    return Text(
      'Period: ${_formatDate(startDate)} - ${_formatDate(endDate)}',
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey[600],
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildComparisonCards() {
    final currentRevenue =
        (_currentPeriodMetrics['totalRevenue'] ?? 0.0) as double;
    final previousRevenue =
        (_previousPeriodMetrics['totalRevenue'] ?? 0.0) as double;
    final revenueChange = previousRevenue > 0
        ? ((currentRevenue - previousRevenue) / previousRevenue) * 100
        : 0.0;

    final currentProfit =
        (_currentPeriodMetrics['netProfit'] ?? 0.0) as double;
    final previousProfit =
        (_previousPeriodMetrics['netProfit'] ?? 0.0) as double;
    final profitChange = previousProfit > 0
        ? ((currentProfit - previousProfit) / previousProfit) * 100
        : 0.0;

    final currentOrders =
        (_currentPeriodMetrics['totalOrders'] ?? 0) as int;
    final previousOrders =
        (_previousPeriodMetrics['totalOrders'] ?? 0) as int;
    final ordersChange = previousOrders > 0
        ? ((currentOrders - previousOrders) / previousOrders) * 100
        : 0.0;

    return Column(
      children: [
        _buildComparisonCard(
          'Revenue',
          'Rs. ${currentRevenue.toStringAsFixed(2)}',
          revenueChange,
          Icons.monetization_on,
          Colors.green,
        ),
        const SizedBox(height: 12),
        _buildComparisonCard(
          'Net Profit',
          'Rs. ${currentProfit.toStringAsFixed(2)}',
          profitChange,
          Icons.trending_up,
          Colors.blue,
        ),
        const SizedBox(height: 12),
        _buildComparisonCard(
          'Total Orders',
          currentOrders.toString(),
          ordersChange,
          Icons.receipt,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildComparisonCard(String label, String value, double changePercent,
      IconData icon, Color color) {
    final isPositive = changePercent >= 0;
    final changeColor = isPositive ? Colors.green : Colors.red;
    final changeIcon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
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
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: changeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(changeIcon, size: 14, color: changeColor),
                  const SizedBox(width: 4),
                  Text(
                    '${changePercent.abs().toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: changeColor,
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

  Widget _buildKeyMetricsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _buildMetricCard(
          'Avg Order Value',
          'Rs. ${((_currentPeriodMetrics['avgOrderValue'] ?? 0.0) as double).toStringAsFixed(2)}',
          Icons.attach_money,
          Colors.purple,
        ),
        _buildMetricCard(
          'Total Quantity',
          ((_currentPeriodMetrics['totalQuantity'] ?? 0) as int).toString(),
          Icons.inventory,
          Colors.indigo,
        ),
        _buildMetricCard(
          'Unique Customers',
          ((_currentPeriodMetrics['uniqueCustomers'] ?? 0) as int).toString(),
          Icons.people,
          Colors.teal,
        ),
        _buildMetricCard(
          'Profit Margin',
          '${((_currentPeriodMetrics['profitMargin'] ?? 0.0) as double).toStringAsFixed(1)}%',
          Icons.percent,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceIndicators() {
    final totalDiscounts =
        (_currentPeriodMetrics['totalDiscounts'] ?? 0.0) as double;
    final totalFreeIssues =
        (_currentPeriodMetrics['totalFreeIssues'] ?? 0.0) as double;
    final totalReturns = (_currentPeriodMetrics['totalReturns'] ?? 0) as int;
    final totalDamaged = (_currentPeriodMetrics['totalDamaged'] ?? 0) as int;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildIndicatorRow(
              'Total Discounts',
              'Rs. ${totalDiscounts.toStringAsFixed(2)}',
              Icons.local_offer,
              Colors.orange,
            ),
            const Divider(height: 24),
            _buildIndicatorRow(
              'Free Issues',
              '${totalFreeIssues.toStringAsFixed(0)} pcs',
              Icons.card_giftcard,
              Colors.purple,
            ),
            const Divider(height: 24),
            _buildIndicatorRow(
              'Returns',
              '$totalReturns pcs',
              Icons.keyboard_return,
              Colors.red,
            ),
            const Divider(height: 24),
            _buildIndicatorRow(
              'Damaged Items',
              '$totalDamaged pcs',
              Icons.broken_image,
              Colors.red[700]!,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicatorRow(
      String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
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

  Widget _buildTrendsSummary() {
    if (_dailyTrends.isEmpty) return const SizedBox.shrink();

    final avgDailyRevenue = _dailyTrends.fold<double>(
            0, (sum, day) => sum + ((day['revenue'] as num).toDouble())) /
        _dailyTrends.length;
    final avgDailyOrders = _dailyTrends.fold<int>(
            0, (sum, day) => sum + ((day['orders'] as num).toInt())) /
        _dailyTrends.length;

    final maxRevenueDay = _dailyTrends.reduce((a, b) =>
        ((a['revenue'] as num).toDouble()) >
                ((b['revenue'] as num).toDouble())
            ? a
            : b);

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
                  child: _buildSmallStat(
                    'Avg Daily Revenue',
                    'Rs. ${avgDailyRevenue.toStringAsFixed(2)}',
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSmallStat(
                    'Avg Daily Orders',
                    avgDailyOrders.toStringAsFixed(0),
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildIndicatorRow(
              'Best Day',
              maxRevenueDay['date'],
              Icons.star,
              Colors.amber,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCard(Map<String, dynamic> day) {
    final revenue = (day['revenue'] as num).toDouble();
    final expenses = (day['expenses'] as num).toDouble();
    final profit = revenue - expenses;
    final orders = (day['orders'] as num).toInt();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  day['date'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$orders orders',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSmallStat('Revenue',
                    'Rs. ${revenue.toStringAsFixed(2)}', Colors.green),
                _buildSmallStat('Profit',
                    'Rs. ${profit.toStringAsFixed(2)}', Colors.blue),
                _buildSmallStat('Qty', day['quantity'].toString(),
                    Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitabilityMetrics() {
    final grossProfit =
        (_profitabilityAnalysis['grossProfit'] ?? 0.0) as double;
    final grossMargin =
        (_profitabilityAnalysis['grossMargin'] ?? 0.0) as double;
    final netProfit = (_profitabilityAnalysis['netProfit'] ?? 0.0) as double;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildIndicatorRow(
              'Gross Profit',
              'Rs. ${grossProfit.toStringAsFixed(2)}',
              Icons.trending_up,
              Colors.green,
            ),
            const Divider(height: 24),
            _buildIndicatorRow(
              'Gross Margin',
              '${grossMargin.toStringAsFixed(1)}%',
              Icons.percent,
              Colors.blue,
            ),
            const Divider(height: 24),
            _buildIndicatorRow(
              'Net Profit',
              'Rs. ${netProfit.toStringAsFixed(2)}',
              Icons.account_balance,
              netProfit >= 0 ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostBreakdown() {
    final costOfGoods =
        (_profitabilityAnalysis['totalCostOfGoods'] ?? 0.0) as double;
    final sellingPrice =
        (_profitabilityAnalysis['totalSellingPrice'] ?? 0.0) as double;
    final expenses = (_currentPeriodMetrics['totalExpenses'] ?? 0.0) as double;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildIndicatorRow(
              'Cost of Goods Sold',
              'Rs. ${costOfGoods.toStringAsFixed(2)}',
              Icons.inventory_2,
              Colors.orange,
            ),
            const Divider(height: 24),
            _buildIndicatorRow(
              'Total Selling Price',
              'Rs. ${sellingPrice.toStringAsFixed(2)}',
              Icons.point_of_sale,
              Colors.green,
            ),
            const Divider(height: 24),
            _buildIndicatorRow(
              'Operating Expenses',
              'Rs. ${expenses.toStringAsFixed(2)}',
              Icons.account_balance_wallet,
              Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImpactAnalysis() {
    final discountImpact =
        (_profitabilityAnalysis['totalDiscountImpact'] ?? 0.0) as double;
    final freeIssueImpact =
        (_profitabilityAnalysis['totalFreeIssueImpact'] ?? 0.0) as double;
    final totalImpact = discountImpact + freeIssueImpact;
    final revenue = (_currentPeriodMetrics['totalRevenue'] ?? 0.0) as double;
    final impactPercent =
        revenue > 0 ? (totalImpact / (revenue + totalImpact)) * 100 : 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Revenue Impact Analysis',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            _buildIndicatorRow(
              'Discount Impact',
              'Rs. ${discountImpact.toStringAsFixed(2)}',
              Icons.local_offer,
              Colors.orange,
            ),
            const Divider(height: 24),
            _buildIndicatorRow(
              'Free Issue Impact',
              'Rs. ${freeIssueImpact.toStringAsFixed(2)}',
              Icons.card_giftcard,
              Colors.purple,
            ),
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Impact',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Rs. ${totalImpact.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                      Text(
                        '${impactPercent.toStringAsFixed(1)}% of potential revenue',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
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

  Widget _buildSmallStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
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
      _loadEnhancedAnalytics();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
