import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoutesCreation extends StatefulWidget {
  const RoutesCreation({super.key});

  @override
  State<RoutesCreation> createState() => _RoutesCreationState();
}

class _RoutesCreationState extends State<RoutesCreation>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _routeNameController = TextEditingController();
  final _routeCodeController = TextEditingController();
  final _startLocationController = TextEditingController();
  final _endLocationController = TextEditingController();
  final _distanceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  // Search controller
  final _searchController = TextEditingController();

  // State variables
  bool _isLoading = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _routes = [];
  String _searchQuery = '';
  String _selectedStatus = 'active';
  Map<String, dynamic>? _editingRoute;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRoutes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _routeNameController.dispose();
    _routeCodeController.dispose();
    _startLocationController.dispose();
    _endLocationController.dispose();
    _distanceController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Loads routes from Firebase
  Future<void> _loadRoutes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot routesSnapshot =
          await FirebaseFirestore.instance
              .collection('routes')
              .orderBy('createdAt', descending: true)
              .get();

      List<Map<String, dynamic>> routes = [];
      for (var doc in routesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        routes.add(data);
      }

      setState(() {
        _routes = routes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading routes: ${e.toString()}');
    }
  }

  /// Filters routes based on search query and status
  List<Map<String, dynamic>> get _filteredRoutes {
    return _routes.where((route) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          route['routeName']?.toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ==
              true ||
          route['routeCode']?.toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ==
              true ||
          route['startLocation']?.toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ==
              true ||
          route['endLocation']?.toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ==
              true;

      final matchesStatus = route['status'] == _selectedStatus;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  /// Saves or updates a route
  Future<void> _saveRoute() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final routeData = {
        'routeName': _routeNameController.text.trim(),
        'routeCode': _routeCodeController.text.trim().toUpperCase(),
        'startLocation': _startLocationController.text.trim(),
        'endLocation': _endLocationController.text.trim(),
        'distance':
            _distanceController.text.isNotEmpty
                ? double.tryParse(_distanceController.text) ?? 0.0
                : 0.0,
        'description': _descriptionController.text.trim(),
        'notes': _notesController.text.trim(),
        'status': 'active',
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (_editingRoute != null) {
        // Update existing route
        await FirebaseFirestore.instance
            .collection('routes')
            .doc(_editingRoute!['id'])
            .update(routeData);
        _showSuccessSnackBar('Route updated successfully!');
      } else {
        // Create new route
        routeData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('routes').add(routeData);
        _showSuccessSnackBar('Route created successfully!');
      }

      _clearForm();
      _loadRoutes();

      // Switch to routes tab
      _tabController.animateTo(1);
    } catch (e) {
      _showErrorSnackBar('Error saving route: ${e.toString()}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  /// Clears the form
  void _clearForm() {
    _routeNameController.clear();
    _routeCodeController.clear();
    _startLocationController.clear();
    _endLocationController.clear();
    _distanceController.clear();
    _descriptionController.clear();
    _notesController.clear();
    setState(() {
      _editingRoute = null;
    });
  }

  /// Loads route data for editing
  void _editRoute(Map<String, dynamic> route) {
    _routeNameController.text = route['routeName'] ?? '';
    _routeCodeController.text = route['routeCode'] ?? '';
    _startLocationController.text = route['startLocation'] ?? '';
    _endLocationController.text = route['endLocation'] ?? '';
    _distanceController.text = route['distance']?.toString() ?? '';
    _descriptionController.text = route['description'] ?? '';
    _notesController.text = route['notes'] ?? '';

    setState(() {
      _editingRoute = route;
    });

    _tabController.animateTo(0);
  }

  /// Toggles route status
  Future<void> _toggleRouteStatus(Map<String, dynamic> route) async {
    try {
      final newStatus = route['status'] == 'active' ? 'inactive' : 'active';
      await FirebaseFirestore.instance
          .collection('routes')
          .doc(route['id'])
          .update({
            'status': newStatus,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      _showSuccessSnackBar('Route status updated!');
      _loadRoutes();
    } catch (e) {
      _showErrorSnackBar('Error updating route status: ${e.toString()}');
    }
  }

  /// Deletes a route
  Future<void> _deleteRoute(Map<String, dynamic> route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Route'),
            content: Text(
              'Are you sure you want to delete "${route['routeName']}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('routes')
            .doc(route['id'])
            .delete();

        _showSuccessSnackBar('Route deleted successfully!');
        _loadRoutes();
      } catch (e) {
        _showErrorSnackBar('Error deleting route: ${e.toString()}');
      }
    }
  }

  /// Formats date for display
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year}';
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Routes Management',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue[600],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.blue[600],
          tabs: const [
            Tab(text: 'Add Route', icon: Icon(Icons.add_road)),
            Tab(text: 'View Routes', icon: Icon(Icons.route)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildAddRouteTab(), _buildViewRoutesTab()],
      ),
    );
  }

  Widget _buildAddRouteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            if (_editingRoute != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Editing Route: ${_editingRoute!['routeName']}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[700],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _clearForm,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Route Name & Code Row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _routeNameController,
                    label: 'Route Name',
                    hintText: 'Enter route name',
                    icon: Icons.route,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Route name is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _routeCodeController,
                    label: 'Route Code',
                    hintText: 'RT001',
                    icon: Icons.qr_code,
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Route code is required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Start & End Location Row
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _startLocationController,
                    label: 'Start Location',
                    hintText: 'Starting point',
                    icon: Icons.my_location,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Start location is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _endLocationController,
                    label: 'End Location',
                    hintText: 'Destination',
                    icon: Icons.location_on,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'End location is required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Distance
            _buildTextField(
              controller: _distanceController,
              label: 'Distance (km)',
              hintText: 'Enter distance in kilometers',
              icon: Icons.straighten,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
            ),

            const SizedBox(height: 16),

            // Description
            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              hintText: 'Route description (optional)',
              icon: Icons.description,
              maxLines: 3,
            ),

            const SizedBox(height: 16),

            // Notes
            _buildTextField(
              controller: _notesController,
              label: 'Notes',
              hintText: 'Additional notes (optional)',
              icon: Icons.note,
              maxLines: 2,
            ),

            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveRoute,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isSaving
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Text(
                          _editingRoute != null ? 'Update Route' : 'Save Route',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewRoutesTab() {
    return Column(
      children: [
        // Search and Filter Section
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              // Search Bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search routes...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon:
                      _searchQuery.isNotEmpty
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
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),

              const SizedBox(height: 12),

              // Status Filter
              Row(
                children: [
                  const Text(
                    'Status:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        _buildStatusChip('Active', 'active'),
                        const SizedBox(width: 8),
                        _buildStatusChip('Inactive', 'inactive'),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loadRoutes,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ],
          ),
        ),

        // Routes List
        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredRoutes.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredRoutes.length,
                    itemBuilder: (context, index) {
                      final route = _filteredRoutes[index];
                      return _buildRouteCard(route);
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String label, String value) {
    final isSelected = _selectedStatus == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[600] : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route) {
    final isActive = route['status'] == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.green[200]! : Colors.red[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    route['routeCode'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green[100] : Colors.red[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isActive ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Route Name
            Text(
              route['routeName'] ?? '',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 12),

            // Route Details
            Row(
              children: [
                Expanded(
                  child: _buildRouteDetail(
                    Icons.my_location,
                    'From',
                    route['startLocation'] ?? 'N/A',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildRouteDetail(
                    Icons.location_on,
                    'To',
                    route['endLocation'] ?? 'N/A',
                  ),
                ),
              ],
            ),

            if (route['distance'] != null && route['distance'] > 0) ...[
              const SizedBox(height: 12),
              _buildRouteDetail(
                Icons.straighten,
                'Distance',
                '${route['distance']} km',
              ),
            ],

            if (route['description'] != null &&
                route['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildRouteDetail(
                Icons.description,
                'Description',
                route['description'],
              ),
            ],

            const SizedBox(height: 12),

            // Footer
            Row(
              children: [
                Text(
                  'Created: ${_formatDate(route['createdAt'])}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _editRoute(route),
                      icon: Icon(Icons.edit, color: Colors.blue[600]),
                      tooltip: 'Edit',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _toggleRouteStatus(route),
                      icon: Icon(
                        isActive ? Icons.toggle_on : Icons.toggle_off,
                        color: isActive ? Colors.green[600] : Colors.grey[400],
                      ),
                      tooltip: isActive ? 'Deactivate' : 'Activate',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _deleteRoute(route),
                      icon: Icon(Icons.delete, color: Colors.red[600]),
                      tooltip: 'Delete',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteDetail(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
          Icon(Icons.route_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No routes found'
                : _selectedStatus == 'active'
                ? 'No active routes'
                : 'No inactive routes',
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
                : 'Create your first route to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// Shows success snackbar
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

  /// Shows error snackbar
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
