import 'package:flutter/material.dart';
import 'package:distro_tracker_flutter/setup/distributions.dart';
import 'package:distro_tracker_flutter/setup/vehicles.dart';
import 'package:distro_tracker_flutter/loading/loadingUi.dart';
import 'package:distro_tracker_flutter/loading/add_stock.dart';
import 'package:distro_tracker_flutter/loading/add_items.dart';
import 'package:distro_tracker_flutter/loading/manage_items.dart';
import 'package:distro_tracker_flutter/loading/stock_viewer.dart';
import 'package:distro_tracker_flutter/loading/price_history.dart';
import 'package:distro_tracker_flutter/unloading/routes.dart';
import 'package:distro_tracker_flutter/unloading/enhanced_unloading.dart';
import 'package:distro_tracker_flutter/expenses/expenses.dart';
import 'package:distro_tracker_flutter/payments/payments.dart';
import 'package:distro_tracker_flutter/reports/daily_reports.dart';
import 'package:distro_tracker_flutter/reports/daily_unloading_details.dart';
import 'package:distro_tracker_flutter/invoices/invoice_list.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Distro Tracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Welcome to Distro Tracker',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Manage your dairy distribution business efficiently',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 28),

            // Daily Operations Section
            _buildSectionTitle('Daily Operations'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDashboardCard(
                    context,
                    title: 'Loading',
                    subtitle: 'Load items to vehicles',
                    icon: Icons.upload,
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Loadingui(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDashboardCard(
                    context,
                    title: 'Unloading',
                    subtitle: 'Record sales & returns',
                    icon: Icons.download,
                    color: Colors.red,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EnhancedUnloadingScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildDashboardCard(
                    context,
                    title: 'Expenses',
                    subtitle: 'Fuel, salary & more',
                    icon: Icons.money_off,
                    color: Colors.deepOrange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ExpensesScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDashboardCard(
                    context,
                    title: 'Payments',
                    subtitle: 'Cash, credits & cheques',
                    icon: Icons.payment,
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PaymentsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Inventory Management Section
            _buildSectionTitle('Inventory Management'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDashboardCard(
                    context,
                    title: 'Add Stock',
                    subtitle: 'Record new stock entry',
                    icon: Icons.add_box_outlined,
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddStock(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDashboardCard(
                    context,
                    title: 'Add Items',
                    subtitle: 'Add new product items',
                    icon: Icons.inventory_2_outlined,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddItems(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildDashboardCard(
                    context,
                    title: 'Manage Items',
                    subtitle: 'Edit & delete items',
                    icon: Icons.edit_note,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManageItems(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDashboardCard(
                    context,
                    title: 'View Stock',
                    subtitle: 'Check current stock',
                    icon: Icons.visibility,
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StockViewer(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildDashboardCard(
                    context,
                    title: 'Price History',
                    subtitle: 'View price changes',
                    icon: Icons.history,
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PriceHistory(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDashboardCard(
                    context,
                    title: 'Invoices',
                    subtitle: 'Manage stock invoices',
                    icon: Icons.receipt_long,
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const InvoiceList(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Reports Section
            _buildSectionTitle('Reports & Analytics'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDashboardCard(
                    context,
                    title: 'Daily Reports',
                    subtitle: 'View accounts & sales reports',
                    icon: Icons.assessment,
                    color: Colors.deepPurple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DailyReportsScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDashboardCard(
                    context,
                    title: 'Daily Details',
                    subtitle: 'View detailed unloading records',
                    icon: Icons.list_alt,
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DailyUnloadingDetailsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Setup Section
            _buildSectionTitle('Setup & Configuration'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDashboardCard(
                    context,
                    title: 'Distributions',
                    subtitle: 'Manage distributions',
                    icon: Icons.business,
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DistributionsScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDashboardCard(
                    context,
                    title: 'Vehicles',
                    subtitle: 'Manage vehicles',
                    icon: Icons.local_shipping,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VehiclesScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _buildDashboardCard(
              context,
              title: 'Routes',
              subtitle: 'Add & manage delivery routes',
              icon: Icons.route,
              color: Colors.blueGrey,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RoutesCreation(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
