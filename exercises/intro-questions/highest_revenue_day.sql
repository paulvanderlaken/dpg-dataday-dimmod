-- WRONG! Duplicate counts because of multiple records per order item, due to supplies.
SELECT 
    CAST(order_datetime AS DATE) AS order_date,
    SUM(order_total) AS daily_revenue
FROM FULL_TABLE
GROUP BY order_date
ORDER BY daily_revenue DESC
LIMIT 3;

-- CORRECT! Need to get unique order totals first, and then take the sum. 
SELECT 
    order_date,
    SUM(order_total) AS daily_revenue
FROM (
    SELECT DISTINCT order_id, CAST(order_datetime AS DATE) AS order_date, order_total
    FROM FULL_TABLE
) AS unique_orders
GROUP BY order_date
ORDER BY daily_revenue DESC
LIMIT 3;