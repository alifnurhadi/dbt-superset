WITH orders_detail AS (
    SELECT *
    FROM {{ ref('int_order_detail') }}
    WHERE order_status = 'delivered'
),
product_sales_agg AS (
    SELECT
        product_category,
        product_name,
        COUNT(order_item_id) AS total_units_sold,
        SUM(price) AS total_revenue,
        SUM(delivery_cost) AS total_delivery_cost,
        COUNT(DISTINCT order_id) AS total_order
    FROM orders_detail
    GROUP BY
        product_category,
        product_name
),
ranked_products AS (
    SELECT
        *,
        RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
        RANK() OVER (ORDER BY total_units_sold DESC) AS volume_rank
    FROM product_sales_agg
)
SELECT * FROM ranked_products
