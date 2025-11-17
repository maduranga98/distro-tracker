import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State variables
  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _selectedItems = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // New fields for distribution/vehicle/date/weather
  String? _selectedDistributionId;
  String? _selectedVehicleId;
  DateTime _selectedDate = DateTime.now();
  String _morningWeather = 'Sunny';
  List<Map<String, dynamic>> _vehicles = [];
  final List<String> _weatherOptions = ['Sunny', 'Cloudy', 'Rainy', 'Stormy'];

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

  /// Loads items from Firebase with current stock
  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot itemsSnapshot = await _firestore
          .collection('stock')
          .where('status', isEqualTo: 'active')
          .where('quantity', isGreaterThan: 0)
          .orderBy('quantity')
          .orderBy('productName')
          .get();

      List<Map<String, dynamic>> items = [];
      for (var doc in itemsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        items.add(data);
      }

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading items: ${e.toString()}');
    }
  }

  /// Loads vehicles for selected distribution
  Future<void> _loadVehicles(String distributionId) async {
    try {
      final snapshot = await _firestore
          .collection('vehicles')
          .where('distributionId', isEqualTo: distributionId)
          .where('status', isEqualTo: 'active')
          .get();

      setState(() {
        _vehicles = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        _selectedVehicleId = null;
      });
    } catch (e) {
      _showErrorSnackBar('Error loading vehicles: ${e.toString()}');
    }
  }

  /// Filters items based on search query
  List<Map<String, dynamic>> get _filteredItems {
    if (_searchQuery.isEmpty) {
      return _items;
    }

    return _items.where((item) {
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

  /// Updates quantity and free issues for an item
  void _updateItemQuantity(String itemId, int quantity, int freeIssues) {
    setState(() {
      final existingIndex = _selectedItems.indexWhere(
        (item) => item['id'] == itemId,
      );

      if (quantity > 0) {
        final itemData = _items.firstWhere((item) => item['id'] == itemId);
        final selectedItem = {
          ...itemData,
          'loadingQuantity': quantity,
          'freeIssues': freeIssues,
        };

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

  /// Gets the current loading quantity for an item
  int _getLoadingQuantity(String itemId) {
    final selectedItem = _selectedItems.firstWhere(
      (item) => item['id'] == itemId,
      orElse: () => <String, dynamic>{},
    );
    return (selectedItem['loadingQuantity'] as int?) ?? 0;
  }

  /// Gets the current free issues for an item
  int _getFreeIssues(String itemId) {
    final selectedItem = _selectedItems.firstWhere(
      (item) => item['id'] == itemId,
      orElse: () => <String, dynamic>{},
    );
    return (selectedItem['freeIssues'] as int?) ?? 0;
  }

  /// Calculates total value of selected items
  double get _totalValue {
    return _selectedItems.fold(0.0, (sum, item) {
      final distributorPrice =
          (item['distributorPrice'] as num?)?.toDouble() ?? 0.0;
      final quantity = (item['loadingQuantity'] as int?) ?? 0;
      return sum + (distributorPrice * quantity);
    });
  }

  /// Calculates total quantity of selected items
  int get _totalQuantity {
    return _selectedItems.fold<int>(
      0,
      (sum, item) => sum + ((item['loadingQuantity'] as int?) ?? 0),
    );
  }

  /// Calculates total free issues
  int get _totalFreeIssues {
    return _selectedItems.fold<int>(
      0,
      (sum, item) => sum + ((item['freeIssues'] as int?) ?? 0),
    );
  }

  /// Saves the loading data
  Future<void> _saveLoading() async {
    if (_selectedDistributionId == null) {
      _showErrorSnackBar('Please select a distribution');
      return;
    }

    if (_selectedVehicleId == null) {
      _showErrorSnackBar('Please select a vehicle');
      return;
    }

    if (_selectedItems.isEmpty) {
      _showErrorSnackBar('Please select at least one item');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final loadingData = {
        'distributionId': _selectedDistributionId,
        'vehicleId': _selectedVehicleId,
        'loadingDate': Timestamp.fromDate(_selectedDate),
        'morningWeather': _morningWeather,
        'items': _selectedItems
            .map(
              (item) => {
                'itemId': item['itemId'],
                'stockDocId': item['id'],
                'productCode': item['productCode'],
                'productName': item['productName'],
                'batchNumber': item['batchNumber'],
                'brand': item['brand'],
                'category': item['category'],
                'unitType': item['unitType'],
                'loadingQuantity': item['loadingQuantity'],
                'freeIssues': item['freeIssues'] ?? 0,
                'distributorPrice': item['distributorPrice'],
                'totalValue':
                    ((item['distributorPrice'] as num?)?.toDouble() ?? 0.0) *
                    ((item['loadingQuantity'] as int?) ?? 0),
                'expiryDate': item['expiryDate'],
                'supplier': item['supplier'],
              },
            )
            .toList(),
        'totalItems': _selectedItems.length,
        'totalQuantity': _totalQuantity,
        'totalFreeIssues': _totalFreeIssues,
        'totalValue': _totalValue,
        'loadedAt': FieldValue.serverTimestamp(),
        'status': 'loaded',
      };

      await _firestore.collection('loading').add(loadingData);

      // Update stock quantities
      for (final item in _selectedItems) {
        await _updateStockQuantity(
          item['id'] as String,
          (item['loadingQuantity'] as int?) ?? 0,
        );
      }

      if (!mounted) return;

      _showSuccessSnackBar('Loading saved successfully!');

      // Clear selections
      setState(() {
        _selectedItems.clear();
        _selectedDistributionId = null;
        _selectedVehicleId = null;
        _selectedDate = DateTime.now();
        _vehicles.clear();
      });

      // Reload items to reflect updated stock
      _loadItems();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error saving loading: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Updates stock quantity after loading
  Future<void> _updateStockQuantity(
    String stockDocId,
    int loadedQuantity,
  ) async {
    try {
      await _firestore.collection('stock').doc(stockDocId).update({
        'quantity': FieldValue.increment(-loadedQuantity),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating stock: $e');
    }
  }

  /// Shows dialog to edit quantity and free issues
  void _showQuantityDialog(Map<String, dynamic> item) {
    final itemId = item['id'] as String;
    final maxStock = (item['quantity'] as int?) ?? 0;

    int currentQuantity = _getLoadingQuantity(itemId);
    int currentFreeIssues = _getFreeIssues(itemId);

    final quantityController = TextEditingController(
      text: currentQuantity.toString(),
    );
    final freeIssuesController = TextEditingController(
      text: currentFreeIssues.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['productName']?.toString() ?? ''),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: quantityController,
              decoration: InputDecoration(
                labelText: 'Loading Quantity',
                hintText: 'Max: $maxStock',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: freeIssuesController,
              decoration: const InputDecoration(
                labelText: 'Free Issues',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
              final quantity = int.tryParse(quantityController.text) ?? 0;
              final freeIssues = int.tryParse(freeIssuesController.text) ?? 0;

              if (quantity > maxStock) {
                _showErrorSnackBar('Quantity exceeds available stock');
                return;
              }

              _updateItemQuantity(itemId, quantity, freeIssues);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Add current step for stepper
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Stepper Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildStepIndicator(0, 'Setup', Icons.settings),
              _buildStepConnector(),
              _buildStepIndicator(1, 'Select Items', Icons.inventory_2),
              _buildStepConnector(),
              _buildStepIndicator(2, 'Review', Icons.check_circle),
            ],
          ),
        ),
        const Divider(height: 1),

        // Content based on current step
        Expanded(
          child: IndexedStack(
            index: _currentStep,
            children: [
              // Step 0: Distribution/Vehicle/Date Selection
              _buildSetupStep(),

              // Step 1: Items Selection
              _buildItemsSelectionStep(),

              // Step 2: Review & Save
              _buildReviewStep(),
            ],
          ),
        ),

        // Navigation Buttons
        Container(
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
          child: Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentStep--;
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (_currentStep > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _currentStep == 2
                      ? (_isSaving ? null : _saveLoading)
                      : _canProceedToNextStep()
                          ? () {
                              setState(() {
                                _currentStep++;
                              });
                            }
                          : null,
                  icon: Icon(_currentStep == 2 ? Icons.save : Icons.arrow_forward),
                  label: Text(
                    _currentStep == 2
                        ? (_isSaving ? 'Saving...' : 'Save Loading')
                        : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 0:
        return _selectedDistributionId != null && _selectedVehicleId != null;
      case 1:
        return _selectedItems.isNotEmpty;
      default:
        return false;
    }
  }

  Widget _buildStepIndicator(int step, String label, IconData icon) {
    final isActive = step == _currentStep;
    final isCompleted = step < _currentStep;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green[600]
                  : isActive
                      ? Colors.blue[600]
                      : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? Colors.blue[600] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector() {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20),
        color: Colors.grey[300],
      ),
    );
  }

  Widget _buildSetupStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildSelectionCard(),
    );
  }

  Widget _buildItemsSelectionStep() {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, code, brand, batch...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
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
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),

        // Summary Card
        if (_selectedItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildCompactSummaryCard(),
          ),

        const SizedBox(height: 8),

        // Items List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredItems.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        return _buildCompactItemCard(item);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Card
          _buildSummaryCard(),
          const SizedBox(height: 16),

          // Selected Items List
          const Text(
            'Selected Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedItems.length,
            itemBuilder: (context, index) {
              final item = _selectedItems[index];
              return _buildReviewItemCard(item);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Distribution Dropdown
            StreamBuilder<QuerySnapshot>(
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
                  decoration: const InputDecoration(
                    labelText: 'Select Distribution *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
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
                      if (value != null) {
                        _loadVehicles(value);
                      }
                    });
                  },
                );
              },
            ),

            const SizedBox(height: 16),

            // Vehicle Dropdown
            DropdownButtonFormField<String>(
              value: _selectedVehicleId,
              decoration: const InputDecoration(
                labelText: 'Select Vehicle *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_shipping),
              ),
              items: _vehicles.map((vehicle) {
                return DropdownMenuItem<String>(
                  value: vehicle['id'] as String?,
                  child: Text(vehicle['vehicleName'] ?? 'Unknown'),
                );
              }).toList(),
              onChanged: _selectedDistributionId == null
                  ? null
                  : (value) {
                      setState(() {
                        _selectedVehicleId = value;
                      });
                    },
            ),

            const SizedBox(height: 16),

            // Date Picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Loading Date'),
              subtitle: Text(_formatDate(_selectedDate)),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 7)),
                );
                if (date != null) {
                  setState(() {
                    _selectedDate = date;
                  });
                }
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),

            const SizedBox(height: 16),

            // Weather Dropdown
            DropdownButtonFormField<String>(
              value: _morningWeather,
              decoration: const InputDecoration(
                labelText: 'Morning Weather',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wb_sunny),
              ),
              items: _weatherOptions.map((weather) {
                return DropdownMenuItem(
                  value: weather,
                  child: Text(weather),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _morningWeather = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                'Items',
                '${_selectedItems.length}',
                Icons.inventory_2,
              ),
              _buildSummaryItem('Quantity', '$_totalQuantity', Icons.numbers),
              _buildSummaryItem(
                'Free',
                '$_totalFreeIssues',
                Icons.card_giftcard,
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Total Value: ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              Text(
                'Rs. ${_totalValue.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue[600], size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.blue[600])),
      ],
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final itemId = item['id'] as String;
    final currentQuantity = _getLoadingQuantity(itemId);
    final currentFreeIssues = _getFreeIssues(itemId);
    final maxStock = (item['quantity'] as int?) ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showQuantityDialog(item),
        borderRadius: BorderRadius.circular(12),
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
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: maxStock > 50
                          ? Colors.green[100]
                          : maxStock > 20
                          ? Colors.orange[100]
                          : Colors.red[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Stock: $maxStock',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: maxStock > 50
                            ? Colors.green[700]
                            : maxStock > 20
                            ? Colors.orange[700]
                            : Colors.red[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Rs. ${((item['distributorPrice'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)} per unit',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
              if (currentQuantity > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Loading Qty:'),
                          Text(
                            '$currentQuantity',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Free Issues:'),
                          Text(
                            '$currentFreeIssues',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactItemCard(Map<String, dynamic> item) {
    final itemId = item['id'] as String;
    final currentQuantity = _getLoadingQuantity(itemId);
    final maxStock = (item['quantity'] as int?) ?? 0;
    final isSelected = currentQuantity > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 3 : 1,
      color: isSelected ? Colors.blue[50] : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => _showQuantityDialog(item),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['productName']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item['productCode']} • Stock: $maxStock',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Quantity Badge
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$currentQuantity',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                )
              else
                Icon(Icons.add_circle_outline, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactSummaryCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text('Items: ${_selectedItems.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text('Qty: $_totalQuantity', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text('Rs. ${_totalValue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildReviewItemCard(Map<String, dynamic> item) {
    final quantity = (item['loadingQuantity'] as int?) ?? 0;
    final freeIssues = (item['freeIssues'] as int?) ?? 0;
    final price = (item['distributorPrice'] as num?)?.toDouble() ?? 0.0;
    final total = price * quantity;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
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
                        item['productName']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['productCode']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () {
                    final fullItem = _items.firstWhere((i) => i['id'] == item['id']);
                    _showQuantityDialog(fullItem);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Qty: $quantity${freeIssues > 0 ? ' + $freeIssues FOC' : ''}', style: const TextStyle(fontSize: 12)),
                Text('Rs. ${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green[700])),
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
            _searchQuery.isNotEmpty ? 'No items found' : 'No items available',
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
                : 'Add some items to your inventory first',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

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
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
