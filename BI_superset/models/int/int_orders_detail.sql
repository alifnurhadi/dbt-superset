WITH products AS (
    SELECT *
    FROM {{ ref('stg_products')}}
),
category_name_translation AS(
    SELECT  *
    FROM {{ ref('stg_product_category_name_translation')}}
    ),
orders_item AS (
SELECT *
    FROM {{ref('stg_order_items')}}
),
orders AS (
    SELECT *
    FROM {{ref('stg_orders')}}
    ),
product_detail AS (
SELECT
    pr.product_id,
    pr.product_category_name AS product_name,
    pr.product_weight_g AS product_weight ,
    COALESCE(cnt.product_category_name_english, 'unknown') AS product_category
FROM products pr
LEFT JOIN category_name_translation cnt ON pr.product_category_name = cnt.product_category_name
),
order_product_item AS (
    SELECT
        oi.order_id,
        pd.product_name,
        pd.product_weight,
        pd.product_category,
        oi.order_item_id,
        oi.seller_id,
        oi.price,
        oi.freight_value as delivery_cost
    FROM orders_item oi
    LEFT JOIN product_detail pd ON oi.product_id = pd.product_id
    )
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    oi.product_name,
    oi.product_weight,
    oi.product_category,
    oi.order_item_id,
    oi.seller_id,
    oi.price,
    oi.delivery_cost ,
    DATE(o.order_purchase_timestamp) AS purchase_at,
    DATE(o.order_approved_at) AS approved_at,
    DATE(o.order_delivered_carrier_date) AS carried_at,
    DATE(o.order_delivered_customer_date) AS received_at
FROM orders o
LEFT JOIN order_product_item oi on oi.order_id = o.order_id
