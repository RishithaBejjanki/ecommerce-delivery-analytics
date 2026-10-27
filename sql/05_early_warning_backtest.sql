-- =============================================================================
-- 05_early_warning_backtest.sql
-- Part 2 evidence: does the proposed late-delivery risk rule actually work?
--
-- The rule scores each order at the moment the seller hands it to the carrier:
--
--   days_left     = time from hand-off to the end of the promised date
--   expected_days = how long the carrier is expected to take on this route:
--                     the larger of
--                       (a) HISTORY: 75th-percentile transit time for this
--                           seller-state -> customer-state lane in 2017
--                           (falls back to customer state if the lane has < 30 orders)
--                       (b) LIVE: 75th-percentile transit time of orders delivered
--                           to the same customer state in the last 14 days
--                           (only used when there are 20+ such deliveries)
--   slack_days    = days_left - expected_days
--
--   HIGH    slack_days < 0                      (expected to miss the promise)
--   MEDIUM  slack_days < 5  OR seller missed ship-by deadline
--   LOW     everything else
--
-- To avoid "cheating", benchmarks are built only from data that would have
-- existed at the time: lane history from 2017, live signal from deliveries
-- completed before the hand-off. The rule is tested on Jan-Aug 2018 orders.
-- Setup statements come first; named result queries follow.
-- =============================================================================

CREATE OR REPLACE TABLE bt_orders AS
SELECT f.*, s.state AS seller_state, c.state AS customer_state
FROM fact_orders f
JOIN dim_seller   s ON f.primary_seller_id = s.seller_id
JOIN dim_customer c USING (customer_id)
WHERE f.in_analysis;

-- (a) History benchmarks, built on 2017 only
CREATE OR REPLACE TABLE bt_lane_benchmark AS
SELECT seller_state, customer_state, COUNT(*) AS orders,
       QUANTILE_CONT(transit_days, 0.75) AS p75_transit_days
FROM bt_orders WHERE purchase_date < DATE '2018-01-01'
GROUP BY 1, 2 HAVING COUNT(*) >= 30;

CREATE OR REPLACE TABLE bt_dest_benchmark AS
SELECT customer_state, QUANTILE_CONT(transit_days, 0.75) AS p75_transit_days
FROM bt_orders WHERE purchase_date < DATE '2018-01-01'
GROUP BY 1;

-- Test population: 2018 orders
CREATE OR REPLACE TABLE bt_test AS
SELECT * FROM bt_orders WHERE purchase_date >= DATE '2018-01-01';

-- (b) Live signal: deliveries to the same state completed in the 14 days before hand-off
CREATE OR REPLACE TABLE bt_live AS
SELECT t.order_id,
       QUANTILE_CONT(h.transit_days, 0.75) AS live_p75_transit_days,
       COUNT(h.order_id)                   AS live_deliveries
FROM bt_test t
JOIN bt_orders h
  ON  h.customer_state = t.customer_state
  AND h.delivered_at <  t.shipped_at
  AND h.delivered_at >= t.shipped_at - INTERVAL 14 DAY
GROUP BY 1;

CREATE OR REPLACE TABLE bt_scored AS
SELECT
    t.order_id, t.purchase_date, t.shipped_at, t.promised_date, t.customer_state,
    t.seller_missed_sla, t.is_late, t.days_late, t.review_score,
    COALESCE(l.p75_transit_days, d.p75_transit_days)                       AS history_days,
    CASE WHEN v.live_deliveries >= 20 THEN v.live_p75_transit_days END     AS live_days,
    DATE_DIFF('minute', t.shipped_at,
              CAST(t.promised_date AS TIMESTAMP) + INTERVAL 1 DAY) / 1440.0 AS days_left
FROM bt_test t
LEFT JOIN bt_lane_benchmark l USING (seller_state, customer_state)
LEFT JOIN bt_dest_benchmark d USING (customer_state)
LEFT JOIN bt_live           v USING (order_id);

-- Candidate threshold settings. The recommended one is option B.
CREATE OR REPLACE TABLE bt_threshold_options AS
SELECT * FROM (VALUES
    ('A', 'History only (no live signal)', FALSE, 0, 5),
    ('B', 'History + live, HIGH < 0, MEDIUM < 5  [recommended]', TRUE, 0, 5),
    ('C', 'History + live, HIGH < 2, MEDIUM < 5', TRUE, 2, 5),
    ('D', 'History + live, HIGH < 3, MEDIUM < 7', TRUE, 3, 7)
) AS o(option_id, description, use_live, high_below, medium_below);

CREATE OR REPLACE TABLE bt_tiered AS
SELECT
    o.option_id, o.description, s.*,
    s.days_left - CASE WHEN o.use_live THEN GREATEST(s.history_days, COALESCE(s.live_days, 0))
                       ELSE s.history_days END                              AS slack_days,
    CASE
        WHEN s.days_left - CASE WHEN o.use_live THEN GREATEST(s.history_days, COALESCE(s.live_days, 0))
                                ELSE s.history_days END < o.high_below      THEN 'HIGH'
        WHEN s.days_left - CASE WHEN o.use_live THEN GREATEST(s.history_days, COALESCE(s.live_days, 0))
                                ELSE s.history_days END < o.medium_below
             OR s.seller_missed_sla                                         THEN 'MEDIUM'
        ELSE 'LOW'
    END                                                                     AS risk_tier
FROM bt_scored s CROSS JOIN bt_threshold_options o;

-- name: bt01_recommended_rule
-- How the recommended rule (option B) sorts 2018 orders.
SELECT
    risk_tier,
    COUNT(*)                                                          AS orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                AS pct_of_orders,
    SUM(is_late::INT)                                                 AS late_orders,
    ROUND(100.0 * AVG(is_late::INT), 1)                               AS late_rate_pct,
    ROUND(100.0 * SUM(is_late::INT) / SUM(SUM(is_late::INT)) OVER (), 1) AS pct_of_all_late_caught,
    ROUND(AVG(review_score), 2)                                       AS avg_review_score
FROM bt_tiered WHERE option_id = 'B'
GROUP BY 1
ORDER BY CASE risk_tier WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END;

-- name: bt02_threshold_options
-- The trade-off the business has to choose: catching more late orders means
-- flagging more orders (more alerts, more false alarms).
SELECT
    option_id, description,
    ROUND(100.0 * AVG((risk_tier = 'HIGH')::INT), 1)                                   AS high_pct_of_orders,
    ROUND(100.0 * AVG(is_late::INT) FILTER (WHERE risk_tier = 'HIGH'), 1)              AS high_late_rate_pct,
    ROUND(100.0 * SUM((is_late AND risk_tier = 'HIGH')::INT) / SUM(is_late::INT), 1)   AS high_catches_pct_of_late,
    ROUND(100.0 * SUM((is_late AND risk_tier <> 'LOW')::INT) / SUM(is_late::INT), 1)   AS high_or_medium_catches_pct_of_late,
    ROUND(100.0 * AVG(is_late::INT) FILTER (WHERE risk_tier = 'LOW'), 1)               AS low_late_rate_pct,
    ROUND(COUNT(*) FILTER (WHERE risk_tier = 'HIGH')
          / COUNT(DISTINCT STRFTIME(purchase_date, '%Y-%m')) / 30.0, 0)                AS high_alerts_per_day
FROM bt_tiered
GROUP BY 1, 2 ORDER BY 1;

-- name: bt03_monthly_alert_volume
-- Recommended rule month by month: alert volume (ops capacity) and whether
-- HIGH keeps separating from LOW, including in the Feb-Mar 2018 spike.
SELECT
    STRFTIME(purchase_date, '%Y-%m')                                        AS year_month,
    COUNT(*)                                                                AS orders,
    ROUND(100.0 * AVG(is_late::INT), 1)                                     AS late_rate_pct,
    COUNT(*) FILTER (WHERE risk_tier = 'HIGH')                              AS high_alerts,
    ROUND(COUNT(*) FILTER (WHERE risk_tier = 'HIGH') / 30.0, 0)             AS high_alerts_per_day,
    ROUND(100.0 * AVG(is_late::INT) FILTER (WHERE risk_tier = 'HIGH'), 1)   AS high_late_rate_pct,
    ROUND(100.0 * AVG(is_late::INT) FILTER (WHERE risk_tier = 'LOW'), 1)    AS low_late_rate_pct,
    ROUND(100.0 * SUM((is_late AND risk_tier = 'HIGH')::INT)
          / NULLIF(SUM(is_late::INT), 0), 1)                                AS high_catches_pct_of_late
FROM bt_tiered WHERE option_id = 'B'
GROUP BY 1 ORDER BY 1;

-- name: bt04_lead_time
-- How much warning does a HIGH alert give? (Days between hand-off and the promised date.)
SELECT
    ROUND(MEDIAN(days_left), 1)                                     AS median_days_warning,
    ROUND(QUANTILE_CONT(days_left, 0.25), 1)                        AS p25_days_warning,
    ROUND(100.0 * AVG((days_left >= 3)::INT), 1)                    AS pct_with_3plus_days_warning
FROM bt_tiered WHERE option_id = 'B' AND risk_tier = 'HIGH' AND is_late;
