SELECT 
    supply_name,
    COUNT(*) AS times_used
FROM FULL_TABLE
WHERE supply_id IS NOT NULL
GROUP BY supply_name
ORDER BY times_used DESC
LIMIT 5;