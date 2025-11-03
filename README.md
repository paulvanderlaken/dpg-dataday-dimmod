# DPG Data Day <br> Dimensional Modelling in Snowflake SQL

Welcome to our DPG data day!

Have you ever heard of a **Jaffle**? Well, after today, you'll never forget about them again!

Today, we'll dive into the world of [Snowflake SQL](https://app.snowflake.com/dpgmedia/training/w30cVLPcTb37#query), specifically looking at our [`CORE.JAFFLE_SHOP.FULL_TABLE` data](https://app.snowflake.com/dpgmedia/training/#/data/databases/CORE/schemas/JAFFLE_SHOP/tables). 

This is a terribly designed data table, that I'm sure you are eager to start remodelling. 

Based on your **proficiency** level, you will pick **one of three adventures**, or decide to go form **your own adventure** completely. 
* [Exercise 1](./exercises/exercise1_star.md): **Building a simple STAR**
* [Exercise 2](./exercises/exercise2_scd2-lawsuit.md): **SCD2 to the rescue**
* [Exercise 3](./exercises/exercise3_scd2-bom-bridge.md): **Bridging the Bill of Materials**

Either case, we'll be redesigning this **One Big Table** (OBT) into a **STAR schema**. Some of you might turn it into a **Galaxy**. Others might opt for a **Snowflake**. Some will take a first jab at building **level-0 dimension tables**. Others will move onto **reloadable/reproducible Type-2** dimension tables.
And the really adventureous might even think of some (slowly changing) **bridges** to build!

## Logging into Snowflake:
Go to [dpgmedia-training.snowflakecomputing.com](dpgmedia-training.snowflakecomputing.com
):
* _Username_: `{name}@persgroep.net` (or `{name}@independer.be`)
* _Password_: ask one of the assistants (or check your mail)

Use the [source schema here](https://app.snowflake.com/dpgmedia/training/#/data/databases/CORE/schemas/JAFFLE_SHOP/tables). 

## Designing new schema's / data models
We highly recommend using [dbdiagram.io](https://dbdiagram.io/) for sketching out your database remodels in a reproducible and version-controllable way. 

It leverages `.dbml` files, which present an lightweight, intuitive format to store relatonal database designs. You can copy-paste existing .dbml files straihgt into [dbdiagram.io](https://dbdiagram.io/) to create the diagram the script represents.

Plus, tools like **VSCode** have plugins that allow you do to the same right in your IDE.

> **Test this**: <br> copy the [starting_point.dbml](./dbml/starting_point.dbml) into [dbdiagram.io](https://dbdiagram.io/) to immediately visualize the contents of [`CORE.JAFFLE_SHOP.FULL_TABLE`](https://app.snowflake.com/dpgmedia/training/#/data/databases/CORE/schemas/JAFFLE_SHOP/tables). <br> A great starting point to start your redesign from!


## Resources:
* [Snowflake](https://app.snowflake.com/dpgmedia/training)
* [Source schema in Snowflake catalog](https://app.snowflake.com/dpgmedia/training/#/data/databases/CORE/schemas/JAFFLE_SHOP/tables)
* [Glossary of Kimball terminology](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/)
* [Database Diagram drawing web app](https://dbdiagram.io/) <-- Copy the dbml files of this repo right in.
* [Snowflake optimization best practices](https://select.dev/posts/snowflake-query-optimization#1-select-fewer-columns)