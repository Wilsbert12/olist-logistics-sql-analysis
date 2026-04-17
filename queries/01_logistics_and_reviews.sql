-- =============================================================================
-- 01_LOGISTICS_AND_REVIEWS.SQL
-- Does logistics performance correlate with review scores?
-- If so, which metric matters most — and is it a seller or carrier issue?
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. CORRELATION — LOGISTICS METRICS VS REVIEW SCORE
-- Four candidate metrics tested against review score using Pearson correlation.
-- Dates rounded to day level: customers think in days, and estimated delivery
-- dates are date-only (no time component), so fractional days would be inconsistent.
-- -----------------------------------------------------------------------------

-- Results:
--   corr_total_wait:     -0.251
--   corr_logistics_time: -0.253
--   corr_delivery_delta: -0.315  ← strongest predictor
--   corr_dispatch_speed: -0.122  ← weakest; seller dispatch is not the main driver
--
-- Key takeaway: customers respond to whether the delivery promise was kept,
-- not to how long they waited in absolute terms. Total wait and logistics time
-- correlate almost identically — the difference (payment processing lag) is
-- not a meaningful driver and the two metrics are effectively redundant.
-- Seller dispatch speed is notably weaker, pointing to the carrier leg rather
-- than the seller as the main source of satisfaction variance.

WITH delivery_metrics AS (
    SELECT
        order_id,
        JULIANDAY(DATE(order_delivered_customer_date)) - JULIANDAY(DATE(order_purchase_timestamp))      AS total_wait,
        JULIANDAY(DATE(order_delivered_customer_date)) - JULIANDAY(DATE(order_approved_at))             AS logistics_time,
        JULIANDAY(DATE(order_delivered_customer_date)) - JULIANDAY(DATE(order_estimated_delivery_date)) AS delivery_delta,
        JULIANDAY(DATE(order_delivered_carrier_date))  - JULIANDAY(DATE(order_approved_at))             AS dispatch_speed
    FROM olist_orders_dataset
)
SELECT
    (AVG(total_wait * review_score) - AVG(total_wait) * AVG(review_score))
    / SQRT(
        (AVG(total_wait * total_wait)         - AVG(total_wait)       * AVG(total_wait)) *
        (AVG(review_score * review_score)     - AVG(review_score)     * AVG(review_score))
    ) AS corr_total_wait,

    (AVG(logistics_time * review_score) - AVG(logistics_time) * AVG(review_score))
    / SQRT(
        (AVG(logistics_time * logistics_time) - AVG(logistics_time)   * AVG(logistics_time)) *
        (AVG(review_score * review_score)     - AVG(review_score)     * AVG(review_score))
    ) AS corr_logistics_time,

    (AVG(delivery_delta * review_score) - AVG(delivery_delta) * AVG(review_score))
    / SQRT(
        (AVG(delivery_delta * delivery_delta) - AVG(delivery_delta)   * AVG(delivery_delta)) *
        (AVG(review_score * review_score)     - AVG(review_score)     * AVG(review_score))
    ) AS corr_delivery_delta,

    (AVG(dispatch_speed * review_score) - AVG(dispatch_speed) * AVG(review_score))
    / SQRT(
        (AVG(dispatch_speed * dispatch_speed) - AVG(dispatch_speed)   * AVG(dispatch_speed)) *
        (AVG(review_score * review_score)     - AVG(review_score)     * AVG(review_score))
    ) AS corr_dispatch_speed

FROM delivery_metrics AS dm
JOIN olist_order_reviews_dataset AS orv
    ON dm.order_id = orv.order_id;


-- -----------------------------------------------------------------------------
-- 2. DISTRIBUTION — TOTAL WAIT AND DELIVERY DELTA
-- Sense-check the averages and identify the scale of outliers.
-- Results: no negative wait times (no data quality issue).
-- 70% of orders arrive within 14 days. Only 7% take over 30 days.
-- Average delivery delta is -12 days — Olist systematically pads estimates.
-- Outlier tails (60+ days wait, extreme early/late deltas) are small enough
-- not to undermine the correlation findings.
-- -----------------------------------------------------------------------------

WITH delivery_metrics AS (
    SELECT
        order_id,
        JULIANDAY(DATE(order_delivered_customer_date)) - JULIANDAY(DATE(order_purchase_timestamp))      AS total_wait,
        JULIANDAY(DATE(order_delivered_customer_date)) - JULIANDAY(DATE(order_estimated_delivery_date)) AS delivery_delta
    FROM olist_orders_dataset
)
SELECT
    MIN(total_wait)      AS min_total_wait,
    MAX(total_wait)      AS max_total_wait,
    ROUND(AVG(total_wait), 1)  AS avg_total_wait,
    MIN(delivery_delta)  AS min_delivery_delta,
    MAX(delivery_delta)  AS max_delivery_delta,
    ROUND(AVG(delivery_delta), 1) AS avg_delivery_delta
FROM delivery_metrics;

-- INTERNAL: total wait distribution
WITH delivery_metrics AS (
    SELECT
        JULIANDAY(DATE(order_delivered_customer_date)) - JULIANDAY(DATE(order_purchase_timestamp)) AS total_wait
    FROM olist_orders_dataset
)
SELECT
    CASE
        WHEN total_wait <= 7  THEN '1. 0-7 days'
        WHEN total_wait <= 14 THEN '2. 7-14 days'
        WHEN total_wait <= 30 THEN '3. 14-30 days'
        WHEN total_wait <= 60 THEN '4. 30-60 days'
        ELSE                       '5. 60+ days'
    END AS total_wait_bucket,
    COUNT(*) AS order_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM delivery_metrics
GROUP BY total_wait_bucket
ORDER BY total_wait_bucket;

-- INTERNAL: delivery delta distribution
WITH delivery_metrics AS (
    SELECT
        JULIANDAY(DATE(order_delivered_customer_date)) - JULIANDAY(DATE(order_estimated_delivery_date)) AS delivery_delta
    FROM olist_orders_dataset
)
SELECT
    CASE
        WHEN delivery_delta < -28  THEN '01. 4+ weeks early'
        WHEN delivery_delta <= -22 THEN '02. 3-4 weeks early'
        WHEN delivery_delta <= -15 THEN '03. 2-3 weeks early'
        WHEN delivery_delta <= -8  THEN '04. 1-2 weeks early'
        WHEN delivery_delta <= -1  THEN '05. 1-7 days early'
        WHEN delivery_delta = 0    THEN '06. on time'
        WHEN delivery_delta <= 7   THEN '07. 1-7 days late'
        WHEN delivery_delta <= 14  THEN '08. 1-2 weeks late'
        WHEN delivery_delta <= 21  THEN '09. 2-3 weeks late'
        WHEN delivery_delta <= 28  THEN '10. 3-4 weeks late'
        ELSE                            '11. 4+ weeks late'
    END AS delivery_delta_bucket,
    COUNT(*) AS order_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM delivery_metrics
GROUP BY delivery_delta_bucket
ORDER BY delivery_delta_bucket;


-- -----------------------------------------------------------------------------
-- 3. REVIEW SCORE BY DELIVERY DELTA BUCKET
-- Average review score per delivery delta bucket to understand the shape
-- of the relationship — is it linear or are there threshold effects?
-- -----------------------------------------------------------------------------

-- Results:
--   Early deliveries (any): avg score 4.2 – 4.34 — consistently high
--   On time:                avg score 4.03 — slightly lower than early
--   1-7 days late:          avg score 2.71 — sharp drop at first sign of lateness
--   1-2 weeks late:         avg score 1.68 — further drop
--   2+ weeks late:          avg score ~1.6 — flatlines; damage already done
--
-- Key takeaway: the relationship is not linear — it is a threshold effect.
-- Satisfaction collapses the moment an order goes late. Beyond ~1 week late,
-- additional lateness barely worsens the score (floor effect near 1.0).
-- Intervention priority: prevent lateness entirely, especially beyond 1 week.

WITH delivery_metrics AS (
    SELECT
        o.order_id,
        JULIANDAY(DATE(o.order_delivered_customer_date)) - JULIANDAY(DATE(o.order_estimated_delivery_date)) AS delivery_delta
    FROM olist_orders_dataset AS o
)
SELECT
    CASE
        WHEN delivery_delta < -28  THEN '01. 4+ weeks early'
        WHEN delivery_delta <= -22 THEN '02. 3-4 weeks early'
        WHEN delivery_delta <= -15 THEN '03. 2-3 weeks early'
        WHEN delivery_delta <= -8  THEN '04. 1-2 weeks early'
        WHEN delivery_delta <= -1  THEN '05. 1-7 days early'
        WHEN delivery_delta = 0    THEN '06. on time'
        WHEN delivery_delta <= 7   THEN '07. 1-7 days late'
        WHEN delivery_delta <= 14  THEN '08. 1-2 weeks late'
        WHEN delivery_delta <= 21  THEN '09. 2-3 weeks late'
        WHEN delivery_delta <= 28  THEN '10. 3-4 weeks late'
        ELSE                            '11. 4+ weeks late'
    END AS delivery_delta_bucket,
    COUNT(*)                        AS order_count,
    ROUND(AVG(orv.review_score), 2) AS avg_review_score
FROM delivery_metrics AS dm
JOIN olist_order_reviews_dataset AS orv ON dm.order_id = orv.order_id
GROUP BY delivery_delta_bucket
ORDER BY delivery_delta_bucket;
