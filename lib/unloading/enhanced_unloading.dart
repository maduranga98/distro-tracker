import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EnhancedUnloadingScreen extends StatefulWidget {
  const EnhancedUnloadingScreen({super.key});

  @override
  State<EnhancedUnloadingScreen> createState() => _EnhancedUnloadingScreenState();
}

class _EnhancedUnloadingScreenState extends State<EnhancedUnloadingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Unloading & Settlement',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('loading')
            .where('status', isEqualTo: 'loaded')
            .orderBy('loadedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final loadings = snapshot.data?.docs ?? [];

          if (loadings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.download_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No loaded items',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Load items first to proceed with unloading',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: loadings.length,
            itemBuilder: (context, index) {
              final doc = loadings[index];
              final data = doc.data() as Map<String, dynamic>;
              final vehicleId = data['vehicleId'] ?? '';
              final distributionId = data['distributionId'] ?? '';
              final loadingDate = data['loadingDate'] as Timestamp?;
              final totalItems = data['totalItems'] ?? 0;
              final totalQuantity = data['totalQuantity'] ?? 0;
              final totalValue = data['totalValue'] ?? 0.0;
              final morningWeather = data['morningWeather'] ?? 'Not recorded';

              return FutureBuilder<Map<String, String>>(
                future: _getVehicleAndDistributionInfo(vehicleId, distributionId),
                builder: (context, infoSnapshot) {
                  final vehicleName =
                      infoSnapshot.data?['vehicleName'] ?? 'Loading...';
                  final distributionName =
                      infoSnapshot.data?['distributionName'] ?? 'Loading...';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () => _showEnhancedUnloadingDialog(doc.id, data),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.local_shipping,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vehicleName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        distributionName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 16),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildInfoChip(
                                  Icons.inventory_2,
                                  '$totalItems items',
                                ),
                                _buildInfoChip(
                                  Icons.numbers,
                                  '$totalQuantity qty',
                                ),
                                _buildInfoChip(
                                  Icons.attach_money,
                                  'Rs. ${totalValue.toStringAsFixed(2)}',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.wb_sunny, size: 14, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text(
                                  'Morning: $morningWeather',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  loadingDate != null ? _formatDate(loadingDate.toDate()) : 'N/A',
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
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>> _getVehicleAndDistributionInfo(
    String vehicleId,
    String distributionId,
  ) async {
    try {
      // Check if IDs are empty
      if (vehicleId.isEmpty && distributionId.isEmpty) {
        return {
          'vehicleName': 'No Vehicle',
          'distributionName': 'No Distribution'
        };
      }

      // Fetch both documents in parallel
      final results = await Future.wait([
        vehicleId.isNotEmpty
            ? _firestore.collection('vehicles').doc(vehicleId).get()
            : Future.value(null),
        distributionId.isNotEmpty
            ? _firestore.collection('distributions').doc(distributionId).get()
            : Future.value(null),
      ]);

      final vehicleDoc = results[0];
      final distributionDoc = results[1];

      return {
        'vehicleName': vehicleDoc != null && vehicleDoc.exists
            ? (vehicleDoc.data()?['vehicleName'] ?? 'Unknown Vehicle')
            : 'Unknown Vehicle',
        'distributionName': distributionDoc != null && distributionDoc.exists
            ? (distributionDoc.data()?['name'] ?? 'Unknown Distribution')
            : 'Unknown Distribution',
      };
    } catch (e) {
      print('Error fetching vehicle/distribution info: $e');
      return {
        'vehicleName': 'Error: ${vehicleId.substring(0, 8)}...',
        'distributionName': 'Error: ${distributionId.substring(0, 8)}...'
      };
    }
  }

  void _showEnhancedUnloadingDialog(String loadingDocId, Map<String, dynamic> loadingData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnloadingFormScreen(
          loadingDocId: loadingDocId,
          loadingData: loadingData,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
}

// Full-screen unloading form
class UnloadingFormScreen extends StatefulWidget {
  final String loadingDocId;
  final Map<String, dynamic> loadingData;

  const UnloadingFormScreen({
    super.key,
    required this.loadingDocId,
    required this.loadingData,
  });

  @override
  State<UnloadingFormScreen> createState() => _UnloadingFormScreenState();
}

class _UnloadingFormScreenState extends State<UnloadingFormScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _freeIssuesController = TextEditingController();
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _creditController = TextEditingController();
  final TextEditingController _creditReceivedController = TextEditingController();
  final TextEditingController _chequeController = TextEditingController();
  final TextEditingController _chequeNumberController = TextEditingController();

  // Weather
  String _unloadingWeather = 'Sunny';
  final List<String> _weatherOptions = ['Sunny', 'Cloudy', 'Rainy', 'Stormy'];

  // Expenses
  final List<Map<String, dynamic>> _expenses = [];

  // Damage Items (separate section for adding multiple damaged items)
  final List<Map<String, dynamic>> _damageItems = [];

  // Returns, Damages, and Free Issues (using cases and pieces)
  final Map<String, Map<String, int>> _itemAdjustments = {};
  final Map<String, int> _itemUnitsPerCase = {};

  bool _isLoading = false;
  bool _showCalculationSteps = false;

  @override
  void initState() {
    super.initState();
    _initializeAdjustments();
  }

  void _initializeAdjustments() {
    final items = widget.loadingData['items'] as List<dynamic>? ?? [];
    for (var item in items) {
      final itemMap = item as Map<String, dynamic>;
      final itemId = itemMap['itemId'] ?? '';
      _itemAdjustments[itemId] = {
        'returnsCases': 0,
        'returnsPieces': 0,
        'returns': 0,
        'damagedCases': 0,
        'damagedPieces': 0,
        'damaged': 0,
        'freeIssuesCases': 0,
        'freeIssuesPieces': 0,
        'freeIssuesGiven': 0,
      };
      // Store unitsPerCase for calculations
      final unitsPerCase = (itemMap['unitsPerCase'] as int?) ?? 1;
      _itemUnitsPerCase[itemId] = unitsPerCase > 0 ? unitsPerCase : 1;
    }
  }

  @override
  void dispose() {
    _discountController.dispose();
    _freeIssuesController.dispose();
    _cashController.dispose();
    _creditController.dispose();
    _creditReceivedController.dispose();
    _chequeController.dispose();
    _chequeNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.loadingData['items'] as List<dynamic>? ?? [];
    int totalLoadedQty = 0;
    int totalFreeIssues = 0;
    double totalValue = 0.0;

    for (var item in items) {
      final itemMap = item as Map<String, dynamic>;
      totalLoadedQty += (itemMap['loadingQuantity'] as int?) ?? 0;
      totalFreeIssues += (itemMap['freeIssues'] as int?) ?? 0;
      final qty = (itemMap['loadingQuantity'] as int?) ?? 0;
      final price = (itemMap['distributorPrice'] as num?)?.toDouble() ?? 0.0;
      totalValue += qty * price;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Unloading'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Loading Summary Card
                  _buildSummaryCard(items, totalLoadedQty, totalFreeIssues, totalValue),
                  const SizedBox(height: 16),

                  // Weather Section
                  _buildWeatherSection(),
                  const SizedBox(height: 16),

                  // Items with Returns and Damages
                  _buildItemsSection(items),
                  const SizedBox(height: 16),

                  // Discounts Section
                  _buildDiscountsSection(),
                  const SizedBox(height: 16),

                  // Damage Items Section
                  _buildDamageItemsSection(),
                  const SizedBox(height: 16),

                  // Expenses Section
                  _buildExpensesSection(),
                  const SizedBox(height: 16),

                  // Payments Section
                  _buildPaymentsSection(),
                  const SizedBox(height: 16),

                  // Calculate Button
                  _buildCalculateButton(),
                  const SizedBox(height: 16),

                  // Summary (shown after calculate is clicked)
                  if (_showCalculationSteps) ...[
                    _buildFinalSummary(totalValue),
                    const SizedBox(height: 80),
                  ] else ...[
                    const SizedBox(height: 80),
                  ],
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveUnloading,
        backgroundColor: Colors.red,
        icon: const Icon(Icons.check),
        label: const Text('Complete Unloading'),
      ),
    );
  }

  Widget _buildSummaryCard(List items, int totalLoadedQty, int totalFreeIssues, double totalValue) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.summarize, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Loading Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildSummaryRow('Total Items:', '${items.length}'),
            _buildSummaryRow('Total Quantity:', '$totalLoadedQty'),
            _buildSummaryRow('Free Issues Loaded:', '$totalFreeIssues'),
            _buildSummaryRow(
              'Total Value:',
              'Rs. ${totalValue.toStringAsFixed(2)}',
              isBold: true,
            ),
            if (widget.loadingData['morningWeather'] != null) ...[
              const Divider(height: 16),
              Row(
                children: [
                  const Icon(Icons.wb_sunny, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Morning Weather: ${widget.loadingData['morningWeather']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Unloading Weather',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _unloadingWeather,
              decoration: const InputDecoration(
                labelText: 'Weather Condition',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wb_cloudy),
              ),
              items: _weatherOptions.map((weather) {
                return DropdownMenuItem(
                  value: weather,
                  child: Text(weather),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _unloadingWeather = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection(List items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Items - Returns & Damages',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) {
              final itemMap = item as Map<String, dynamic>;
              final itemId = itemMap['itemId'] ?? '';
              final loadingQty = (itemMap['loadingQuantity'] as int?) ?? 0;
              final unitsPerCase = _itemUnitsPerCase[itemId] ?? 1;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemMap['productName'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Loaded: $loadingQty units ($unitsPerCase pcs/case)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Returns Section
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Returns',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: _itemAdjustments[itemId]!['returnsCases'].toString(),
                                  decoration: const InputDecoration(
                                    labelText: 'Cases',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    setState(() {
                                      _itemAdjustments[itemId]!['returnsCases'] = int.tryParse(value) ?? 0;
                                      _itemAdjustments[itemId]!['returns'] =
                                        (_itemAdjustments[itemId]!['returnsCases']! * unitsPerCase) +
                                        _itemAdjustments[itemId]!['returnsPieces']!;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue: _itemAdjustments[itemId]!['returnsPieces'].toString(),
                                  decoration: const InputDecoration(
                                    labelText: 'Pieces',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    setState(() {
                                      _itemAdjustments[itemId]!['returnsPieces'] = int.tryParse(value) ?? 0;
                                      _itemAdjustments[itemId]!['returns'] =
                                        (_itemAdjustments[itemId]!['returnsCases']! * unitsPerCase) +
                                        _itemAdjustments[itemId]!['returnsPieces']!;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Total',
                                      style: TextStyle(fontSize: 9, color: Colors.grey[700]),
                                    ),
                                    Text(
                                      '${_itemAdjustments[itemId]!['returns']}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[900],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Damaged Section
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Damaged',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[900],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: _itemAdjustments[itemId]!['damagedCases'].toString(),
                                  decoration: const InputDecoration(
                                    labelText: 'Cases',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    setState(() {
                                      _itemAdjustments[itemId]!['damagedCases'] = int.tryParse(value) ?? 0;
                                      _itemAdjustments[itemId]!['damaged'] =
                                        (_itemAdjustments[itemId]!['damagedCases']! * unitsPerCase) +
                                        _itemAdjustments[itemId]!['damagedPieces']!;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue: _itemAdjustments[itemId]!['damagedPieces'].toString(),
                                  decoration: const InputDecoration(
                                    labelText: 'Pieces',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    setState(() {
                                      _itemAdjustments[itemId]!['damagedPieces'] = int.tryParse(value) ?? 0;
                                      _itemAdjustments[itemId]!['damaged'] =
                                        (_itemAdjustments[itemId]!['damagedCases']! * unitsPerCase) +
                                        _itemAdjustments[itemId]!['damagedPieces']!;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Total',
                                      style: TextStyle(fontSize: 9, color: Colors.grey[700]),
                                    ),
                                    Text(
                                      '${_itemAdjustments[itemId]!['damaged']}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[900],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Free Issues Section (only show if item has free issues)
                    if ((itemMap['freeIssues'] ?? 0) > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.card_giftcard, size: 14, color: Colors.green[900]),
                                const SizedBox(width: 4),
                                Text(
                                  'Free Issues (Loaded: ${itemMap['freeIssues']} units)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[900],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _itemAdjustments[itemId]!['freeIssuesCases'].toString(),
                                    decoration: const InputDecoration(
                                      labelText: 'Cases Given',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      setState(() {
                                        _itemAdjustments[itemId]!['freeIssuesCases'] = int.tryParse(value) ?? 0;
                                        _itemAdjustments[itemId]!['freeIssuesGiven'] =
                                          (_itemAdjustments[itemId]!['freeIssuesCases']! * unitsPerCase) +
                                          _itemAdjustments[itemId]!['freeIssuesPieces']!;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _itemAdjustments[itemId]!['freeIssuesPieces'].toString(),
                                    decoration: const InputDecoration(
                                      labelText: 'Pieces Given',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      setState(() {
                                        _itemAdjustments[itemId]!['freeIssuesPieces'] = int.tryParse(value) ?? 0;
                                        _itemAdjustments[itemId]!['freeIssuesGiven'] =
                                          (_itemAdjustments[itemId]!['freeIssuesCases']! * unitsPerCase) +
                                          _itemAdjustments[itemId]!['freeIssuesPieces']!;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green[200],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Total',
                                        style: TextStyle(fontSize: 9, color: Colors.grey[700]),
                                      ),
                                      Text(
                                        '${_itemAdjustments[itemId]!['freeIssuesGiven']}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[900],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Actual Sold:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${loadingQty - (_itemAdjustments[itemId]!['returns']! + _itemAdjustments[itemId]!['damaged']!)} units',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.discount, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  'Discounts',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _discountController,
              decoration: const InputDecoration(
                labelText: 'Total Discounts Given',
                hintText: '0.00',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.discount),
                prefixText: 'Rs. ',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (double.tryParse(value) == null) {
                    return 'Enter valid amount';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDamageItemsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.broken_image, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text(
                      'Damaged Items',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.red),
                  onPressed: _addDamageItem,
                ),
              ],
            ),
            if (_damageItems.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No damage items added. Tap + to add.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ..._damageItems.asMap().entries.map((entry) {
                final index = entry.key;
                final damageItem = entry.value;
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              damageItem['productName'].toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Quantity: ${damageItem['quantity']} units',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                            if (damageItem['reason'].toString().isNotEmpty)
                              Text(
                                'Reason: ${damageItem['reason']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () => _removeDamageItem(index),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculateButton() {
    return Card(
      color: Colors.blue[600],
      child: InkWell(
        onTap: () {
          setState(() {
            _showCalculationSteps = !_showCalculationSteps;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calculate, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                _showCalculationSteps ? 'Hide Calculation' : 'Show Calculation',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpensesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.money_off, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    const Text(
                      'Trip Expenses',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.deepOrange),
                  onPressed: _addExpense,
                ),
              ],
            ),
            if (_expenses.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No expenses added. Tap + to add.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ..._expenses.asMap().entries.map((entry) {
                final index = entry.key;
                final expense = entry.value;
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expense['type'].toString().toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rs. ${expense['amount'].toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.red[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (expense['description'].toString().isNotEmpty)
                              Text(
                                expense['description'],
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () => _removeExpense(index),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payment, color: Colors.teal),
                const SizedBox(width: 8),
                const Text(
                  'Payment Collection',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cashController,
              decoration: const InputDecoration(
                labelText: 'Cash Received',
                hintText: '0.00',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.money),
                prefixText: 'Rs. ',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (double.tryParse(value) == null) {
                    return 'Enter valid amount';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _creditController,
              decoration: const InputDecoration(
                labelText: 'Credit Given',
                hintText: '0.00',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.credit_card),
                prefixText: 'Rs. ',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (double.tryParse(value) == null) {
                    return 'Enter valid amount';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _creditReceivedController,
              decoration: const InputDecoration(
                labelText: 'Credit Received (Old Debts)',
                hintText: '0.00',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_wallet),
                prefixText: 'Rs. ',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (double.tryParse(value) == null) {
                    return 'Enter valid amount';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _chequeController,
              decoration: const InputDecoration(
                labelText: 'Cheque Amount',
                hintText: '0.00',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.check_circle),
                prefixText: 'Rs. ',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (double.tryParse(value) == null) {
                    return 'Enter valid amount';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _chequeNumberController,
              decoration: const InputDecoration(
                labelText: 'Cheque Number (if applicable)',
                hintText: 'Enter cheque number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.confirmation_number),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalSummary(double totalValue) {
    final discounts = double.tryParse(_discountController.text) ?? 0.0;
    final cash = double.tryParse(_cashController.text) ?? 0.0;
    final credit = double.tryParse(_creditController.text) ?? 0.0;
    final creditReceived = double.tryParse(_creditReceivedController.text) ?? 0.0;
    final cheque = double.tryParse(_chequeController.text) ?? 0.0;

    final totalExpenses = _expenses.fold<double>(0.0, (sum, exp) => sum + (exp['amount'] as double));

    // Calculate total free issues given from item adjustments
    int totalFreeIssuesQty = 0;
    for (var adjustment in _itemAdjustments.values) {
      totalFreeIssuesQty += adjustment['freeIssuesGiven'] as int;
    }

    final totalDamageQty = _damageItems.fold<int>(0, (sum, item) => sum + (item['quantity'] as int));

    final netSalesValue = totalValue - discounts;
    final totalPayments = cash + creditReceived + cheque;
    final balance = netSalesValue - totalPayments - credit - totalExpenses;

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calculate, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Calculation Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Sales Calculation Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sales Calculation:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Gross Sales Value:', 'Rs. ${totalValue.toStringAsFixed(2)}'),
                  _buildSummaryRow('Less: Discounts:', '- Rs. ${discounts.toStringAsFixed(2)}'),
                  const Divider(height: 12),
                  _buildSummaryRow('Net Sales Value:', 'Rs. ${netSalesValue.toStringAsFixed(2)}', isBold: true, color: Colors.green[800]),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Free Issues & Damages Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Additional Information:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Free Issues Given:', '$totalFreeIssuesQty units'),
                  _buildSummaryRow('Damaged Items:', '$totalDamageQty units'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Payments Calculation Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payments Calculation:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Cash Received:', '+ Rs. ${cash.toStringAsFixed(2)}'),
                  _buildSummaryRow('Cheque Received:', '+ Rs. ${cheque.toStringAsFixed(2)}'),
                  _buildSummaryRow('Old Credit Received:', '+ Rs. ${creditReceived.toStringAsFixed(2)}'),
                  const Divider(height: 12),
                  _buildSummaryRow('Total Received:', 'Rs. ${totalPayments.toStringAsFixed(2)}', isBold: true),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Deductions Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Deductions:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSummaryRow('New Credit Given:', '- Rs. ${credit.toStringAsFixed(2)}'),
                  _buildSummaryRow('Trip Expenses:', '- Rs. ${totalExpenses.toStringAsFixed(2)}'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Final Balance
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: balance >= 0 ? Colors.green[600] : Colors.red[600],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Calculation Steps:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Net Sales (${netSalesValue.toStringAsFixed(2)}) - Total Received (${totalPayments.toStringAsFixed(2)}) - Credit Given (${credit.toStringAsFixed(2)}) - Expenses (${totalExpenses.toStringAsFixed(2)})',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                  const Divider(height: 16, color: Colors.white38),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Final Balance:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Rs. ${balance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    balance >= 0 ? 'Amount to be returned to office' : 'Shortage amount',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
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

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _addExpense() {
    showDialog(
      context: context,
      builder: (context) {
        final amountController = TextEditingController();
        final descriptionController = TextEditingController();
        String expenseType = 'fuel';
        final formKey = GlobalKey<FormState>();

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Add Expense'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: expenseType,
                    decoration: const InputDecoration(
                      labelText: 'Expense Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'fuel', child: Text('Fuel')),
                      DropdownMenuItem(value: 'meals', child: Text('Meals')),
                      DropdownMenuItem(value: 'salary', child: Text('Salary')),
                      DropdownMenuItem(value: 'repairs', child: Text('Repairs')),
                      DropdownMenuItem(value: 'tolls', child: Text('Tolls')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        expenseType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                      prefixText: 'Rs. ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Amount is required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Enter valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
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
                  if (formKey.currentState!.validate()) {
                    this.setState(() {
                      _expenses.add({
                        'type': expenseType,
                        'amount': double.parse(amountController.text),
                        'description': descriptionController.text.trim(),
                      });
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeExpense(int index) {
    setState(() {
      _expenses.removeAt(index);
    });
  }


  void _addDamageItem() async {
    // Get available items from Firestore
    final itemsSnapshot = await _firestore.collection('items').get();
    final availableItems = itemsSnapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'productName': doc['productName'] ?? '',
        'productCode': doc['productCode'] ?? '',
      };
    }).toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        final quantityController = TextEditingController();
        final reasonController = TextEditingController();
        String? selectedItemId;
        String selectedItemName = '';
        final formKey = GlobalKey<FormState>();

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Add Damaged Item'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedItemId,
                      decoration: const InputDecoration(
                        labelText: 'Select Item',
                        border: OutlineInputBorder(),
                      ),
                      items: availableItems.map((item) {
                        return DropdownMenuItem<String>(
                          value: item['id'] as String,
                          child: Text('${item['productCode']} - ${item['productName']}'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedItemId = value;
                          selectedItemName = availableItems.firstWhere(
                            (item) => item['id'] == value,
                            orElse: () => {'productName': ''},
                          )['productName'] as String;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select an item';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                        hintText: '0',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Quantity is required';
                        }
                        if (int.tryParse(value) == null || int.parse(value) <= 0) {
                          return 'Enter valid quantity';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        border: OutlineInputBorder(),
                        hintText: 'Why is it damaged?',
                      ),
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please provide a reason';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    this.setState(() {
                      _damageItems.add({
                        'itemId': selectedItemId,
                        'productName': selectedItemName,
                        'quantity': int.parse(quantityController.text),
                        'reason': reasonController.text.trim(),
                      });
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeDamageItem(int index) {
    setState(() {
      _damageItems.removeAt(index);
    });
  }

  Future<void> _saveUnloading() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final items = widget.loadingData['items'] as List<dynamic>;
      int totalSoldQty = 0;
      int totalReturns = 0;
      int totalDamaged = 0;
      int totalFreeIssuesFromLoading = 0;

      // Calculate adjusted items
      int totalFreeIssuesGiven = 0;
      final adjustedItems = items.map((item) {
        final itemMap = Map<String, dynamic>.from(item as Map<String, dynamic>);
        final itemId = itemMap['itemId'] ?? '';
        final loadingQty = (itemMap['loadingQuantity'] as int?) ?? 0;
        final returns = _itemAdjustments[itemId]!['returns']!;
        final damaged = _itemAdjustments[itemId]!['damaged']!;
        final freeIssuesGiven = _itemAdjustments[itemId]!['freeIssuesGiven']!;
        final actualSold = loadingQty - returns - damaged;

        totalSoldQty += actualSold;
        totalReturns += returns;
        totalDamaged += damaged;
        totalFreeIssuesFromLoading += (itemMap['freeIssues'] as int?) ?? 0;
        totalFreeIssuesGiven += freeIssuesGiven;

        itemMap['returns'] = returns;
        itemMap['damaged'] = damaged;
        itemMap['actualSold'] = actualSold;
        itemMap['freeIssuesGiven'] = freeIssuesGiven;

        return itemMap;
      }).toList();

      final discounts = double.tryParse(_discountController.text) ?? 0.0;
      final cash = double.tryParse(_cashController.text) ?? 0.0;
      final credit = double.tryParse(_creditController.text) ?? 0.0;
      final creditReceived = double.tryParse(_creditReceivedController.text) ?? 0.0;
      final cheque = double.tryParse(_chequeController.text) ?? 0.0;
      final chequeNumber = _chequeNumberController.text.trim();

      final totalValue = widget.loadingData['totalValue'] as num;
      final netValue = totalValue.toDouble() - discounts;
      final totalExpenses = _expenses.fold<double>(0.0, (sum, exp) => sum + (exp['amount'] as double));
      final totalPayments = cash + creditReceived + cheque;
      final balance = netValue - totalPayments - credit - totalExpenses;

      // Calculate total damage quantities
      final totalDamageQty = _damageItems.fold<int>(0, (sum, item) => sum + (item['quantity'] as int));

      final unloadingData = {
        'loadingDocId': widget.loadingDocId,
        'vehicleId': widget.loadingData['vehicleId'],
        'distributionId': widget.loadingData['distributionId'],
        'loadingDate': widget.loadingData['loadingDate'],
        'unloadingDate': Timestamp.now(),
        'morningWeather': widget.loadingData['morningWeather'] ?? 'Not recorded',
        'unloadingWeather': _unloadingWeather,
        'items': adjustedItems,
        'totalItems': widget.loadingData['totalItems'],
        'totalQuantity': totalSoldQty,
        'totalReturns': totalReturns,
        'totalDamaged': totalDamaged,
        'totalFreeIssues': totalFreeIssuesFromLoading,
        'totalFreeIssuesGiven': totalFreeIssuesGiven,
        'freeIssuesFromLoading': totalFreeIssuesFromLoading,
        'damageItems': _damageItems,
        'totalDamageItemsQty': totalDamageQty,
        'grossValue': totalValue,
        'totalDiscounts': discounts,
        'netValue': netValue,
        'expenses': _expenses,
        'totalExpenses': totalExpenses,
        'payments': {
          'cash': cash,
          'credit': credit,
          'creditReceived': creditReceived,
          'cheque': cheque,
          'chequeNumber': chequeNumber,
        },
        'totalPayments': totalPayments,
        'balance': balance,
        'unloadedAt': FieldValue.serverTimestamp(),
        'status': 'completed',
      };

      // Save unloading
      await _firestore.collection('unloading').add(unloadingData);

      // Update loading status
      await _firestore
          .collection('loading')
          .doc(widget.loadingDocId)
          .update({'status': 'completed'});

      // Save individual payment records if needed
      if (cash > 0 || credit > 0 || creditReceived > 0 || cheque > 0) {
        await _firestore.collection('payments').add({
          'vehicleId': widget.loadingData['vehicleId'],
          'unloadingDocId': widget.loadingDocId,
          'cash': cash,
          'credit': credit,
          'creditReceived': creditReceived,
          'cheque': cheque,
          'chequeNumber': chequeNumber,
          'date': Timestamp.now(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Save individual expense records
      for (var expense in _expenses) {
        await _firestore.collection('expenses').add({
          'vehicleId': widget.loadingData['vehicleId'],
          'unloadingDocId': widget.loadingDocId,
          'expenseType': expense['type'],
          'amount': expense['amount'],
          'description': expense['description'],
          'date': Timestamp.now(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unloading completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
