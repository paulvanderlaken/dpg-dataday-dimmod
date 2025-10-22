-- WRONG! Total spent has double counted because of the more detailed level of observation ()
SELECT 
    customer_name,
    customer_id,
    SUM(order_total) AS total_spent
FROM FULL_TABLE
GROUP BY customer_name, customer_id
ORDER BY total_spent DESC
LIMIT 3;


-- CORRECT! Need to take distinct customer-order combinations first, to avoid the double counting due to supplies.
SELECT 
    customer_name,
    customer_id,
    SUM(order_total) AS total_spent
FROM (
    SELECT DISTINCT order_id, customer_id, customer_name, order_total
    FROM FULL_TABLE
) AS unique_orders
GROUP BY customer_name, customer_id
ORDER BY total_spent DESC
LIMIT 3;