import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ItemPerformanceScreen extends StatefulWidget {
  const ItemPerformanceScreen({super.key});

  @override
  State<ItemPerformanceScreen> createState() => _ItemPerformanceScreenState();
}

class _ItemPerformanceScreenState extends State<ItemPerformanceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime endDate = DateTime.now();
  String? selectedRouteId;
  String? selectedDistributionId;
  bool _isLoading = false;

  List<Map<String, dynamic>> _itemPerformanceData = [];
  Map<String, dynamic>? _routeDetails;
  Map<String, dynamic>? _distributionDetails;

  @override
  void initState() {
    super.initState();
    _loadItemPerformance();
  }

  Future<void> _loadItemPerformance() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Build query based on filters
      var query = _firestore
          .collection('unloading')
          .where(
            'unloadedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where('unloadedAt', isLessThan: Timestamp.fromDate(endDate));

      if (selectedRouteId != null) {
        query = query.where('routeId', isEqualTo: selectedRouteId);

        // Load route details
        final routeDoc = await _firestore.collection('routes').doc(selectedRouteId).get();
        if (routeDoc.exists) {
          _routeDetails = {'id': routeDoc.id, ...routeDoc.data()!};
        }
      }

      if (selectedDistributionId != null) {
        query = query.where('distributionId', isEqualTo: selectedDistributionId);

        // Load distribution details
        final distDoc = await _firestore.collection('distributions').doc(selectedDistributionId).get();
        if (distDoc.exists) {
          _distributionDetails = {'id': distDoc.id, ...distDoc.data()!};
        }
      }

      final snapshot = await query.get();

      // Aggregate item data
      Map<String, Map<String, dynamic>> itemsMap = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final items = data['items'] as List<dynamic>? ?? [];

        for (var item in items) {
          final itemMap = item as Map<String, dynamic>;
          final itemId = itemMap['itemId'] ?? 'unknown';
          final productName = itemMap['productName'] ?? 'Unknown';
          final productCode = itemMap['productCode'] ?? '';
          final quantity = (itemMap['quantity'] ?? 0) as num;
          final value = ((itemMap['sellingPrice'] ?? itemMap['distributorPrice'] ?? 0) as num).toDouble() * quantity.toDouble();
          final freeIssues = (itemMap['freeIssues'] ?? 0) as num;
          final returns = (itemMap['returns'] ?? 0) as num;
          final damaged = (itemMap['damaged'] ?? 0) as num;

          if (itemsMap.containsKey(itemId)) {
            itemsMap[itemId]!['totalQuantity'] =
                ((itemsMap[itemId]!['totalQuantity'] as num).toDouble()) + quantity.toDouble();
            itemsMap[itemId]!['totalValue'] =
                ((itemsMap[itemId]!['totalValue'] as num).toDouble()) + value;
            itemsMap[itemId]!['totalFreeIssues'] =
                ((itemsMap[itemId]!['totalFreeIssues'] as num).toDouble()) + freeIssues.toDouble();
            itemsMap[itemId]!['totalReturns'] =
                ((itemsMap[itemId]!['totalReturns'] as num).toDouble()) + returns.toDouble();
            itemsMap[itemId]!['totalDamaged'] =
                ((itemsMap[itemId]!['totalDamaged'] as num).toDouble()) + damaged.toDouble();
            itemsMap[itemId]!['transactionCount'] =
                ((itemsMap[itemId]!['transactionCount'] as num).toInt()) + 1;
          } else {
            itemsMap[itemId] = {
              'itemId': itemId,
              'productName': productName,
              'productCode': productCode,
              'totalQuantity': quantity,
              'totalValue': value,
              'totalFreeIssues': freeIssues,
              'totalReturns': returns,
              'totalDamaged': damaged,
              'transactionCount': 1,
            };
          }
        }
      }

      // Convert to list and sort by value
      final itemsList = itemsMap.values.toList();
      itemsList.sort((a, b) => ((b['totalValue'] as num).toDouble()).compareTo((a['totalValue'] as num).toDouble()));

      setState(() {
        _itemPerformanceData = itemsList;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Item Performance',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Summary
          _buildFilterSummary(),

          // Statistics Summary
          if (_itemPerformanceData.isNotEmpty) _buildStatisticsSummary(),

          // Items List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _itemPerformanceData.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _itemPerformanceData.length,
                        itemBuilder: (context, index) {
                          final item = _itemPerformanceData[index];
                          return _buildItemCard(item, index + 1);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Period: ${_formatDate(startDate)} - ${_formatDate(endDate)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    if (selectedRouteId != null && _routeDetails != null)
                      Text(
                        'Route: ${_routeDetails!['routeName']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    if (selectedDistributionId != null && _distributionDetails != null)
                      Text(
                        'Distribution: ${_distributionDetails!['name']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _showFilterDialog,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Filters'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSummary() {
    final totalItems = _itemPerformanceData.length;
    final totalValue = _itemPerformanceData.fold<double>(
      0, (sum, item) => sum + ((item['totalValue'] as num).toDouble()),
    );
    final totalQuantity = _itemPerformanceData.fold<num>(
      0, (sum, item) => sum + (item['totalQuantity'] as num),
    );
    final totalTransactions = _itemPerformanceData.fold<num>(
      0, (sum, item) => sum + (item['transactionCount'] as num),
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[400]!, Colors.indigo[600]!],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard('Items', totalItems.toString(), Icons.inventory_2),
              _buildStatCard('Quantity', totalQuantity.toString(), Icons.numbers),
              _buildStatCard('Orders', totalTransactions.toString(), Icons.receipt),
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
                const Icon(Icons.attach_money, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Total Revenue: ',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  'Rs. ${totalValue.toStringAsFixed(2)}',
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

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, int rank) {
    final totalValue = (item['totalValue'] as num).toDouble();
    final totalQuantity = (item['totalQuantity'] as num).toInt();
    final totalFreeIssues = (item['totalFreeIssues'] as num).toInt();
    final totalReturns = (item['totalReturns'] as num).toInt();
    final totalDamaged = (item['totalDamaged'] as num).toInt();
    final transactionCount = (item['transactionCount'] as num).toInt();
    final avgPerTransaction = transactionCount > 0 ? totalValue / transactionCount : 0;

    Color rankColor = rank <= 3 ? Colors.amber : Colors.grey;
    IconData rankIcon = rank == 1
        ? Icons.emoji_events
        : rank == 2
            ? Icons.military_tech
            : rank == 3
                ? Icons.star
                : Icons.circle;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: rank <= 3 ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: rank <= 3
            ? BorderSide(color: rankColor, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(rankIcon, color: rankColor, size: 20),
                const SizedBox(width: 8),
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
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildMetric(
                    'Revenue',
                    'Rs. ${totalValue.toStringAsFixed(2)}',
                    Icons.monetization_on,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildMetric(
                    'Quantity Sold',
                    totalQuantity.toString(),
                    Icons.shopping_cart,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetric(
                    'Avg/Order',
                    'Rs. ${avgPerTransaction.toStringAsFixed(2)}',
                    Icons.trending_up,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildMetric(
                    'Orders',
                    transactionCount.toString(),
                    Icons.receipt,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            if (totalFreeIssues > 0 || totalReturns > 0 || totalDamaged > 0) ...[
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
                    if (totalFreeIssues > 0)
                      _buildSmallMetric('FOC', totalFreeIssues.toString(), Colors.orange),
                    if (totalReturns > 0)
                      _buildSmallMetric('Returns', totalReturns.toString(), Colors.red),
                    if (totalDamaged > 0)
                      _buildSmallMetric('Damaged', totalDamaged.toString(), Colors.red[700]!),
                  ],
                ),
              ),
            ],
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

  Widget _buildSmallMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No data available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        startDate: startDate,
        endDate: endDate,
        selectedRouteId: selectedRouteId,
        selectedDistributionId: selectedDistributionId,
        onApply: (newStartDate, newEndDate, routeId, distributionId) {
          setState(() {
            startDate = newStartDate;
            endDate = newEndDate;
            selectedRouteId = routeId;
            selectedDistributionId = distributionId;
          });
          _loadItemPerformance();
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _FilterDialog extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final String? selectedRouteId;
  final String? selectedDistributionId;
  final Function(DateTime, DateTime, String?, String?) onApply;

  const _FilterDialog({
    required this.startDate,
    required this.endDate,
    this.selectedRouteId,
    this.selectedDistributionId,
    required this.onApply,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late DateTime startDate;
  late DateTime endDate;
  String? selectedRouteId;
  String? selectedDistributionId;

  @override
  void initState() {
    super.initState();
    startDate = widget.startDate;
    endDate = widget.endDate;
    selectedRouteId = widget.selectedRouteId;
    selectedDistributionId = widget.selectedDistributionId;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Options'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Date Range', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Start Date'),
              subtitle: Text(_formatDate(startDate)),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: startDate,
                  firstDate: DateTime(2020),
                  lastDate: endDate,
                );
                if (date != null) {
                  setState(() {
                    startDate = date;
                  });
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('End Date'),
              subtitle: Text(_formatDate(endDate)),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: endDate,
                  firstDate: startDate,
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    endDate = date;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            const Text('Filters', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('distributions')
                  .where('status', isEqualTo: 'active')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final distributions = snapshot.data!.docs;

                return DropdownButtonFormField<String>(
                  value: selectedDistributionId,
                  decoration: const InputDecoration(
                    labelText: 'Distribution (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Distributions'),
                    ),
                    ...distributions.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(data['name'] ?? 'Unknown'),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedDistributionId = value;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('routes')
                  .where('status', isEqualTo: 'active')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final routes = snapshot.data!.docs;

                return DropdownButtonFormField<String>(
                  value: selectedRouteId,
                  decoration: const InputDecoration(
                    labelText: 'Route (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Routes'),
                    ),
                    ...routes.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text('${data['routeCode']} - ${data['routeName']}'),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedRouteId = value;
                    });
                  },
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(startDate, endDate, selectedRouteId, selectedDistributionId);
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
