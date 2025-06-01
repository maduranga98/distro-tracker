import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddItems extends StatefulWidget {
  const AddItems({super.key});

  @override
  State<AddItems> createState() => _AddItemsState();
}

class _AddItemsState extends State<AddItems> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController productNameController = TextEditingController();
  final TextEditingController productCodeController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController brandController = TextEditingController();
  final TextEditingController distributorPriceController =
      TextEditingController();
  final TextEditingController wholeSalePriceController =
      TextEditingController();
  final TextEditingController mrpController = TextEditingController();
  final TextEditingController unitTypeController = TextEditingController();
  final TextEditingController unitsPerCaseController = TextEditingController();
  final TextEditingController focController = TextEditingController();

  bool _isLoading = false;
  String? _selectedSupplier;

  // Supplier list
  final List<String> _suppliers = [
    'Lanka Dairies PVT Ltd',
    'Lanka Milk Foods (CWE) PLC',
    'Ambewela Products (PVT) Ltd',
  ];

  @override
  void dispose() {
    // Dispose all controllers
    productNameController.dispose();
    productCodeController.dispose();
    categoryController.dispose();
    brandController.dispose();
    distributorPriceController.dispose();
    wholeSalePriceController.dispose();
    mrpController.dispose();
    unitTypeController.dispose();
    unitsPerCaseController.dispose();
    focController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Add New Item",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Information Section
              _buildSectionHeader("Product Information"),
              const SizedBox(height: 16),
              _buildTextField(
                controller: productNameController,
                label: "Product Name",
                hint: "Enter product name",
                icon: Icons.inventory_2_outlined,
                isRequired: true,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: productCodeController,
                label: "Product Code",
                hint: "Enter unique product code",
                icon: Icons.qr_code_outlined,
                isRequired: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: categoryController,
                      label: "Category",
                      hint: "Select category",
                      icon: Icons.category_outlined,
                      isRequired: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: brandController,
                      label: "Brand",
                      hint: "Enter brand name",
                      icon: Icons.business_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSupplierDropdown(),

              const SizedBox(height: 32),

              // Pricing Section
              _buildSectionHeader("Pricing"),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: distributorPriceController,
                      label: "Distributor Price",
                      hint: "0.00",
                      icon: Icons.attach_money_outlined,
                      keyboardType: TextInputType.number,
                      isRequired: true,
                      prefix: "Rs. ",
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: wholeSalePriceController,
                      label: "Wholesale Price",
                      hint: "0.00",
                      icon: Icons.store_outlined,
                      keyboardType: TextInputType.number,
                      isRequired: true,
                      prefix: "Rs. ",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: mrpController,
                label: "MRP (Maximum Retail Price)",
                hint: "0.00",
                icon: Icons.price_change_rounded,
                keyboardType: TextInputType.number,
                isRequired: true,
                prefix: "Rs. ",
              ),

              const SizedBox(height: 32),

              // Unit Information Section
              _buildSectionHeader("Unit Information"),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: unitTypeController,
                      label: "Unit Type",
                      hint: "pcs, kg, ltr, etc.",
                      icon: Icons.straighten_outlined,
                      isRequired: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: unitsPerCaseController,
                      label: "Units per Case",
                      hint: "0",
                      icon: Icons.inventory_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: focController,
                label: "FOC (Free of Cost)",
                hint: "0",
                icon: Icons.card_giftcard_outlined,
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 40),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _clearForm,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey[400]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Clear",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveItem,
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
                          _isLoading
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Text(
                                "Save Item",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildSupplierDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedSupplier,
      decoration: InputDecoration(
        labelText: 'Supplier *',
        hintText: 'Select supplier',
        prefixIcon: Icon(
          Icons.local_shipping_outlined,
          color: Colors.grey[600],
        ),
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
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(
          color: Colors.grey[700],
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(color: Colors.grey[400]),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Supplier is required';
        }
        return null;
      },
      items:
          _suppliers.map((String supplier) {
            return DropdownMenuItem<String>(
              value: supplier,
              child: Text(
                supplier,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedSupplier = newValue;
        });
      },
      isExpanded: true,
      icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
      dropdownColor: Colors.white,
      style: TextStyle(color: Colors.grey[800], fontSize: 16),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
    String? prefix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters:
          keyboardType == TextInputType.number
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))]
              : null,
      validator:
          isRequired
              ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return '$label is required';
                }
                return null;
              }
              : null,
      decoration: InputDecoration(
        labelText: label + (isRequired ? ' *' : ''),
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        prefixText: prefix,
        prefixStyle: TextStyle(
          color: Colors.grey[700],
          fontWeight: FontWeight.w500,
        ),
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
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(
          color: Colors.grey[700],
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(color: Colors.grey[400]),
      ),
    );
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    productNameController.clear();
    productCodeController.clear();
    categoryController.clear();
    brandController.clear();
    distributorPriceController.clear();
    wholeSalePriceController.clear();
    mrpController.clear();
    unitTypeController.clear();
    unitsPerCaseController.clear();
    focController.clear();

    setState(() {
      _selectedSupplier = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Form cleared'),
        backgroundColor: Colors.grey[600],
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate API call - Replace with your actual Firebase/API logic
      await Future.delayed(const Duration(seconds: 2));

      // TODO: Implement your save logic here
      await FirebaseFirestore.instance.collection('items').add({
        'productName': productNameController.text.trim(),
        'productCode': productCodeController.text.trim(),
        'category': categoryController.text.trim(),
        'brand': brandController.text.trim(),
        'supplier': _selectedSupplier,
        'distributorPrice':
            double.tryParse(distributorPriceController.text) ?? 0.0,
        'wholesalePrice': double.tryParse(wholeSalePriceController.text) ?? 0.0,
        'mrp': double.tryParse(mrpController.text) ?? 0.0,
        'unitType': unitTypeController.text.trim(),
        'unitsPerCase': int.tryParse(unitsPerCaseController.text) ?? 0,
        'foc': int.tryParse(focController.text) ?? 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Item saved successfully!'),
            ],
          ),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      _clearForm();
    } catch (e) {
      if (!mounted) return;
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Error saving item: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red[600],
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
