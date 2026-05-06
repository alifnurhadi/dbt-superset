WITH product_detail AS (
SELECT
    pr.product_id,
    pr.product_category_name AS product_name,
    pr.product_weight_g AS product_weight ,
    cnt.product_category_name_english AS product_category
FROM ref{{'stg_product'}} pr
LEFT JOIN ref{{'stg_product_category_name_translation'}} cnt ON pr.product_id = cnt.product_id
)
