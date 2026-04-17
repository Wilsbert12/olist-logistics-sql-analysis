# Olist E-Commerce SQL Analysis
## What Is Driving Poor Customer Satisfaction on the Olist Platform?

**Tools:** SQL (SQLite) · VS Code · SQLTools · Python (setup only)
**Status:** In progress

---

## Business Question

Olist is a Brazilian marketplace that connects small independent sellers to customers across multiple e-commerce channels. Because Olist does not fulfil orders directly, customer satisfaction depends on seller quality and logistics performance — factors Olist can influence but not control.

This analysis asks: **does logistics performance drive poor customer satisfaction — and if so, is it a carrier problem or a seller problem?**

<!-- INTERNAL NOTE: If logistics does not correlate with review scores, reframe the business question to the broader "what is driving poor customer satisfaction?" and pivot the analysis to product-level drivers. Delete this note before publishing. -->

The primary thread is the relationship between delivery performance and review scores. If that relationship holds, the follow-up questions are which delivery metric matters most and whether underperformance is attributable to sellers (dispatch speed) or carriers (transit time). Geography is a secondary explanatory dimension — used to understand where problems concentrate, not as an end in itself.

---

## Dataset

**Source:** [Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle)

Real anonymised transaction data from Olist. Approximately 100,000 orders placed between 2016 and 2018 across multiple Brazilian marketplaces.

**Schema overview:** 8 core tables connected primarily by `order_id` (the central spine) and zip code prefix (the geographic layer). The structure is close to a star schema — orders as the central fact table with customers, sellers, products, payments, reviews, and geolocation as dimension tables.

| Table | Description |
|---|---|
| olist_orders | Core fact table — order status and delivery timestamps |
| olist_order_items | Line items per order, links to products and sellers |
| olist_order_reviews | Customer review scores and comments |
| olist_customers | Customer ID and location (zip code) |
| olist_sellers | Seller ID and location (zip code) |
| olist_products | Product attributes and category |
| olist_order_payments | Payment type and value |
| olist_geolocation | Zip code to latitude/longitude mapping |
| product_category_name_translation | Portuguese to English category name lookup |

The diagram below shows the relationships between tables and the key fields used to join them:

![Database schema](schema.png)

### Data Notes

**Geolocation coordinates do not add precision beyond zip code prefix.** The geolocation table maps 5-digit zip code prefixes (not full 8-digit CEPs) to lat/lng coordinates, with multiple coordinate entries per prefix. These multiple entries reflect the various full zip codes that were collapsed into the prefix — there is no way to know which coordinate belongs to which customer or seller. Working with the zip code prefix directly is more honest: it represents a geographic area, and that is all the data actually supports.

---

### Schema Notes

**`customer_id` is redundant.** The dataset ships with two customer identifiers: `customer_id` and `customer_unique_id`. Per the Kaggle documentation, `customer_id` is generated fresh for each order — making it 1:1 with `order_id` and carrying no additional information. `customer_unique_id` is the actual person-level identifier and the correct field for any customer-level analysis (e.g. repeat purchase rate). The `olist_customers` table exists solely to map `customer_id` → `customer_unique_id` and is not in normal form — `customer_unique_id` is a property of a real-world person, but is stored repeatedly across every order that person placed rather than once in a properly keyed table.

---

## Environment

**SQL engine:** SQLite, via Python's built-in `sqlite3` module — no additional install required. The Olist CSVs are loaded into a local SQLite database using the setup script described below.

**Editor:** VS Code with two extensions:
- [SQLTools](https://marketplace.visualstudio.com/items?itemName=mtxr.sqltools) — writing and running SQL queries with inline results
- [SQLite Viewer](https://marketplace.visualstudio.com/items?itemName=qwtel.sqlite-viewer) — browsing table structure and contents

**File format:** `.sqlite` extension used rather than `.db` — more explicit about the engine for anyone reading the repository.

**Note on SQLite:** SQLite was chosen for setup simplicity. The queries use standard SQL and are compatible with PostgreSQL and BigQuery with minor syntax adjustments (e.g. date functions). This reflects a deliberate trade-off: the SQL skill being demonstrated is engine-agnostic; the tool running it is not the point.

---

## Setup

### 1. Download the data
Download all CSV files from the [Kaggle dataset page](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) and place them in a `/data` folder in the project root.

### 2. Load into SQLite
Run the setup script to create the database:

```bash
python setup_db.py
```

This creates `olist.sqlite` in the project root with all 9 tables loaded. The script uses only Python's standard library — no additional dependencies.

### 3. Connect in VS Code
Open VS Code, go to SQLTools, add a new connection, select SQLite, and point it at `olist.sqlite`. All `.sql` files in `/queries` can then be run directly from the editor.

---

## Repository Structure

```
├── data/                          # Raw CSVs (not tracked in git)
├── queries/
│   ├── 00_data_quality.sql        # Table sizes, null checks, join integrity
│   ├── 01_logistics_and_reviews.sql   # Does logistics correlate with reviews? Seller vs carrier attribution
│   ├── 02_seller_analysis.sql         # Seller-level performance and satisfaction patterns
│   └── 03_regional_analysis.sql       # Geographic decomposition of delivery performance
├── setup_db.py                    # One-time script to load CSVs into SQLite
├── olist.sqlite                   # SQLite database (not tracked in git)
└── README.md
```

---

## Analytical Approach

### Phase 1 — Data Quality & Orientation
Before any analysis, a focused data quality check establishes what the data can and cannot support. This is documented in `00_data_quality.sql` and covers:

- **Table sizes** — row counts per table
- **Null checks** — null rates on key join columns and all delivery timestamp fields
- **Join integrity** — confirm foreign key relationships hold in practice (e.g. how many order items have no matching order)
- **Delivery data completeness** — `order_delivered_customer_date` is null for undelivered orders; establishes what proportion of orders are usable for delivery performance analysis

This section demonstrates analytical rigour but is not the centrepiece of the project. Findings from the data quality check inform the scope and any caveats documented in the findings.

### Phase 2 — Analysis

**`01_logistics_and_reviews.sql` — Does logistics performance predict review scores?**

The first question is whether logistics metrics correlate with review scores at all. Several candidate metrics are tested to identify which has the strongest relationship:

| Metric | What it captures |
|---|---|
| `order_delivered_customer_date` − `order_purchase_timestamp` | Total customer wait time |
| `order_delivered_customer_date` − `order_approved_at` | Logistics time only, strips payment processing lag |
| `order_delivered_customer_date` − `order_estimated_delivery_date` | Delivery promise accuracy |
| `order_delivered_carrier_date` − `order_approved_at` | Seller dispatch speed — the only leg attributable to the seller |

Payment method (boleto vs credit card) is included as a control variable, since boleto requires manual payment and can delay order approval — inflating apparent logistics time for those orders.

**Findings:** Delivery delta (promise accuracy) is the strongest predictor of review score (r = -0.315). Total wait time and logistics time correlate at a similar but weaker level (~-0.25 each). Since the difference between total wait and logistics time is only the payment processing lag, and both correlate almost identically, payment lag is not a meaningful driver — total wait time and logistics time are effectively redundant. Seller dispatch speed is the weakest predictor (r = -0.12), suggesting the carrier leg matters more than seller dispatch in explaining satisfaction. The key takeaway is that customers respond to whether the delivery promise was kept, not to how long they waited in absolute terms.

If a correlation is established, the sub-question is attribution: is underperformance driven by slow seller dispatch or by the carrier transit leg?

**`02_seller_analysis.sql` — Are there seller-level differences in satisfaction?**

Seller-level analysis runs regardless of the outcome of `01`. If logistics correlates with reviews, this file identifies which sellers are driving the problem. If logistics does not correlate, seller-level patterns may point to other satisfaction drivers (e.g. product quality, customer service) that are outside the scope of this dataset — findings would motivate a recommended deep dive rather than a conclusion.

**`03_regional_analysis.sql` — Does geography explain delivery performance?**

Conditional on `01` establishing a logistics-review relationship. Asks at which geographic granularity delivery performance diverges most, using the hierarchy: state → city → zip code prefix (where zip prefix serves as the within-city unit, avoiding the coordinate ambiguity in the geolocation table — see Data Notes). The analysis runs on both the customer side (where orders are delivered to) and the seller side (where they ship from). As an extension, origin-destination state pairs (seller state × customer state) are included at state level only — finer granularity fragments the data too much to be reliable.

---

## SQL Techniques Demonstrated

- Multi-table joins across 4–6 tables
- CTEs (Common Table Expressions) for readable, modular query structure
- Window functions — ranking sellers, computing rolling metrics
- Aggregations and grouping by region, seller, and product category
- Derived metrics — delivery delta (actual vs estimated), review score aggregation by seller and region

---

## Key Findings

### Logistics and review scores (`01_logistics_and_reviews.sql`)

Pearson correlation of four logistics metrics against review score:

| Metric | Pearson r |
|---|---|
| Delivery delta (actual vs estimated) | -0.315 |
| Logistics time (approved → delivered) | -0.253 |
| Total wait (purchase → delivered) | -0.251 |
| Seller dispatch speed (approved → carrier) | -0.122 |

Logistics performance correlates negative with review scores, with delivery promise accuracy being the strongest predictor (Pearson r = -0.315). Total wait time and logistics time correlate at similar but weaker levels (~-0.25), and are effectively redundant — the payment processing lag that separates them is not a meaningful driver. Seller dispatch speed is the weakest predictor (r = -0.12), suggesting the carrier leg rather than the seller is the primary source of satisfaction variance.

**89% of orders arrive before the estimated delivery date**, with the majority arriving 1–2 weeks early. Olist systematically sets conservative estimates (average delivery delta: -12 days). The modest size of the late tail (≈10% of orders) validates the correlation findings — the signal is not driven by outliers.

**The relationship between lateness and review scores is a threshold effect, not linear:**

| Delivery outcome | Avg review score |
|---|---|
| Any early delivery | 4.2 – 4.34 |
| On time | 4.03 |
| 1–7 days late | 2.71 |
| 1–2 weeks late | 1.68 |
| 2+ weeks late | ~1.6 |

Satisfaction collapses at the first sign of lateness and then flatlines — customers are already very dissatisfied by 1 week late, and further delays make little additional difference. **The intervention priority is to prevent orders going late at all, particularly beyond one week.**

### Seller analysis (`02_seller_analysis.sql`)

The seller-level correlation between average delivery delta and average review score is -0.353, slightly stronger than the order-level correlation (-0.315). Aggregating to seller level removes order-level noise, confirming that sellers who are systematically late are systematically poorly rated.

The dataset contains 3,095 sellers, but the majority have fewer than 10 orders — consistent with Olist's model of onboarding many small and micro-sellers. Filtering to sellers with at least 10 orders (1,311 sellers) and a late delivery rate more than 1.5x the platform average (>14.4%), **126 sellers are identified as consistently underperforming on delivery promises**. The query in `02_seller_analysis.sql` generates the full list ranked by late delivery rate.

### Regional analysis (`03_regional_analysis.sql`)

At state level, there is a clear geographic pattern in review scores — a broadly north/south divide, with southern and southeastern states (SP, MG, PR, RS) scoring above 4.1 and northern and northeastern states (MA, AL, BA, SE) clustering below 3.9. The pattern has notable exceptions: RJ is a negative island in the south (3.87 despite being Brazil's second largest city), and RN, PB, PE form a positive island in the northeast (above 4.0 despite being in the underperforming region). The state-level correlation between average delivery delta and average review score is -0.311, almost identical to the order-level correlation, confirming that the geographic pattern in satisfaction is driven by delivery performance.

However, comparing between-state variance (10.6) with within-state variance (25–270 across states) reveals that cities within the same state differ from each other far more than states differ from each other. The north/south pattern is real but misleading as a targeting framework — the actual variation in delivery performance is happening at city level, not state level. Intervention efforts should be organised at city level, not state level.

**DF (Brasília) stands out as an anomaly:** high review variance but very low delivery delta variance. Delivery is consistent there, but satisfaction is not — pointing to non-logistics drivers in that market specifically.

### Recommendations

1. **Start with the 126 underperforming sellers** identified in `02_seller_analysis.sql` — pilot all interventions below with this group first, monitor closely, then roll out platform-wide.

2. **Organise all geographic efforts at city level, not state level.** Within-state variance in delivery performance far exceeds between-state variance — state-level targeting would miss most of the problem.

3. **Recalibrate delivery estimates by region.** Since Olist controls the delivery promise, estimates can be tightened on routes where carriers consistently over-deliver and buffered where they don't. The regional analysis (`03_regional_analysis.sql`) identifies where late deliveries concentrate, providing the input for this recalibration.

4. **Identify and address underperforming carrier routes.** The carrier leg — not seller dispatch — is where lateness originates. Olist should use delivery performance data to renegotiate SLAs or switch providers on consistently underperforming routes. Carrier-level analysis is beyond the scope of this dataset (carrier identity is not recorded) but is a clear next step.

5. **Proactive customer communication on delayed orders.** Rather than reducing lateness directly, Olist can reduce its impact by notifying customers before the estimated delivery date passes. The data suggests the moment of lateness is the primary damage point — getting ahead of it with a proactive update may soften the review score impact.

---

## Limitations

- **No product-level analysis.** This analysis focuses on logistics as the driver of poor satisfaction. Product quality, pricing, and category-level effects are outside scope but likely account for a meaningful share of the review score variance not explained by delivery performance.
- **No carrier-level analysis.** Carrier identity is not recorded in this dataset. The finding that the carrier leg drives lateness cannot be attributed to specific providers — a recommended next step would be to enrich the data with carrier information.

