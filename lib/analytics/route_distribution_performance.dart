import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RouteDistributionPerformanceScreen extends StatefulWidget {
  const RouteDistributionPerformanceScreen({super.key});

  @override
  State<RouteDistributionPerformanceScreen> createState() =>
      _RouteDistributionPerformanceScreenState();
}

class _RouteDistributionPerformanceScreenState
    extends State<RouteDistributionPerformanceScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;
  DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime endDate = DateTime.now();
  bool _isLoading = false;

  List<Map<String, dynamic>> _routePerformance = [];
  List<Map<String, dynamic>> _distributionPerformance = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPerformanceData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPerformanceData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadRoutePerformance(),
        _loadDistributionPerformance(),
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

  Future<void> _loadRoutePerformance() async {
    final unloadingSnapshot = await _firestore
        .collection('unloading')
        .where('unloadedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('unloadedAt', isLessThan: Timestamp.fromDate(endDate))
        .get();

    Map<String, Map<String, dynamic>> routesMap = {};

    for (var doc in unloadingSnapshot.docs) {
      final data = doc.data();
      final routeId = data['routeId'] ?? 'unknown';
      final totalValue = ((data['netValue'] ?? data['totalValue'] ?? 0) as num).toDouble();
      final totalQuantity = ((data['totalQuantity'] ?? 0) as num).toInt();
      final totalExpenses = ((data['totalExpenses'] ?? 0) as num).toDouble();
      final items = data['items'] as List<dynamic>? ?? [];
      final uniqueItems = items.map((i) => (i as Map<String, dynamic>)['itemId']).toSet().length;

      if (!routesMap.containsKey(routeId)) {
        routesMap[routeId] = {
          'routeId': routeId,
          'totalRevenue': 0.0,
          'totalExpenses': 0.0,
          'totalQuantity': 0,
          'tripCount': 0,
          'uniqueItems': <String>{},
        };
      }

      routesMap[routeId]!['totalRevenue'] =
          (routesMap[routeId]!['totalRevenue'] as double) + totalValue;
      routesMap[routeId]!['totalExpenses'] =
          (routesMap[routeId]!['totalExpenses'] as double) + totalExpenses;
      routesMap[routeId]!['totalQuantity'] =
          (routesMap[routeId]!['totalQuantity'] as int) + totalQuantity;
      routesMap[routeId]!['tripCount'] =
          (routesMap[routeId]!['tripCount'] as int) + 1;

      for (var item in items) {
        final itemId = (item as Map<String, dynamic>)['itemId'];
        (routesMap[routeId]!['uniqueItems'] as Set<String>).add(itemId);
      }
    }

    // Load route details
    final routesList = <Map<String, dynamic>>[];
    for (var entry in routesMap.entries) {
      final routeId = entry.key;
      final data = entry.value;

      String routeName = 'Unknown Route';
      String routeCode = '';

      if (routeId != 'unknown') {
        try {
          final routeDoc = await _firestore.collection('routes').doc(routeId).get();
          if (routeDoc.exists) {
            final routeData = routeDoc.data()!;
            routeName = routeData['routeName'] ?? 'Unknown';
            routeCode = routeData['routeCode'] ?? '';
          }
        } catch (e) {
          // Ignore
        }
      }

      final totalRevenue = (data['totalRevenue'] as double);
      final totalExpenses = (data['totalExpenses'] as double);
      final netProfit = totalRevenue - totalExpenses;
      final tripCount = (data['tripCount'] as int);
      final avgRevenuePerTrip = tripCount > 0 ? totalRevenue / tripCount : 0.0;
      final profitMargin = totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0.0;

      routesList.add({
        'routeId': routeId,
        'routeName': routeName,
        'routeCode': routeCode,
        'totalRevenue': totalRevenue,
        'totalExpenses': totalExpenses,
        'netProfit': netProfit,
        'totalQuantity': data['totalQuantity'],
        'tripCount': tripCount,
        'uniqueItems': (data['uniqueItems'] as Set<String>).length,
        'avgRevenuePerTrip': avgRevenuePerTrip,
        'profitMargin': profitMargin,
      });
    }

    routesList.sort((a, b) => (b['totalRevenue'] as double).compareTo(a['totalRevenue'] as double));
    _routePerformance = routesList;
  }

  Future<void> _loadDistributionPerformance() async {
    final unloadingSnapshot = await _firestore
        .collection('unloading')
        .where('unloadedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('unloadedAt', isLessThan: Timestamp.fromDate(endDate))
        .get();

    Map<String, Map<String, dynamic>> distributionsMap = {};

    for (var doc in unloadingSnapshot.docs) {
      final data = doc.data();
      final distributionId = data['distributionId'] ?? 'unknown';
      final totalValue = ((data['netValue'] ?? data['totalValue'] ?? 0) as num).toDouble();
      final totalQuantity = ((data['totalQuantity'] ?? 0) as num).toInt();
      final totalExpenses = ((data['totalExpenses'] ?? 0) as num).toDouble();

      if (!distributionsMap.containsKey(distributionId)) {
        distributionsMap[distributionId] = {
          'distributionId': distributionId,
          'totalRevenue': 0.0,
          'totalExpenses': 0.0,
          'totalQuantity': 0,
          'deliveryCount': 0,
        };
      }

      distributionsMap[distributionId]!['totalRevenue'] =
          (distributionsMap[distributionId]!['totalRevenue'] as double) + totalValue;
      distributionsMap[distributionId]!['totalExpenses'] =
          (distributionsMap[distributionId]!['totalExpenses'] as double) + totalExpenses;
      distributionsMap[distributionId]!['totalQuantity'] =
          (distributionsMap[distributionId]!['totalQuantity'] as int) + totalQuantity;
      distributionsMap[distributionId]!['deliveryCount'] =
          (distributionsMap[distributionId]!['deliveryCount'] as int) + 1;
    }

    // Load distribution details
    final distributionsList = <Map<String, dynamic>>[];
    for (var entry in distributionsMap.entries) {
      final distributionId = entry.key;
      final data = entry.value;

      String distributionName = 'Unknown Distribution';

      if (distributionId != 'unknown') {
        try {
          final distDoc = await _firestore.collection('distributions').doc(distributionId).get();
          if (distDoc.exists) {
            final distData = distDoc.data()!;
            distributionName = distData['name'] ?? 'Unknown';
          }
        } catch (e) {
          // Ignore
        }
      }

      final totalRevenue = (data['totalRevenue'] as double);
      final totalExpenses = (data['totalExpenses'] as double);
      final netProfit = totalRevenue - totalExpenses;
      final deliveryCount = (data['deliveryCount'] as int);
      final avgRevenuePerDelivery = deliveryCount > 0 ? totalRevenue / deliveryCount : 0.0;
      final profitMargin = totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0.0;

      distributionsList.add({
        'distributionId': distributionId,
        'distributionName': distributionName,
        'totalRevenue': totalRevenue,
        'totalExpenses': totalExpenses,
        'netProfit': netProfit,
        'totalQuantity': data['totalQuantity'],
        'deliveryCount': deliveryCount,
        'avgRevenuePerDelivery': avgRevenuePerDelivery,
        'profitMargin': profitMargin,
      });
    }

    distributionsList.sort((a, b) =>
        (b['totalRevenue'] as double).compareTo(a['totalRevenue'] as double));
    _distributionPerformance = distributionsList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Route & Distribution Performance',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.purple,
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
            Tab(text: 'Routes'),
            Tab(text: 'Distributions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRoutePerformanceTab(),
          _buildDistributionPerformanceTab(),
        ],
      ),
    );
  }

  Widget _buildRoutePerformanceTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_routePerformance.isEmpty) {
      return _buildEmptyState('No route data available');
    }

    final totalRevenue = _routePerformance.fold<double>(
      0, (sum, r) => sum + (r['totalRevenue'] as double),
    );
    final totalProfit = _routePerformance.fold<double>(
      0, (sum, r) => sum + (r['netProfit'] as double),
    );

    return Column(
      children: [
        _buildSummaryHeader(
          'Total Routes',
          _routePerformance.length.toString(),
          'Revenue',
          'Rs. ${totalRevenue.toStringAsFixed(2)}',
          'Profit',
          'Rs. ${totalProfit.toStringAsFixed(2)}',
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _routePerformance.length,
            itemBuilder: (context, index) {
              final route = _routePerformance[index];
              return _buildRouteCard(route, index + 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionPerformanceTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_distributionPerformance.isEmpty) {
      return _buildEmptyState('No distribution data available');
    }

    final totalRevenue = _distributionPerformance.fold<double>(
      0, (sum, d) => sum + (d['totalRevenue'] as double),
    );
    final totalProfit = _distributionPerformance.fold<double>(
      0, (sum, d) => sum + (d['netProfit'] as double),
    );

    return Column(
      children: [
        _buildSummaryHeader(
          'Total Distributions',
          _distributionPerformance.length.toString(),
          'Revenue',
          'Rs. ${totalRevenue.toStringAsFixed(2)}',
          'Profit',
          'Rs. ${totalProfit.toStringAsFixed(2)}',
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _distributionPerformance.length,
            itemBuilder: (context, index) {
              final distribution = _distributionPerformance[index];
              return _buildDistributionCard(distribution, index + 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryHeader(
    String label1,
    String value1,
    String label2,
    String value2,
    String label3,
    String value3,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[400]!, Colors.purple[600]!],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildHeaderMetric(label1, value1),
          Container(width: 1, height: 40, color: Colors.white30),
          _buildHeaderMetric(label2, value2),
          Container(width: 1, height: 40, color: Colors.white30),
          _buildHeaderMetric(label3, value3),
        ],
      ),
    );
  }

  Widget _buildHeaderMetric(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route, int rank) {
    final totalRevenue = (route['totalRevenue'] as double);
    final totalExpenses = (route['totalExpenses'] as double);
    final netProfit = (route['netProfit'] as double);
    final tripCount = (route['tripCount'] as int);
    final avgRevenuePerTrip = (route['avgRevenuePerTrip'] as double);
    final profitMargin = (route['profitMargin'] as double);
    final uniqueItems = (route['uniqueItems'] as int);

    final isTop = rank <= 3;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isTop ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isTop ? BorderSide(color: Colors.amber, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isTop)
                  Icon(
                    rank == 1 ? Icons.emoji_events : Icons.star,
                    color: Colors.amber,
                    size: 20,
                  ),
                if (isTop) const SizedBox(width: 8),
                Text(
                  '#$rank',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isTop ? Colors.amber : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route['routeName'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (route['routeCode'].isNotEmpty)
                        Text(
                          route['routeCode'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: profitMargin >= 20
                        ? Colors.green[100]
                        : profitMargin >= 10
                            ? Colors.orange[100]
                            : Colors.red[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${profitMargin.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: profitMargin >= 20
                          ? Colors.green[700]
                          : profitMargin >= 10
                              ? Colors.orange[700]
                              : Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildMetric(
                    'Revenue',
                    'Rs. ${totalRevenue.toStringAsFixed(2)}',
                    Icons.monetization_on,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildMetric(
                    'Profit',
                    'Rs. ${netProfit.toStringAsFixed(2)}',
                    Icons.trending_up,
                    netProfit >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetric(
                    'Trips',
                    tripCount.toString(),
                    Icons.local_shipping,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildMetric(
                    'Avg/Trip',
                    'Rs. ${avgRevenuePerTrip.toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSmallStat('Items', uniqueItems.toString()),
                  _buildSmallStat('Expenses', 'Rs. ${totalExpenses.toStringAsFixed(0)}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionCard(Map<String, dynamic> distribution, int rank) {
    final totalRevenue = (distribution['totalRevenue'] as double);
    final totalExpenses = (distribution['totalExpenses'] as double);
    final netProfit = (distribution['netProfit'] as double);
    final deliveryCount = (distribution['deliveryCount'] as int);
    final avgRevenuePerDelivery = (distribution['avgRevenuePerDelivery'] as double);
    final profitMargin = (distribution['profitMargin'] as double);

    final isTop = rank <= 3;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isTop ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isTop ? BorderSide(color: Colors.amber, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isTop)
                  Icon(
                    rank == 1 ? Icons.emoji_events : Icons.star,
                    color: Colors.amber,
                    size: 20,
                  ),
                if (isTop) const SizedBox(width: 8),
                Text(
                  '#$rank',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isTop ? Colors.amber : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    distribution['distributionName'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: profitMargin >= 20
                        ? Colors.green[100]
                        : profitMargin >= 10
                            ? Colors.orange[100]
                            : Colors.red[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${profitMargin.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: profitMargin >= 20
                          ? Colors.green[700]
                          : profitMargin >= 10
                              ? Colors.orange[700]
                              : Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildMetric(
                    'Revenue',
                    'Rs. ${totalRevenue.toStringAsFixed(2)}',
                    Icons.monetization_on,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildMetric(
                    'Profit',
                    'Rs. ${netProfit.toStringAsFixed(2)}',
                    Icons.trending_up,
                    netProfit >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetric(
                    'Deliveries',
                    deliveryCount.toString(),
                    Icons.local_shipping,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildMetric(
                    'Avg/Delivery',
                    'Rs. ${avgRevenuePerDelivery.toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSmallStat('Quantity', distribution['totalQuantity'].toString()),
                  _buildSmallStat('Expenses', 'Rs. ${totalExpenses.toStringAsFixed(0)}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
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

  Widget _buildSmallStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
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
      _loadPerformanceData();
    }
  }
}
