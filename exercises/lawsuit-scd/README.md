# Exercise 2: The Jaffle hits the fan when dimensions come changing
It’s 2017 and Jaffle Shop is in hot water.

> _NEWS HEADLINE_: <br>**Ferrero Roche sues Jaffle Shop!**

 Ferrero sued us for selling a Jaffle dubbed the _nutellaphone_. 
 
 After reviewing the case, our Legal department suggests a simple rename to _"chocophone"_ effective 2017-01-01. 
 
 A well-meaning analyst "fixed" the history by overwriting `product_name` in the orders OBT (`CORE.JAFFLE_SHOP.FULL_TABLE_SCD`) from that date onward for the affected SKU.

Meanwhile, PR turns up an older issue: German tourists complained about our Jaffle _"the krautback"_ (`product_sku` = 'JAF-003'). 

We quietly rebranded it to _"sourbun"_ on the 10th of February 2017-02 . Finance now needs historically correct reporting and legal discovery. You have been tasked to build the dimensional model to succeed where naïve approaches fail. You'll need to construct a proper SCD2 dimension where names are valid as-of dates.

## 0) Failing with a type 0 dimension table.

With slowly changing dimension [type 0](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/type-0/), the dimension attribute value never changes, so facts are always grouped by this original value. 

Let's observe how this approach would fail in our case.

Using a `DISTINCT` try and construct a simple type-0 dimension table for the _"jaffle"_ `product_type` products. It should become immediately clear what the issue is and what data modelling and backfilling is still needed.

> Bonus: add the first and last seen date per product and order by first_seen_date within products.


<details>
  <summary>Possible Solution</summary>

```sql
-- First/last sighting of each (sku, name) in facts
WITH sightings AS (
  SELECT
    product_sku,
    product_name,
    MIN(CAST(order_datetime AS DATE)) AS first_seen_date,
    MAX(CAST(order_datetime AS DATE)) AS last_seen_date
  FROM CORE.JAFFLE_SHOP.FULL_TABLE_SCD
  WHERE product_type = 'jaffle'
  GROUP BY 1,2
)
SELECT *
FROM sightings
ORDER BY product_sku, first_seen_date;
```

</details>


## 00) Failing with a type 1 dimension table

Your colleague suggests you just derive a [type 1](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/type-1/) dimension table from the full table. 

With slowly changing dimension type 1, the old attribute value in the dimension row is overwritten with the new value.

Can you already guess the main issue with these kind of tables?

* Create a type-1 dimension table under `[YOUR_NAME].JAFFLE_SHOP_SCD2.DIM_PRODUCT_L1`
* Load only columns `product_sku`, `product_name`, and `product_type`
* Ensure that you save only the last observation per SKU. 

<details>
  <summary>Possible Solution</summary>

```sql
CREATE SCHEMA IF NOT EXISTS [YOUR_NAME].JAFFLE_SHOP_SCD2;

CREATE OR REPLACE TABLE [YOUR_NAME].JAFFLE_SHOP_SCD2.DIM_PRODUCT_L1 AS
SELECT product_sku, product_name, product_type
FROM (
  SELECT
    product_sku,
    product_name,
    product_type,
    ROW_NUMBER() OVER (PARTITION BY product_sku ORDER BY order_datetime DESC) AS rn
  FROM CORE.JAFFLE_SHOP.FULL_TABLE_SCD
)
WHERE rn = 1;
```

> Note: Change [YOUR_NAME] to your assigned database name.

</details>
<br>
To assess the financial risk the lawsuit represents, your legal team has asked you what the **total revenue** (i.e. the sum of prices of sold SKUs) has been before the rename on Jan 1st 2017.

Would you be able to derive those using your new type-1 dimension table `[YOUR_NAME].JAFFLE_SHOP_SCD2.DIM_PRODUCT_L1`?

Treat the `CORE.JAFFLE_SHOP.FULL_TABLE_SCD` as facts table. Feel free to filter for just Jaffle products.

> Note: Remember that the full table is at the order_item_id x supply_id level, and you'll need to deduplicate.

<details>
  <summary>Possible Solution</summary>

```sql
SELECT 
    io.product_sku, 
    l1.product_name, 
    sum(io.product_price) as total_revenue
    FROM (
        -- Remember to first get the unique orders (and deduplicate for supply items)
        SELECT DISTINCT order_item_id, product_sku, product_price
        FROM CORE.JAFFLE_SHOP.FULL_TABLE_SCD
    ) as io
    LEFT JOIN [YOUR_NAME].JAFFLE_SHOP_SCD2.DIM_PRODUCT_L1 as l1
    ON l1.product_sku = io.product_sku
    WHERE l1.product_type = 'jaffle'
    GROUP BY io.product_sku, l1.product_name;
```
> Note: Change [YOUR_NAME] to your assigned database name.

</details>

## 1) Reconstructing dimensions from observations. 
Let's start with what we can observe.

Your job (for now): derive change points only from the data you can observe (first seen dates in orders), and materialize a clean SCD2 dimension with:
* `valid_from_date` and exclusive `valid_to_date_excl`
* one current row (`is_current = TRUE`) per product_sku
* a sequence-based surrogate key

Let's start by running the following code to create a schema:
```sql
-- Replace [YOUR_NAME] with the assigned database
CREATE SCHEMA IF NOT EXISTS [YOUR_NAME].JAFFLE_SHOP_SCD2;
```
Now, let's turn our attention to the latter point of our to-do list: creating the sequence-based surrogate key.

```sql
-- Replace [YOUR_NAME] with the assigned database
CREATE SEQUENCE IF NOT EXISTS [YOUR_NAME].JAFFLE_SHOP_SCD2.SEQ_DIM_PRODUCT START = 1 INCREMENT = 1;
```
Okay, now everything is set an we'll construct the type-2 dimension table in the following steps. 
1) Create temporary table with `valid_from_date` (first date seen per (`sku`, `name`))
2) Create temporary table with exclusive end dates by `LEAD`ing over the `valid_from_date` of step 1.
3) Create table with sequence as surrogate key, and boolean is_current for where the exclusive end date is missing.

Feel free to look at the code examples and copy them over if you get stuck.


<details>
  <summary>Possible Solution: step 1</summary>

```sql
USE DATABASE [YOUR_NAME];

CREATE OR REPLACE TEMP TABLE _first_seen AS
SELECT
  product_sku,
  product_name,
  MIN(CAST(order_datetime AS DATE)) AS valid_from_date
FROM CORE.JAFFLE_SHOP.FULL_TABLE_SCD
GROUP BY 1,2;
```

> Note: Replace [YOUR_NAME] with your assigned database.

</details>

<details>
  <summary>Possible Solution: step 2</summary>

```sql
CREATE OR REPLACE TEMP TABLE _ranged AS
SELECT
  product_sku,
  product_name,
  valid_from_date,
  LEAD(valid_from_date) OVER (
    PARTITION BY product_sku
    ORDER BY valid_from_date
  ) AS valid_to_date_excl
FROM _first_seen;
```

> Note: This will only run if you assigned a database like in the step 1 example code.

</details>

<details>
  <summary>Possible Solution: step 3</summary>

```sql
CREATE OR REPLACE TABLE [YOUR_NAME].JAFFLE_SHOP_SCD2.DIM_PRODUCT AS
SELECT
  [YOUR_NAME].JAFFLE_SHOP_SCD2.SEQ_DIM_PRODUCT.NEXTVAL AS product_key,  -- surrogate key
  product_sku,
  product_name,
  valid_from_date,
  valid_to_date_excl,
  (valid_to_date_excl IS NULL) AS is_current
FROM _ranged;
```

</details>

<details>
  <summary>Possible Solution: full code</summary>

```sql
CREATE SEQUENCE IF NOT EXISTS [YOUR_NAME].JAFFLE_SHOP_SCD2.SEQ_DIM_PRODUCT START = 1 INCREMENT = 1;

USE DATABASE [YOUR_NAME];

CREATE OR REPLACE TEMP TABLE _first_seen AS
SELECT
  product_sku,
  product_name,
  MIN(CAST(order_datetime AS DATE)) AS valid_from_date
FROM CORE.JAFFLE_SHOP.FULL_TABLE_SCD
GROUP BY 1,2;


CREATE OR REPLACE TEMP TABLE _ranged AS
SELECT
  product_sku,
  product_name,
  valid_from_date,
  LEAD(valid_from_date) OVER (
    PARTITION BY product_sku
    ORDER BY valid_from_date
  ) AS valid_to_date_excl
FROM _first_seen;

CREATE OR REPLACE TABLE [YOUR_NAME].JAFFLE_SHOP_SCD2.DIM_PRODUCT AS
SELECT
  [YOUR_NAME].JAFFLE_SHOP_SCD2.SEQ_DIM_PRODUCT.NEXTVAL AS product_key,  -- surrogate key
  product_sku,
  product_name,
  valid_from_date,
  valid_to_date_excl,
  (valid_to_date_excl IS NULL) AS is_current
FROM _ranged;

SELECT * FROM [YOUR_NAME].JAFFLE_SHOP_SCD2.DIM_PRODUCT;

```

> Note: Replace all `[YOUR_NAME]` instances with the assigned database.

</details>



## 2) Ensuring and enforcing reproducibility  
While we did solve for the lawsuit-related rename of the _"chocophone"_ with our latest fix, the German incident was not yet visible in the transactional full table, even though we have been officially using the new name in all our communication.


### Creating a table for `PRODUCT_RENAME_RULES`
It would be good to create a backfilling rule table to seed any legal changeovers and ensure our data can be always made "up-to-date".

Here's what you need to do:
1) Create a table `[YOUR_NAME].JAFFLE_SHOP_SCD2.PRODUCT_RENAME_RULES` with columns `product_sku`, `old_name`, `new_name`, `cutover_date`, and `reason`
2) Insert into this table a record for 'JAF-003', 'the krautback', 'sourbun', '2017-02-10', 'Tourist complaint'
3) Insert into this table a record for 'JAF-001', 'nutellaphone who dis?', 'chocophone', '2017-01-01', 'Ferrero lawsuit'
4) Ensure these inserts can be executed without adding new records so that you have a script your can add to.

<details>
  <summary>Possible Solution</summary>

```sql
CREATE SCHEMA IF NOT EXISTS [YOUR_NAME].JAFFLE_SHOP_SCD2;

CREATE OR REPLACE TABLE [YOUR_NAME].JAFFLE_SHOP_SCD2.PRODUCT_RENAME_RULES (
  product_sku   STRING,
  old_name      STRING,
  new_name      STRING,
  cutover_date  DATE,
  reason        STRING
);

-- 1) German tourist complaint 
INSERT INTO [YOUR_NAME].JAFFLE_SHOP_SCD2.PRODUCT_RENAME_RULES
SELECT 'JAF-003', 'the krautback', 'sourbun', '2017-02-10', 'Tourist complaint'
WHERE NOT EXISTS (
  SELECT 1
  FROM [YOUR_NAME].JAFFLE_SHOP_SCD2.PRODUCT_RENAME_RULES
  WHERE product_sku='JAF-003' AND old_name='the krautback' AND new_name='sourbun' AND cutover_date='2017-02-10'
);

-- 2) Ferrero lawsuit 
INSERT INTO [YOUR_NAME].JAFFLE_SHOP_SCD2.PRODUCT_RENAME_RULES (product_sku, old_name, new_name, cutover_date, reason)
SELECT 'JAF-001', 'nutellaphone who dis?', 'chocophone', '2017-01-01', 'Ferrero lawsuit'
WHERE NOT EXISTS (
  SELECT  1
  FROM [YOUR_NAME].JAFFLE_SHOP_SCD2.PRODUCT_RENAME_RULES
  WHERE product_sku='JAF-001' AND old_name='nutellaphone who dis?' AND new_name='chocophone' AND cutover_date='2017-01-01'
);

```

> Note: Change [YOUR_NAME] to your assigned database name.

</details>
<br>

Great work!

Now all that's left is updating our `DIM_PRODUCT` table based on this ledger of changes.

1) **First**, you **"clamp"** the old_name's `valid_to` at the cutover date (but only if it passes it!).
2) **Next**, you insert the new_name's row starting at exactly the cutover date (if it doesn't yet exist)
3) **Finally**, you nsure only one current row per SKU: If a SKU already had a current row (open-ended) before we inserted, flip it to not current so the newly inserted row is the only current one.

Feel free to look at and copy over the proposed solutions below if you get stuck:


<details>
  <summary>Possible Solution: Step 1</summary>

```sql
-- Clamp the old name’s valid_to to the cutover date (if it extends past it)
UPDATE [YOUR_NAME].JAFFLE_SHOP_SCD2.DIM_PRODUCT d
SET    valid_to_date_excl = r.cutover_date,
       is_current = FALSE
FROM   CORE.JAFFLE_SHOP_SCD2.PRODUCT_RENAME_RULES r
WHERE  d.product_sku = r.product_sku
  AND  LOWER(d.product_name) = LOWER(r.old_name)
  AND  d.valid_from_date < r.cutover_date
  AND  (d.valid_to_date_excl IS NULL OR d.valid_to_date_excl > r.cutover_date);
```
</details>

<details>
  <summary>Possible Solution: Step 2</summary>

```sql
-- Add a new version row at the cutover, open-ended
INSERT INTO [YOUR_NAME].JAFFLE_SHOP_SCD2.DIM_PRODUCT (
  product_key, product_sku, product_name, valid_from_date, valid_to_date_excl, is_current
)
SELECT
  CORE.JAFFLE_SHOP_SCD2.SEQ_DIM_PRODUCT.NEXTVAL,
  r.product_sku,
  r.new_name,
  r.cutover_date,
  NULL,
  TRUE
FROM CORE.JAFFLE_SHOP_SCD2.PRODUCT_RENAME_RULES r
LEFT JOIN [YOUR_NAME].JAFFLE_SHOP_SCD2.DIM_PRODUCT d
  ON  d.product_sku = r.product_sku
  AND LOWER(d.product_name) = LOWER(r.new_name)
  AND d.valid_from_date = r.cutover_date
WHERE d.product_sku IS NULL;   -- only insert if not already present
```
</details>

<details>
  <summary>Possible Solution: Step 3</summary>

```sql
-- For each SKU, keep the latest open-ended row as current, others not current
UPDATE [YOUR_NAME].JAFFLE_SHOP_SCD2.DIM_PRODUCT d
SET    is_current = CASE WHEN d.valid_from_date = x.latest_open_start THEN TRUE ELSE FALSE END
FROM (
  SELECT product_sku,
         MAX(valid_from_date) AS latest_open_start
  FROM [YOUR_NAME].JAFFLE_SHOP_SCD2.DIM_PRODUCT
  WHERE valid_to_date_excl IS NULL
  GROUP BY 1
) x
WHERE d.product_sku = x.product_sku
  AND d.valid_to_date_excl IS NULL;
```
</details>

<details>
  <summary>Possible Solution: full code</summary>

```sql
-- Clamp the old name’s valid_to to the cutover date (if it extends past it)
UPDATE [YOUR_NAME].JAFFLE_SHOP_SCD2.DIM_PRODUCT d
SET    valid_to_date_excl = r.cutover_date,
       is_current = FALSE
FROM   CORE.JAFFLE_SHOP_SCD2.PRODUCT_RENAME_RULES r
WHERE  d.product_sku = r.product_sku
  AND  LOWER(d.product_name) = LOWER(r.old_name)
  AND  d.valid_from_date < r.cutover_date
  AND  (d.valid_to_date_excl IS NULL OR d.valid_to_date_excl > r.cutover_date);


  -- Add a new version row at the cutover, open-ended
INSERT INTO [YOUR_NAME].JAFFLE_SHOP_SCD2.DIM_PRODUCT (
  product_key, product_sku, product_name, valid_from_date, valid_to_date_excl, is_current
)
SELECT
  CORE.JAFFLE_SHOP_SCD2.SEQ_DIM_PRODUCT.NEXTVAL,
  r.product_sku,
  r.new_name,
  r.cutover_date,
  NULL,
  TRUE
FROM CORE.JAFFLE_SHOP_SCD2.PRODUCT_RENAME_RULES r
LEFT JOIN [YOUR_NAME].JAFFLE_SHOP_SCD2.DIM_PRODUCT d
  ON  d.product_sku = r.product_sku
  AND LOWER(d.product_name) = LOWER(r.new_name)
  AND d.valid_from_date = r.cutover_date
WHERE d.product_sku IS NULL;   -- only insert if not already present

-- For each SKU, keep the latest open-ended row as current, others not current
UPDATE [YOUR_NAME].JAFFLE_SHOP_SCD2.DIM_PRODUCT d
SET    is_current = CASE WHEN d.valid_from_date = x.latest_open_start THEN TRUE ELSE FALSE END
FROM (
  SELECT product_sku,
         MAX(valid_from_date) AS latest_open_start
  FROM [YOUR_NAME].JAFFLE_SHOP_SCD2.DIM_PRODUCT
  WHERE valid_to_date_excl IS NULL
  GROUP BY 1
) x
WHERE d.product_sku = x.product_sku
  AND d.valid_to_date_excl IS NULL;
```

</details>

## 3) Report out to finance and legal

With your type-2 slowly changing dimension table now in place, you are all set to **report out** to your **finance and legal** teams.

They want to see how much **revenue** (sum of price of ordered items) each `product_sku` generated under each of their names.

Given that you already put in a lot of effort feel free to directly peak at the solution instead.

If you want to do it yourself, here's some guidance:
1) Get the line item information out of `CORE.JAFFLE_SHOP.FULL_TABLE_SCD`. 
    * You will need to create order dates
    * Also don't forget to select distinct products sold per order_item_id along with their price, and avoid duplicates caused by supply items.
2) Join on your type-2 dim table `JAFFLE_SHOP_SCD2.DIM_PRODUCT`.
    * Ensure that the join happnes only for order dates in the valid_from/*_to period. 
    * Tip: join among others on `(d.valid_to_date_excl IS NULL OR f.order_date < d.valid_to_date_excl)`
3) Calculate the total revenue per (`sku`, `name`) by taking the sum of the prices.


<details>
  <summary>Possible Solution: full code</summary>

```sql
WITH line_items AS (
  SELECT DISTINCT
    CAST(order_datetime as DATE) as order_date,
    order_item_id,
    product_sku,
    product_price
  FROM CORE.JAFFLE_SHOP.FULL_TABLE_SCD
),
dim AS (
  SELECT product_sku, product_name, valid_from_date, valid_to_date_excl
  FROM GOLD.JAFFLE_SHOP_SCD2.DIM_PRODUCT
)
SELECT
  d.product_sku,
  d.product_name,
  SUM(f.product_price) AS total_revenue
FROM line_items f
JOIN dim d
  ON f.product_sku = d.product_sku
 AND f.order_date >= d.valid_from_date
 AND (d.valid_to_date_excl IS NULL OR f.order_date < d.valid_to_date_excl)
GROUP BY 1,2
ORDER BY 1,2;

```
</details>
<br>

**Bonus**: You might notice that you are now reporting on all products, including beverages. The simple way would be to **subset** this report for records that match a certain **string pattern**. Can you make it do just that?

A real engineer would **revisit** all earlier assignments and ensure that `product_type` is included in the dimension table going forward. Are you up for the task?
