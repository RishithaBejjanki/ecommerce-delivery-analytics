-- =============================================================================
-- 04_analysis.sql
-- The business questions. Each query starts with "-- name: <result_name>";
-- scripts/run_pipeline.py runs them in order and saves each result to
-- outputs/<result_name>.csv (and one tab each in outputs/analysis_results.xlsx).
--
-- Population for every query: fact_orders WHERE in_analysis
-- (delivered orders, Jan-2017 to Aug-2018, clean timestamps; 96,004 orders).
-- =============================================================================

-- name: q01_headline_kpis
-- Q1. How are we doing overall?
SELECT
    COUNT(*)                                                  AS delivered_orders,
    ROUND(SUM(order_value), 0)                                AS gmv_brl,
    ROUND(100.0 * AVG(is_late::INT), 1)                       AS late_pct,
    ROUND(AVG(delivery_days), 1)                              AS avg_delivery_days,
    ROUND(AVG(promised_days), 1)                              AS avg_promised_days,
    ROUND(AVG(review_score), 2)                               AS avg_review_score,
    ROUND(100.0 * AVG(seller_missed_sla::INT), 1)             AS seller_missed_sla_pct
FROM fact_orders WHERE in_analysis;

-- name: q02_monthly_trend
-- Q2. Is lateness getting better or worse, and when does it spike?
SELECT
    STRFTIME(purchase_date, '%Y-%m')                          AS year_month,
    COUNT(*)                                                  AS orders,
    ROUND(100.0 * AVG(is_late::INT), 1)                       AS late_pct,
    ROUND(AVG(delivery_days), 1)                              AS avg_delivery_days,
    ROUND(AVG(promised_days), 1)                              AS avg_promised_days,
    ROUND(AVG(transit_days), 1)                               AS avg_transit_days,
    ROUND(AVG(review_score), 2)                               AS avg_review_score
FROM fact_orders WHERE in_analysis
GROUP BY 1 ORDER BY 1;

-- name: q03_review_by_lateness
-- Q3. How much does lateness cost us in customer satisfaction?
SELECT
    CASE WHEN NOT is_late      THEN '0. On time'
         WHEN days_late <= 3   THEN '1. 1-3 days late'
         WHEN days_late <= 7   THEN '2. 4-7 days late'
         ELSE                       '3. 8+ days late' END     AS lateness_bucket,
    COUNT(*)                                                  AS orders,
    ROUND(AVG(review_score), 2)                               AS avg_review_score,
    ROUND(100.0 * AVG((review_score = 1)::INT), 1)            AS one_star_pct,
    ROUND(100.0 * AVG((review_score >= 4)::INT), 1)           AS positive_pct
FROM fact_orders WHERE in_analysis
GROUP BY 1 ORDER BY 1;

-- name: q04_share_of_bad_reviews
-- Q4. What share of all negative reviews come from late orders?
SELECT
    COUNT(*) FILTER (WHERE is_late)                                         AS late_orders,
    ROUND(100.0 * AVG(is_late::INT), 1)                                     AS late_pct_of_orders,
    COUNT(*) FILTER (WHERE review_score = 1)                                AS one_star_reviews,
    COUNT(*) FILTER (WHERE review_score = 1 AND is_late)                    AS one_star_from_late,
    ROUND(100.0 * COUNT(*) FILTER (WHERE review_score = 1 AND is_late)
                / COUNT(*) FILTER (WHERE review_score = 1), 1)              AS one_star_from_late_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE review_score <= 2 AND is_late)
                / COUNT(*) FILTER (WHERE review_score <= 2), 1)             AS neg_1_2_from_late_pct
FROM fact_orders WHERE in_analysis;

-- name: q05_stage_breakdown
-- Q5. Where in the process does the time go: approval, seller, or carrier?
SELECT
    CASE WHEN is_late THEN 'Late' ELSE 'On time' END          AS outcome,
    COUNT(*)                                                  AS orders,
    ROUND(AVG(approval_days), 1)                              AS approval_days,
    ROUND(AVG(handling_days), 1)                              AS seller_handling_days,
    ROUND(AVG(transit_days), 1)                               AS carrier_transit_days,
    ROUND(AVG(delivery_days), 1)                              AS total_delivery_days,
    ROUND(AVG(promised_days), 1)                              AS promised_days
FROM fact_orders WHERE in_analysis
GROUP BY 1 ORDER BY 1 DESC;

-- name: q06_seller_sla_effect
-- Q6. When a seller misses the hand-off deadline, how much likelier is a late delivery?
--     And how many late orders had a seller who shipped on time (i.e. carrier-driven)?
SELECT
    CASE WHEN seller_missed_sla THEN 'Seller missed ship-by date'
         ELSE 'Seller shipped on time' END                    AS seller_sla,
    COUNT(*)                                                  AS orders,
    ROUND(100.0 * AVG(is_late::INT), 1)                       AS late_pct,
    COUNT(*) FILTER (WHERE is_late)                           AS late_orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_late)
          / SUM(COUNT(*) FILTER (WHERE is_late)) OVER (), 1)  AS share_of_all_late_pct
FROM fact_orders WHERE in_analysis
GROUP BY 1 ORDER BY 1;

-- name: q07_region_performance
-- Q7. Which customer regions are worst served?
SELECT
    c.region                                                  AS customer_region,
    COUNT(*)                                                  AS orders,
    ROUND(100.0 * AVG(f.is_late::INT), 1)                     AS late_pct,
    ROUND(AVG(f.transit_days), 1)                             AS avg_transit_days,
    ROUND(AVG(f.promised_days), 1)                            AS avg_promised_days,
    ROUND(AVG(f.review_score), 2)                             AS avg_review_score,
    COUNT(*) FILTER (WHERE f.is_late)                         AS late_orders
FROM fact_orders f JOIN dim_customer c USING (customer_id)
WHERE f.in_analysis
GROUP BY 1 ORDER BY late_pct DESC;

-- name: q08_state_performance
-- Q8. State-level view (states with 500+ orders), ranked by number of late orders,
--     because a big state with a moderate rate can matter more than a small state with a high one.
SELECT
    c.state                                                   AS customer_state,
    c.region,
    COUNT(*)                                                  AS orders,
    ROUND(100.0 * AVG(f.is_late::INT), 1)                     AS late_pct,
    COUNT(*) FILTER (WHERE f.is_late)                         AS late_orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE f.is_late)
          / SUM(COUNT(*) FILTER (WHERE f.is_late)) OVER (), 1) AS share_of_all_late_pct,
    ROUND(AVG(f.delivery_days), 1)                            AS avg_delivery_days
FROM fact_orders f JOIN dim_customer c USING (customer_id)
WHERE f.in_analysis
GROUP BY 1, 2
HAVING COUNT(*) >= 500
ORDER BY late_orders DESC;

-- name: q09_interstate_effect
-- Q9. Do cross-state shipments run late more often?
SELECT
    CASE WHEN same_state THEN 'Same state' ELSE 'Interstate' END AS route_type,
    COUNT(*)                                                  AS orders,
    ROUND(100.0 * AVG(is_late::INT), 1)                       AS late_pct,
    ROUND(AVG(transit_days), 1)                               AS avg_transit_days
FROM fact_orders WHERE in_analysis
GROUP BY 1 ORDER BY 1;

-- name: q10_peak_periods
-- Q10. What happens in the two spike periods (Black Friday Nov-2017, Feb-Mar 2018)?
SELECT
    CASE WHEN purchase_date BETWEEN DATE '2017-11-01' AND DATE '2017-12-31' THEN '1. Nov-Dec 2017 (Black Friday / holiday)'
         WHEN purchase_date BETWEEN DATE '2018-02-01' AND DATE '2018-03-31' THEN '2. Feb-Mar 2018'
         ELSE '0. All other months' END                       AS period,
    COUNT(*)                                                  AS orders,
    ROUND(COUNT(*) / COUNT(DISTINCT STRFTIME(purchase_date, '%Y-%m')), 0) AS orders_per_month,
    ROUND(100.0 * AVG(is_late::INT), 1)                       AS late_pct,
    ROUND(AVG(handling_days), 1)                              AS seller_handling_days,
    ROUND(AVG(transit_days), 1)                               AS carrier_transit_days,
    ROUND(AVG(promised_days), 1)                              AS promised_days
FROM fact_orders WHERE in_analysis
GROUP BY 1 ORDER BY 1;

-- name: q11_seller_concentration
-- Q11. Are late orders spread evenly, or concentrated in a few sellers?
WITH s AS (
    SELECT primary_seller_id, COUNT(*) AS orders, COUNT(*) FILTER (WHERE is_late) AS late_orders
    FROM fact_orders WHERE in_analysis GROUP BY 1
), ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (ORDER BY late_orders DESC, orders DESC, primary_seller_id)                     AS rk,
           SUM(late_orders) OVER (ORDER BY late_orders DESC, orders DESC, primary_seller_id
                                  ROWS UNBOUNDED PRECEDING) * 1.0 / SUM(late_orders) OVER () AS cum_share,
           COUNT(*) OVER ()                                                                 AS total_sellers
    FROM s
)
SELECT
    MAX(total_sellers)                                         AS active_sellers,
    MIN(rk) FILTER (WHERE cum_share >= 0.5)                    AS sellers_for_50pct_of_late,
    ROUND(100.0 * MIN(rk) FILTER (WHERE cum_share >= 0.5) / MAX(total_sellers), 1) AS pct_of_sellers_50,
    MIN(rk) FILTER (WHERE cum_share >= 0.8)                    AS sellers_for_80pct_of_late,
    ROUND(100.0 * MIN(rk) FILTER (WHERE cum_share >= 0.8) / MAX(total_sellers), 1) AS pct_of_sellers_80
FROM ranked;

-- name: q12_seller_watchlist
-- Q12. Chronic late sellers: 50+ orders and a late rate at least ~2x the platform average.
--      This is the list an account manager would act on.
WITH s AS (
    SELECT
        f.primary_seller_id                                   AS seller_id,
        ds.state                                              AS seller_state,
        COUNT(*)                                              AS orders,
        COUNT(*) FILTER (WHERE f.is_late)                     AS late_orders,
        ROUND(100.0 * AVG(f.is_late::INT), 1)                 AS late_pct,
        ROUND(100.0 * AVG(f.seller_missed_sla::INT), 1)       AS missed_sla_pct,
        ROUND(AVG(f.handling_days), 1)                        AS avg_handling_days,
        ROUND(AVG(f.review_score), 2)                         AS avg_review_score,
        ROUND(SUM(f.order_value), 0)                          AS gmv_brl
    FROM fact_orders f JOIN dim_seller ds ON f.primary_seller_id = ds.seller_id
    WHERE f.in_analysis
    GROUP BY 1, 2
)
SELECT *,
       CASE WHEN missed_sla_pct >= 20 THEN 'Seller-driven: coach on handling time'
            ELSE 'Route-driven: review carrier / lane' END    AS likely_cause
FROM s
WHERE orders >= 50 AND late_pct >= 12
ORDER BY late_orders DESC, seller_id;

-- name: q13_opportunity_sizing
-- Q13. If late orders were reviewed like on-time orders, how many 1-star reviews
--      would disappear and where would the average score land?
WITH base AS (
    SELECT
        COUNT(*) FILTER (WHERE is_late AND review_score IS NOT NULL)            AS late_reviewed,
        AVG((review_score = 1)::INT) FILTER (WHERE is_late)                     AS late_1star_rate,
        AVG((review_score = 1)::INT) FILTER (WHERE NOT is_late)                 AS ontime_1star_rate,
        AVG(review_score) FILTER (WHERE is_late)                                AS late_avg,
        AVG(review_score) FILTER (WHERE NOT is_late)                            AS ontime_avg,
        COUNT(*) FILTER (WHERE review_score IS NOT NULL)                        AS reviewed,
        AVG(review_score)                                                       AS current_avg,
        COUNT(*) FILTER (WHERE review_score = 1)                                AS one_star_total
    FROM fact_orders WHERE in_analysis
)
SELECT
    'Eliminate all lateness'                                                    AS scenario,
    ROUND(late_reviewed * (late_1star_rate - ontime_1star_rate), 0)             AS one_star_reviews_avoided,
    ROUND(100.0 * late_reviewed * (late_1star_rate - ontime_1star_rate) / one_star_total, 1) AS pct_of_all_one_star,
    ROUND(current_avg, 2)                                                       AS current_avg_review,
    ROUND(current_avg + late_reviewed * (ontime_avg - late_avg) / reviewed, 2)  AS new_avg_review
FROM base
UNION ALL
SELECT
    'Halve lateness',
    ROUND(0.5 * late_reviewed * (late_1star_rate - ontime_1star_rate), 0),
    ROUND(50.0 * late_reviewed * (late_1star_rate - ontime_1star_rate) / one_star_total, 1),
    ROUND(current_avg, 2),
    ROUND(current_avg + 0.5 * late_reviewed * (ontime_avg - late_avg) / reviewed, 2)
FROM base;

-- name: q14_repeat_purchase
-- Q14. Does a late first order make customers less likely to come back?
--      (First orders before Jun-2018 so every customer had 3+ months to return.)
WITH o AS (
    SELECT c.customer_unique_id, f.purchased_at, f.purchase_date, f.is_late,
           ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id ORDER BY f.purchased_at, f.order_id) AS order_seq
    FROM fact_orders f JOIN dim_customer c USING (customer_id)
    WHERE f.in_analysis
), first_orders AS (
    SELECT customer_unique_id, is_late FROM o
    WHERE order_seq = 1 AND purchase_date < DATE '2018-06-01'
), repeaters AS (
    SELECT DISTINCT customer_unique_id FROM o WHERE order_seq > 1
)
SELECT
    CASE WHEN f.is_late THEN 'First order late' ELSE 'First order on time' END AS first_order,
    COUNT(*)                                                                    AS customers,
    ROUND(100.0 * AVG((r.customer_unique_id IS NOT NULL)::INT), 2)              AS repeat_rate_pct
FROM first_orders f LEFT JOIN repeaters r USING (customer_unique_id)
GROUP BY 1 ORDER BY 1 DESC;
