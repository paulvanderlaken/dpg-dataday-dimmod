# Exercise 1: From One Big Table to a Star for “Jaffle Shop”

In your **new job**, you are responsible for all **reporting and analytics** for Jaffle Shop. 

Your **predecessor** was not very good at his job. 
He leveraged **one big table** (`CORE.JAFFLE_SHOP.FULL_TABLE`) for every analysis and report that he was asked to do.

You want to introduce some **self-service analytics** for your users, and are thinking about exposing the data using the company's **BI** software. 

You know that you'll first have to **redesign the data model**. This will make it a lot easier to develop a BI front-end that is maintainable, scalable, correct, and user-friendly.

## How to start?
As part of this exercise, you'll need to perform the **following steps**:
1) Design the new data model in .dbml format using [DB diagram](https://dbdiagram.io/d). 
  * Copy over the [starting_point.dbml] for a quick start. 
2) Seperate the dimension tables from `CORE.JAFFLE_SHOP.FULL_TABLE` 
3) Seperate the fact table(s) from `CORE.JAFFLE_SHOP.FULL_TABLE` 
* Optional: use a bridge or a second fact table to achieve a higher-level grain for your main fact table.
* Optional: add views on top for easy analysis and common aggregates

There are **two ways** to complete this assignment. 

### Best appraoch: Try it yourself!
First, you should **attempt** to complete the steps above **yourself**. 

You'll learn most, even if you struggle a bit.

You can always ask a neighboring colleague or one of the assistants for help.

### Alternative approach: Follow the guided steps below.
If you get stuck or know you'll need some extra assistance, you can opt to follow the steps below.

However, try not to peek at the answers too quickly. 

At the end, you will still be challenged to extend the model without supervision. 

## 0) Create a schema.
We will be creating our own Star schema tables, and we'll need some place to store them.

Try to create a new schema in the database that has been set up for you.

Copy the code below into Snowflake and replace the [YOUR_NAME] with your database name.

```sql
CREATE SCHEMA IF NOT EXISTS [YOUR_NAME].JAFFLE_SHOP;
```

## 1) Explore the grain of the dataset
We're looking at a rather large transactional dataset of our Jaffle shop.

Can you spot the different entities that are represented in the dataset? How many distinct ids are there for each?

And most importantly, what level of granularity is this dataset at?

> Hint: You can use `COUNT(DISTINCT id) AS distinct_id` to quickly count unique values per column. 

<details>
  <summary>Possible Solution</summary>

```sql
SELECT
  COUNT(*)                             AS obt_rows,
  COUNT(DISTINCT order_item_id)        AS distinct_order_item_id,
  COUNT(DISTINCT order_id)             AS distinct_order_id,
  COUNT(DISTINCT customer_id)          AS distinct_customer_id,
  COUNT(DISTINCT product_sku)          AS distinct_product_sku,
  COUNT(DISTINCT supply_id)            AS distinct_supply_id,
FROM CORE.JAFFLE_SHOP.FULL_TABLE;
```
</details>

While you might think the dataset is at the level of `order_item_id`, these do not seem to be unique. 

Try reasoning what the following query results tells you:
```sql
SELECT 
    id_count,
    COUNT(*) as count 
FROM (
    SELECT 
        order_item_id, 
        COUNT(*) AS id_count
    FROM CORE.JAFFLE_SHOP.FULL_TABLE
    GROUP BY order_item_id
)
GROUP BY id_count
ORDER BY id_count;
```

### Building a database diagram.
This would be a great point to start building out your conceptual knowledge of the dataset and turning it into a conceptual diagram.

[DB diagram](https://dbdiagram.io/d) is a great tool for doing just that. 

You can use the [starting_point.dbml](dbml\starting_point.dbml) and copy its contents straight over into the [DB diagram](https://dbdiagram.io/d) web interface. The starting_point.dbml code represents the current FULL_TABLE -- a great starting point to start seperating out your entities/dimensions. 

You can work on .dbml files in any text editor, and if you remember to save them as .dbml, tools like VSCode even offer nice plugins for visualization.



## 2) Identifying the entities (Shaping Level-0 Dimensions)
With the grain clarified as (order_item_id, supply_id), you’re now ready to get modeling. 

Your job is to pull clean, stable descriptions of the business entities from the OBT so our future fact table can reference them without dragging along noisy attributes.

Your dimensions should hold the who/what/where.

Here's an example of the SQL code to generate a `DIM_CUSTOMER` table based off our one big table. Please copy paste this code and use it as a starting point for the work to come.

```sql
-- DIM_CUSTOMER (PK = customer_id)
CREATE OR REPLACE TABLE [YOUR_NAME].JAFFLE_SHOP.DIM_CUSTOMER AS
SELECT DISTINCT
    customer_id,
    customer_name
FROM CORE.JAFFLE_SHOP.FULL_TABLE;

ALTER TABLE [YOUR_NAME].JAFFLE_SHOP.DIM_CUSTOMER
  ADD CONSTRAINT PK_DIM_CUSTOMER PRIMARY KEY (customer_id);
```

> Note: Please change `[YOUR_NAME]` to the appropriate database name, and ensure you've added the schema as per [0)]()

> Note: While it serves mostly information purposes in Snowflake, it's good practice to set the keys (primary+foreign) of any table you create. Understanding tables' keys is essential to avoid data duplication later on.

Now it's your turn.

Create the following **Level-0 dimension** tables (no history, one row per business key) 

* `DIM_PRODUCT` (by product_sku)
* `DIM_STORE` (by store_id)
* `DIM_SUPPLY` (by supply_id)

> Note: some attributes are prone to frequent changes (like `product_price`) and arguably less suited for (slowly changing) dimension tables. <br>
> At times, these would be part of the fact table instead. <br>
> For now, draw all attributes into the dimensional tables as we know they are stable.


<details>
  <summary>Possible Solution</summary>

DIM_PRODUCT: 
```sql
-- DIM_PRODUCT (PK = product_sku)
CREATE OR REPLACE TABLE [YOUR_NAME].JAFFLE_SHOP.DIM_PRODUCT AS
SELECT DISTINCT
    product_sku,
    product_name,
    product_type,
    product_price,
    product_description
FROM CORE.JAFFLE_SHOP.FULL_TABLE;

ALTER TABLE [YOUR_NAME].JAFFLE_SHOP.DIM_PRODUCT
  ADD CONSTRAINT PK_DIM_PRODUCT PRIMARY KEY (product_sku);
```

DIM_STORE
```sql
-- DIM_STORE (PK = store_id)
CREATE OR REPLACE TABLE [YOUR_NAME].JAFFLE_SHOP.DIM_STORE AS
SELECT DISTINCT
    store_id,
    store_name,
    store_opened_at,
    store_tax_rate
FROM CORE.JAFFLE_SHOP.FULL_TABLE;

ALTER TABLE [YOUR_NAME].JAFFLE_SHOP.DIM_STORE
  ADD CONSTRAINT PK_DIM_STORE PRIMARY KEY (store_id);
```

DIM_SUPPLY:
```sql
-- DIM_SUPPLY (PK = supply_id)
CREATE OR REPLACE TABLE [YOUR_NAME].JAFFLE_SHOP.DIM_SUPPLY AS
SELECT DISTINCT
    supply_id,
    supply_name,
    supply_cost,
    supply_perishable
FROM CORE.JAFFLE_SHOP.FULL_TABLE;

ALTER TABLE [YOUR_NAME].JAFFLE_SHOP.DIM_SUPPLY
  ADD CONSTRAINT PK_DIM_SUPPLY PRIMARY KEY (supply_id);
```

> Note: Please change `[YOUR_NAME]` to the appropriate database name, and ensure you've added the schema as per [0)]()

</details>

Check your database to see whether you now have all four level-0 dimension tables in the `JAFFLE_SHOP` schema. 

Your dimensions should be stable and even hold pricing attributes (`product_price`, `supply_cost`) by design. Nice!

You're good to continue!

<br>

> Note: If you want a challenge, you can think about how to build a `DIM_DATE` table in Snowflake SQL, as this requires slightly more engineering, since you don't want to do this based off observational data/transactions.

## 3) Building the Fact at Line+Supply Grain
You've now cast your characters (i.e. dimensions) and decided that each scene in our story is a single order line paired with a supply item: the grain is (order_item_id, supply_id). 

Now we'll build the fact table as a clean stage: keys, timestamps, and minimal context. No further attributes are needed as we can draw everything we know about the characters in by design.

We'll keep it ultra-simple: Build a fact at grain (order_item_id, supply_id) and create a single-column record ID that encodes that composite key. Foreign keys point to your natural-key dimensions.

1) Create `FACT_SUPPLY_ORDER_ITEMS` at grain (`order_item_id`, `supply_id`) with a composite record ID column.
2) Keep only foreign keys + line context (e.g., `order_id`, `order_datetime`).
3) Make the new record ID the primary key.
4) (Optional) Add plain foreign keys to dims (informational).
5) (Optional) Add a clustering key to help time- and product/store-filtered queries.

> Hints: <br>
> A readable composite ID is fine: '<order_item_id>|<supply_id>'. <br>
> You can always switch the ID to a hash later (e.g., `MD5(...)`) without changing the table grain.
> While the current data is clean, were you to expect messy source data, you'd need to add a `WHERE order_item_id IS NOT NULL AND supply_id IS NOT NULL`. <br>


<details>
  <summary>Possible Solution</summary>

```sql
CREATE OR REPLACE TABLE [YOUR_NAME].JAFFLE_SHOP.FACT_SUPPLY_ORDER_ITEMS
CLUSTER BY (order_datetime, store_id, product_sku, supply_id) AS
SELECT
    -- Composite record ID
    TO_VARCHAR(order_item_id) || '|' || TO_VARCHAR(supply_id) AS supply_order_item_id,

    -- Natural keys and context
    order_item_id,
    order_id,
    customer_id,
    product_sku,
    store_id,
    supply_id,
    order_datetime
FROM CORE.JAFFLE_SHOP.FULL_TABLE
WHERE order_item_id IS NOT NULL
  AND supply_id     IS NOT NULL;

-- Make the new composite ID the primary key (informational in Snowflake)
ALTER TABLE [YOUR_NAME].JAFFLE_SHOP.FACT_SUPPLY_ORDER_ITEMS
  ADD CONSTRAINT PK_FACT_SUPPLY_ORDER_ITEMS PRIMARY KEY (supply_order_item_id);
```

It would be good practice to also explicitly define the foreign key relationships:
```sql
-- One constraint per statement (Snowflake requirement)
ALTER TABLE [YOUR_NAME].JAFFLE_SHOP.FACT_SUPPLY_ORDER_ITEMS
  ADD CONSTRAINT FK_FOI_CUST
  FOREIGN KEY (customer_id)
  REFERENCES [YOUR_NAME].JAFFLE_SHOP.DIM_CUSTOMER(customer_id) NOT ENFORCED;

ALTER TABLE [YOUR_NAME].JAFFLE_SHOP.FACT_SUPPLY_ORDER_ITEMS
  ADD CONSTRAINT FK_FOI_PROD
  FOREIGN KEY (product_sku)
  REFERENCES [YOUR_NAME].JAFFLE_SHOP.DIM_PRODUCT(product_sku) NOT ENFORCED;

ALTER TABLE [YOUR_NAME].JAFFLE_SHOP.FACT_SUPPLY_ORDER_ITEMS
  ADD CONSTRAINT FK_FOI_STORE
  FOREIGN KEY (store_id)
  REFERENCES [YOUR_NAME].JAFFLE_SHOP.DIM_STORE(store_id) NOT ENFORCED;

ALTER TABLE [YOUR_NAME].JAFFLE_SHOP.FACT_SUPPLY_ORDER_ITEMS
  ADD CONSTRAINT FK_FOI_SUPPLY
  FOREIGN KEY (supply_id)
  REFERENCES [YOUR_NAME].JAFFLE_SHOP.DIM_SUPPLY(supply_id) NOT ENFORCED;
```

> Note: Please change `[YOUR_NAME]` to the appropriate database name, and ensure you've added the schema as per [0)]()

</details>

## 4) Putting hte model to work
Your **STAR** is live: a clean fact at grain (order_item_id, product_sku, supply_id) and tidy dimensions with stable price/cost. 

Now we'll use our new data model to answer a common business question using safe aggregations that avoid double counting revenue while correctly summing supply costs.

### Reporting revenue, cost, and markup by store × product type.
The management of our Jaffle Corporation is interested in learning more about the **markup** of our product categories at each of our locations. 

Markup is calculated by taking the **profit** (revenue - costs) as a **ratio** of the total **costs**. 

So for each **store** and each **product type**, calculate the **total revenue** (i.e. prices of sold products) and the **total costs** (i.e. costs of needed supplies) and use these to calculate the **markup**.



<details>
  <summary>Possible Solution</summary>

```sql
WITH
-- Line-level view (one row per order_item_id) to avoid double-counting price
line_fact AS (
  SELECT DISTINCT
    order_item_id,
    order_id,
    customer_id,
    product_sku,
    store_id,
    order_datetime
  FROM [YOUR_NAME].JAFFLE_SHOP.FACT_SUPPLY_ORDER_ITEMS
),

-- Revenue: count price once per order item
rev AS (
  SELECT
    s.store_name,
    p.product_type,
    SUM(p.product_price) AS total_revenue
  FROM line_fact lf
  JOIN [YOUR_NAME].JAFFLE_SHOP.DIM_PRODUCT p  USING (product_sku)
  JOIN [YOUR_NAME].JAFFLE_SHOP.DIM_STORE   s  USING (store_id)
  GROUP BY 1,2
),

-- Cost: sum across supplies (uses full grain)
cst AS (
  SELECT
    s.store_name,
    p.product_type,
    SUM(u.supply_cost) AS total_cost
  FROM [YOUR_NAME].JAFFLE_SHOP.FACT_SUPPLY_ORDER_ITEMS f
  JOIN [YOUR_NAME].JAFFLE_SHOP.DIM_SUPPLY  u USING (supply_id)
  JOIN [YOUR_NAME].JAFFLE_SHOP.DIM_PRODUCT p USING (product_sku)
  JOIN [YOUR_NAME].JAFFLE_SHOP.DIM_STORE   s USING (store_id)
  GROUP BY 1,2
)

SELECT
  r.store_name,
  r.product_type,
  r.total_revenue,
  c.total_cost,
  r.total_revenue - c.total_cost AS total_profit,
  (r.total_revenue - c.total_cost) / total_cost AS markup
FROM rev r
FULL OUTER JOIN cst c
  ON r.store_name   = c.store_name
 AND r.product_type = c.product_type
ORDER BY store_name, total_profit DESC;

```

> Note: Please change `[YOUR_NAME]` to the appropriate database name, and ensure you've added the schema as per [0)]()

</details>



## 5) Next steps 
You might have noticed that it was still less than straightfoward to use your new **STAR** to do basic analytics. 

The current grain (order_item_id, product_sku, supply_id) seems just misaligned with the main type of questions one might ask. 

Can you consider how to enhance this current Star schema to improve the user experience?

* How would you redesign the schema? Start by trying to improve your original design in [dbdiagram.io](dbdiagram.io)?
    * Would another fact table help?
    * Do you need to snowflake out?
    * Or would building a ["bridge" table](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/multivalued-dimension-bridge-table/) be a better solution?
* Can you implement this new redesign in code?
* Can you put views on top to simplify the most basic calculations, or even pre-calculate revelant aggregations?


<details>
  <summary>Possible Solution</summary>

Have a look at the [example_star_bridge.dbml] or the [example_galaxy.dbml] for possible solutions.
Copy these over into [dbdiagram.io](dbdiagram.io) to see what they look like.

</details>
