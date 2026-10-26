# DAX measures

Create a blank table called **_Measures** (Home → Enter data → name it `_Measures` → Load) and add
these measures to it. Every measure respects the `in_analysis` filter, which is applied once at
page level (see the build guide), so the numbers match `outputs/q01_headline_kpis.csv`.

```dax
Orders = COUNTROWS ( fact_orders )

Late Orders = CALCULATE ( [Orders], fact_orders[is_late] = TRUE () )

Late % = DIVIDE ( [Late Orders], [Orders] )

On-Time % = 1 - [Late %]

GMV = SUM ( fact_orders[order_value] )

Avg Delivery Days = AVERAGE ( fact_orders[delivery_days] )

Avg Promised Days = AVERAGE ( fact_orders[promised_days] )

Avg Handling Days = AVERAGE ( fact_orders[handling_days] )

Avg Transit Days = AVERAGE ( fact_orders[transit_days] )

Avg Review = AVERAGE ( fact_orders[review_score] )

One-Star % =
DIVIDE (
    CALCULATE ( [Orders], fact_orders[review_score] = 1 ),
    CALCULATE ( [Orders], NOT ISBLANK ( fact_orders[review_score] ) )
)

Seller Missed SLA % =
DIVIDE ( CALCULATE ( [Orders], fact_orders[seller_missed_sla] = TRUE () ), [Orders] )

-- Share of all late orders that sit in the current filter (e.g. one state).
-- ALLSELECTED keeps the page/date filters but ignores the visual's own grouping.
Share of Late Orders =
DIVIDE ( [Late Orders], CALCULATE ( [Late Orders], ALLSELECTED ( dim_customer ) ) )

-- Late rate vs the platform average for the same period. Positive = worse than average.
Late % vs Avg (pts) =
[Late %] - CALCULATE ( [Late %], ALLSELECTED ( dim_customer ), ALLSELECTED ( dim_seller ) )

-- Same month last year, for the trend tooltip
Late % LY = CALCULATE ( [Late %], SAMEPERIODLASTYEAR ( dim_date[date] ) )
```

## Calculated column (on fact_orders)
Used for the lateness-bucket chart; matches `outputs/q03_review_by_lateness.csv`.

```dax
Lateness Bucket =
SWITCH (
    TRUE (),
    ISBLANK ( fact_orders[is_late] ), BLANK (),
    fact_orders[is_late] = FALSE (), "0. On time",
    fact_orders[days_late] <= 3, "1. 1-3 days late",
    fact_orders[days_late] <= 7, "2. 4-7 days late",
    "3. 8+ days late"
)
```
