-- =============================================================================
-- 03_data_quality.sql
-- One row per data-quality rule: how many records it affects and what we did.
-- Output feeds outputs/data_quality_checks.csv and docs/data_quality_log.md.
-- =============================================================================

CREATE OR REPLACE TABLE dq_results AS
SELECT 'DQ-01' AS rule_id, 'Orders not in delivered status' AS check_name,
       COUNT(*) FILTER (WHERE order_status <> 'delivered') AS rows_affected,
       COUNT(*) AS rows_checked,
       'Excluded from delivery analysis (no delivery outcome yet)' AS action
FROM stg_orders
UNION ALL
SELECT 'DQ-02', 'Orders outside Jan-2017 to Aug-2018 window',
       COUNT(*) FILTER (WHERE purchased_at < TIMESTAMP '2017-01-01' OR purchased_at >= TIMESTAMP '2018-09-01'),
       COUNT(*),
       'Excluded: 2016 and Sep/Oct-2018 months have under 400 orders each'
FROM stg_orders
UNION ALL
SELECT 'DQ-03', 'Handed to carrier before purchase timestamp',
       COUNT(*) FILTER (WHERE dq_shipped_before_purchase), COUNT(*),
       'Excluded: impossible sequence, likely a system timestamp error'
FROM stg_orders
UNION ALL
SELECT 'DQ-04', 'Delivered to customer before handed to carrier',
       COUNT(*) FILTER (WHERE dq_delivered_before_shipped), COUNT(*),
       'Excluded: impossible sequence'
FROM stg_orders
UNION ALL
SELECT 'DQ-05', 'Status delivered but no delivery date',
       COUNT(*) FILTER (WHERE dq_delivered_no_date), COUNT(*),
       'Excluded: outcome unknown'
FROM stg_orders
UNION ALL
SELECT 'DQ-06', 'Duplicate / multiple reviews for one order',
       (SELECT COUNT(*) FROM read_csv_auto('data/raw/olist_order_reviews_dataset.csv'))
         - (SELECT COUNT(*) FROM stg_reviews),
       (SELECT COUNT(*) FROM read_csv_auto('data/raw/olist_order_reviews_dataset.csv')),
       'Kept the most recently answered review per order'
UNION ALL
SELECT 'DQ-07', 'Products with no category',
       (SELECT COUNT(*) FROM read_csv_auto('data/raw/olist_products_dataset.csv') WHERE product_category_name IS NULL),
       (SELECT COUNT(*) FROM stg_products),
       'Labelled "unknown"'
UNION ALL
SELECT 'DQ-08', 'Categories missing from English translation file',
       (SELECT COUNT(DISTINCT p.product_category_name)
          FROM read_csv_auto('data/raw/olist_products_dataset.csv') p
          LEFT JOIN read_csv_auto('data/raw/product_category_name_translation.csv') t USING (product_category_name)
         WHERE p.product_category_name IS NOT NULL AND t.product_category_name_english IS NULL),
       (SELECT COUNT(DISTINCT product_category_name) FROM read_csv_auto('data/raw/olist_products_dataset.csv')),
       'Kept the Portuguese name'
UNION ALL
SELECT 'DQ-09', 'Delivered orders with no review',
       COUNT(*) FILTER (WHERE review_score IS NULL), COUNT(*),
       'Kept for delivery KPIs; excluded only from review-score averages'
FROM fact_orders WHERE in_analysis
UNION ALL
SELECT 'DQ-10', 'Orders with items from more than one seller',
       COUNT(*) FILTER (WHERE seller_count > 1), COUNT(*),
       'Attributed to the seller of the highest-priced item (primary_seller_id)'
FROM fact_orders WHERE in_analysis
UNION ALL
SELECT 'DQ-11', 'Orders kept for analysis (after all rules)',
       COUNT(*) FILTER (WHERE in_analysis), COUNT(*),
       'Final analysis population'
FROM fact_orders;
