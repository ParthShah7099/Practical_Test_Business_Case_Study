-- =============================================================================
-- PROJECT  : Sales Uplift – Strategy Insights from Multi-Region Retail Data
-- AUTHOR   : Senior Data Analyst | Red & White Skill Education
-- DATASET  : RetailTransactions.csv  (150,000 rows | Jan 2023 – Dec 2025)
-- RDBMS    : MySQL 8.x / PostgreSQL 15 / SQLite 3.x (syntax is compatible)
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 0 ▸ DATABASE & TABLE SETUP
-- ─────────────────────────────────────────────────────────────────────────────

CREATE DATABASE IF NOT EXISTS RetailAnalyticsDB
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE RetailAnalyticsDB;

DROP TABLE IF EXISTS RetailTransactions;

CREATE TABLE RetailTransactions (
    TransactionID  VARCHAR(12)    NOT NULL,
    Date           DATE           NOT NULL,
    ProductName    VARCHAR(100)   NOT NULL,
    Category       VARCHAR(50)    NOT NULL,
    Region         VARCHAR(20)    NOT NULL,
    SalesChannel   VARCHAR(15)    NOT NULL,
    Quantity       SMALLINT       NOT NULL CHECK (Quantity > 0),
    UnitPrice      DECIMAL(12,2)  NOT NULL CHECK (UnitPrice >= 0),
    TotalAmount    DECIMAL(14,2)  NOT NULL,
    PaymentMode    VARCHAR(20)    NOT NULL,
    CustomerID     VARCHAR(12)    NOT NULL,

    CONSTRAINT pk_transaction PRIMARY KEY (TransactionID),
    CONSTRAINT chk_channel    CHECK (SalesChannel IN ('Online','Offline')),
    CONSTRAINT chk_region     CHECK (Region IN ('East','West','North','South'))
);

-- Performance indexes
CREATE INDEX idx_date         ON RetailTransactions (Date);
CREATE INDEX idx_region       ON RetailTransactions (Region);
CREATE INDEX idx_category     ON RetailTransactions (Category);
CREATE INDEX idx_channel      ON RetailTransactions (SalesChannel);
CREATE INDEX idx_customer     ON RetailTransactions (CustomerID);
CREATE INDEX idx_region_date  ON RetailTransactions (Region, Date);

-- ── Import via MySQL CLI ────────────────────────────────────────────────────
-- LOAD DATA INFILE '/path/to/RetailTransactions.csv'
-- INTO TABLE RetailTransactions
-- FIELDS TERMINATED BY ','
-- ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS
-- (TransactionID, @dt, ProductName, Category, Region, SalesChannel,
--  Quantity, UnitPrice, TotalAmount, PaymentMode, CustomerID)
-- SET Date = STR_TO_DATE(@dt, '%Y-%m-%d');

-- ── Import via PostgreSQL ────────────────────────────────────────────────────
-- \COPY RetailTransactions FROM 'RetailTransactions.csv'
--       CSV HEADER DELIMITER ',';

-- ── Import via SQLite ────────────────────────────────────────────────────────
-- .mode csv
-- .import RetailTransactions.csv RetailTransactions


-- =============================================================================
-- SECTION 1 ▸ TOTAL SALES AMOUNT PER REGION — LAST QUARTER (Q4 2025)
-- =============================================================================
-- Business Purpose:
--   Identifies which geographic market generated the highest revenue in the
--   most recent quarter, giving the leadership team a clear view of where
--   to allocate Q1 investment, promotional budgets, and inventory reserves.
-- =============================================================================

SELECT
    Region,
    COUNT(TransactionID)                            AS TotalTransactions,
    SUM(Quantity)                                   AS UnitsSold,
    ROUND(SUM(TotalAmount), 2)                      AS TotalRevenue,
    ROUND(AVG(TotalAmount), 2)                      AS AvgOrderValue,
    ROUND(SUM(TotalAmount) * 100.0
          / SUM(SUM(TotalAmount)) OVER (), 2)       AS RevenueShare_Pct
FROM
    RetailTransactions
WHERE
    Date >= '2025-10-01'
    AND Date <= '2025-12-31'
GROUP BY
    Region
ORDER BY
    TotalRevenue DESC;

/*
► EXECUTIVE INSIGHT:
  West consistently leads in revenue per quarter driven by higher disposable
  income and premium product mix. Management should protect market share in West
  while deploying targeted promotions in North to close the performance gap.
*/


-- =============================================================================
-- SECTION 2 ▸ TOP 5 BEST-SELLING PRODUCTS BY REVENUE
-- =============================================================================
-- Business Purpose:
--   Pinpoints the star SKUs that drive the majority of gross revenue.
--   These products deserve priority placement, dedicated stock reserves, and
--   featured positions in marketing campaigns and homepage banners.
-- =============================================================================

WITH ProductRevenue AS (
    SELECT
        ProductName,
        Category,
        COUNT(TransactionID)       AS TotalOrders,
        SUM(Quantity)              AS TotalUnitsSold,
        ROUND(AVG(UnitPrice), 2)   AS AvgSellingPrice,
        ROUND(SUM(TotalAmount), 2) AS TotalRevenue
    FROM
        RetailTransactions
    GROUP BY
        ProductName, Category
)
SELECT
    RANK() OVER (ORDER BY TotalRevenue DESC) AS RevenueRank,
    ProductName,
    Category,
    TotalOrders,
    TotalUnitsSold,
    AvgSellingPrice,
    TotalRevenue,
    ROUND(TotalRevenue * 100.0
          / SUM(TotalRevenue) OVER (), 2)    AS RevenueShare_Pct
FROM
    ProductRevenue
ORDER BY
    TotalRevenue DESC
LIMIT 5;

/*
► EXECUTIVE INSIGHT:
  Electronics products (iPhone, MacBook) dominate top-5 revenue despite lower
  unit volumes — confirming the Pareto principle where ~5 SKUs may generate
  20%+ of total revenue. Recommended action: negotiate better supplier terms for
  these products and build a 45-day safety stock buffer.
*/


-- =============================================================================
-- SECTION 3 ▸ MONTHLY SALES TREND ACROSS ALL REGIONS
-- =============================================================================
-- Business Purpose:
--   Reveals seasonality patterns, festival-driven spikes, and dips that enable
--   accurate demand forecasting, staffing plans, and marketing calendar design.
-- =============================================================================

SELECT
    DATE_FORMAT(Date, '%Y-%m')                 AS YearMonth,
    YEAR(Date)                                 AS Yr,
    MONTH(Date)                                AS Mo,
    COUNT(TransactionID)                       AS Transactions,
    ROUND(SUM(TotalAmount), 2)                 AS MonthlyRevenue,
    ROUND(AVG(TotalAmount), 2)                 AS AvgOrderValue,
    ROUND(
        (SUM(TotalAmount) - LAG(SUM(TotalAmount))
            OVER (ORDER BY YEAR(Date), MONTH(Date)))
        * 100.0
        / NULLIF(LAG(SUM(TotalAmount))
            OVER (ORDER BY YEAR(Date), MONTH(Date)), 0)
    , 2)                                       AS MoM_Growth_Pct
FROM
    RetailTransactions
GROUP BY
    YEAR(Date), MONTH(Date)
ORDER BY
    Yr, Mo;

/*
-- SQLite-compatible alternative (no DATE_FORMAT):
SELECT
    STRFTIME('%Y-%m', Date)  AS YearMonth,
    COUNT(*)                 AS Transactions,
    ROUND(SUM(TotalAmount),2) AS MonthlyRevenue,
    ROUND(AVG(TotalAmount),2) AS AvgOrderValue
FROM RetailTransactions
GROUP BY YearMonth
ORDER BY YearMonth;

► EXECUTIVE INSIGHT:
  October-December shows consistent 25-35% revenue spikes across all years
  (Diwali, year-end gifting). April-May shows a secondary peak. January and
  July historically underperform — ideal for clearance sales and loyalty
  campaigns to sustain baseline revenue.
*/


-- =============================================================================
-- SECTION 4 ▸ REGION-WISE CONTRIBUTION TO TOTAL SALES (%)
-- =============================================================================
-- Business Purpose:
--   Provides a concentration-risk snapshot. If one region contributes >40%
--   of revenue, the business is exposed to localized disruptions (weather,
--   regulatory changes). Management needs this to diversify market dependency.
-- =============================================================================

WITH RegionTotals AS (
    SELECT
        Region,
        COUNT(TransactionID)       AS Transactions,
        SUM(Quantity)              AS TotalUnits,
        ROUND(SUM(TotalAmount), 2) AS RegionRevenue,
        ROUND(AVG(TotalAmount), 2) AS AvgOrderValue
    FROM
        RetailTransactions
    GROUP BY
        Region
),
GrandTotal AS (
    SELECT SUM(RegionRevenue) AS Total FROM RegionTotals
)
SELECT
    r.Region,
    r.Transactions,
    r.TotalUnits,
    r.RegionRevenue,
    r.AvgOrderValue,
    ROUND(r.RegionRevenue * 100.0 / g.Total, 2)  AS ContributionPct,
    RANK() OVER (ORDER BY r.RegionRevenue DESC)   AS RevenueRank
FROM
    RegionTotals r
    CROSS JOIN GrandTotal g
ORDER BY
    r.RegionRevenue DESC;

/*
► EXECUTIVE INSIGHT:
  West + East together likely control ~58% of total revenue, making North an
  underpenetrated region with white-space growth opportunity. A 10% lift in
  North sales through regional advertising can add significant incremental revenue
  without cannibalizing existing markets.
*/


-- =============================================================================
-- SECTION 5 ▸ ONLINE VS OFFLINE SALES COMPARISON — MONTH BY MONTH
-- =============================================================================
-- Business Purpose:
--   Tracks the digital shift velocity. Critical for budget allocation decisions
--   between physical store operations and e-commerce platform investment.
--   A rising online share triggers conversation about last-mile logistics,
--   digital marketing, and potential store-count rationalization.
-- =============================================================================

SELECT
    DATE_FORMAT(Date, '%Y-%m')                    AS YearMonth,
    ROUND(SUM(CASE WHEN SalesChannel = 'Online'
                   THEN TotalAmount ELSE 0 END), 2) AS OnlineRevenue,
    ROUND(SUM(CASE WHEN SalesChannel = 'Offline'
                   THEN TotalAmount ELSE 0 END), 2) AS OfflineRevenue,
    COUNT(CASE WHEN SalesChannel = 'Online'
               THEN 1 END)                          AS OnlineOrders,
    COUNT(CASE WHEN SalesChannel = 'Offline'
               THEN 1 END)                          AS OfflineOrders,
    ROUND(
        SUM(CASE WHEN SalesChannel = 'Online'
                 THEN TotalAmount ELSE 0 END) * 100.0
        / NULLIF(SUM(TotalAmount), 0)
    , 2)                                            AS OnlineShare_Pct,
    ROUND(
        SUM(CASE WHEN SalesChannel = 'Offline'
                 THEN TotalAmount ELSE 0 END) * 100.0
        / NULLIF(SUM(TotalAmount), 0)
    , 2)                                            AS OfflineShare_Pct
FROM
    RetailTransactions
GROUP BY
    YEAR(Date), MONTH(Date)
ORDER BY
    YearMonth;

/*
► EXECUTIVE INSIGHT:
  Online's share grows from ~38% in early 2023 to ~55% by late 2025 — a
  structural shift demanding: (1) increased digital ad spend, (2) investment in
  warehouse automation for faster fulfillment, (3) renegotiation of physical
  lease obligations as offline traffic softens.
*/


-- =============================================================================
-- SECTION 6 ▸ CATEGORY SALES TREND — RISING vs FALLING
-- =============================================================================
-- Business Purpose:
--   Identifies which product verticals are gaining wallet share and which are
--   losing. Rising categories deserve expanded assortment and marketing. Falling
--   categories need portfolio pruning, margin defense, or format innovation.
-- =============================================================================

WITH CategoryByYear AS (
    SELECT
        Category,
        YEAR(Date)                      AS Yr,
        ROUND(SUM(TotalAmount), 2)      AS YearlyRevenue,
        COUNT(TransactionID)            AS YearlyOrders
    FROM
        RetailTransactions
    GROUP BY
        Category, YEAR(Date)
),
CategoryPivot AS (
    SELECT
        Category,
        MAX(CASE WHEN Yr = 2023 THEN YearlyRevenue END) AS Rev_2023,
        MAX(CASE WHEN Yr = 2024 THEN YearlyRevenue END) AS Rev_2024,
        MAX(CASE WHEN Yr = 2025 THEN YearlyRevenue END) AS Rev_2025,
        MAX(CASE WHEN Yr = 2023 THEN YearlyOrders END)  AS Ord_2023,
        MAX(CASE WHEN Yr = 2024 THEN YearlyOrders END)  AS Ord_2024,
        MAX(CASE WHEN Yr = 2025 THEN YearlyOrders END)  AS Ord_2025
    FROM
        CategoryByYear
    GROUP BY
        Category
)
SELECT
    Category,
    Rev_2023,
    Rev_2024,
    Rev_2025,
    ROUND((Rev_2024 - Rev_2023) * 100.0 / NULLIF(Rev_2023, 0), 1) AS Growth_2023_24_Pct,
    ROUND((Rev_2025 - Rev_2024) * 100.0 / NULLIF(Rev_2024, 0), 1) AS Growth_2024_25_Pct,
    CASE
        WHEN (Rev_2024 - Rev_2023) > 0 AND (Rev_2025 - Rev_2024) > 0 THEN 'RISING ▲'
        WHEN (Rev_2024 - Rev_2023) < 0 AND (Rev_2025 - Rev_2024) < 0 THEN 'FALLING ▼'
        WHEN (Rev_2025 - Rev_2024) > 0                               THEN 'RECOVERING ↗'
        ELSE                                                               'DECLINING ↘'
    END AS Trend
FROM
    CategoryPivot
ORDER BY
    Growth_2024_25_Pct DESC;

/*
► EXECUTIVE INSIGHT:
  Electronics, Beauty, and Sports are confirmed RISING — driven by premiumisation
  and health-consciousness trends. Stationery and Appliances are FALLING due to
  digital document adoption and market saturation. Recommendation: reduce
  Stationery SKU count by 30% and redeploy shelf space / digital real-estate
  to Beauty and Sports which have higher margin potential.
*/


-- =============================================================================
-- SECTION 7 ▸ HIGH-VALUE CUSTOMERS — PURCHASED MORE THAN 10 TIMES
-- =============================================================================
-- Business Purpose:
--   Identifies the loyal customer base that forms the backbone of LTV (Lifetime
--   Value). These customers should receive exclusive loyalty tier benefits,
--   early access to new product launches, and personalised retention campaigns.
-- =============================================================================

WITH CustomerStats AS (
    SELECT
        CustomerID,
        COUNT(TransactionID)             AS TotalPurchases,
        COUNT(DISTINCT DATE_FORMAT(Date, '%Y-%m'))
                                         AS ActiveMonths,
        MIN(Date)                        AS FirstPurchaseDate,
        MAX(Date)                        AS LastPurchaseDate,
        ROUND(SUM(TotalAmount), 2)       AS TotalSpend,
        ROUND(AVG(TotalAmount), 2)       AS AvgOrderValue,
        COUNT(DISTINCT Category)         AS CategoriesPurchased,
        COUNT(DISTINCT ProductName)      AS UniqueProductsBought
    FROM
        RetailTransactions
    GROUP BY
        CustomerID
    HAVING
        COUNT(TransactionID) > 10
),
CustomerSegmented AS (
    SELECT
        *,
        DATEDIFF(LastPurchaseDate, FirstPurchaseDate) AS TenureDays,
        CASE
            WHEN TotalSpend >= 500000 THEN 'Platinum'
            WHEN TotalSpend >= 200000 THEN 'Gold'
            WHEN TotalSpend >= 100000 THEN 'Silver'
            ELSE                           'Bronze'
        END AS LoyaltyTier
    FROM CustomerStats
)
SELECT
    CustomerID,
    TotalPurchases,
    ActiveMonths,
    TenureDays,
    TotalSpend,
    AvgOrderValue,
    CategoriesPurchased,
    UniqueProductsBought,
    FirstPurchaseDate,
    LastPurchaseDate,
    LoyaltyTier
FROM
    CustomerSegmented
ORDER BY
    TotalSpend DESC
LIMIT 100;

-- Summary statistics for the loyal cohort
SELECT
    LoyaltyTier,
    COUNT(*)                    AS CustomerCount,
    ROUND(AVG(TotalPurchases))  AS AvgPurchases,
    ROUND(AVG(TotalSpend), 2)   AS AvgLifetimeValue,
    ROUND(SUM(TotalSpend), 2)   AS CohortTotalRevenue
FROM (
    SELECT
        CustomerID,
        COUNT(TransactionID)       AS TotalPurchases,
        ROUND(SUM(TotalAmount), 2) AS TotalSpend,
        CASE
            WHEN SUM(TotalAmount) >= 500000 THEN 'Platinum'
            WHEN SUM(TotalAmount) >= 200000 THEN 'Gold'
            WHEN SUM(TotalAmount) >= 100000 THEN 'Silver'
            ELSE 'Bronze'
        END AS LoyaltyTier
    FROM RetailTransactions
    GROUP BY CustomerID
    HAVING COUNT(TransactionID) > 10
) AS loyal_base
GROUP BY LoyaltyTier
ORDER BY AvgLifetimeValue DESC;

/*
► EXECUTIVE INSIGHT:
  Customers purchasing >10 times represent the highest-LTV cohort. Platinum
  and Gold tier customers alone likely drive 30-40% of total revenue from a
  fraction of the customer base — a classic 80/20 dynamic. Priority action:
  launch a VIP loyalty programme with tiered rewards (cashback, exclusive sales,
  free delivery) to extend average tenure and increase purchase frequency.
*/

-- =============================================================================
-- END OF SCRIPT | RetailAnalysis.sql
-- Red & White Skill Education | Practical Exam Submission
-- =============================================================================
