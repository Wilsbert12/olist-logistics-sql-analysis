-- =============================================================================
-- 00_DATA_QUALITY.SQL
-- Orientation and data quality checks before any analysis.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. ROW COUNTS
-- Get a sense of the size of each table.
-- -----------------------------------------------------------------------------

SELECT COUNT(*) FROM olist_customers_dataset;       -- 99,441
SELECT COUNT(*) FROM olist_geolocation_dataset;     -- 1,000,163
SELECT COUNT(*) FROM olist_order_items_dataset;     -- 112,650
SELECT COUNT(*) FROM olist_order_payments_dataset;  -- 103,886
SELECT COUNT(*) FROM olist_order_reviews_dataset;   -- 99,224
SELECT COUNT(*) FROM olist_orders_dataset;          -- 99,441
SELECT COUNT(*) FROM olist_products_dataset;        -- 32,951
SELECT COUNT(*) FROM olist_sellers_dataset;         -- 3,095
SELECT COUNT(*) FROM product_category_name_translation; -- 71

-- Notable observations:
-- - customers and orders have identical row counts (99,441). See duplicate check below.
-- - items (112,650) > orders: expected, some orders contain multiple items.
-- - payments (103,886) > orders: expected, some orders use multiple payment methods.
-- - geolocation (1,000,163) is an order of magnitude larger than all other tables.
--   Each 5-digit zip code prefix has multiple lat/lng entries, reflecting the full
--   8-digit CEPs that were collapsed into it during anonymisation. The coordinates
--   do not add meaningful precision beyond the zip code prefix itself.


-- -----------------------------------------------------------------------------
-- 2. DUPLICATE PRIMARY KEY CHECKS
-- Confirm that key columns are actually unique where expected.
-- -----------------------------------------------------------------------------

SELECT COUNT(*) AS total, COUNT(DISTINCT customer_id) AS distinct_customers
FROM olist_customers_dataset;
-- Result: total = distinct (99,441). No duplicates.

SELECT COUNT(*) AS total, COUNT(DISTINCT order_id) AS distinct_orders
FROM olist_orders_dataset;
-- Result: total = distinct (99,441). No duplicates.

-- The equal row counts in customers and orders are not duplicates — they reflect
-- a schema design issue: customer_id is generated per order, making it 1:1 with
-- order_id and carrying no additional information. customer_unique_id is the actual
-- person-level identifier and should be used for any customer-level analysis.
-- See README schema notes for full explanation.


-- -----------------------------------------------------------------------------
-- 3. NULL CHECKS
-- Check null rates on all columns used for joins or as core metrics.
-- -----------------------------------------------------------------------------

-- All tables: zero nulls across all checked columns.
-- The dataset is clean — no rows will be lost in joins due to missing keys,
-- and no delivery timestamps or review scores are missing unexpectedly.

-- customers
SELECT
    COUNT(*) AS total,
    COUNT(*) - COUNT(customer_id)              AS null_count_customer_id,
    ROUND(100.0 * (COUNT(*) - COUNT(customer_id)) / COUNT(*), 1)              AS null_pct_customer_id,
    COUNT(*) - COUNT(customer_zip_code_prefix) AS null_count_zip_code,
    ROUND(100.0 * (COUNT(*) - COUNT(customer_zip_code_prefix)) / COUNT(*), 1) AS null_pct_zip_code
FROM olist_customers_dataset;

-- geolocation
SELECT
    COUNT(*) AS total,
    COUNT(*) - COUNT(geolocation_zip_code_prefix) AS null_count_zip_code,
    ROUND(100.0 * (COUNT(*) - COUNT(geolocation_zip_code_prefix)) / COUNT(*), 1) AS null_pct_zip_code
FROM olist_geolocation_dataset;

-- order_items
SELECT
    COUNT(*) AS total,
    COUNT(*) - COUNT(order_id)   AS null_count_order_id,
    ROUND(100.0 * (COUNT(*) - COUNT(order_id)) / COUNT(*), 1)   AS null_pct_order_id,
    COUNT(*) - COUNT(seller_id)  AS null_count_seller_id,
    ROUND(100.0 * (COUNT(*) - COUNT(seller_id)) / COUNT(*), 1)  AS null_pct_seller_id,
    COUNT(*) - COUNT(product_id) AS null_count_product_id,
    ROUND(100.0 * (COUNT(*) - COUNT(product_id)) / COUNT(*), 1) AS null_pct_product_id
FROM olist_order_items_dataset;

-- order_payments
SELECT
    COUNT(*) AS total,
    COUNT(*) - COUNT(order_id) AS null_count_order_id,
    ROUND(100.0 * (COUNT(*) - COUNT(order_id)) / COUNT(*), 1) AS null_pct_order_id
FROM olist_order_payments_dataset;

-- order_reviews
SELECT
    COUNT(*) AS total,
    COUNT(*) - COUNT(order_id)     AS null_count_order_id,
    ROUND(100.0 * (COUNT(*) - COUNT(order_id)) / COUNT(*), 1)     AS null_pct_order_id,
    COUNT(*) - COUNT(review_score) AS null_count_review_score,
    ROUND(100.0 * (COUNT(*) - COUNT(review_score)) / COUNT(*), 1) AS null_pct_review_score
FROM olist_order_reviews_dataset;

-- orders (join keys + all delivery timestamps)
SELECT
    COUNT(*) AS total,
    COUNT(*) - COUNT(order_id)                    AS null_count_order_id,
    ROUND(100.0 * (COUNT(*) - COUNT(order_id)) / COUNT(*), 1)                    AS null_pct_order_id,
    COUNT(*) - COUNT(customer_id)                 AS null_count_customer_id,
    ROUND(100.0 * (COUNT(*) - COUNT(customer_id)) / COUNT(*), 1)                 AS null_pct_customer_id,
    COUNT(*) - COUNT(order_approved_at)            AS null_count_approved,
    ROUND(100.0 * (COUNT(*) - COUNT(order_approved_at)) / COUNT(*), 1)            AS null_pct_approved,
    COUNT(*) - COUNT(order_delivered_carrier_date) AS null_count_delivered_carrier,
    ROUND(100.0 * (COUNT(*) - COUNT(order_delivered_carrier_date)) / COUNT(*), 1) AS null_pct_delivered_carrier,
    COUNT(*) - COUNT(order_delivered_customer_date) AS null_count_delivered_customer,
    ROUND(100.0 * (COUNT(*) - COUNT(order_delivered_customer_date)) / COUNT(*), 1) AS null_pct_delivered_customer,
    COUNT(*) - COUNT(order_estimated_delivery_date) AS null_count_estimated,
    ROUND(100.0 * (COUNT(*) - COUNT(order_estimated_delivery_date)) / COUNT(*), 1) AS null_pct_estimated
FROM olist_orders_dataset;

-- products
SELECT
    COUNT(*) AS total,
    COUNT(*) - COUNT(product_id)            AS null_count_product_id,
    ROUND(100.0 * (COUNT(*) - COUNT(product_id)) / COUNT(*), 1)            AS null_pct_product_id,
    COUNT(*) - COUNT(product_category_name) AS null_count_category,
    ROUND(100.0 * (COUNT(*) - COUNT(product_category_name)) / COUNT(*), 1) AS null_pct_category
FROM olist_products_dataset;

-- sellers
SELECT
    COUNT(*) AS total,
    COUNT(*) - COUNT(seller_id)              AS null_count_seller_id,
    ROUND(100.0 * (COUNT(*) - COUNT(seller_id)) / COUNT(*), 1)              AS null_pct_seller_id,
    COUNT(*) - COUNT(seller_zip_code_prefix) AS null_count_zip_code,
    ROUND(100.0 * (COUNT(*) - COUNT(seller_zip_code_prefix)) / COUNT(*), 1) AS null_pct_zip_code
FROM olist_sellers_dataset;


-- -----------------------------------------------------------------------------
-- 4. JOIN INTEGRITY CHECKS
-- Verify that foreign keys match across tables in practice.
-- Any non-zero count means rows will be silently dropped in joins.
-- -----------------------------------------------------------------------------

-- All joins: zero unmatched rows. Every foreign key has a match in its target table.
-- No rows will be lost in any join across the core tables.

-- order_items → orders
SELECT COUNT(*) AS unmatched
FROM olist_order_items_dataset AS oi
LEFT JOIN olist_orders_dataset AS o ON oi.order_id = o.order_id
WHERE o.customer_id IS NULL; -- 0

-- order_reviews → orders
SELECT COUNT(*) AS unmatched
FROM olist_order_reviews_dataset AS orv
LEFT JOIN olist_orders_dataset AS o ON orv.order_id = o.order_id
WHERE o.customer_id IS NULL; -- 0

-- order_payments → orders
SELECT COUNT(*) AS unmatched
FROM olist_order_payments_dataset AS op
LEFT JOIN olist_orders_dataset AS o ON op.order_id = o.order_id
WHERE o.customer_id IS NULL; -- 0

-- orders → customers
SELECT COUNT(*) AS unmatched
FROM olist_orders_dataset AS o
LEFT JOIN olist_customers_dataset AS c ON o.customer_id = c.customer_id
WHERE c.customer_unique_id IS NULL; -- 0

-- order_items → sellers
SELECT COUNT(*) AS unmatched
FROM olist_order_items_dataset AS oi
LEFT JOIN olist_sellers_dataset AS s ON oi.seller_id = s.seller_id
WHERE s.seller_zip_code_prefix IS NULL; -- 0

-- order_items → products
SELECT COUNT(*) AS unmatched
FROM olist_order_items_dataset AS oi
LEFT JOIN olist_products_dataset AS p ON oi.product_id = p.product_id
WHERE p.product_category_name IS NULL; -- 0
