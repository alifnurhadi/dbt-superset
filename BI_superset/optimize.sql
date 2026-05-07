WITH base AS MATERIALIZED (
    SELECT
        t.product_category_name_english,
        oi.order_id,
        oi.price,
        pay.payment_type,
        pay.payment_value,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    FROM order_items oi
    JOIN products p
        ON p.product_id = oi.product_id
    JOIN product_category_name_translation t
        ON t.product_category_name = p.product_category_name
    LEFT JOIN order_payments pay
        ON pay.order_id = oi.order_id
    LEFT JOIN orders o
        ON o.order_id = oi.order_id
),
category_stats AS (
    SELECT
        product_category_name_english                                           AS category,
        COUNT(DISTINCT order_id)                                                AS total_orders,
        SUM(price)                                                              AS total_revenue,
        ROUND((SUM(price) / NULLIF(COUNT(DISTINCT order_id), 0))::numeric, 2)  AS avg_order_value,

        SUM(payment_value) FILTER (WHERE payment_type = 'credit_card')         AS credit_card_revenue,
        SUM(payment_value) FILTER (WHERE payment_type = 'boleto')              AS boleto_revenue,

        COUNT(DISTINCT CASE
            WHEN order_delivered_customer_date > order_estimated_delivery_date
            THEN order_id END)                                                  AS late_count,

        ROUND(AVG(CASE
            WHEN order_delivered_customer_date IS NOT NULL
             AND order_delivered_customer_date > order_estimated_delivery_date
            THEN EXTRACT(EPOCH FROM (
                order_delivered_customer_date - order_estimated_delivery_date
            )) / 86400.0
        END)::numeric, 1)                                                       AS avg_days_late
    FROM base
    GROUP BY product_category_name_english
),
ranked AS (
    SELECT
        RANK() OVER (ORDER BY total_revenue DESC)                               AS revenue_rank,
        category,
        total_orders,
        total_revenue,
        avg_order_value,
        credit_card_revenue,
        boleto_revenue,
        ROUND((credit_card_revenue * 100.0 /
            NULLIF(credit_card_revenue + boleto_revenue, 0))::numeric, 1)       AS credit_card_share_pct,
        late_count,
        avg_days_late,
        ROUND((late_count * 100.0 / NULLIF(total_orders, 0))::numeric, 1)       AS late_rate_pct,
        SUM(total_revenue) OVER ()                                              AS grand_total  -- computed once, reused twice below
    FROM category_stats
)
SELECT
    revenue_rank,
    category,
    total_orders,
    total_revenue,
    ROUND((total_revenue * 100.0 / NULLIF(grand_total, 0))::numeric, 2)         AS revenue_share_pct,
    ROUND((SUM(total_revenue) OVER (
        ORDER BY total_revenue DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) * 100.0 / NULLIF(grand_total, 0))::numeric, 2)                            AS cumulative_revenue_pct,
    avg_order_value,
    credit_card_revenue,
    boleto_revenue,
    credit_card_share_pct,
    late_count,
    late_rate_pct,
    avg_days_late,
    RANK() OVER (ORDER BY late_rate_pct DESC)                                   AS late_rank
FROM ranked
ORDER BY revenue_rank;


VERSION 2

WITH payment_agg AS (
    SELECT 
        order_id,
        SUM(payment_value) FILTER (WHERE payment_type = 'credit_card') AS credit_card_payment,
        SUM(payment_value) FILTER (WHERE payment_type = 'boleto') AS boleto_payment
    FROM order_payments
    GROUP BY order_id
),
base AS (
    SELECT 
        t.product_category_name_english AS category,
        oi.order_id,
        oi.price,
        pay.credit_card_payment,
        pay.boleto_payment,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    JOIN product_category_name_translation t ON t.product_category_name = p.product_category_name
    JOIN orders o ON o.order_id = oi.order_id
    LEFT JOIN payment_agg pay ON pay.order_id = oi.order_id
),
category_stats AS (
    SELECT 
        category,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(price) AS total_revenue,
        ROUND((SUM(price) / NULLIF(COUNT(DISTINCT order_id), 0))::numeric, 2) AS avg_order_value,
        -- (Using MAX ensures we don't double count the pre-aggregated payment if a category has 2 items in the same cart)
        SUM(MAX(credit_card_payment)) OVER (PARTITION BY category) AS credit_card_revenue,
        SUM(MAX(boleto_payment)) OVER (PARTITION BY category) AS boleto_revenue,

        COUNT(DISTINCT CASE 
            WHEN order_delivered_customer_date > order_estimated_delivery_date 
            THEN order_id END) AS late_count,
            
        ROUND(AVG(CASE 
            WHEN order_delivered_customer_date > order_estimated_delivery_date 
            THEN EXTRACT(EPOCH FROM (order_delivered_customer_date - order_estimated_delivery_date)) / 86400.0 
        END)::numeric, 1) AS avg_days_late
    FROM base
    GROUP BY category, order_id
),
recap_stats AS (
    SELECT 
        category,
        SUM(total_orders) AS total_orders,
        SUM(total_revenue) AS total_revenue,
        ROUND((SUM(total_revenue) / NULLIF(SUM(total_orders), 0))::numeric, 2) AS avg_order_value,
        MAX(credit_card_revenue) AS credit_card_revenue,
        MAX(boleto_revenue) AS boleto_revenue,
        SUM(late_count) AS late_count,
        MAX(avg_days_late) AS avg_days_late
    FROM category_stats
    GROUP BY category
),
ranked AS (
    SELECT 
        RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
        *,
        SUM(total_revenue) OVER () AS grand_total 
    FROM recap_stats
)
SELECT 
    revenue_rank,
    category,
    total_orders,
    total_revenue,
    ROUND((total_revenue * 100.0 / NULLIF(grand_total, 0))::numeric, 2) AS revenue_share_pct,
    ROUND((SUM(total_revenue) OVER (ORDER BY total_revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) * 100.0 / NULLIF(grand_total, 0))::numeric, 2) AS cumulative_revenue_pct,
    avg_order_value,
    credit_card_revenue,
    boleto_revenue,
    ROUND((credit_card_revenue * 100.0 / NULLIF(credit_card_revenue + boleto_revenue, 0))::numeric, 1) AS credit_card_share_pct,
    late_count,
    ROUND((late_count * 100.0 / NULLIF(total_orders, 0))::numeric, 1) AS late_rate_pct,
    avg_days_late,
    RANK() OVER (ORDER BY (late_count * 100.0 / NULLIF(total_orders, 0)) DESC) AS late_rank
FROM ranked
ORDER BY revenue_rank;