-- 1) Ensure target schema exists
CREATE SCHEMA IF NOT EXISTS CORE.JAFFLE_SHOP;


-- 2) Build the base FULL_TABLE
CREATE OR REPLACE TABLE CORE.JAFFLE_SHOP.FULL_TABLE (
    order_datetime        TIMESTAMP_NTZ
    , product_name          STRING
    , store_name            STRING
    , customer_name         STRING

    
    , order_id              STRING
    , order_item_id         STRING
    , customer_id           STRING
    
    , product_sku           STRING
    , product_type          STRING
    , product_description   STRING

    , supply_id             STRING
    , supply_name           STRING
    , supply_perishable     BOOLEAN

    , store_id              STRING
    , store_opened_at       TIMESTAMP_NTZ
    
    , product_price         NUMBER(38,0)
    , order_total           NUMBER(38,0)
    , order_subtotal        NUMBER(38,0)
    , supply_cost           NUMBER(38,0)
    , order_tax_paid        NUMBER(38,0)
    , store_tax_rate        FLOAT

    , load_ts               TIMESTAMP_NTZ
);


-- 3) Insert joined data
INSERT INTO CORE.JAFFLE_SHOP.FULL_TABLE (
      customer_id
    , customer_name
    , order_id
    , order_datetime
    , store_id
    , order_subtotal
    , order_tax_paid
    , order_total
    , order_item_id
    , product_sku
    , product_name
    , product_type
    , product_price
    , product_description
    , supply_id
    , supply_name
    , supply_cost
    , supply_perishable
    , store_name
    , store_opened_at
    , store_tax_rate
    , load_ts
)
SELECT
      c.id                                        AS customer_id
    , c.name                                      AS customer_name

    , o.id                                        AS order_id
    , o.ordered_at                                AS order_datetime
    , o.store_id                                  AS store_id
    , o.subtotal                                  AS order_subtotal
    , o.tax_paid                                  AS order_tax_paid
    , o.order_total                               AS order_total

    , oi.id                                       AS order_item_id
    , oi.sku                                      AS product_sku
    , p.name                                      AS product_name
    , p.type                                      AS product_type
    , p.price                                     AS product_price
    , p.description                               AS product_description

    , s.id                                        AS supply_id
    , s.name                                      AS supply_name
    , s.cost                                      AS supply_cost
    , s.perishable                                AS supply_perishable

    , st.name                                     AS store_name
    , st.opened_at                                AS store_opened_at
    , st.tax_rate                                 AS store_tax_rate

    , CURRENT_TIMESTAMP()                         AS load_ts
FROM RAW.JAFFLE_SHOP_RAW.ORDERS            AS o
LEFT JOIN RAW.JAFFLE_SHOP_RAW.CUSTOMERS    AS c  ON c.id = o.customer
LEFT JOIN RAW.JAFFLE_SHOP_RAW.ITEMS        AS oi ON oi.order_id = o.id
LEFT JOIN RAW.JAFFLE_SHOP_RAW.PRODUCTS     AS p  ON p.sku = oi.sku
LEFT JOIN RAW.JAFFLE_SHOP_RAW.SUPPLIES     AS s  ON s.sku = oi.sku
LEFT JOIN RAW.JAFFLE_SHOP_RAW.STORES       AS st ON st.id = o.store_id
WHERE oi.id IS NOT NULL -- There appear to be some orders without ordered items.
ORDER BY o.ordered_at;


-- 4) Create SCD-style table with targeted rename for JAF-001 on/after 2017-01-01
CREATE OR REPLACE TABLE CORE.JAFFLE_SHOP.FULL_TABLE_SCD
COPY GRANTS
AS
SELECT
    order_datetime,
    CASE
        WHEN product_sku = 'JAF-001'
         AND order_datetime >= TO_TIMESTAMP_NTZ('2017-01-01 00:00:00')
        THEN 'chocophone'
        ELSE product_name
    END                                  AS product_name,
    store_name,
    customer_name,

    order_id,
    order_item_id,
    customer_id,

    product_sku,
    product_type,
    product_description,

    supply_id,
    supply_name,
    supply_perishable,

    store_id,
    store_opened_at,

    product_price,
    order_total,
    order_subtotal,
    supply_cost,
    order_tax_paid,
    store_tax_rate,

    load_ts
FROM CORE.JAFFLE_SHOP.FULL_TABLE;


-- 5) Create BRIDGE table: FILTER OUT SUP-007 on/after 2017-04-01,
--    then reduce price by 10 for all remaining rows
CREATE OR REPLACE TABLE CORE.JAFFLE_SHOP.FULL_TABLE_SCD_BRIDGE
COPY GRANTS
AS
SELECT
    order_datetime,
    product_name,
    store_name,
    customer_name,
    order_id,
    order_item_id,
    customer_id,
    product_sku,
    product_type,
    product_description,
    supply_id,
    supply_name,
    supply_perishable,
    store_id,
    store_opened_at,
    CASE
        WHEN product_type = 'beverage'
         AND order_datetime >= TO_TIMESTAMP_NTZ('2017-04-01 00:00:00')
        THEN product_price - 10
        ELSE product_price
    END AS product_price,
    order_total,
    order_subtotal,
    supply_cost,
    order_tax_paid,
    store_tax_rate,
    load_ts
FROM CORE.JAFFLE_SHOP.FULL_TABLE_SCD
WHERE NOT (
    supply_id = 'SUP-007'
    AND order_datetime >= TO_TIMESTAMP_NTZ('2017-04-01 00:00:00')
);
