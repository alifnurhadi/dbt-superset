SELECT
    revenue_rank,
    category,
    total_orders,
    total_revenue,
    ROUND((total_revenue * 100.0 / NULLIF(SUM(total_revenue) OVER (), 0))::numeric,
        2) AS revenue_share_pct,
    ROUND((SUM(total_revenue) OVER (
                                    ORDER BY total_revenue DESC
                                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                                    ) * 100.0 / NULLIF(SUM(total_revenue) OVER (), 0))::numeric, 2) AS cumulative_revenue_pct,
    avg_order_value,
    credit_card_revenue,
    boleto_revenue,
    credit_card_share_pct,
    late_count,
    late_rate_pct,
    avg_days_late,
    RANK() OVER (ORDER BY late_rate_pct DESC) AS late_rank
FROM (
SELECT
    RANK() OVER (ORDER BY SUM(b.price) DESC)
    AS revenue_rank,
    b.product_category_name_english
    AS category,
    COUNT(DISTINCT b.order_id)
    AS total_orders,
    SUM(b.price)
    AS total_revenue,
    ROUND((SUM(b.price) / NULLIF(COUNT(DISTINCT b.order_id), 0))::numeric, 2)
    AS avg_order_value,
    ps.credit_card_revenue,
    ps.boleto_revenue,
    ROUND((ps.credit_card_revenue * 100.0 /
    NULLIF(ps.credit_card_revenue + ps.boleto_revenue, 0))::numeric, 1)
    AS credit_card_share_pct,
    ls.late_count,
    ls.avg_days_late,
    ROUND((ls.late_count * 100.0 /
    NULLIF(COUNT(DISTINCT b.order_id), 0))::numeric, 1)
    AS late_rate_pct
FROM (
SELECT
    p.product_category_name,
    t.product_category_name_english,
    oi.order_id,
    oi.price
FROM products p
JOIN product_category_name_translation t
ON t.product_category_name = p.product_category_name
JOIN order_items oi
ON oi.product_id = p.product_id
) b
JOIN (
SELECT
    p.product_category_name,
    SUM(pay.payment_value) FILTER (WHERE pay.payment_type = 'credit_card')
    AS credit_card_revenue,
    SUM(pay.payment_value) FILTER (WHERE pay.payment_type = 'boleto')
    AS boleto_revenue
    FROM products p
JOIN order_items oi ON oi.product_id = p.product_id
JOIN order_payments pay ON pay.order_id = oi.order_id
GROUP BY p.product_category_name
) ps ON ps.product_category_name = b.product_category_name
JOIN (
SELECT
    p.product_category_name,
    COUNT(DISTINCT CASE WHEN o.order_delivered_customer_date
    > o.order_estimated_delivery_date
    THEN o.order_id END)
    AS late_count,
    ROUND(AVG(CASE WHEN o.order_delivered_customer_date
    > o.order_estimated_delivery_date
    THEN EXTRACT(EPOCH FROM (o.order_delivered_customer_date
    - o.order_estimated_delivery_date)) / 86400.0
    END)::numeric, 1)
    AS avg_days_late
FROM products p
JOIN order_items oi ON oi.product_id = p.product_id
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY p.product_category_name
) ls ON ls.product_category_name = b.product_category_name
GROUP BY
    b.product_category_name_english,
    ps.credit_card_revenue,
    ps.boleto_revenue,
    ls.late_count,
    ls.avg_days_late
    ) ranked
ORDER BY revenue_rank;
