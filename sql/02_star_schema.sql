-- =============================================================================
-- 02_star_schema.sql
-- Build the reporting model: one order-grain fact table, one item-grain fact
-- table, and four dimensions. This is the model Power BI imports.
--
--   dim_date ─┐
--   dim_customer ─┤
--                 ├── fact_orders (1 row per order) ──< fact_order_items >── dim_product
--   dim_seller ───┘                                                      └── dim_seller
-- =============================================================================

-- Brazil's five official macro-regions, used for regional roll-ups.
CREATE OR REPLACE TABLE ref_state_region AS
SELECT * FROM (VALUES
    ('AC','North'),('AP','North'),('AM','North'),('PA','North'),('RO','North'),('RR','North'),('TO','North'),
    ('AL','Northeast'),('BA','Northeast'),('CE','Northeast'),('MA','Northeast'),('PB','Northeast'),
    ('PE','Northeast'),('PI','Northeast'),('RN','Northeast'),('SE','Northeast'),
    ('DF','Central-West'),('GO','Central-West'),('MT','Central-West'),('MS','Central-West'),
    ('ES','Southeast'),('MG','Southeast'),('RJ','Southeast'),('SP','Southeast'),
    ('PR','South'),('RS','South'),('SC','South')
) AS t(state, region);

-- ---------------------------------------------------------------------------
-- Dimensions
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE dim_customer AS
SELECT c.customer_id, c.customer_unique_id, c.city, c.state, r.region
FROM stg_customers c
LEFT JOIN ref_state_region r USING (state);

CREATE OR REPLACE TABLE dim_seller AS
SELECT s.seller_id, s.city, s.state, r.region
FROM stg_sellers s
LEFT JOIN ref_state_region r USING (state);

CREATE OR REPLACE TABLE dim_product AS
SELECT product_id, category, weight_g FROM stg_products;

CREATE OR REPLACE TABLE dim_date AS
SELECT
    d::DATE                         AS date,
    YEAR(d)                         AS year,
    QUARTER(d)                      AS quarter,
    MONTH(d)                        AS month,
    STRFTIME(d, '%Y-%m')            AS year_month,
    STRFTIME(d, '%b')               AS month_name,
    DAYOFWEEK(d)                    AS day_of_week   -- 0 = Sunday
FROM generate_series(DATE '2016-09-01', DATE '2018-12-31', INTERVAL 1 DAY) g(d);

-- ---------------------------------------------------------------------------
-- fact_order_items: item grain
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE fact_order_items AS
SELECT
    i.order_id, i.order_item_id, i.product_id, i.seller_id,
    i.ship_by_at, i.price, i.freight_value
FROM stg_order_items i;

-- ---------------------------------------------------------------------------
-- fact_orders: order grain, with the delivery stages already calculated.
--
-- Delivery stages (in days, fractional):
--   approval_days  = purchased -> payment approved            (Olist / payments)
--   handling_days  = approved  -> handed to carrier           (seller)
--   transit_days   = handed to carrier -> delivered           (carrier)
--   delivery_days  = purchased -> delivered                   (what the customer feels)
--
-- is_late          = delivered after the promised (estimated) date
-- seller_missed_sla = handed to carrier after the item's ship-by deadline
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE fact_orders AS
WITH items AS (
    SELECT
        order_id,
        COUNT(*)                         AS item_count,
        COUNT(DISTINCT seller_id)        AS seller_count,
        SUM(price)                       AS items_value,
        SUM(freight_value)               AS freight_value,
        MIN(ship_by_at)                  AS ship_by_at,           -- earliest deadline on the order
        ARG_MAX(seller_id, price)        AS primary_seller_id     -- seller of the highest-priced item
    FROM stg_order_items
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    CAST(o.purchased_at AS DATE)                                   AS purchase_date,
    o.purchased_at, o.approved_at, o.shipped_at, o.delivered_at, o.promised_date,

    i.primary_seller_id,
    i.item_count, i.seller_count, i.items_value, i.freight_value,
    i.items_value + i.freight_value                                AS order_value,

    r.review_score,

    -- Stage durations in days
    DATE_DIFF('minute', o.purchased_at, o.approved_at) / 1440.0    AS approval_days,
    DATE_DIFF('minute', o.approved_at,  o.shipped_at)  / 1440.0    AS handling_days,
    DATE_DIFF('minute', o.shipped_at,   o.delivered_at)/ 1440.0    AS transit_days,
    DATE_DIFF('minute', o.purchased_at, o.delivered_at)/ 1440.0    AS delivery_days,
    DATE_DIFF('day', o.purchased_at::DATE, o.promised_date)        AS promised_days,

    -- Lateness vs the date shown to the customer at checkout
    CASE WHEN o.delivered_at IS NULL THEN NULL
         ELSE CAST(o.delivered_at AS DATE) > o.promised_date END   AS is_late,
    CASE WHEN o.delivered_at IS NULL THEN NULL
         ELSE GREATEST(DATE_DIFF('day', o.promised_date, CAST(o.delivered_at AS DATE)), 0) END
                                                                   AS days_late,

    -- Did the seller miss their hand-off deadline?
    CASE WHEN o.shipped_at IS NULL THEN NULL
         ELSE o.shipped_at > i.ship_by_at END                      AS seller_missed_sla,

    (c.state = s.state)                                            AS same_state,

    -- Rows the analysis should use: delivered, dated, in the analysis window,
    -- and with no impossible timestamps (see data quality log)
    (o.order_status = 'delivered'
     AND o.delivered_at IS NOT NULL
     AND o.purchased_at >= TIMESTAMP '2017-01-01'
     AND o.purchased_at <  TIMESTAMP '2018-09-01'
     AND NOT COALESCE(o.dq_shipped_before_purchase, FALSE)
     AND NOT COALESCE(o.dq_delivered_before_shipped, FALSE)
     AND o.approved_at IS NOT NULL
     AND o.shipped_at  IS NOT NULL)                                AS in_analysis
FROM stg_orders o
LEFT JOIN items         i ON o.order_id = i.order_id
LEFT JOIN stg_reviews   r ON o.order_id = r.order_id
LEFT JOIN stg_customers c ON o.customer_id = c.customer_id
LEFT JOIN stg_sellers   s ON i.primary_seller_id = s.seller_id;
