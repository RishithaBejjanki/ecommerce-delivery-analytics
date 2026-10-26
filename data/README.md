# Data

## Source
[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle).
Real, anonymised commercial data: ~100k orders placed 2016–2018 across Brazilian marketplaces.
Licensed CC BY-NC-SA 4.0.

## Setup
1. Download the dataset from the link above (Kaggle account needed) and unzip it.
2. Put the CSV files in `data/raw/`. The pipeline uses these seven:
   - `olist_orders_dataset.csv`
   - `olist_order_items_dataset.csv`
   - `olist_order_reviews_dataset.csv`
   - `olist_customers_dataset.csv`
   - `olist_sellers_dataset.csv`
   - `olist_products_dataset.csv`
   - `product_category_name_translation.csv`
3. Run `python scripts/run_pipeline.py` from the repository root.

The raw and processed files aren't committed (~120 MB). Every result the analysis needs is
saved in `outputs/`, so the repo reads completely without downloading anything.

## Folders
- `raw/`: original Kaggle CSVs, untouched
- `processed/`: star-schema tables exported for Power BI (generated)
