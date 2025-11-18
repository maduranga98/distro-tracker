# Distribution Tracking System - Codebase Analysis

## Executive Summary
This is a **Flutter mobile application** built with **Firebase Cloud Firestore** as the backend. The system tracks dairy distribution operations including loading inventory, unloading/selling items, routes, expenses, payments, and invoices.

---

## 1. PROJECT STRUCTURE

### Technology Stack
- **Frontend**: Flutter (Dart) - Cross-platform mobile app
- **Backend**: Firebase Cloud Firestore (NoSQL database)
- **Platform Support**: iOS, Android, Web, Windows, Linux, macOS
- **Package Manager**: Pubspec (Flutter dependencies)

### Directory Structure
```
distro_tracker_flutter/
├── lib/
│   ├── main.dart                          # App entry point
│   ├── dashboard.dart                     # Main dashboard/navigation
│   ├── firebase_options.dart              # Firebase configuration
│   ├── loading/                           # Inventory loading management
│   │   ├── loading.dart                   # Main loading workflow (4-step stepper)
│   │   ├── loadingUi.dart                 # Loading UI wrapper
│   │   ├── add_items.dart                 # Add new items to catalog
│   │   ├── add_stock.dart                 # Add stock for items
│   │   ├── manage_items.dart              # Manage item catalog
│   │   ├── stock_viewer.dart              # View current stock levels
│   │   └── price_history.dart             # Historical price tracking
│   ├── unloading/                         # Sales/distribution management
│   │   ├── unloading.dart                 # Basic unloading interface
│   │   ├── enhanced_unloading.dart        # Advanced unloading with details
│   │   ├── routes.dart                    # Route management (unloading routes)
│   │   └── customers.dart                 # Customer management
│   ├── setup/                             # Configuration & setup
│   │   ├── distributions.dart             # Distribution center management
│   │   ├── distribution_routes.dart       # Assign routes to distributions
│   │   └── vehicles.dart                  # Vehicle management
│   ├── reports/                           # Analytics & reporting
│   │   ├── daily_reports.dart             # Daily sales & expense summaries
│   │   └── daily_unloading_details.dart   # Unloading transaction details
│   ├── expenses/                          # Expense tracking
│   │   └── expenses.dart                  # Record fuel, salary, etc.
│   ├── payments/                          # Payment management
│   │   └── payments.dart                  # Cash, cheque, credit tracking
│   └── invoices/                          # Invoice management
│       ├── invoice_list.dart
│       ├── add_invoice.dart
│       └── invoice_details.dart
├── android/                               # Android native code
├── ios/                                   # iOS native code
├── web/                                   # Web platform support
├── windows/                               # Windows platform support
├── macos/                                 # macOS platform support
└── linux/                                 # Linux platform support
```

---

## 2. FIRESTORE DATABASE SCHEMA

### Collections & Data Models

#### **1. distributions** Collection
Master list of distribution centers
```
Document Fields:
- name (string): Distribution center name
- description (string): Description
- status (string): 'active' or 'inactive'
- routeIds (array): List of route IDs assigned to this distribution
- createdAt (timestamp): Creation date
- updatedAt (timestamp): Last update date
```

#### **2. routes** Collection
Delivery/distribution routes
```
Document Fields:
- routeName (string): Name of the route
- routeCode (string): Unique route code (e.g., RT001)
- startLocation (string): Starting point
- endLocation (string): Destination
- distance (number): Distance in km
- description (string): Route description
- notes (string): Additional notes
- status (string): 'active' or 'inactive'
- createdAt (timestamp)
- lastUpdated (timestamp)
```

#### **3. vehicles** Collection
Delivery vehicles/transportation
```
Document Fields:
- vehicleName (string): Vehicle name
- vehicleNumber (string): Registration/license plate
- distributionId (reference): Foreign key to distribution
- status (string): 'active' or 'inactive'
- createdAt (timestamp)
```

#### **4. items** Collection
Item catalog/product master data
```
Document Fields:
- productName (string): Product name
- productCode (string): Unique product code
- category (string): Product category
- brand (string): Brand name
- supplier (string): Supplier name
- unitType (string): Unit of measurement (pieces, liters, etc.)
- unitsPerCase (number): Units in a case (for bulk calculations)
- distributorPrice (number): Cost to distributor
- sellingPrice (number): Retail selling price
- mrp (number): Maximum Retail Price
- foc (number): Free on Case units
- createdAt (timestamp)
- updatedAt (timestamp)
```

#### **5. stock** Collection
Current inventory levels
```
Document Fields:
- itemId (reference): Foreign key to items
- productName (string): Product name (denormalized)
- productCode (string): Product code (denormalized)
- quantity (number): Current stock quantity in pieces
- unitsPerCase (number): Units per case
- batch (string): Batch/lot number
- batchNumber (string): Alternative batch identifier
- expiryDate (date): Expiration date
- supplier (string): Supplier
- distributorPrice (number): Unit cost
- category (string): Product category
- brand (string): Brand
- unitType (string): Unit type
- status (string): 'active' or 'inactive'
- createdAt (timestamp)
- lastUpdated (timestamp)
```

#### **6. loading** Collection
Outbound shipments from warehouse to vehicles
```
Document Fields:
- distributionId (reference): Distribution center
- routeId (reference): Route assigned
- vehicleId (reference): Vehicle used
- loadingDate (timestamp): Date loaded
- morningWeather (string): Weather conditions (Sunny, Cloudy, Rainy, Stormy)
- items (array of objects):
  - itemId (reference)
  - stockDocId (reference)
  - productCode (string)
  - productName (string)
  - batchNumber (string)
  - brand (string)
  - category (string)
  - unitType (string)
  - unitsPerCase (number)
  - loadingQuantity (number)
  - freeIssues (number): Free items included
  - distributorPrice (number)
  - totalValue (number): quantity × price
  - expiryDate (date)
  - supplier (string)
- totalItems (number): Count of different items
- totalQuantity (number): Total units loaded
- totalFreeIssues (number): Total free units
- totalValue (number): Total monetary value
- loadedAt (timestamp): Server timestamp
- status (string): 'loaded' or 'completed'
```

#### **7. unloading** Collection
Inbound returns/sales records from vehicles
```
Document Fields:
- loadingDocId (reference): Original loading record
- vehicleId (reference)
- distributionId (reference)
- loadingDate (timestamp): Original loading date
- unloadingDate (timestamp): When unloaded/sold
- items (array): Same structure as loading items
- totalItems (number): Items in shipment
- totalQuantity (number): Total units sold
- totalFreeIssues (number): Free items from loading + additional
- freeIssuesFromLoading (number): Free items in original loading
- additionalFreeIssues (number): Extra free items given at sale
- totalValue (number): Base sales value
- totalDiscounts (number): Discounts given
- netValue (number): totalValue - totalDiscounts
- unloadedAt (timestamp): Server timestamp
- status (string): 'completed'
```

#### **8. expenses** Collection
Operational expenses
```
Document Fields:
- expenseType (string): Type (Fuel, Salary, Maintenance, etc.)
- amount (number): Expense amount
- vehicleId (reference): Associated vehicle
- date (timestamp): Expense date
- description (string): Details
- createdAt (timestamp)
```

#### **9. payments** Collection
Payment records
```
Document Fields:
- paymentType (string): Type (Cash, Cheque, Credit)
- amount (number): Payment amount
- vehicleId (reference): Associated vehicle
- date (timestamp): Payment date
- description (string): Details
- chequeNumber (string): Cheque number if applicable
- createdAt (timestamp)
```

#### **10. invoices** Collection
Sales invoices
```
Document Fields:
- invoiceNumber (string): Unique invoice ID
- customerId (reference): Customer reference
- items (array): Items in invoice
- totalAmount (number)
- status (string): Draft, Issued, Paid, etc.
- createdAt (timestamp)
```

#### **11. price_history** Collection
Historical pricing data
```
Document Fields:
- itemId (reference)
- price (number): Price at that time
- date (timestamp): Date of price
- supplier (string)
```

#### **12. daily_sales** Collection
Aggregated daily sales summaries
```
Document Fields:
- date (timestamp): Date of sales
- totalSales (number)
- totalQuantity (number)
- itemsSold (number)
```

---

## 3. API ENDPOINTS & DATA FLOW

### Loading Flow (4-Step Process)
**Step 1: Distribution & Route Selection**
- Retrieves active distributions from `distributions` collection
- Retrieves assigned routes from `routes` collection (via distribution.routeIds)
- User selects distribution and route

**Step 2: Loading Details**
- Retrieves vehicles for selected distribution from `vehicles` collection
- User selects vehicle, loading date, and weather conditions

**Step 3: Items Selection**
- Retrieves active items with stock > 0 from `stock` collection
- User selects items and specifies quantities (in cases/pieces)
- Supports free issues (FOC) quantities

**Step 4: Review & Save**
- Creates document in `loading` collection
- Decrements stock in `stock` collection
- Displays loading summary

### Unloading/Sales Flow
1. Fetches `loading` documents with status 'loaded'
2. Shows list of loaded shipments
3. User records:
   - Total discounts given
   - Additional free issues
4. Creates document in `unloading` collection
5. Updates loading document status to 'completed'

### Stock Management
- `add_stock.dart`: Adds new stock entries to `stock` collection
- `add_items.dart`: Creates items in `items` collection
- `manage_items.dart`: CRUD operations on items
- Stock decrements on loading, tracked in stock.quantity

### Routes Management
- Creation: `unloading/routes.dart` (RoutesCreation widget)
- Uses `routes` collection for full CRUD
- Supports route codes, start/end locations, distance, status

### Distribution Setup
- `setup/distributions.dart`: Create/edit distributions
- `setup/distribution_routes.dart`: Assign routes to distributions
- Updates distribution.routeIds array

---

## 4. EXISTING ANALYTICS & REPORTING FEATURES

### Daily Reports (daily_reports.dart)
**Accessible from Dashboard → Reports → Daily Reports**

**Features:**
1. **Date & Vehicle Filtering**
   - Select specific date
   - Filter by vehicle (optional - shows all if not selected)

2. **Sales Summary**
   - Net Sales Value (total revenue)
   - Total Items Sold (count)
   - Total Returns (quantity)
   - Total Damaged (quantity)
   - Total Discounts (amount)
   - Free Issues Given (quantity)
   
   **Data Source**: Queries `unloading` collection for selected date range
   
   **Calculation Logic**:
   ```
   Total Sales = SUM(unloading.totalValue - unloading.totalDiscounts)
   Total Items Sold = SUM(unloading.totalQuantity)
   Total Returns/Damaged = Tracked separately in unloading records
   Free Issues = SUM(unloading.totalFreeIssues)
   ```

3. **Expenses Summary**
   - Total Expenses (sum)
   - Fuel Expenses
   - Salary Expenses
   - Other expense categories
   
   **Data Source**: Queries `expenses` collection grouped by expenseType
   
   **Calculation Logic**:
   ```
   Total Expenses = SUM(expenses.amount) WHERE date = selected_date
   By Type = SUM(expenses.amount) WHERE date = selected_date AND expenseType = 'type'
   ```

4. **Profit/Loss Summary**
   - Gross Profit = Net Sales - Cost of Goods
   - Net Profit = Gross Profit - Total Expenses

### Daily Unloading Details (daily_unloading_details.dart)
**Detailed transaction-level reporting**
- Lists all unloading transactions for a selected date
- Shows item-level details
- Displays quantities sold, discounts, and free issues per transaction
- Expandable view for individual items in each unloading

---

## 5. KEY BUSINESS LOGIC PATTERNS

### Stock Tracking
```
Available Stock = stock.quantity (pieces)
Cases = quantity / unitsPerCase
Pieces = quantity % unitsPerCase
```

### Pricing Models
```
Cost = stock.distributorPrice
Revenue = loading.loadingQuantity × stock.distributorPrice (at loading)
Discount = unloading.totalDiscounts (applied at sale time)
Net Revenue = totalValue - totalDiscounts
```

### Free Issues (FOC) Management
```
FOC in Loading = specified at loading time
FOC at Sale = freeIssuesFromLoading + additionalFreeIssues
These are tracked separately from sold quantities
```

### Weather Tracking
Records morning weather during loading for correlation analysis

---

## 6. CURRENT DATA MODEL LIMITATIONS

### Issues for Analytics System Development:

1. **No Customer/Buyer Data**
   - Unloading doesn't track who purchased items
   - No way to analyze by customer/shop
   - No credit tracking per customer

2. **Incomplete Return Tracking**
   - Returns are mentioned in reports but not explicitly tracked
   - No separate return reason codes
   - No damaged goods audit trail

3. **Missing Timestamps in Some Collections**
   - Some collections lack proper audit timestamps
   - Makes historical analysis difficult

4. **Denormalized Data**
   - Item details duplicated in stock and loading/unloading
   - Can cause data inconsistency
   - Updates require changes in multiple places

5. **No Hierarchical Customer/Route Mapping**
   - Can't track sales per shop/customer
   - Route coverage analysis not possible

6. **Limited Payment Tracking**
   - Payments stored separately from unloading
   - No direct linking of payment to specific sales
   - Cash flow tracking is manual

---

## 7. RECOMMENDATIONS FOR ANALYTICS SYSTEM

### 1. Enhance Data Model
- Add `customers` collection with shop details
- Add `unloading_details` with item-level tracking
- Add `customer_sales_map` for shop-to-sale linking
- Add `route_performance` pre-calculated summaries

### 2. Create Analytics Collections
```
daily_analytics/
├── {date}/
│   ├── totalSales
│   ├── totalQuantity
│   ├── byVehicle
│   ├── byRoute
│   ├── byItem
│   └── profitability

performance_metrics/
├── vehicle_performance/
├── route_performance/
├── item_performance/
└── salesperson_performance/
```

### 3. Key Metrics to Track
- Daily/Weekly/Monthly sales trends
- Vehicle utilization rates
- Route profitability
- Item sell-through rates
- Return rates by item
- Free issue distribution impact
- Discount patterns
- Customer concentration

### 4. Real-time Dashboard Queries
Optimize for:
- Today's sales vs target
- Vehicle on-route status
- Stock level alerts
- Cash collection tracking
- Expense approvals

---

## 8. SUMMARY TABLE: COLLECTIONS & RELATIONSHIPS

| Collection | Purpose | Key Fields | Relations |
|-----------|---------|-----------|-----------|
| distributions | Distribution centers | name, routeIds | → routes, vehicles |
| routes | Delivery routes | routeName, routeCode | ← distributions |
| vehicles | Vehicles | vehicleName, distributionId | → distributions, loading, unloading |
| items | Product catalog | productName, productCode | → stock, price_history |
| stock | Inventory levels | quantity, itemId | ← items, → loading |
| loading | Shipments out | vehicleId, routeId, items | ← stock, → unloading |
| unloading | Sales recorded | loadingDocId, totalValue | ← loading, → payments |
| expenses | Operating costs | expenseType, vehicleId | → vehicles |
| payments | Revenue collection | paymentType, vehicleId | → vehicles, unloading |
| invoices | Sales invoices | items, totalAmount | → unloading |
| price_history | Historical pricing | itemId, price, date | ← items |
| daily_sales | Aggregated summaries | totalSales, date | ← unloading |

---

## 9. FIREBASE SECURITY & CONFIGURATION

Located in: `lib/firebase_options.dart`
- Contains platform-specific Firebase configuration
- Supports: iOS, Android, Web, Windows, macOS, Linux

---

## 10. NEXT STEPS FOR ANALYTICS DEVELOPMENT

1. **Review current data accuracy** - Audit existing loading/unloading records
2. **Design new analytics collections** - Plan pre-calculated metrics
3. **Create Firestore indexes** - For efficient querying of analytics data
4. **Build dashboards** - Real-time and historical analysis views
5. **Implement data export** - CSV/PDF reports for external analysis
6. **Create alerts system** - For anomalies and thresholds
7. **Add forecasting** - Demand and inventory predictions

