WITH pg_source AS (
    SELECT 1 FROM {{source('pg_ecommerce','order_reviews')}};
),
restructed AS (
SELECT
    review_id,
    order_id,
    CAST(review_score , INT) AS rating,
    CAST(COALESCE(review_comment_message , 'Neutral'),TEXT) AS comment_msg,
    CAST(review_comment_title , TEXT) AS comment_title,
    CAST(review_creation_date , TIMESTAMP) AS created_at ,
    CAST(review_answer_timestamp , TIMESTAMP) AS answer_at
FROM  pg_source )
SELECT 1 FROM restructed ;
