# Data dictionary: reporting model

Built by [`sql/02_star_schema.sql`](../sql/02_star_schema.sql). Exported to `data/processed/` for Power BI.

```
dim_date ──────┐
dim_customer ──┼──< fact_orders (1 row per order) ──< fact_order_items >── dim_product
dim_seller ────┘        (primary_seller_id)                (seller_id) ──── dim_seller
```

## fact_orders: one row per order (99,441 rows; 96,004 with `in_analysis = true`)

| Column | Type | Description |
|---|---|---|
| order_id | text | Primary key |
| customer_id | text | FK → dim_customer |
| order_status | text | delivered, shipped, canceled, … |
| purchase_date | date | FK → dim_date |
| purchased_at / approved_at / shipped_at / delivered_at | timestamp | Order milestones (`shipped_at` = handed to carrier) |
| promised_date | date | Estimated delivery date shown to the customer at checkout |
| primary_seller_id | text | FK → dim_seller. Seller of the highest-priced item |
| item_count, seller_count | int | Lines and distinct sellers on the order |
| items_value, freight_value, order_value | decimal (BRL) | Item total, freight, and the two combined |
| review_score | int 1–5 | Latest review for the order (null if none) |
| approval_days | decimal | Purchase → payment approved |
| handling_days | decimal | Approved → handed to carrier (seller's stage) |
| transit_days | decimal | Handed to carrier → delivered (carrier's stage) |
| delivery_days | decimal | Purchase → delivered (customer's experience) |
| promised_days | int | Purchase date → promised date |
| is_late | bool | Delivered after the promised date |
| days_late | int | Days past the promised date (0 if on time) |
| seller_missed_sla | bool | Handed to carrier after the ship-by deadline |
| same_state | bool | Customer and primary seller in the same state |
| in_analysis | bool | Passes all data-quality rules. **Filter on this.** |

## fact_order_items: one row per item line (112,650 rows)
order_id, order_item_id, product_id (FK → dim_product), seller_id (FK → dim_seller), ship_by_at, price, freight_value

## Dimensions
| Table | Key | Columns |
|---|---|---|
| dim_customer | customer_id | customer_unique_id (the real person; one person can have several customer_ids), city, state, region |
| dim_seller | seller_id | city, state, region |
| dim_product | product_id | category (English), weight_g |
| dim_date | date | year, quarter, month, year_month, month_name, day_of_week |

`region` = Brazil's five official macro-regions (North, Northeast, Central-West, Southeast, South).
