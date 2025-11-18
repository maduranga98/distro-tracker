# Analytics System Documentation

## Overview

This comprehensive analytics system provides deep insights into your distribution business performance. It includes multiple analytics modules designed to help you make data-driven decisions about inventory, routes, distributions, and overall business operations.

## Analytics Modules

### 1. Business Analytics Dashboard
**Location:** `lib/analytics/business_analytics_dashboard.dart`
**Access:** Dashboard → Reports & Analytics → Business Analytics

#### Features:
- **Financial Overview**
  - Total Revenue
  - Total Expenses
  - Net Profit & Profit Margin
  - Average Order Value
  - Total Discounts

- **Operational Metrics**
  - Total Orders
  - Items Sold
  - Active Routes
  - Product Count
  - Current Stock Value
  - Total Returns

- **Top 5 Selling Items**
  - Ranked by revenue
  - Shows quantity sold and total value
  - Visual ranking with medals for top 3

- **Slow Moving Items**
  - Items with low sales relative to stock
  - Helps identify inventory to reduce

- **Quick Navigation**
  - Direct access to detailed analytics modules
  - Item Performance
  - Route & Distribution Performance
  - Order Recommendations

#### Use Cases:
- Daily/weekly business performance review
- Identifying top performers and problem areas
- Quick overview of business health
- Strategic planning and decision making

---

### 2. Item Performance Analytics
**Location:** `lib/analytics/item_performance.dart`
**Access:** Business Analytics Dashboard → Item Performance

#### Features:
- **Performance Metrics by Item**
  - Total Revenue per item
  - Quantity Sold
  - Number of Orders
  - Average Revenue per Order
  - Free Issues (FOC) given
  - Returns and Damaged items

- **Filtering Options**
  - Date Range selection
  - Filter by Route
  - Filter by Distribution
  - Combined filters

- **Ranking System**
  - Items ranked by revenue
  - Top 3 highlighted with badges
  - Visual indicators for performance

- **Analytics Summary**
  - Total items sold
  - Total quantity
  - Total number of orders
  - Total revenue

#### Use Cases:
- Identify best-selling products
- Analyze item performance by route
- Compare item performance across distributions
- Optimize product mix based on sales data
- Identify items with high returns/damage

---

### 3. Route & Distribution Performance
**Location:** `lib/analytics/route_distribution_performance.dart`
**Access:** Business Analytics Dashboard → Route & Distribution

#### Features:

##### Routes Tab:
- **Route Metrics**
  - Total Revenue per route
  - Net Profit
  - Profit Margin %
  - Number of Trips
  - Average Revenue per Trip
  - Unique Items sold
  - Total Expenses

- **Route Ranking**
  - Ranked by revenue
  - Visual indicators for top performers
  - Profit margin badges (color-coded)

##### Distributions Tab:
- **Distribution Metrics**
  - Total Revenue per distribution
  - Net Profit
  - Profit Margin %
  - Number of Deliveries
  - Average Revenue per Delivery
  - Total Quantity sold
  - Total Expenses

- **Distribution Ranking**
  - Ranked by revenue
  - Performance indicators
  - Profit margin analysis

#### Use Cases:
- Evaluate route profitability
- Compare distribution center performance
- Identify underperforming routes
- Optimize route planning
- Allocate resources based on performance
- Identify expansion opportunities

---

### 4. Inventory Recommendations
**Location:** `lib/analytics/inventory_recommendations.dart`
**Access:** Business Analytics Dashboard → Order Recommendations

#### Features:
- **Smart Order Recommendations**
  - Analyzes sales history
  - Calculates average daily sales
  - Projects future needs
  - Recommends order quantities

- **Priority Levels**
  - **Critical:** < 2 days of stock
  - **High:** 2-5 days of stock
  - **Medium:** 5-10 days of stock
  - **Low:** > 10 days of stock

- **For Each Item:**
  - Current Stock level
  - Average Daily Sales
  - Days of Stock Remaining
  - Recommended Order Quantity (pieces and cases)
  - Estimated Cost
  - Returns and Damage tracking

- **Configurable Settings**
  - Days to Analyze (7-90 days)
  - Days to Project (3-30 days)
  - Customizable for your business cycle

- **Summary Dashboard**
  - Count by priority level
  - Estimated total order value
  - Visual priority indicators

#### Use Cases:
- Prevent stockouts
- Optimize inventory levels
- Plan purchase orders
- Reduce excess inventory
- Minimize waste and expiry
- Budget planning for inventory purchases

---

## Data Sources

All analytics modules pull data from the following Firestore collections:

1. **unloading** - Sales transactions
2. **loading** - Shipment data
3. **stock** - Current inventory levels
4. **items** - Product catalog
5. **routes** - Delivery routes
6. **distributions** - Distribution centers
7. **vehicles** - Vehicle information
8. **expenses** - Operating costs
9. **payments** - Payment records

## Key Metrics Explained

### Financial Metrics

- **Total Revenue**: Sum of all sales (after discounts)
- **Total Expenses**: Operating costs (fuel, salary, maintenance, etc.)
- **Net Profit**: Revenue - Expenses
- **Profit Margin**: (Net Profit / Revenue) × 100%
- **Average Order Value**: Total Revenue / Number of Orders

### Operational Metrics

- **Days of Stock**: Current Stock / Average Daily Sales
- **Average Daily Sales**: Total Sales / Days Analyzed
- **Sell-Through Rate**: Units Sold / Units Available
- **Return Rate**: Returns / Total Sales

### Performance Indicators

- **Top Performers**: Items/Routes/Distributions in top 20% by revenue
- **Slow Movers**: Items with low sales relative to stock levels
- **Profit Margin Thresholds**:
  - Green (Good): ≥ 20%
  - Orange (Fair): 10-20%
  - Red (Poor): < 10%

## Best Practices

### 1. Regular Review Schedule
- **Daily**: Check Business Analytics Dashboard for overview
- **Weekly**: Review Item Performance and Route Performance
- **Monthly**: Analyze trends and adjust strategies

### 2. Inventory Management
- Review Order Recommendations at least twice weekly
- Address Critical and High priority items immediately
- Plan orders 3-5 days in advance

### 3. Route Optimization
- Analyze route performance monthly
- Compare similar routes for efficiency
- Adjust route assignments based on performance

### 4. Product Strategy
- Promote top-selling items
- Consider discontinuing consistent slow movers
- Investigate high-return items for quality issues

### 5. Data Quality
- Ensure all unloading records are complete
- Record expenses accurately for profit analysis
- Update stock quantities regularly

## Filters and Date Ranges

All analytics modules support flexible date range selection:

- Default: Last 30 days
- Customizable via date picker
- Can analyze any historical period
- Real-time data when viewing current period

### Recommended Analysis Periods

- **Weekly Review**: Last 7 days
- **Monthly Review**: Last 30 days
- **Quarterly Review**: Last 90 days
- **Seasonal Analysis**: Last 365 days
- **Year-over-Year**: Compare same periods

## Performance Tips

### For Large Datasets

1. Use specific date ranges instead of "all time"
2. Filter by specific routes or distributions
3. Focus on active items only
4. Archive old completed transactions

### For Accurate Insights

1. Ensure consistent data entry
2. Record all expenses and payments
3. Update stock levels after every loading
4. Complete unloading records immediately after sales
5. Track returns and damaged items accurately

## Future Enhancements

Potential additions to the analytics system:

1. **Predictive Analytics**
   - Machine learning for demand forecasting
   - Seasonal trend detection
   - Automatic reorder points

2. **Customer Analytics**
   - Customer segmentation (requires customer tracking)
   - Customer lifetime value
   - Repeat purchase analysis

3. **Comparative Analytics**
   - Period-over-period comparisons
   - Year-over-year growth metrics
   - Benchmark against targets

4. **Export Capabilities**
   - PDF report generation
   - CSV export for external analysis
   - Email scheduled reports

5. **Dashboard Widgets**
   - Customizable home screen widgets
   - Key metric alerts
   - Trend visualizations

## Troubleshooting

### No Data Showing

- Check date range selection
- Verify filters are not too restrictive
- Ensure unloading records exist for the period
- Check data permissions

### Unexpected Results

- Verify all unloading records are complete
- Check for duplicate entries
- Ensure expenses are recorded correctly
- Validate stock quantities

### Performance Issues

- Reduce date range for large datasets
- Use specific filters
- Clear app cache
- Check internet connection for Firestore queries

## Support

For questions or issues with the analytics system:

1. Check this documentation first
2. Review the code comments in each analytics file
3. Verify data integrity in Firestore
4. Contact the development team

---

## Analytics Module Summary

| Module | Primary Use | Key Metrics | Best For |
|--------|-------------|-------------|----------|
| Business Analytics Dashboard | Overall business health | Revenue, Profit, Orders | Daily overview |
| Item Performance | Product analysis | Sales by item, Returns | Product strategy |
| Route & Distribution Performance | Operational efficiency | Route/Distribution profit | Resource allocation |
| Inventory Recommendations | Stock planning | Days of stock, Order needs | Purchase planning |

---

**Last Updated:** November 2024
**Version:** 1.0.0
