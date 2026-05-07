-- A1 Monthly Revenue Trend
WITH monthly_revenue AS (
SELECT
    EXTRACT(YEAR FROM o.order_purchase_timestamp) AS year,
    EXTRACT(MONTH FROM o.order_purchase_timestamp) AS month,
    SUM(p.payment_value)::NUMERIC(12,2) AS total_revenue
  FROM orders o
  JOIN order_payments p ON o.order_id = p.order_id
  WHERE o.order_status != 'canceled'
  GROUP BY 1, 2
  ),
addition_prev AS (
SELECT *,
LAG(total_revenue) OVER (ORDER BY year, month) AS prev_month_revenue
FROM
monthly_revenue
  )
SELECT
  year,
  month,
  total_revenue,
  prev_month_revenue,
  ROUND(
    ((total_revenue - prev_month_revenue ) /
    NULLIF(prev_month_revenue, 0)) * 100.0,
  2) AS mom_change_pct
  FROM addition_prev
  ORDER BY year, month;


-- A2: Top 10 Product Categories by Revenue
WITH filtered_orders AS (
    SELECT order_id
    FROM orders
    WHERE order_status != 'canceled'
),
product_categories AS (
    SELECT
        pr.product_id,
        t.product_category_name_english AS category
    FROM products pr
    JOIN product_category_name_translation t
        ON pr.product_category_name = t.product_category_name
),
items_detail AS (
    SELECT
        pc.category,
        fo.order_id,
        oi.order_item_id,
        oi.price
    FROM filtered_orders fo
    JOIN order_items oi ON fo.order_id = oi.order_id
    JOIN product_categories pc ON oi.product_id = pc.product_id
)
SELECT
    category,
    COUNT(DISTINCT order_id) AS total_order,
    COUNT(order_item_id) AS total_items_sold,
    SUM(price) AS total_revenue,
    ROUND((SUM(price) / NULLIF(COUNT(DISTINCT order_id), 0))::numeric, 2) AS avg_category_order_value
FROM items_detail
GROUP BY 1
ORDER BY total_revenue DESC
LIMIT 10;


-- A3: Customer Cohort Retention
WITH cohort_setup AS (
  SELECT
    c.customer_unique_id,
    DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
  FROM orders o
  JOIN customers c ON o.customer_id = c.customer_id
  GROUP BY 1
),
cohort_size AS (
  SELECT
    cohort_month,
    COUNT(DISTINCT customer_unique_id) AS cohort_size
  FROM cohort_setup
  GROUP BY 1
),
retention_data AS (
  SELECT
    cs.cohort_month,
    DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month,
    COUNT(DISTINCT c.customer_unique_id) AS retained_customers
  FROM cohort_setup cs
  JOIN customers c ON cs.customer_unique_id = c.customer_unique_id
  JOIN orders o ON c.customer_id = o.customer_id
  GROUP BY 1, 2
)
SELECT
  s.cohort_month,
  s.cohort_size,
  MAX(CASE WHEN r.order_month = s.cohort_month + INTERVAL '1 month' THEN r.retained_customers ELSE 0 END) AS retained_m1,
  MAX(CASE WHEN r.order_month = s.cohort_month + INTERVAL '2 month' THEN r.retained_customers ELSE 0 END) AS retained_m2,
  MAX(CASE WHEN r.order_month = s.cohort_month + INTERVAL '3 month' THEN r.retained_customers ELSE 0 END) AS retained_m3
FROM cohort_size s
LEFT JOIN retention_data r ON s.cohort_month = r.cohort_month
GROUP BY 1, 2
ORDER BY 1;
