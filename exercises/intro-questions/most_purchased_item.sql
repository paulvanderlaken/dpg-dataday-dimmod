-- WRONG! Duplicate counts because of multiple records per order item, due to supplies.
SELECT 
    product_name,
    COUNT(product_name) AS times_purchased
FROM FULL_TABLE
WHERE store_name = 'Philadelphia'
GROUP BY product_name
ORDER BY times_purchased DESC
LIMIT 3;


-- CORRECT! By counting only distinct order_item_ids, one tackles the (potential) count inflation due to supplies.
SELECT 
    product_name,
    COUNT(DISTINCT order_item_id) AS times_purchased
FROM FULL_TABLE
WHERE store_name = 'Philadelphia'
GROUP BY product_name
ORDER BY times_purchased DESC
LIMIT 3;

-- ALSO CORRECT! Slightly more superfluous to count only distinct order_item_ids, and avoid double counts due to supplies.
SELECT 
    product_name,
    COUNT(*) AS times_purchased
FROM (
    SELECT DISTINCT order_item_id, product_name
    FROM FULL_TABLE
    WHERE store_name = 'Philadelphia'
) AS unique_items
GROUP BY product_name
ORDER BY times_purchased DESC
LIMIT 3;



