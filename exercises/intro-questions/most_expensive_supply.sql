-- CORRECT!
SELECT 
    supply_id,
    supply_name,
    supply_cost AS max_cost
FROM (
    SELECT DISTINCT supply_id, supply_name, supply_cost
    FROM FULL_TABLE
) AS unique_supplies
ORDER BY supply_cost DESC
LIMIT 3;

-- FASTER, though it may tie and not show the tied second first placed item.
SELECT 
    supply_id,
    supply_name,
    supply_cost
FROM FULL_TABLE
ORDER BY supply_cost DESC
LIMIT 3;