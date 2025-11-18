# Analytics System Development Guide

## Quick Reference

This document serves as a starting point for building a comprehensive analytics system for the distribution tracking application.

### Generated Documentation Files

**IMPORTANT**: Three detailed documentation files have been generated for you:

1. **CODEBASE_ANALYSIS.md** (17 KB)
   - Complete project structure and technology stack
   - Full Firestore database schema with all 12 collections
   - API endpoints and data flow patterns
   - Existing analytics features (Daily Reports, Unloading Details)
   - Current limitations and recommendations
   - Collections relationship summary table

2. **DATA_MODELS.md** (12 KB)
   - Detailed data structures with Dart class definitions
   - Firestore document examples with sample data
   - Field validation rules
   - Key calculation patterns (cases/pieces, FOC, revenue)
   - Index requirements for efficient analytics queries
   - Business logic for stock tracking and pricing

3. **QUERY_PATTERNS_ANALYTICS.md** (13 KB)
   - Real code examples from the application
   - Loading data queries and patterns
   - Unloading/sales flow queries
   - Analytics aggregation queries
   - Recommended analytics collection structures
   - Optimization strategies and caching patterns
   - Cloud Functions examples for automation
   - KPI tracking recommendations

---

## Architecture Overview

```
DISTRIBUTION TRACKER SYSTEM

FRONTEND: Flutter (Dart)
├── loading/              Loading/Shipment Management
├── unloading/           Sales/Distribution Recording
├── setup/               Configuration
├── reports/             Analytics & Reporting
├── expenses/            Cost Tracking
├── payments/            Revenue Collection
└── invoices/            Invoice Management

BACKEND: Firebase Cloud Firestore
├── distributions        Distribution Centers
├── routes              Delivery Routes
├── vehicles            Transport Fleet
├── items               Product Catalog
├── stock               Inventory Levels
├── loading             Shipment Records
├── unloading           Sales Records
├── expenses            Operating Costs
├── payments            Revenue Records
├── invoices            Invoice Documents
├── price_history       Historical Pricing
└── daily_sales         Aggregated Summaries
```

---

## Key Firestore Collections (12 Total)

| Collection | Purpose | Records |
|-----------|---------|---------|
| **distributions** | Distribution centers | Masters |
| **routes** | Delivery routes | Masters |
| **vehicles** | Delivery vehicles | Masters |
| **items** | Product catalog | Masters |
| **stock** | Current inventory | Real-time |
| **loading** | Shipments sent out | Transactions |
| **unloading** | Sales completed | Transactions |
| **expenses** | Operating costs | Transactions |
| **payments** | Revenue collected | Transactions |
| **invoices** | Sales invoices | Transactions |
| **price_history** | Historical pricing | Historical |
| **daily_sales** | Daily summaries | Summaries |

---

## Current Analytics Features

### 1. Daily Reports (daily_reports.dart)
- **Sales Summary**: Total sales, items sold, returns, damaged, discounts, free issues
- **Expenses Summary**: By type (Fuel, Salary, Maintenance)
- **Profit/Loss**: Gross and net profit calculations
- **Filtering**: By date and vehicle

### 2. Daily Unloading Details (daily_unloading_details.dart)
- Transaction-level reporting
- Item-level details
- Expandable views for drill-down analysis

---

## Data Flow

### Loading Process (4-Step Workflow)
1. **Step 1**: Select Distribution & Route
2. **Step 2**: Select Vehicle, Date & Weather
3. **Step 3**: Select Items & Quantities
4. **Step 4**: Review & Save
- **Action**: Creates `loading` document, decrements `stock`

### Unloading Process
1. Display loaded shipments (status='loaded')
2. Record discounts given & additional free issues
3. **Action**: Creates `unloading` document, updates loading status to 'completed'

### Data Relationships
```
stock → loading (outbound shipments)
loading → unloading (sales/returns)
vehicles, routes, distributions ← both loading & unloading
expenses, payments ← operational records
```

---

## Essential Metrics & KPIs

### Sales & Revenue
- Daily/weekly/monthly sales trends
- Sales by vehicle, route, item
- Sell-through rate by item
- Free issue (FOC) impact analysis
- Discount patterns

### Inventory
- Stock turnover rate
- Days to sell inventory
- Slow-moving items
- Expiry rate
- Warehouse utilization

### Operations
- Vehicle utilization (loads/sales per day)
- Route efficiency (revenue per distance)
- Average load/sales value
- Fuel efficiency ratio
- Cost per unit sold

### Financial
- Gross profit margin
- Net profit margin
- FOC cost as % of revenue
- Discount as % of sales
- Expense breakdown

---

## Database Schema Key Points

### Stock Tracking
- **quantity**: Measured in pieces (not cases)
- **unitsPerCase**: Conversion factor (e.g., 24 bottles per carton)
- **Cases**: quantity ÷ unitsPerCase
- **Pieces**: quantity % unitsPerCase

### Free Issues (FOC) System
- Specified at loading time
- Added to unloading separately
- Tracked as:
  - `freeIssuesFromLoading`: Original FOC
  - `additionalFreeIssues`: Extra given at sale
  - `totalFreeIssues`: Sum of both

### Pricing Model
- **Cost**: distributorPrice (per unit)
- **Revenue**: loadingQuantity × distributorPrice
- **Discount**: Applied at unloading time
- **Net Revenue**: totalValue - totalDiscounts

### Timestamps
- **loading.loadedAt**: When shipment prepared
- **unloading.unloadedAt**: When sales recorded
- All use server timestamps for accuracy

---

## Recommended Analytics Collections

### 1. daily_analytics/{date}
Pre-calculated daily metrics:
- totalSalesValue, totalQuantity, totalExpenses
- Grouped by vehicle, route, expenseType
- Includes profitability and margins

### 2. performance_metrics/vehicle_performance/{vehicleId}
Vehicle performance tracking:
- Total loads/unloads, distance
- Sales value, profit margin
- Average order value

### 3. performance_metrics/route_performance/{routeId}
Route performance tracking:
- Total loads, sales value
- Average daily sales, profitability

### 4. performance_metrics/item_performance/{itemId}
Item sales analytics:
- Quantity loaded vs sold
- Sales rate percentage
- Total revenue and discount rate

---

## Next Steps for Implementation

### Phase 1: Foundation (Week 1-2)
- [ ] Create `daily_analytics` collection
- [ ] Implement daily summary calculations
- [ ] Add basic dashboard views
- [ ] Set up Firestore indexes

### Phase 2: Performance Metrics (Week 3-4)
- [ ] Create `performance_metrics/vehicle_performance`
- [ ] Create `performance_metrics/route_performance`
- [ ] Add vehicle/route analytics views
- [ ] Optimize queries

### Phase 3: Automation (Week 5-6)
- [ ] Deploy Cloud Functions for daily calculations
- [ ] Implement real-time dashboards
- [ ] Add caching layer
- [ ] Optimize for mobile

### Phase 4: Advanced (Week 7+)
- [ ] Trend analysis and forecasting
- [ ] Custom report generation
- [ ] Export to CSV/PDF
- [ ] Mobile dashboard refinement
- [ ] Alert system for anomalies

---

## Important Limitations to Address

1. **No Customer Tracking**
   - Solution: Add `customers` collection with shop details
   - Link unloading records to specific customers

2. **Incomplete Return Tracking**
   - Solution: Add return reasons and categorization
   - Track returns separately from sales

3. **Denormalized Data**
   - Solution: Normalize item data references
   - Implement data consistency checks

4. **No Payment-to-Sales Linking**
   - Solution: Add reference field in payments to unloading
   - Enable cash flow analysis

5. **Limited Historical Analysis**
   - Solution: Archive old records separately
   - Pre-calculate historical metrics

---

## Query Performance Tips

### Indexes Needed
```
loading: (distributionId, loadedAt desc)
loading: (vehicleId, loadedAt desc)
loading: (routeId, loadedAt desc)
unloading: (distributionId, unloadedAt desc)
unloading: (vehicleId, unloadedAt desc)
expenses: (vehicleId, date desc)
expenses: (expenseType, date desc)
payments: (vehicleId, date desc)
```

### Optimization Strategies
1. Use pre-calculated daily summaries instead of on-demand queries
2. Cache results for 30 minutes
3. Use aggregation queries for counts
4. Implement pagination for large result sets
5. Use subcollections for nested data

---

## File Locations Reference

| Document | Path | Size |
|----------|------|------|
| This Guide | `ANALYTICS_SYSTEM_GUIDE.md` | This file |
| Codebase Analysis | `CODEBASE_ANALYSIS.md` | 17 KB |
| Data Models | `DATA_MODELS.md` | 12 KB |
| Query Patterns | `QUERY_PATTERNS_ANALYTICS.md` | 13 KB |

---

## Contact Points for Questions

### When reviewing files, pay special attention to:

1. **CODEBASE_ANALYSIS.md** → Section 4: "Existing Analytics & Reporting Features"
   - Shows how current reports query the database
   - Calculation logic for metrics

2. **DATA_MODELS.md** → Section "Key Calculation Patterns"
   - How case/piece conversions work
   - Revenue calculation formulas

3. **QUERY_PATTERNS_ANALYTICS.md** → "Recommended Analytics Collection Structure"
   - How to structure pre-calculated metrics
   - Cloud Functions for automation

---

## Summary Statistics

- **Total Collections**: 12 (4 masters, 4 transactions, 1 history, 1 summary, 2 pending)
- **Data Models Identified**: 9+ core data structures
- **Query Patterns Documented**: 15+ real examples
- **Recommended Indexes**: 13 to create
- **KPIs to Track**: 20+ key metrics
- **Existing Features**: 2 (Daily Reports, Unloading Details)
- **Implementation Phases**: 4 phases over 7+ weeks

---

## Quick Start Checklist

- [ ] Read CODEBASE_ANALYSIS.md for full context
- [ ] Review DATA_MODELS.md for data structure details
- [ ] Study QUERY_PATTERNS_ANALYTICS.md for implementation patterns
- [ ] Create Firestore indexes (see recommended list)
- [ ] Design daily_analytics collection structure
- [ ] Implement Phase 1 tasks
- [ ] Set up monitoring and logging
- [ ] Plan customer data integration

---

**Generated**: November 18, 2024  
**Project**: Distribution Tracker Flutter App  
**Backend**: Firebase Cloud Firestore  
**Documentation Status**: Complete & Comprehensive
