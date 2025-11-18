import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryRecommendationsScreen extends StatefulWidget {
  const InventoryRecommendationsScreen({super.key});

  @override
  State<InventoryRecommendationsScreen> createState() =>
      _InventoryRecommendationsScreenState();
}

class _InventoryRecommendationsScreenState
    extends State<InventoryRecommendationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  int daysToAnalyze = 30;
  int daysToProject = 7;

  List<Map<String, dynamic>> _recommendations = [];
  Map<String, int> _currentStock = {};

  @override
  void initState() {
    super.initState();
    _generateRecommendations();
  }

  Future<void> _generateRecommendations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Get current stock levels
      final stockSnapshot = await _firestore
          .collection('stock')
          .where('status', isEqualTo: 'active')
          .get();

      Map<String, int> currentStock = {};
      Map<String, Map<String, dynamic>> itemDetails = {};

      for (var doc in stockSnapshot.docs) {
        final data = doc.data();
        final itemId = data['itemId'];
        final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
        currentStock[itemId] = (currentStock[itemId] ?? 0) + quantity;

        if (!itemDetails.containsKey(itemId)) {
          itemDetails[itemId] = {
            'productName': data['productName'],
            'productCode': data['productCode'],
            'unitsPerCase': data['unitsPerCase'] ?? 1,
            'distributorPrice': data['distributorPrice'] ?? 0,
          };
        }
      }

      // 2. Analyze sales history
      final startDate = DateTime.now().subtract(Duration(days: daysToAnalyze));
      final unloadingSnapshot = await _firestore
          .collection('unloading')
          .where('unloadedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      Map<String, Map<String, dynamic>> salesData = {};

      for (var doc in unloadingSnapshot.docs) {
        final data = doc.data();
        final items = data['items'] as List<dynamic>? ?? [];

        for (var item in items) {
          final itemMap = item as Map<String, dynamic>;
          final itemId = itemMap['itemId'] ?? 'unknown';
          final quantity = (itemMap['quantity'] ?? 0) as num;
          final returns = (itemMap['returns'] ?? 0) as num;
          final damaged = (itemMap['damaged'] ?? 0) as num;

          if (!salesData.containsKey(itemId)) {
            salesData[itemId] = {
              'totalSold': 0,
              'totalReturns': 0,
              'totalDamaged': 0,
              'salesCount': 0,
            };
          }

          salesData[itemId]!['totalSold'] =
              ((salesData[itemId]!['totalSold'] as num).toDouble()) + quantity.toDouble();
          salesData[itemId]!['totalReturns'] =
              ((salesData[itemId]!['totalReturns'] as num).toDouble()) + returns.toDouble();
          salesData[itemId]!['totalDamaged'] =
              ((salesData[itemId]!['totalDamaged'] as num).toDouble()) + damaged.toDouble();
          salesData[itemId]!['salesCount'] =
              ((salesData[itemId]!['salesCount'] as num).toInt()) + 1;
        }
      }

      // 3. Calculate recommendations
      List<Map<String, dynamic>> recommendations = [];

      for (var itemId in {...currentStock.keys, ...salesData.keys}) {
        final stock = currentStock[itemId] ?? 0;
        final sales = salesData[itemId];

        if (sales == null) {
          // Item has stock but no sales history - low priority
          if (stock > 0) {
            recommendations.add({
              'itemId': itemId,
              'productName': itemDetails[itemId]?['productName'] ?? 'Unknown',
              'productCode': itemDetails[itemId]?['productCode'] ?? '',
              'currentStock': stock,
              'avgDailySales': 0.0,
              'daysOfStock': double.infinity,
              'recommendedOrder': 0,
              'priority': 'low',
              'reason': 'No recent sales',
              'unitsPerCase': itemDetails[itemId]?['unitsPerCase'] ?? 1,
              'distributorPrice': itemDetails[itemId]?['distributorPrice'] ?? 0,
            });
          }
          continue;
        }

        final totalSold = (sales['totalSold'] as num).toDouble();
        final avgDailySales = totalSold / daysToAnalyze;
        final daysOfStock = avgDailySales > 0 ? stock / avgDailySales : double.infinity;
        final projectedNeed = avgDailySales * daysToProject;
        final recommendedOrder = (projectedNeed - stock).ceil();

        String priority;
        String reason;

        if (daysOfStock <= 2) {
          priority = 'critical';
          reason = 'Stock critical - ${daysOfStock.toStringAsFixed(1)} days remaining';
        } else if (daysOfStock <= 5) {
          priority = 'high';
          reason = 'Low stock - ${daysOfStock.toStringAsFixed(1)} days remaining';
        } else if (daysOfStock <= 10) {
          priority = 'medium';
          reason = 'Moderate stock - ${daysOfStock.toStringAsFixed(1)} days remaining';
        } else {
          priority = 'low';
          reason = 'Sufficient stock - ${daysOfStock.toStringAsFixed(1)} days remaining';
        }

        recommendations.add({
          'itemId': itemId,
          'productName': itemDetails[itemId]?['productName'] ?? 'Unknown',
          'productCode': itemDetails[itemId]?['productCode'] ?? '',
          'currentStock': stock,
          'avgDailySales': avgDailySales,
          'daysOfStock': daysOfStock,
          'recommendedOrder': recommendedOrder > 0 ? recommendedOrder : 0,
          'priority': priority,
          'reason': reason,
          'totalReturns': sales['totalReturns'],
          'totalDamaged': sales['totalDamaged'],
          'unitsPerCase': itemDetails[itemId]?['unitsPerCase'] ?? 1,
          'distributorPrice': itemDetails[itemId]?['distributorPrice'] ?? 0,
        });
      }

      // Sort by priority
      final priorityOrder = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3};
      recommendations.sort((a, b) {
        final priorityCompare = priorityOrder[a['priority']]!
            .compareTo(priorityOrder[b['priority']]!);
        if (priorityCompare != 0) return priorityCompare;
        return ((a['daysOfStock'] as num).toDouble())
            .compareTo((b['daysOfStock'] as num).toDouble());
      });

      setState(() {
        _recommendations = recommendations;
        _currentStock = currentStock;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating recommendations: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Order Recommendations',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Card
          _buildSummaryCard(),

          // Recommendations List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _recommendations.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _recommendations.length,
                        itemBuilder: (context, index) {
                          final item = _recommendations[index];
                          return _buildRecommendationCard(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final critical = _recommendations.where((r) => r['priority'] == 'critical').length;
    final high = _recommendations.where((r) => r['priority'] == 'high').length;
    final medium = _recommendations.where((r) => r['priority'] == 'medium').length;
    final totalOrderValue = _recommendations.fold<double>(
      0,
      (sum, item) {
        final recommendedOrder = (item['recommendedOrder'] as int).toDouble();
        final price = (item['distributorPrice'] as num).toDouble();
        return sum + (recommendedOrder * price);
      },
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal[400]!, Colors.teal[600]!],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Analysis Period: Last $daysToAnalyze days',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            'Projection: Next $daysToProject days',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPriorityBadge('Critical', critical, Colors.red[300]!),
              _buildPriorityBadge('High', high, Colors.orange[300]!),
              _buildPriorityBadge('Medium', medium, Colors.yellow[300]!),
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
                const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Est. Order Value: ',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  'Rs. ${totalOrderValue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
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

  Widget _buildPriorityBadge(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> item) {
    final priority = item['priority'] as String;
    final currentStock = (item['currentStock'] as num).toInt();
    final avgDailySales = (item['avgDailySales'] as num).toDouble();
    final daysOfStock = (item['daysOfStock'] as num).toDouble();
    final recommendedOrder = (item['recommendedOrder'] as num).toInt();
    final unitsPerCase = (item['unitsPerCase'] as num).toInt();
    final distributorPrice = (item['distributorPrice'] as num).toDouble();

    Color priorityColor;
    IconData priorityIcon;

    switch (priority) {
      case 'critical':
        priorityColor = Colors.red;
        priorityIcon = Icons.error;
        break;
      case 'high':
        priorityColor = Colors.orange;
        priorityIcon = Icons.warning;
        break;
      case 'medium':
        priorityColor = Colors.yellow[700]!;
        priorityIcon = Icons.info;
        break;
      default:
        priorityColor = Colors.green;
        priorityIcon = Icons.check_circle;
    }

    final recommendedCases = recommendedOrder ~/ unitsPerCase;
    final recommendedPieces = recommendedOrder % unitsPerCase;
    final orderValue = recommendedOrder * distributorPrice;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: priority == 'critical' ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: priority == 'critical' || priority == 'high'
            ? BorderSide(color: priorityColor, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(priorityIcon, color: priorityColor, size: 20),
                const SizedBox(width: 8),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: priorityColor,
                    ),
                  ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current Stock:',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      Text(
                        '$currentStock pcs',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Avg Daily Sales:',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      Text(
                        '${avgDailySales.toStringAsFixed(1)} pcs/day',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Days of Stock:',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      Text(
                        daysOfStock.isFinite
                            ? '${daysOfStock.toStringAsFixed(1)} days'
                            : '∞ days',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: priorityColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (recommendedOrder > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shopping_bag, color: Colors.blue[700], size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Recommended Order',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$recommendedCases cases + $recommendedPieces pcs',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '($recommendedOrder pcs)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Est. Cost:',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Rs. ${orderValue.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item['reason'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
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
            'No recommendations available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add stock and record sales to get insights',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    int tempDaysToAnalyze = daysToAnalyze;
    int tempDaysToProject = daysToProject;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Analysis Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Days to Analyze'),
                subtitle: Text('$tempDaysToAnalyze days'),
                trailing: SizedBox(
                  width: 150,
                  child: Slider(
                    value: tempDaysToAnalyze.toDouble(),
                    min: 7,
                    max: 90,
                    divisions: 11,
                    label: '$tempDaysToAnalyze days',
                    onChanged: (value) {
                      setState(() {
                        tempDaysToAnalyze = value.toInt();
                      });
                    },
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Days to Project'),
                subtitle: Text('$tempDaysToProject days'),
                trailing: SizedBox(
                  width: 150,
                  child: Slider(
                    value: tempDaysToProject.toDouble(),
                    min: 3,
                    max: 30,
                    divisions: 9,
                    label: '$tempDaysToProject days',
                    onChanged: (value) {
                      setState(() {
                        tempDaysToProject = value.toInt();
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                this.setState(() {
                  daysToAnalyze = tempDaysToAnalyze;
                  daysToProject = tempDaysToProject;
                });
                Navigator.pop(context);
                _generateRecommendations();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}
