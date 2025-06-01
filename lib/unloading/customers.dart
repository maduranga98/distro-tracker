import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Customers extends StatefulWidget {
  const Customers({super.key});

  @override
  State<Customers> createState() => _CustomersState();
}

class _CustomersState extends State<Customers> {
  // State management
  int _currentStep = 0;
  String? _selectedRouteId;
  Map<String, dynamic>? _selectedRoute;
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _routes = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _cheques = [];
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = false;
  bool _isSaving = false;

  // Form controllers
  final _customerNameController = TextEditingController();
  final _valueController = TextEditingController();
  final _cashController = TextEditingController();
  final _chequeController = TextEditingController();
  final _creditController = TextEditingController();
  final _oldCreditController = TextEditingController();

  // Cheque form controllers
  final _chequeNumberController = TextEditingController();
  final _bankController = TextEditingController();
  final _chequeDateController = TextEditingController();
  final _chequeValueController = TextEditingController();

  // Expense form controllers
  final _expenseDescriptionController = TextEditingController();
  final _expenseAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _valueController.dispose();
    _cashController.dispose();
    _chequeController.dispose();
    _creditController.dispose();
    _oldCreditController.dispose();
    _chequeNumberController.dispose();
    _bankController.dispose();
    _chequeDateController.dispose();
    _chequeValueController.dispose();
    _expenseDescriptionController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }

  /// Load available routes
  Future<void> _loadRoutes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot routesSnapshot =
          await FirebaseFirestore.instance
              .collection('routes')
              .where('status', isEqualTo: 'active')
              .orderBy('routeName')
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

  /// Load existing customers for selected route and date
  Future<void> _loadExistingCustomers() async {
    if (_selectedRouteId == null) return;

    try {
      final dateKey =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      final QuerySnapshot customerSnapshot =
          await FirebaseFirestore.instance
              .collection('daily_sales')
              .where('routeId', isEqualTo: _selectedRouteId)
              .where('date', isEqualTo: dateKey)
              .get();

      if (customerSnapshot.docs.isNotEmpty) {
        final salesData =
            customerSnapshot.docs.first.data() as Map<String, dynamic>;
        setState(() {
          _customers = List<Map<String, dynamic>>.from(
            salesData['customers'] ?? [],
          );
          _cheques = List<Map<String, dynamic>>.from(
            salesData['cheques'] ?? [],
          );
          _expenses = List<Map<String, dynamic>>.from(
            salesData['expenses'] ?? [],
          );
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error loading existing data: ${e.toString()}');
    }
  }

  /// Add customer
  void _addCustomer() {
    if (_customerNameController.text.trim().isEmpty ||
        _valueController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter customer name and value');
      return;
    }

    final cash = double.tryParse(_cashController.text) ?? 0.0;
    final cheque = double.tryParse(_chequeController.text) ?? 0.0;
    final credit = double.tryParse(_creditController.text) ?? 0.0;
    final oldCredit = double.tryParse(_oldCreditController.text) ?? 0.0;
    final value = double.tryParse(_valueController.text) ?? 0.0;

    // Validate payment total
    final totalPayment = cash + cheque + credit - oldCredit;
    if ((totalPayment - value).abs() > 0.01) {
      _showErrorSnackBar('Payment total must equal the customer value');
      return;
    }

    final customer = {
      'name': _customerNameController.text.trim(),
      'value': value,
      'cash': cash,
      'cheque': cheque,
      'credit': credit,
      'oldCredit': oldCredit,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    setState(() {
      _customers.add(customer);
    });

    _clearCustomerForm();
    _showSuccessSnackBar('Customer added successfully');
  }

  /// Clear customer form
  void _clearCustomerForm() {
    _customerNameController.clear();
    _valueController.clear();
    _cashController.clear();
    _chequeController.clear();
    _creditController.clear();
    _oldCreditController.clear();
  }

  /// Add cheque details
  void _addCheque() {
    if (_chequeNumberController.text.trim().isEmpty ||
        _bankController.text.trim().isEmpty ||
        _chequeValueController.text.trim().isEmpty) {
      _showErrorSnackBar('Please fill all cheque details');
      return;
    }

    final cheque = {
      'chequeNumber': _chequeNumberController.text.trim(),
      'bank': _bankController.text.trim(),
      'chequeDate': _chequeDateController.text.trim(),
      'value': double.tryParse(_chequeValueController.text) ?? 0.0,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    setState(() {
      _cheques.add(cheque);
    });

    _clearChequeForm();
    _showSuccessSnackBar('Cheque details added');
  }

  /// Clear cheque form
  void _clearChequeForm() {
    _chequeNumberController.clear();
    _bankController.clear();
    _chequeDateController.clear();
    _chequeValueController.clear();
  }

  /// Add expense
  void _addExpense() {
    if (_expenseDescriptionController.text.trim().isEmpty ||
        _expenseAmountController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter expense description and amount');
      return;
    }

    final expense = {
      'description': _expenseDescriptionController.text.trim(),
      'amount': double.tryParse(_expenseAmountController.text) ?? 0.0,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    setState(() {
      _expenses.add(expense);
    });

    _clearExpenseForm();
    _showSuccessSnackBar('Expense added');
  }

  /// Clear expense form
  void _clearExpenseForm() {
    _expenseDescriptionController.clear();
    _expenseAmountController.clear();
  }

  /// Save daily sales data
  Future<void> _saveDailySales() async {
    if (_selectedRouteId == null || _customers.isEmpty) {
      _showErrorSnackBar('Please select a route and add at least one customer');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final dateKey =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      final salesData = {
        'routeId': _selectedRouteId,
        'routeName': _selectedRoute?['routeName'],
        'date': dateKey,
        'customers': _customers,
        'cheques': _cheques,
        'expenses': _expenses,
        'summary': _calculateSummary(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Check if document exists for this route and date
      final existingQuery =
          await FirebaseFirestore.instance
              .collection('daily_sales')
              .where('routeId', isEqualTo: _selectedRouteId)
              .where('date', isEqualTo: dateKey)
              .get();

      if (existingQuery.docs.isNotEmpty) {
        // Update existing document
        await FirebaseFirestore.instance
            .collection('daily_sales')
            .doc(existingQuery.docs.first.id)
            .update(salesData);
      } else {
        // Create new document
        await FirebaseFirestore.instance
            .collection('daily_sales')
            .add(salesData);
      }

      _showSuccessSnackBar('Daily sales saved successfully!');
    } catch (e) {
      _showErrorSnackBar('Error saving data: ${e.toString()}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  /// Calculate summary
  Map<String, dynamic> _calculateSummary() {
    double totalSales = 0;
    double totalCash = 0;
    double totalCheques = 0;
    double totalCredits = 0;
    double totalCreditsReceived = 0;
    int numberOfCustomers = _customers.length;

    for (var customer in _customers) {
      totalSales += (customer['value'] as num?)?.toDouble() ?? 0.0;
      totalCash += (customer['cash'] as num?)?.toDouble() ?? 0.0;
      totalCheques += (customer['cheque'] as num?)?.toDouble() ?? 0.0;
      totalCredits += (customer['credit'] as num?)?.toDouble() ?? 0.0;
      totalCreditsReceived +=
          (customer['oldCredit'] as num?)?.toDouble() ?? 0.0;
    }

    double totalExpenses = 0;
    for (var expense in _expenses) {
      totalExpenses += (expense['amount'] as num?)?.toDouble() ?? 0.0;
    }

    return {
      'totalSales': totalSales,
      'totalCash': totalCash,
      'totalCheques': totalCheques,
      'totalCredits': totalCredits,
      'totalCreditsReceived': totalCreditsReceived,
      'numberOfCustomers': numberOfCustomers,
      'totalExpenses': totalExpenses,
      'netTotal': totalSales - totalExpenses,
    };
  }

  /// Navigate to routes creation
  void _navigateToRoutes() {
    Navigator.of(context).pushNamed('/routes').then((_) {
      _loadRoutes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _routes.isEmpty
              ? _buildNoRoutesState()
              : _buildStepsContent(),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  String _getAppBarTitle() {
    switch (_currentStep) {
      case 0:
        return 'Select Route';
      case 1:
        return 'Add Customers';
      case 2:
        return 'Daily Summary';
      case 3:
        return 'Cheque Details';
      case 4:
        return 'Expenses';
      case 5:
        return 'Final Summary';
      default:
        return 'Customer Management';
    }
  }

  Widget _buildNoRoutesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.route_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Routes Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please add routes first to continue',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _navigateToRoutes,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Add Routes'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsContent() {
    switch (_currentStep) {
      case 0:
        return _buildRouteSelection();
      case 1:
        return _buildCustomerEntry();
      case 2:
        return _buildDailySummary();
      case 3:
        return _buildChequeDetails();
      case 4:
        return _buildExpenses();
      case 5:
        return _buildFinalSummary();
      default:
        return _buildRouteSelection();
    }
  }

  Widget _buildRouteSelection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.blue[600]),
                  const SizedBox(width: 12),
                  Text(
                    'Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 30),
                        ),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _selectedDate = date;
                        });
                      }
                    },
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Select Route',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // Routes List
          Expanded(
            child: ListView.builder(
              itemCount: _routes.length,
              itemBuilder: (context, index) {
                final route = _routes[index];
                final isSelected = _selectedRouteId == route['id'];

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue[600] : Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.route,
                        color: isSelected ? Colors.white : Colors.blue[600],
                      ),
                    ),
                    title: Text(
                      route['routeName'] ?? '',
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '${route['startLocation']} → ${route['endLocation']}',
                    ),
                    trailing:
                        isSelected
                            ? Icon(Icons.check_circle, color: Colors.green[600])
                            : null,
                    onTap: () {
                      setState(() {
                        _selectedRouteId = route['id'];
                        _selectedRoute = route;
                      });
                      _loadExistingCustomers();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerEntry() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected Route Info
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.route, color: Colors.blue[600]),
                  const SizedBox(width: 8),
                  Text(
                    _selectedRoute?['routeName'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Customer Form
          const Text(
            'Add Customer',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Customer Name
                  _buildTextField(
                    controller: _customerNameController,
                    label: 'Customer Name',
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 12),

                  // Value
                  _buildTextField(
                    controller: _valueController,
                    label: 'Total Value',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),

                  // Payment Methods Row 1
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _cashController,
                          label: 'Cash',
                          icon: Icons.money,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _chequeController,
                          label: 'Cheque',
                          icon: Icons.receipt,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Payment Methods Row 2
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _creditController,
                          label: 'Credit',
                          icon: Icons.credit_card,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _oldCreditController,
                          label: 'Old Credit Received',
                          icon: Icons.payment,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Add Customer Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addCustomer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Add Customer'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Customers List
                  if (_customers.isNotEmpty) ...[
                    const Text(
                      'Today\'s Customers',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _customers.length,
                      itemBuilder: (context, index) {
                        final customer = _customers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(customer['name']),
                            subtitle: Text(
                              'Value: Rs.${customer['value'].toStringAsFixed(2)}',
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red[600]),
                              onPressed: () {
                                setState(() {
                                  _customers.removeAt(index);
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySummary() {
    final summary = _calculateSummary();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Sales Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: ListView(
              children: [
                _buildSummaryCard(
                  'Total Sales',
                  'Rs.${summary['totalSales'].toStringAsFixed(2)}',
                  Icons.trending_up,
                  Colors.blue,
                ),
                _buildSummaryCard(
                  'Number of Customers',
                  '${summary['numberOfCustomers']}',
                  Icons.people,
                  Colors.green,
                ),
                _buildSummaryCard(
                  'Total Cash',
                  'Rs.${summary['totalCash'].toStringAsFixed(2)}',
                  Icons.money,
                  Colors.orange,
                ),
                _buildSummaryCard(
                  'Total Cheques',
                  'Rs.${summary['totalCheques'].toStringAsFixed(2)}',
                  Icons.receipt,
                  Colors.purple,
                ),
                _buildSummaryCard(
                  'Total Credits',
                  'Rs.${summary['totalCredits'].toStringAsFixed(2)}',
                  Icons.credit_card,
                  Colors.red,
                ),
                _buildSummaryCard(
                  'Credits Received',
                  'Rs.${summary['totalCreditsReceived'].toStringAsFixed(2)}',
                  Icons.payment,
                  Colors.teal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChequeDetails() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cheque Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Cheque Form
                  _buildTextField(
                    controller: _chequeNumberController,
                    label: 'Cheque Number',
                    icon: Icons.numbers,
                  ),
                  const SizedBox(height: 12),

                  _buildTextField(
                    controller: _bankController,
                    label: 'Bank Name',
                    icon: Icons.account_balance,
                  ),
                  const SizedBox(height: 12),

                  _buildTextField(
                    controller: _chequeDateController,
                    label: 'Cheque Date',
                    icon: Icons.date_range,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        _chequeDateController.text =
                            '${date.day}/${date.month}/${date.year}';
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  _buildTextField(
                    controller: _chequeValueController,
                    label: 'Cheque Value',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addCheque,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Add Cheque'),
                    ),
                  ),

                  // Cheques List
                  if (_cheques.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Added Cheques',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _cheques.length,
                      itemBuilder: (context, index) {
                        final cheque = _cheques[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              '${cheque['chequeNumber']} - ${cheque['bank']}',
                            ),
                            subtitle: Text(
                              'Rs.${cheque['value'].toStringAsFixed(2)} | ${cheque['chequeDate']}',
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red[600]),
                              onPressed: () {
                                setState(() {
                                  _cheques.removeAt(index);
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenses() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Expenses',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Expense Form
                  _buildTextField(
                    controller: _expenseDescriptionController,
                    label: 'Expense Description',
                    icon: Icons.description,
                  ),
                  const SizedBox(height: 12),

                  _buildTextField(
                    controller: _expenseAmountController,
                    label: 'Amount',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addExpense,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Add Expense'),
                    ),
                  ),

                  // Expenses List
                  if (_expenses.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Today\'s Expenses',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _expenses.length,
                      itemBuilder: (context, index) {
                        final expense = _expenses[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(expense['description']),
                            subtitle: Text(
                              'Rs.${expense['amount'].toStringAsFixed(2)}',
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red[600]),
                              onPressed: () {
                                setState(() {
                                  _expenses.removeAt(index);
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalSummary() {
    final summary = _calculateSummary();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Final Daily Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: ListView(
              children: [
                _buildSummaryCard(
                  'Total Sales',
                  'Rs.${summary['totalSales'].toStringAsFixed(2)}',
                  Icons.trending_up,
                  Colors.blue,
                ),
                _buildSummaryCard(
                  'Total Expenses',
                  'Rs.${summary['totalExpenses'].toStringAsFixed(2)}',
                  Icons.trending_down,
                  Colors.red,
                ),
                _buildSummaryCard(
                  'Net Total',
                  'Rs.${summary['netTotal'].toStringAsFixed(2)}',
                  Icons.account_balance_wallet,
                  Colors.green,
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                _buildSummaryCard(
                  'Customers Count',
                  '${summary['numberOfCustomers']}',
                  Icons.people,
                  Colors.purple,
                ),
                _buildSummaryCard(
                  'Total Cash',
                  'Rs.${summary['totalCash'].toStringAsFixed(2)}',
                  Icons.money,
                  Colors.orange,
                ),
                _buildSummaryCard(
                  'Total Cheques',
                  'Rs.${summary['totalCheques'].toStringAsFixed(2)}',
                  Icons.receipt,
                  Colors.purple,
                ),
                _buildSummaryCard(
                  'Total Credits Given',
                  'Rs.${summary['totalCredits'].toStringAsFixed(2)}',
                  Icons.credit_card,
                  Colors.red,
                ),
                _buildSummaryCard(
                  'Credits Received',
                  'Rs.${summary['totalCreditsReceived'].toStringAsFixed(2)}',
                  Icons.payment,
                  Colors.teal,
                ),
              ],
            ),
          ),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveDailySales,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                      : const Text(
                        'Save Daily Sales',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onTap: onTap,
          readOnly: onTap != null,
          decoration: InputDecoration(
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

  Widget _buildBottomNavigation() {
    if (_routes.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
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
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentStep--;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Previous'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          if (_currentStep < 5)
            Expanded(
              child: ElevatedButton(
                onPressed:
                    _selectedRouteId != null
                        ? () {
                          setState(() {
                            _currentStep++;
                          });
                        }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Next'),
              ),
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
        duration: const Duration(seconds: 2),
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
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
