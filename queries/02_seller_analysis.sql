-- =============================================================================
-- 02_SELLER_ANALYSIS.SQL
-- Are there seller-level differences in delivery performance and satisfaction?
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. CORRELATION — SELLER-LEVEL DELIVERY DELTA VS REVIEW SCORE
-- Same Pearson correlation as 01_logistics_and_reviews.sql, but aggregated
-- to seller level first. Averaging to seller level removes order-level noise,
-- so the correlation is expected to be slightly stronger.
-- -----------------------------------------------------------------------------

-- Result: -0.353 (vs -0.315 at order level)
-- Confirms the pattern holds at seller level — sellers who are systematically
-- late are systematically poorly rated. The modest increase reflects cleaner
-- signal once random per-order variation is smoothed out.

WITH delivery_metrics AS (
    SELECT
        seller_id,
        AVG(JULIANDAY(DATE(order_delivered_customer_date)) - JULIANDAY(DATE(order_estimated_delivery_date))) AS avg_delivery_delta,
        AVG(review_score) AS avg_review_score
    FROM olist_orders_dataset AS o
    JOIN olist_order_reviews_dataset AS orv ON o.order_id = orv.order_id
    JOIN olist_order_items_dataset AS oi    ON o.order_id = oi.order_id
    GROUP BY seller_id
)
SELECT
    (AVG(avg_delivery_delta * avg_review_score) - AVG(avg_delivery_delta) * AVG(avg_review_score))
    / SQRT(
        (AVG(avg_delivery_delta * avg_delivery_delta) - AVG(avg_delivery_delta) * AVG(avg_delivery_delta)) *
        (AVG(avg_review_score   * avg_review_score)   - AVG(avg_review_score)   * AVG(avg_review_score))
    ) AS corr_seller_delta_vs_review
FROM delivery_metrics;


-- -----------------------------------------------------------------------------
-- 2. UNDERPERFORMING SELLERS — HIGH LATE DELIVERY RATE
-- Identifies sellers with a significantly above-average rate of late deliveries
-- (orders where actual delivery exceeded the estimated delivery date).
--
-- Threshold: 1.5x the overall late rate (9.6%), i.e. >14.4% of orders late.
-- Minimum order count: 10 — filters out sellers with too few orders to be
-- statistically meaningful. Note: the majority of sellers (3,095 total) have
-- fewer than 10 orders in this dataset, reflecting Olist's model of connecting
-- many small and micro-sellers to marketplaces.
--
-- Result: 126 sellers meet both criteria.
-- Run this query to generate the full list for further investigation.
-- -----------------------------------------------------------------------------

WITH delivery_metrics AS (
    SELECT
        seller_id,
        JULIANDAY(DATE(order_delivered_customer_date)) - JULIANDAY(DATE(order_estimated_delivery_date)) AS delivery_delta
    FROM olist_orders_dataset AS o
    JOIN olist_order_items_dataset AS oi ON o.order_id = oi.order_id
)
SELECT
    seller_id,
    (COUNT(CASE WHEN delivery_delta > 0 THEN 1 END) * 100.0 / COUNT(*)) AS pct_delayed
FROM delivery_metrics AS dm
GROUP BY seller_id
HAVING pct_delayed > (1.5 * 9.6) AND COUNT(*) > 10
ORDER BY pct_delayed DESC;
