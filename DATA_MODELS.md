# DATA MODELS - DETAILED SPECIFICATIONS

## Detailed Data Structures with Examples

### 1. ITEMS Collection
```dart
// Dart Model (should be formalized in production)
class Item {
  String id;
  String productName;              // e.g., "Full Cream Milk"
  String productCode;              // e.g., "FCM-001"
  String category;                 // e.g., "Dairy"
  String brand;                    // e.g., "Lanka Dairies"
  String supplier;                 // e.g., "Lanka Dairies PVT Ltd"
  String unitType;                 // e.g., "Bottle", "Litre", "Pieces"
  int unitsPerCase;               // e.g., 24 bottles per carton
  double distributorPrice;         // e.g., 45.50 (cost to distributor)
  double sellingPrice;             // e.g., 55.00 (retail price)
  double mrp;                      // e.g., 55.00 (max retail price)
  int foc;                        // e.g., 2 (free issues per case)
  DateTime createdAt;
  DateTime updatedAt;
}

// Firestore Document Example
{
  "productName": "Full Cream Milk",
  "productCode": "FCM-001",
  "category": "Dairy Products",
  "brand": "Lanka Dairies",
  "supplier": "Lanka Dairies PVT Ltd",
  "unitType": "Bottle",
  "unitsPerCase": 24,
  "distributorPrice": 45.50,
  "sellingPrice": 55.00,
  "mrp": 55.00,
  "foc": 2,
  "createdAt": Timestamp(2024-01-15),
  "updatedAt": Timestamp(2024-01-15)
}
```

### 2. STOCK Collection (Inventory)
```dart
class Stock {
  String id;
  String itemId;                   // Reference to items collection
  String productName;              // Denormalized from items
  String productCode;              // Denormalized from items
  int quantity;                    // Current pieces in stock
  int unitsPerCase;               // From item master
  String batchNumber;              // e.g., "BATCH-20240115-001"
  DateTime expiryDate;             // e.g., 2024-06-15
  String supplier;
  double distributorPrice;
  String category;
  String brand;
  String unitType;
  String status;                   // "active" or "inactive"
  DateTime createdAt;
  DateTime lastUpdated;
}

// Firestore Document Example
{
  "itemId": "doc_id_123",
  "productName": "Full Cream Milk",
  "productCode": "FCM-001",
  "quantity": 480,                 // 20 cases × 24 pieces
  "unitsPerCase": 24,
  "batchNumber": "BATCH-20240115-001",
  "expiryDate": Timestamp(2024-06-15),
  "supplier": "Lanka Dairies PVT Ltd",
  "distributorPrice": 45.50,
  "category": "Dairy Products",
  "brand": "Lanka Dairies",
  "unitType": "Bottle",
  "status": "active",
  "createdAt": Timestamp(2024-01-15),
  "lastUpdated": Timestamp(2024-01-15)
}
```

### 3. LOADING Collection (Shipments)
```dart
class LoadingRecord {
  String id;
  String distributionId;           // Reference to distributions
  String routeId;                  // Reference to routes
  String vehicleId;                // Reference to vehicles
  DateTime loadingDate;
  String morningWeather;           // "Sunny", "Cloudy", "Rainy", "Stormy"
  List<LoadingItem> items;
  int totalItems;                  // Count of different items
  int totalQuantity;               // Total units loaded
  int totalFreeIssues;
  double totalValue;               // Cost value
  String status;                   // "loaded" or "completed"
  DateTime loadedAt;               // Server timestamp
}

class LoadingItem {
  String itemId;
  String stockDocId;
  String productCode;
  String productName;
  String batchNumber;
  String brand;
  String category;
  String unitType;
  int unitsPerCase;
  int loadingQuantity;             // Pieces loaded
  int freeIssues;                  // FOC pieces
  double distributorPrice;
  double totalValue;               // quantity × price
  DateTime expiryDate;
  String supplier;
}

// Firestore Document Example
{
  "distributionId": "dist_001",
  "routeId": "route_001",
  "vehicleId": "vehicle_001",
  "loadingDate": Timestamp(2024-01-15T06:30:00),
  "morningWeather": "Sunny",
  "items": [
    {
      "itemId": "item_001",
      "stockDocId": "stock_001",
      "productCode": "FCM-001",
      "productName": "Full Cream Milk",
      "batchNumber": "BATCH-20240115-001",
      "brand": "Lanka Dairies",
      "category": "Dairy Products",
      "unitType": "Bottle",
      "unitsPerCase": 24,
      "loadingQuantity": 240,      // 10 cases
      "freeIssues": 20,            // 2 FOC per case
      "distributorPrice": 45.50,
      "totalValue": 10920.00,      // 240 × 45.50
      "expiryDate": Timestamp(2024-06-15),
      "supplier": "Lanka Dairies PVT Ltd"
    }
  ],
  "totalItems": 1,
  "totalQuantity": 240,
  "totalFreeIssues": 20,
  "totalValue": 10920.00,
  "status": "loaded",
  "loadedAt": Timestamp(2024-01-15T06:35:00Z)
}
```

### 4. UNLOADING Collection (Sales/Returns)
```dart
class UnloadingRecord {
  String id;
  String loadingDocId;             // Reference to original loading
  String vehicleId;
  String distributionId;
  DateTime loadingDate;
  DateTime unloadingDate;
  List<LoadingItem> items;         // Same structure as loading
  int totalItems;
  int totalQuantity;               // Units sold/returned
  int totalFreeIssues;
  int freeIssuesFromLoading;
  int additionalFreeIssues;
  double totalValue;               // Gross sales value
  double totalDiscounts;           // Discounts given
  double netValue;                 // Net after discount
  String status;                   // "completed"
  DateTime unloadedAt;             // Server timestamp
}

// Firestore Document Example
{
  "loadingDocId": "loading_001",
  "vehicleId": "vehicle_001",
  "distributionId": "dist_001",
  "loadingDate": Timestamp(2024-01-15T06:35:00Z),
  "unloadingDate": Timestamp(2024-01-15T17:30:00Z),
  "items": [
    {
      "itemId": "item_001",
      "stockDocId": "stock_001",
      "productCode": "FCM-001",
      "productName": "Full Cream Milk",
      "loadingQuantity": 240,
      "freeIssues": 20,
      "distributorPrice": 45.50,
      "totalValue": 10920.00
      // ... other fields
    }
  ],
  "totalItems": 1,
  "totalQuantity": 240,
  "totalFreeIssues": 20,
  "freeIssuesFromLoading": 20,
  "additionalFreeIssues": 0,
  "totalValue": 10920.00,
  "totalDiscounts": 500.00,        // Amount discounted
  "netValue": 10420.00,            // After discount
  "status": "completed",
  "unloadedAt": Timestamp(2024-01-15T17:35:00Z)
}
```

### 5. DISTRIBUTIONS Collection
```dart
class Distribution {
  String id;
  String name;                     // e.g., "Colombo District"
  String description;
  String status;                   // "active", "inactive"
  List<String> routeIds;          // Array of route IDs
  DateTime createdAt;
  DateTime updatedAt;
}

// Firestore Document Example
{
  "name": "Colombo District",
  "description": "Main distribution center for Colombo region",
  "status": "active",
  "routeIds": ["route_001", "route_002", "route_003"],
  "createdAt": Timestamp(2024-01-01),
  "updatedAt": Timestamp(2024-01-15)
}
```

### 6. ROUTES Collection
```dart
class Route {
  String id;
  String routeName;               // e.g., "Downtown Colombo"
  String routeCode;               // e.g., "RT-001"
  String startLocation;           // e.g., "Colombo Distribution Center"
  String endLocation;             // e.g., "Pettah Market"
  double distance;                // Distance in km
  String description;
  String notes;
  String status;                  // "active", "inactive"
  DateTime createdAt;
  DateTime lastUpdated;
}

// Firestore Document Example
{
  "routeName": "Downtown Colombo",
  "routeCode": "RT-001",
  "startLocation": "Colombo Distribution Center",
  "endLocation": "Pettah Market",
  "distance": 12.5,
  "description": "Main commercial shopping area",
  "notes": "Heavy traffic after 3 PM",
  "status": "active",
  "createdAt": Timestamp(2024-01-01),
  "lastUpdated": Timestamp(2024-01-15)
}
```

### 7. VEHICLES Collection
```dart
class Vehicle {
  String id;
  String vehicleName;             // e.g., "Truck-01"
  String vehicleNumber;           // e.g., "WP-ABC-1234"
  String distributionId;          // Reference to distributions
  String status;                  // "active", "inactive"
  DateTime createdAt;
}

// Firestore Document Example
{
  "vehicleName": "Truck-01",
  "vehicleNumber": "WP-ABC-1234",
  "distributionId": "dist_001",
  "status": "active",
  "createdAt": Timestamp(2024-01-01)
}
```

### 8. EXPENSES Collection
```dart
class Expense {
  String id;
  String expenseType;             // "Fuel", "Salary", "Maintenance", etc.
  double amount;
  String vehicleId;               // Reference to vehicles
  DateTime date;
  String description;
  DateTime createdAt;
}

// Firestore Document Example
{
  "expenseType": "Fuel",
  "amount": 3500.00,
  "vehicleId": "vehicle_001",
  "date": Timestamp(2024-01-15),
  "description": "Diesel refill at Shell station",
  "createdAt": Timestamp(2024-01-15T08:00:00Z)
}
```

### 9. PAYMENTS Collection
```dart
class Payment {
  String id;
  String paymentType;             // "Cash", "Cheque", "Credit"
  double amount;
  String vehicleId;               // Reference to vehicles
  DateTime date;
  String description;
  String? chequeNumber;           // For cheque payments
  DateTime createdAt;
}

// Firestore Document Example
{
  "paymentType": "Cash",
  "amount": 10420.00,
  "vehicleId": "vehicle_001",
  "date": Timestamp(2024-01-15),
  "description": "Cash collection from retail outlets",
  "chequeNumber": null,
  "createdAt": Timestamp(2024-01-15T17:45:00Z)
}
```

---

## Key Calculation Patterns

### Case & Piece Breakdown
```dart
int cases = quantity ~/ unitsPerCase;      // Integer division
int pieces = quantity % unitsPerCase;      // Remainder
// Example: 240 pieces with 24/case = 10 cases, 0 pieces
```

### FOC (Free on Case) Calculation
```dart
// During Loading
int focCases = freeIssuesPerCase * cases;
int focPieces = freeIssuesPerCase * cases;

// Example: 10 cases × 2 FOC per case = 20 free pieces
```

### Revenue Calculations
```dart
double loadingValue = loadingQuantity * distributorPrice;
// Example: 240 pieces × 45.50 = 10,920.00 (cost value)

double netRevenue = totalValue - totalDiscounts;
// Example: 10,920.00 - 500.00 = 10,420.00
```

---

## Field Validation Rules

### Items
- productCode: Must be unique
- unitsPerCase: Must be > 0
- Prices: Must be >= 0

### Stock
- quantity: Must be >= 0
- batchNumber: Must be unique per item
- expiryDate: Must be future date

### Loading
- loadingQuantity: Must not exceed available stock
- freeIssues: Must be >= 0
- At least 1 item required

### Unloading
- totalDiscounts: Must be <= totalValue
- Cannot process without corresponding loading

---

## Index Requirements for Analytics

```
// Recommended Firestore Indexes

// For Loading Analytics
1. loading: (distributionId, loadedAt desc)
2. loading: (vehicleId, loadedAt desc)
3. loading: (routeId, loadedAt desc)
4. loading: (status, loadedAt desc)

// For Unloading Analytics
5. unloading: (distributionId, unloadedAt desc)
6. unloading: (vehicleId, unloadedAt desc)
7. unloading: (status, unloadedAt desc)

// For Expense/Payment Analysis
8. expenses: (vehicleId, date desc)
9. expenses: (expenseType, date desc)
10. payments: (vehicleId, date desc)
11. payments: (paymentType, date desc)

// For Stock Management
12. stock: (status, quantity)
13. stock: (itemId, lastUpdated desc)
```

