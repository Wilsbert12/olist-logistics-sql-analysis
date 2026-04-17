-- =============================================================================
-- 03_REGIONAL_ANALYSIS.SQL
-- Does geography explain delivery performance and poor satisfaction?
-- At which geographic level does delivery performance diverge most?
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. CORRELATION — STATE-LEVEL DELIVERY DELTA VS REVIEW SCORE
-- Average delivery delta and review score aggregated to state level,
-- then Pearson correlation computed across all 27 states.
-- -----------------------------------------------------------------------------

-- Result: -0.311 — almost identical to the order-level correlation (-0.315).
-- The geographic pattern in review scores is driven by delivery performance.
-- States with worse delivery deltas are consistently the lower-rated states.

WITH delivery_metrics AS (
    SELECT
        c.customer_state,
        AVG(review_score) AS avg_review_score,
        AVG(JULIANDAY(DATE(order_delivered_customer_date)) - JULIANDAY(DATE(order_estimated_delivery_date))) AS avg_delivery_delta
    FROM olist_order_reviews_dataset AS orv
    JOIN olist_orders_dataset AS o ON orv.order_id = o.order_id
    JOIN olist_customers_dataset AS c ON c.customer_id = o.customer_id
    GROUP BY c.customer_state
)
SELECT
    (AVG(avg_delivery_delta * avg_review_score) - AVG(avg_delivery_delta) * AVG(avg_review_score))
    / SQRT(
        (AVG(avg_delivery_delta * avg_delivery_delta) - AVG(avg_delivery_delta) * AVG(avg_delivery_delta)) *
        (AVG(avg_review_score   * avg_review_score)   - AVG(avg_review_score)   * AVG(avg_review_score))
    ) AS corr_state_delta_vs_review
FROM delivery_metrics;


-- -----------------------------------------------------------------------------
-- 2. WITHIN-STATE VARIANCE — CITY-LEVEL DELIVERY DELTA AND REVIEW SCORE
-- Computes variance of city averages within each state to understand whether
-- delivery performance diverges more between states or within states.
-- -----------------------------------------------------------------------------

-- Results: within-state variance (25–270) far exceeds between-state variance
-- (10.6, see query 3). The north/south pattern is real but misleading as a
-- targeting framework — most variation happens at city level within states.
-- Notable: DF has high review variance but very low delivery delta variance,
-- suggesting non-logistics drivers in that market.

WITH city_level AS (
    SELECT
        c.customer_city,
        c.customer_state,
        AVG(review_score) AS avg_review_score,
        AVG(JULIANDAY(DATE(order_delivered_customer_date)) - JULIANDAY(DATE(order_estimated_delivery_date))) AS avg_delivery_delta
    FROM olist_order_reviews_dataset AS orv
    JOIN olist_orders_dataset AS o ON orv.order_id = o.order_id
    JOIN olist_customers_dataset AS c ON c.customer_id = o.customer_id
    GROUP BY c.customer_state, c.customer_city
),
state_level AS (
    SELECT
        customer_state,
        (AVG(avg_review_score * avg_review_score)     - AVG(avg_review_score)     * AVG(avg_review_score))     AS var_reviews,
        (AVG(avg_delivery_delta * avg_delivery_delta) - AVG(avg_delivery_delta)   * AVG(avg_delivery_delta))   AS var_delivery_delta
    FROM city_level
    GROUP BY customer_state
)
SELECT
    customer_state,
    var_reviews,
    var_delivery_delta
FROM state_level
ORDER BY var_reviews DESC;


-- -----------------------------------------------------------------------------
-- 3. BETWEEN-STATE VARIANCE — DELIVERY DELTA AND REVIEW SCORE
-- Single number: variance of state averages across all 27 states.
-- Compare with within-state variance above to establish where divergence
-- is greater — between states or within states.
-- -----------------------------------------------------------------------------

-- Results:
--   Between-state variance in reviews:        0.023
--   Between-state variance in delivery delta: 10.6
-- Both are far smaller than within-state variance, confirming that
-- city level is the right granularity for targeting interventions.

WITH delivery_metrics AS (
    SELECT
        c.customer_state,
        AVG(review_score) AS avg_review_score,
        AVG(JULIANDAY(DATE(order_delivered_customer_date)) - JULIANDAY(DATE(order_estimated_delivery_date))) AS avg_delivery_delta
    FROM olist_order_reviews_dataset AS orv
    JOIN olist_orders_dataset AS o ON orv.order_id = o.order_id
    JOIN olist_customers_dataset AS c ON c.customer_id = o.customer_id
    GROUP BY c.customer_state
)
SELECT
    (AVG(avg_review_score * avg_review_score)     - AVG(avg_review_score)   * AVG(avg_review_score))   AS var_between_state_reviews,
    (AVG(avg_delivery_delta * avg_delivery_delta) - AVG(avg_delivery_delta) * AVG(avg_delivery_delta)) AS var_between_state_deltas
FROM delivery_metrics;
