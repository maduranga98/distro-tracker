# QUERY PATTERNS & ANALYTICS IMPLEMENTATION

## Firestore Query Patterns Used in App

### 1. Loading Data Queries

#### Query Active Stock
```dart
// From loading.dart - Load items with stock > 0
final QuerySnapshot itemsSnapshot = await _firestore
    .collection('stock')
    .where('status', isEqualTo: 'active')
    .where('quantity', isGreaterThan: 0)
    .orderBy('quantity')
    .orderBy('productName')
    .get();

// Use case: Populate items list for loading
// Performance: Can be slow with large inventories
```

#### Query Vehicles for Distribution
```dart
// From loading.dart - Get vehicles by distribution
final snapshot = await _firestore
    .collection('vehicles')
    .where('distributionId', isEqualTo: distributionId)
    .where('status', isEqualTo: 'active')
    .get();

// Use case: Populate vehicle dropdown
```

#### Query Routes for Distribution
```dart
// From loading.dart - Get routes assigned to distribution
final distributionDoc = await _firestore
    .collection('distributions')
    .doc(distributionId)
    .get();

final routeIds = List<String>.from(data?['routeIds'] ?? []);

final routesSnapshot = await _firestore
    .collection('routes')
    .where(FieldPath.documentId, whereIn: routeIds)
    .where('status', isEqualTo: 'active')
    .get();

// Use case: Show only routes assigned to distribution
```

### 2. Unloading Data Queries

#### Query Loaded Shipments
```dart
// From unloading.dart - Get pending unloading records
final loadings = _firestore
    .collection('loading')
    .where('status', isEqualTo: 'loaded')
    .orderBy('loadedAt', descending: true)
    .snapshots();

// Use case: Show list of loaded items ready to unload
```

#### Save Unloading Record
```dart
// Create unloading document
final unloadingData = {
  'loadingDocId': loadingDocId,
  'vehicleId': loadingData['vehicleId'],
  'distributionId': loadingData['distributionId'],
  'loadingDate': loadingData['loadingDate'],
  'unloadingDate': Timestamp.now(),
  'items': items,
  'totalItems': loadingData['totalItems'],
  'totalQuantity': totalSoldQty,
  'totalFreeIssues': totalFreeIssuesFromLoading + additionalFreeIssues,
  'totalValue': loadingData['totalValue'],
  'totalDiscounts': discounts,
  'netValue': (loadingData['totalValue'] as num).toDouble() - discounts,
  'unloadedAt': FieldValue.serverTimestamp(),
  'status': 'completed',
};

await _firestore.collection('unloading').add(unloadingData);

// Update loading status
await _firestore
    .collection('loading')
    .doc(loadingDocId)
    .update({'status': 'completed'});
```

### 3. Analytics Queries

#### Daily Sales Summary Query
```dart
// From daily_reports.dart - Calculate sales summary
Future<Map<String, dynamic>> _getSalesSummary() async {
  final startDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  final endDate = startDate.add(Duration(days: 1));
  
  Query query = _firestore
      .collection('unloading')
      .where('unloadedAt', isGreaterThanOrEqualTo: startDate)
      .where('unloadedAt', isLessThan: endDate);
  
  if (selectedVehicleId != null) {
    query = query.where('vehicleId', isEqualTo: selectedVehicleId);
  }
  
  final snapshot = await query.get();
  
  // Aggregate results
  double totalSales = 0;
  int totalItemsSold = 0;
  int totalReturns = 0;
  int totalDamaged = 0;
  double totalDiscounts = 0;
  int totalFreeIssues = 0;
  
  for (var doc in snapshot.docs) {
    final data = doc.data() as Map<String, dynamic>;
    totalSales += (data['netValue'] as num?)?.toDouble() ?? 0;
    totalItemsSold += (data['totalItems'] as int?) ?? 0;
    // ... other calculations
  }
  
  return {
    'totalSales': totalSales,
    'totalItemsSold': totalItemsSold,
    'totalReturns': totalReturns,
    'totalDamaged': totalDamaged,
    'totalDiscounts': totalDiscounts,
    'totalFreeIssues': totalFreeIssues,
  };
}

// Query Result Example:
// {
//   "totalSales": 52100.00,
//   "totalItemsSold": 5,
//   "totalReturns": 0,
//   "totalDamaged": 0,
//   "totalDiscounts": 2500.00,
//   "totalFreeIssues": 100
// }
```

#### Expenses Summary Query
```dart
// From daily_reports.dart - Calculate expenses summary
Future<Map<String, dynamic>> _getExpensesSummary() async {
  final startDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  final endDate = startDate.add(Duration(days: 1));
  
  Query query = _firestore
      .collection('expenses')
      .where('date', isGreaterThanOrEqualTo: startDate)
      .where('date', isLessThan: endDate);
  
  if (selectedVehicleId != null) {
    query = query.where('vehicleId', isEqualTo: selectedVehicleId);
  }
  
  final snapshot = await query.get();
  
  // Aggregate by expense type
  Map<String, double> expensesByType = {};
  double totalExpenses = 0;
  
  for (var doc in snapshot.docs) {
    final data = doc.data() as Map<String, dynamic>;
    final expenseType = data['expenseType'] as String?;
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    
    if (expenseType != null) {
      expensesByType[expenseType] = (expensesByType[expenseType] ?? 0) + amount;
    }
    totalExpenses += amount;
  }
  
  return {
    'totalExpenses': totalExpenses,
    'fuelExpenses': expensesByType['Fuel'] ?? 0,
    'salaryExpenses': expensesByType['Salary'] ?? 0,
    'maintenanceExpenses': expensesByType['Maintenance'] ?? 0,
    'otherExpenses': expensesByType['Other'] ?? 0,
  };
}
```

---

## Recommended Analytics Collection Structure

### 1. Create Performance Metrics Collection
```
performance_metrics/
├── vehicle_performance/{vehicleId}/
│   ├── totalLoads: 15
│   ├── totalUnloads: 15
│   ├── totalDistance: 450 km
│   ├── totalSalesValue: 525000
│   ├── totalDiscounts: 25000
│   ├── profitMargin: 8.5%
│   ├── avgLoadValue: 35000
│   ├── avgUnloadValue: 35000
│   ├── lastUpdated: Timestamp
│
├── route_performance/{routeId}/
│   ├── totalLoads: 30
│   ├── totalSalesValue: 1050000
│   ├── avgSalesPerDay: 35000
│   ├── profitability: 8.2%
│   ├── lastUpdated: Timestamp
│
├── item_performance/{itemId}/
│   ├── totalQuantityLoaded: 5000
│   ├── totalQuantitySold: 4900
│   ├── salesRate: 98%
│   ├── totalRevenue: 250000
│   ├── avgDiscount: 2.5%
│   ├── lastUpdated: Timestamp
```

### 2. Daily Summary Collection
```
daily_analytics/{date}/
{
  "date": "2024-01-15",
  "totalSalesValue": 525000,
  "totalSalesQty": 2500,
  "totalExpenses": 75000,
  "netProfit": 450000,
  "profitMargin": 8.5%,
  "avgOrderValue": 35000,
  
  "byVehicle": {
    "vehicle_001": {
      "salesValue": 175000,
      "quantity": 800,
      "expenses": 25000,
      "netProfit": 150000
    },
    "vehicle_002": {
      "salesValue": 175000,
      "quantity": 850,
      "expenses": 25000,
      "netProfit": 150000
    }
  },
  
  "byRoute": {
    "route_001": {
      "salesValue": 175000,
      "quantity": 800
    },
    "route_002": {
      "salesValue": 175000,
      "quantity": 850
    }
  },
  
  "byExpenseType": {
    "Fuel": 50000,
    "Salary": 25000
  },
  
  "lastUpdated": Timestamp(2024-01-15T23:59:59Z)
}
```

---

## Optimization Strategies

### 1. Pre-calculate Metrics
Instead of calculating on-demand, use Cloud Functions to update metrics:

```dart
// Cloud Function (TypeScript)
export const updateDailyMetrics = functions.pubsub
  .schedule('0 0 * * *')  // Daily at midnight
  .onRun(async (context) => {
    const db = admin.firestore();
    
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    
    const startDate = new Date(yesterday.getFullYear(), 
                               yesterday.getMonth(), 
                               yesterday.getDate());
    const endDate = new Date(startDate);
    endDate.setDate(endDate.getDate() + 1);
    
    // Query unloading records for yesterday
    const unloadings = await db.collection('unloading')
      .where('unloadedAt', '>=', startDate)
      .where('unloadedAt', '<', endDate)
      .get();
    
    // Calculate metrics
    let totalSales = 0;
    let byVehicle = {};
    let byRoute = {};
    
    unloadings.forEach(doc => {
      const data = doc.data();
      totalSales += data.netValue;
      
      // Group by vehicle
      const vehicleId = data.vehicleId;
      if (!byVehicle[vehicleId]) {
        byVehicle[vehicleId] = {
          salesValue: 0,
          quantity: 0
        };
      }
      byVehicle[vehicleId].salesValue += data.netValue;
      byVehicle[vehicleId].quantity += data.totalQuantity;
      
      // Group by route
      const routeId = data.routeId;
      if (!byRoute[routeId]) {
        byRoute[routeId] = {
          salesValue: 0,
          quantity: 0
        };
      }
      byRoute[routeId].salesValue += data.netValue;
      byRoute[routeId].quantity += data.totalQuantity;
    });
    
    // Store in daily_analytics
    const dateStr = `${startDate.getFullYear()}-${
      String(startDate.getMonth() + 1).padStart(2, '0')}-${
      String(startDate.getDate()).padStart(2, '0')}`;
    
    await db.collection('daily_analytics').doc(dateStr).set({
      totalSalesValue: totalSales,
      byVehicle: byVehicle,
      byRoute: byRoute,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });
  });
```

### 2. Use Aggregation Queries (Firebase 9.0+)
```dart
// More efficient aggregation
final snapshot = await _firestore
    .collection('unloading')
    .where('unloadedAt', isGreaterThanOrEqualTo: startDate)
    .where('unloadedAt', isLessThan: endDate)
    .count()
    .get();

final count = snapshot.count; // Get count without fetching all docs
```

### 3. Cache Results
```dart
// Store in local cache with timestamp
class CachedMetrics {
  final Map<String, dynamic> data;
  final DateTime cachedAt;
  
  bool isExpired() {
    return DateTime.now().difference(cachedAt).inMinutes > 30;
  }
}

final cache = CachedMetrics(
  data: metrics,
  cachedAt: DateTime.now()
);
```

---

## Real-time Analytics Dashboard Pattern

```dart
// Listen to unloading changes in real-time
StreamBuilder<QuerySnapshot>(
  stream: _firestore
      .collection('unloading')
      .where('unloadedAt', isGreaterThanOrEqualTo: startDate)
      .where('unloadedAt', isLessThan: endDate)
      .orderBy('unloadedAt', descending: true)
      .snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
      return const CircularProgressIndicator();
    }
    
    // Real-time calculations
    double totalSales = 0;
    int totalQuantity = 0;
    
    for (var doc in snapshot.data!.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalSales += (data['netValue'] as num?)?.toDouble() ?? 0;
      totalQuantity += (data['totalQuantity'] as int?) ?? 0;
    }
    
    return Column(
      children: [
        Text('Today\'s Sales: Rs. ${totalSales.toStringAsFixed(2)}'),
        Text('Quantity Sold: $totalQuantity units'),
      ],
    );
  },
)
```

---

## Key Performance Indicators (KPIs) to Track

### 1. Sales Metrics
- Daily sales value
- Sales by vehicle
- Sales by route
- Average order value
- Sales trend (7-day, 30-day)
- Best-selling items
- Sell-through rate

### 2. Inventory Metrics
- Stock turnover rate
- Slow-moving items
- Expired/expiring stock
- Stock utilization
- Warehouse fill rate

### 3. Operational Metrics
- Vehicle utilization (loads per day)
- Average load value
- Distance traveled vs sales
- Fuel efficiency
- Route efficiency

### 4. Financial Metrics
- Gross profit margin
- Net profit margin
- Discount rate
- FOC cost impact
- Expense ratio

### 5. Customer Metrics
- Repeat order rate
- Average payment terms
- Bad debt ratio
- Customer concentration

---

## Implementation Timeline

**Phase 1** (Week 1-2):
- Create daily_analytics collection
- Implement daily summary calculations
- Add basic dashboards

**Phase 2** (Week 3-4):
- Create performance_metrics collection
- Add vehicle performance tracking
- Add route performance analytics

**Phase 3** (Week 5-6):
- Implement Cloud Functions for automation
- Add real-time dashboards
- Optimize queries with indexes

**Phase 4** (Week 7+):
- Advanced analytics (forecasting, trends)
- Export/reporting features
- Mobile dashboard optimization

