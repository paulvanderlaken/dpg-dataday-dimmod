-- WRONG! Inflated, duplicate counting due to supply-level granularity of the big table.
SELECT 
    customer_id,
    customer_name,
    store_id,
    store_name,
    COUNT(*) AS visits
FROM FULL_TABLE
GROUP BY customer_id, customer_name, store_id, store_name
ORDER BY visits DESC
LIMIT 3;

-- CORRECT! By counting the distinct order_ids, one avoids duplicate order_ids due to supply-linkages inflating the visit count.
SELECT 
    customer_id,
    customer_name,
    store_id,
    store_name,
    COUNT(DISTINCT order_id) AS visits
FROM FULL_TABLE
GROUP BY customer_id, customer_name, store_id, store_name
ORDER BY visits DESC
LIMIT 3;