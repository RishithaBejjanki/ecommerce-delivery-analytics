-- =============================================================================
-- 01_staging.sql
-- Load the raw Olist CSVs into typed staging tables and apply cleaning rules.
-- Every rule here is logged in docs/data_quality_log.md.
-- Engine: DuckDB (runs locally, no server). Syntax is close to Snowflake/Postgres.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Orders: one row per order. Flag (don't silently drop) timestamp anomalies.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE stg_orders AS
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp                         AS purchased_at,
    order_approved_at                                AS approved_at,
    order_delivered_carrier_date                     AS shipped_at,
    order_delivered_customer_date                    AS delivered_at,
    CAST(order_estimated_delivery_date AS DATE)      AS promised_date,

    -- Anomaly flags (see data quality log, rules DQ-03 to DQ-05)
    (order_delivered_carrier_date < order_purchase_timestamp)        AS dq_shipped_before_purchase,
    (order_delivered_customer_date < order_delivered_carrier_date)   AS dq_delivered_before_shipped,
    (order_status = 'delivered' AND order_delivered_customer_date IS NULL) AS dq_delivered_no_date
FROM read_csv_auto('data/raw/olist_orders_dataset.csv');

-- ---------------------------------------------------------------------------
-- Order items: one row per item line.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE stg_order_items AS
SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date      AS ship_by_at,      -- seller's deadline to hand to carrier
    price,
    freight_value
FROM read_csv_auto('data/raw/olist_order_items_dataset.csv');

-- ---------------------------------------------------------------------------
-- Reviews: the raw file has duplicate review rows and some orders with more
-- than one review (DQ-06). Keep the most recent answered review per order.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE stg_reviews AS
SELECT order_id, review_id, review_score, review_creation_date, review_answer_timestamp
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY order_id
                              ORDER BY review_answer_timestamp DESC, review_id) AS rn
    FROM read_csv_auto('data/raw/olist_order_reviews_dataset.csv')
)
WHERE rn = 1;

-- ---------------------------------------------------------------------------
-- Customers. customer_id is per-order; customer_unique_id is the real person.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE stg_customers AS
SELECT
    customer_id,
    customer_unique_id,
    LPAD(CAST(customer_zip_code_prefix AS VARCHAR), 5, '0') AS zip_prefix,
    customer_city   AS city,
    customer_state  AS state
FROM read_csv_auto('data/raw/olist_customers_dataset.csv');

CREATE OR REPLACE TABLE stg_sellers AS
SELECT
    seller_id,
    LPAD(CAST(seller_zip_code_prefix AS VARCHAR), 5, '0') AS zip_prefix,
    seller_city   AS city,
    seller_state  AS state
FROM read_csv_auto('data/raw/olist_sellers_dataset.csv');

-- ---------------------------------------------------------------------------
-- Products with English category names. 610 products have no category (DQ-07)
-- and two categories are missing from the translation file (DQ-08).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE stg_products AS
SELECT
    p.product_id,
    COALESCE(t.product_category_name_english,
             p.product_category_name,          -- untranslated fallback
             'unknown')                        AS category,
    p.product_weight_g                         AS weight_g
FROM read_csv_auto('data/raw/olist_products_dataset.csv') p
LEFT JOIN read_csv_auto('data/raw/product_category_name_translation.csv') t
       ON p.product_category_name = t.product_category_name;
