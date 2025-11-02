# Exercise #3: Building the Bridge

> _NEWS HEADLINE:_<br>
> **ALL STRAWS BANNED AS OF Q2 2017!**

Our Jaffle Shop serves not only delicious jaffles, but also satisfying cold drinks. 

Unfortunately, new legislation is forcing us to change our recipies as of Q2 2017. While the change is relatively small, it has some implications on our data management front. 

In the transactional data (`CORE.JAFFLE_SHOP.FULL_TABLE_SCD_BRIDGE`) you will observe that our "bill of materials" (BOM) has changed for our bevereages. There are no more records with supply items for straws.

You might have also noticed the slight price reduction to all our beverage items. While margins will slightly improve because of these changes, our analytics will only reflect this if we change our data models to work with changing BOMs.

## Your mission

Build a **BOM Version Dimension table** + **Bridge table** so analysts can:
* Know which supplies made up each product **during a given period**;
* Stamp facts with the **correct BOM version** for margin analysis;
* Drill into **component-level** details when they want.

> NOTE: You do not have to build the full Star schema or data model. You can assume your new dimension and bridge table will be fit into the wider model later on. 

## Step-by-step guide

### 0) Understanding the grain


Take some time to understand the grain of the table you're dealing with. 

* Source table: `CORE.JAFFLE_SHOP.FULL_TABLE_SCD_BRIDGE`
* Columns of interest: `product_sku`, `supply_id`, `order_datetime`
* Observed grain: order item × supply item at sell time

Here's a piece of code to get you started:

```sql
SELECT TOP 40 
* 
FROM CORE.JAFFLE_SHOP.FULL_TABLE_SCD_BRIDGE 
ORDER BY ORDER_ID, ORDER_ITEM_ID;
```


### 00) Checking what the BOMs looked like
Also take some time to check what happened to the recipes of the different items. 

For example:
1) First, aggregate supplies per order item.
2) Then roll up to the product-day view 
3) Summarize min/max dates per observed component count. 

This lets you see when items started having fewer components.

> Hints:<br>
> Cast timestamps to DATE: `CAST(order_datetime AS DATE)`. <br>
> Filter to focus on beverages: `WHERE product_type = 'beverage'`.

<details>
  <summary>Possible Solution</summary>

```sql
-- Checking the distinct items in the table
SELECT 
DISTINCT product_sku, product_description, product_type 
FROM CORE.JAFFLE_SHOP.FULL_TABLE_SCD_BRIDGE 
ORDER BY product_sku;
```

```sql
-- Checking what supplies have (ever) been used for which beverage item
SELECT 
DISTINCT product_sku, product_name, supply_id, supply_name 
FROM CORE.JAFFLE_SHOP.FULL_TABLE_SCD_BRIDGE 
WHERE product_type = 'beverage'
ORDER BY product_sku, supply_id;
```

```sql
-- Checking whether and when the observed BOM changes happened
WITH line_components AS (
  SELECT
      product_sku,
      order_id,
      order_item_id,
      CAST(order_datetime AS DATE) AS order_date,
      COUNT(DISTINCT supply_id)    AS component_cnt_line
  FROM CORE.JAFFLE_SHOP.FULL_TABLE_SCD_BRIDGE
  WHERE product_type = 'beverage'         
  GROUP BY product_sku, order_id, order_item_id, CAST(order_datetime AS DATE)
),
daily_components AS (
  SELECT
      product_sku,
      order_date,
      MAX(component_cnt_line) AS component_cnt_day
  FROM line_components
  GROUP BY product_sku, order_date
)
SELECT
    product_sku,
    component_cnt_day AS component_cnt,
    MIN(order_date)   AS first_date_seen,
    MAX(order_date)   AS last_date_seen
FROM daily_components
GROUP BY product_sku, component_cnt_day
ORDER BY product_sku, first_date_seen;
```
</details>


### 1) Create a landing schema and empty targets
You will need to create two tables as part of this exercise, and this is a great time to prepare the objects to store them.

You need to: 
* Ensure a schema exists for the tables
* Create a sequence for surrogate keys
* Then create your two tables:

#### `DIM_PRODUCT_BOM_VERSION`
One row per product & BOM version & validity window.

__Columns:__ 
* `product_sku`
* `bom_signature` (expect a string-representation of the supply_ids)
* `effective_from` 
* `effective_to_excl`
* `is_current`

####  `BR_BOM_VERSION_SUPPLY` 
The component rows for each version

__Columns:__ 
* `bom_version_key`
* `supply_id`
* `component_qty` (not really necessary, you may default to 1)

> Hints: <br>
> Use the Snowflake database created under your name. <br>
> You can use `CREATE SEQUENCE IF NOT EXISTS [DATABASE].[SCHEMA].SEQ_BOM_VERSION START = 1 INCREMENT = 1;` to make unique keys which you can directly leverage in a DDL script to make a column using `bom_version_key   NUMBER DEFAULT [DATABASE].[SCHEMA].SEQ_BOM_VERSION.NEXTVAL` 


<details>
  <summary>Possible Solution</summary>

Your DDL script could look something like this:

> Note: Replace `[YOUR_NAME]` below with the Snowflake database created in your name before this workshop.

```sql
CREATE SCHEMA IF NOT EXISTS [YOUR_NAME].JAFFLE_SHOP_BRIDGE;

CREATE SEQUENCE IF NOT EXISTS [YOUR_NAME].JAFFLE_SHOP_BRIDGE.SEQ_BOM_VERSION START = 1 INCREMENT = 1;

CREATE OR REPLACE TABLE [YOUR_NAME].JAFFLE_SHOP_BRIDGE.DIM_PRODUCT_BOM_VERSION (
      bom_version_key   NUMBER DEFAULT [YOUR_NAME].JAFFLE_SHOP_BRIDGE.SEQ_BOM_VERSION.NEXTVAL
    , product_sku       STRING NOT NULL
    , bom_signature     STRING NOT NULL            -- sorted, canonical list of supplies
    , effective_from    DATE   NOT NULL            -- inclusive
    , effective_to_excl DATE                        -- exclusive; NULL = current
    , is_current        BOOLEAN NOT NULL
    , CONSTRAINT PK_DIM_PRODUCT_BOM_VERSION PRIMARY KEY (bom_version_key)
    , CONSTRAINT UK_DIM_PRODUCT_BOM_VERSION UNIQUE (product_sku, effective_from)
);

CREATE OR REPLACE TABLE [YOUR_NAME].JAFFLE_SHOP_BRIDGE.BR_BOM_VERSION_SUPPLY (
      bom_version_key   NUMBER NOT NULL
    , supply_id         STRING NOT NULL
    , component_qty     NUMBER(38,0) DEFAULT 1     -- normally you'd add something like a quantity in a BOM, but fine to default to 1 for this workshops purpose 
);
```
</details>

## 2) Build daily BOM signatures (per product)
For each product and day, produce a canonical list of the unique supplies observed for each product_sku. For example, `"SUP-001,SUP-003,SUP-010"` would be a great "signature" to represent the bill of materials of an item.

* Group by (`product_sku`, `order_date`).
* Build a comma-seperated string of `supply_id` values.

> Hints:
> You can use `LISTAGG` to create a comma-seperated string of distinct items "within" a group.
> Casting to `DATE` normalizes multiple sales within a day.

<details>
  <summary>Possible Solution</summary>

```sql
WITH daily_sets AS (
  SELECT
      product_sku,
      CAST(order_datetime AS DATE) AS order_date,
      LISTAGG(DISTINCT supply_id, ',') WITHIN GROUP (ORDER BY supply_id) AS bom_signature
  FROM CORE.JAFFLE_SHOP.FULL_TABLE_SCD_BRIDGE
  GROUP BY 1,2
)
SELECT * FROM daily_sets ORDER BY product_sku, order_date;
```
</details>
<br>

**Double check:** do you see straws (SUP-007) in signatures on/after 2017-04-01?

## 3) Detect version starts (where the set changes)
Now you now use these `daily_sets` to derive the first date of each new signature per product.

> Hints:
> You can either use `LAG` directly in `QUALIFY`, or in a CTE to identify the "change points" that you then filter.

<details>
  <summary>Possible Solution</summary>

Solution using `QUALIFY`:
```sql
WITH daily_sets AS (
  SELECT
      product_sku,
      CAST(order_datetime AS DATE) AS order_date,
      LISTAGG(DISTINCT supply_id, ',') WITHIN GROUP (ORDER BY supply_id) AS bom_signature
  FROM CORE.JAFFLE_SHOP.FULL_TABLE_SCD_BRIDGE
  GROUP BY 1,2
)

SELECT
  product_sku,
  order_date AS effective_from,
  bom_signature
FROM daily_sets
QUALIFY LAG(bom_signature) OVER (PARTITION BY product_sku ORDER BY order_date)
       IS DISTINCT FROM bom_signature;
```

Solution using extra CTE with `LAG` + `FILTER`:
```sql
WITH daily_sets AS (
  SELECT
      product_sku,
      CAST(order_datetime AS DATE) AS order_date,
      LISTAGG(DISTINCT supply_id, ',') WITHIN GROUP (ORDER BY supply_id) AS bom_signature
  FROM CORE.JAFFLE_SHOP.FULL_TABLE_SCD_BRIDGE
  GROUP BY 1,2
),
change_points AS (
  SELECT
    product_sku,
    order_date AS effective_from,
    bom_signature,
    LAG(bom_signature) OVER (PARTITION BY product_sku ORDER BY order_date) AS prev_sig
  FROM daily_sets
)
SELECT product_sku, effective_from, bom_signature
FROM change_points
WHERE prev_sig IS NULL OR prev_sig <> bom_signature;
```
</details>

## 4) Turn starts into validity windows
Produce `[effective_from, effective_to_excl)` periods per product.

* Use `LEAD(effective_from)` (partition by product) to compute the exclusive end.
* Mark `is_current` when the `LEAD` is `NULL`.

<details>
  <summary>Possible Solution</summary>

```sql
-- Per product & day: canonical set of supplies (comma-seperated)
WITH daily_sets AS (
  SELECT
      product_sku,
      CAST(order_datetime AS DATE) AS order_date,
      LISTAGG(DISTINCT supply_id, ',') WITHIN GROUP (ORDER BY supply_id) AS bom_signature
  FROM CORE.JAFFLE_SHOP.FULL_TABLE_SCD_BRIDGE
  GROUP BY 1,2
),
-- Keep only the first day a new signature appears
version_starts AS (
  SELECT
      product_sku,
      order_date AS effective_from,
      bom_signature
  FROM daily_sets
  QUALIFY LAG(bom_signature) OVER (PARTITION BY product_sku ORDER BY order_date)
         IS DISTINCT FROM bom_signature
)
SELECT
    product_sku,
    bom_signature,
    effective_from,
    LEAD(effective_from) OVER (
        PARTITION BY product_sku
        ORDER BY effective_from
    ) AS effective_to_excl,
    LEAD(effective_from) OVER (
        PARTITION BY product_sku
        ORDER BY effective_from
    ) IS NULL AS is_current
FROM version_starts
ORDER BY product_sku, effective_from;
```
</details>


## 5) Now insert into `DIM_PRODUCT_BOM_VERSION`
Now it's time to persist the versioned BOM periods.

> Hints: <br>
> If you need several attempts, `TRUNCATE` the table after each.

<details>
  <summary>Possible Solution</summary>

> Note: replace [YOUR_NAME] with the appropriate database after copying the below.

```sql
CREATE SCHEMA IF NOT EXISTS [YOUR_NAME].JAFFLE_SHOP_BRIDGE;

-- Clear existing rows, then repopulate to avoid duplicates
TRUNCATE TABLE [YOUR_NAME].JAFFLE_SHOP_BRIDGE.DIM_PRODUCT_BOM_VERSION;

INSERT INTO [YOUR_NAME].JAFFLE_SHOP_BRIDGE.DIM_PRODUCT_BOM_VERSION
  (product_sku, bom_signature, effective_from, effective_to_excl, is_current)
WITH daily_sets AS (
  -- Per product & day: canonical set of supplies (sorted, distinct CSV)
  SELECT
      product_sku,
      CAST(order_datetime AS DATE) AS order_date,
      LISTAGG(DISTINCT supply_id, ',') WITHIN GROUP (ORDER BY supply_id) AS bom_signature
  FROM CORE.JAFFLE_SHOP.FULL_TABLE_SCD_BRIDGE
  GROUP BY 1,2
),
version_starts AS (
  -- Keep only the first day a new signature appears (or first observation)
  SELECT
      product_sku,
      order_date AS effective_from,
      bom_signature
  FROM daily_sets
  QUALIFY LAG(bom_signature) OVER (PARTITION BY product_sku ORDER BY order_date)
         IS DISTINCT FROM bom_signature
),
version_ranges AS (
  -- Turn starts into [effective_from, effective_to_excl) windows
  SELECT
      product_sku,
      bom_signature,
      effective_from,
      LEAD(effective_from) OVER (
          PARTITION BY product_sku
          ORDER BY effective_from
      ) AS effective_to_excl
  FROM version_starts
)
SELECT
    product_sku,
    bom_signature,
    effective_from,
    effective_to_excl,
    effective_to_excl IS NULL AS is_current
FROM version_ranges
ORDER BY product_sku, effective_from;
```
</details>

## 6) Build the bridge: version → component supplies

With each version’s signature as a comma-seperated string list, it's relatively easy to turn these into rows of (bom_version_key, supply_id).

* Split the supply-ids string and `FLATTEN` it.
* A join is not needed as you already have `bom_version_key` in the "seed" rows.

> Hints: <br>
> * Use the `DIM_PRODUCT_BOM_VERSION` table you just created as a seed. <br>
> * If you attempt multiple times, don't forget to `TRUNCATE` the table.
> * Remember to set the `component_qty` (to 1) if you made that a column in the bridge table! <br>
> * Check out the [Snowflake docs](https://docs.snowflake.com/en/sql-reference/functions/flatten) on how to use `LATERAL FLATTEN(INPUT => SPLIT(bom_signature, ','))` to turn the string signatures into a workable data.

<details>
  <summary>Possible Solution</summary>

> Note: replace [YOUR_NAME] with the appropriate database after copying the below.

A minimalistic solution:
```sql
-- (Optional) keep idempotent
TRUNCATE TABLE [YOUR_NAME].JAFFLE_SHOP_BRIDGE.BR_BOM_VERSION_SUPPLY;

INSERT INTO [YOUR_NAME].JAFFLE_SHOP_BRIDGE.BR_BOM_VERSION_SUPPLY (bom_version_key, supply_id, component_qty)
SELECT
  v.bom_version_key,
  TRIM(f.value::STRING) AS supply_id,
  1 AS component_qty
FROM [YOUR_NAME].JAFFLE_SHOP_BRIDGE.DIM_PRODUCT_BOM_VERSION AS v,
     LATERAL FLATTEN(INPUT => SPLIT(v.bom_signature, ',')) AS f
```

A potentially clearer solution using CTEs:

```sql
INSERT INTO [YOUR_NAME].JAFFLE_SHOP_BRIDGE.BR_BOM_VERSION_SUPPLY (bom_version_key, supply_id, component_qty)
SELECT bom_version_key, supply_id, 1
FROM (
  WITH seeds AS (
    SELECT bom_version_key, bom_signature
    FROM [YOUR_NAME].JAFFLE_SHOP_BRIDGE.DIM_PRODUCT_BOM_VERSION
  ),
  exploded AS (
    SELECT
      s.bom_version_key,
      TRIM(f.value::STRING) AS supply_id
    FROM seeds s,
         LATERAL FLATTEN(INPUT => SPLIT(s.bom_signature, ',')) f
  )
  SELECT bom_version_key, supply_id FROM exploded
);
```
</details>


## 7) Thinking about the future

What other (dimension/fact) tables would you need in order to start reporting on the the revenue and cost of items before and after the change? 

How would you use your new dimension and bridge table in a query for `product_sku = 'BEV-001'`?

You can assume the supply dimensions have not changed over time, so if you need a `dim_supply` table you can simply take the distinct ids and their max/latest cost. 

Take distinct records for (order_id, order_item_id) and use your product dimension table and BOM bridge to find the appropriate supplies according to the recipe signature.

Once you have these calculate some interesting metrics, like the cost, the margin, and the total revenue and profits before/after the change.


<details>
  <summary>Possible Solution</summary>

> Note: Replace `[YOUR_NAME]` with your own database.

```sql
-- Compute cost & revenue for BEV-001 without duplication
-- Strategy:
--   1) Build a supply "dimension" from the FULL_TABLE.
--   2) Build one row per order item (distinct order_item_id) with its price and order_date.
--   3) Stamp each order item with the correct BOM version (as of order_date).
--   4) Use the bridge to fetch the valid supplies for that version.
--   5) Join to the supply dim for costs, sum to item level, then compare pre/post 2017-04-01.

WITH supply_dim AS (
  -- 1) Supply "dimension": one cost per supply_id (assumed stable; pick MAX if multiple)
  SELECT
      supply_id,
      MAX(supply_cost) AS supply_cost
  FROM CORE.JAFFLE_SHOP.FULL_TABLE_SCD_BRIDGE
  GROUP BY supply_id
),
order_items AS (
  -- 2) One row per order item (avoid duplication), focused on BEV-001
  SELECT
      order_id,
      order_item_id,
      'BEV-001'                 AS product_sku,
      CAST(order_datetime AS DATE) AS order_date,
      MAX(product_price)        AS product_price   -- single revenue per item
  FROM CORE.JAFFLE_SHOP.FULL_TABLE_SCD_BRIDGE
  WHERE product_sku = 'BEV-001'
  GROUP BY order_id, order_item_id, CAST(order_datetime AS DATE)
),


stamped_versions AS (
  -- 3) Stamp each order item with its BOM version valid on the order_date
  SELECT
      oi.*,
      v.bom_version_key
  FROM order_items oi
  JOIN [YOUR_NAME].JAFFLE_SHOP_BRIDGE.DIM_PRODUCT_BOM_VERSION v
    ON v.product_sku = oi.product_sku
   AND oi.order_date >= v.effective_from
   AND (v.effective_to_excl IS NULL OR oi.order_date < v.effective_to_excl)
),

bom_components AS (
  -- 4) Components for that version (no duplicates by design: one row per supply_id per version)
  SELECT
      sv.order_id,
      sv.order_item_id,
      sv.order_date,
      b.supply_id
  FROM stamped_versions sv
  JOIN [YOUR_NAME].JAFFLE_SHOP_BRIDGE.BR_BOM_VERSION_SUPPLY b
    ON b.bom_version_key = sv.bom_version_key
),

line_costs AS (
  -- 5) Sum component costs to item level
  SELECT
      bc.order_id,
      bc.order_item_id,
      bc.order_date,
      SUM(sd.supply_cost) AS line_cost
  FROM bom_components bc
  JOIN supply_dim sd
    ON sd.supply_id = bc.supply_id
  GROUP BY bc.order_id, bc.order_item_id, bc.order_date
),

line_agg AS (
  -- 6) Combine revenue (from distinct order_items) with computed costs
  SELECT
      oi.order_id,
      oi.order_item_id,
      oi.order_date,
      oi.product_price AS line_revenue,
      COALESCE(lc.line_cost, 0) AS line_cost
  FROM order_items oi
  LEFT JOIN line_costs lc
    ON lc.order_id = oi.order_id
   AND lc.order_item_id = oi.order_item_id
   AND lc.order_date = oi.order_date
)

-- 7) Compare before vs after the change (2017-04-01)
SELECT
    CASE WHEN order_date < '2017-04-01' THEN 'pre' ELSE 'post' END AS period,
    COUNT(*)                              AS lines,
    SUM(line_revenue)                     AS total_revenue,
    SUM(line_cost)                        AS total_cost,
    SUM(line_revenue) - SUM(line_cost)    AS total_margin,
    AVG(line_revenue)                     AS avg_revenue_per_line,
    AVG(line_cost)                        AS avg_cost_per_line,
    AVG(line_revenue - line_cost)         AS avg_margin_per_line
FROM line_agg
GROUP BY 1
ORDER BY period;
```

</details>