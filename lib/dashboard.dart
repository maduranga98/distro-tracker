import 'package:flutter/material.dart';
import 'package:distro_tracker_flutter/setup/distributions.dart';
import 'package:distro_tracker_flutter/setup/vehicles.dart';
import 'package:distro_tracker_flutter/loading/loadingUi.dart';
import 'package:distro_tracker_flutter/unloading/unloading.dart';
import 'package:distro_tracker_flutter/expenses/expenses.dart';
import 'package:distro_tracker_flutter/payments/payments.dart';
import 'package:distro_tracker_flutter/reports/daily_reports.dart';
import 'package:distro_tracker_flutter/invoices/invoice_list.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Welcome to Distro Tracker',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage your dairy distribution business',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
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

            const SizedBox(height: 24),

            // Inventory Management Section
            _buildSectionTitle('Inventory Management'),
            const SizedBox(height: 12),
            _buildDashboardCard(
              context,
              title: 'Invoices',
              subtitle: 'Manage stock invoices',
              icon: Icons.receipt_long,
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const InvoiceList(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

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
                          builder: (context) => const UnloadingScreen(),
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

            // Reports Section
            _buildSectionTitle('Reports & Analytics'),
            const SizedBox(height: 12),
            _buildDashboardCard(
              context,
              title: 'Daily Reports',
              subtitle: 'View accounts & sales reports',
              icon: Icons.assessment,
              color: Colors.indigo,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DailyReportsScreen(),
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
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.grey[700],
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
