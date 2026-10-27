"""
run_pipeline.py
---------------
Runs the whole analysis from raw CSVs to results, in one command:

    python scripts/run_pipeline.py

Steps
  1. Build staging tables, star schema and data-quality checks (sql/01-03)
  2. Run every business question in sql/04_analysis.sql
  3. Save each result to outputs/<name>.csv and all of them to outputs/analysis_results.xlsx
  4. Export the star schema to data/processed/ as CSV for Power BI
  5. Draw the charts (scripts/make_charts.py)

Run it from the repository root. Needs: duckdb, pandas, openpyxl, matplotlib.
"""
import re
import sys
from pathlib import Path

import duckdb
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
SQL = ROOT / "sql"
OUT = ROOT / "outputs"
PROCESSED = ROOT / "data" / "processed"
DB_PATH = ROOT / "data" / "olist.duckdb"

STAR_TABLES = ["fact_orders", "fact_order_items", "dim_customer",
               "dim_seller", "dim_product", "dim_date"]


def check_raw_data():
    needed = ["olist_orders_dataset.csv", "olist_order_items_dataset.csv",
              "olist_order_reviews_dataset.csv", "olist_customers_dataset.csv",
              "olist_sellers_dataset.csv", "olist_products_dataset.csv",
              "product_category_name_translation.csv"]
    missing = [f for f in needed if not (ROOT / "data" / "raw" / f).exists()]
    if missing:
        sys.exit("Missing raw files in data/raw/: " + ", ".join(missing) +
                 "\nDownload them first - see data/README.md")


def split_named_queries(sql_text):
    """Split 04_analysis.sql into {name: query} using '-- name: x' markers."""
    parts = re.split(r"^-- name:\s*(\w+)\s*$", sql_text, flags=re.MULTILINE)
    # parts = [header, name1, body1, name2, body2, ...]
    return {parts[i]: parts[i + 1].strip().rstrip(";") for i in range(1, len(parts), 2)}


def main():
    check_raw_data()
    OUT.mkdir(exist_ok=True)
    PROCESSED.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect(str(DB_PATH))
    # The SQL uses paths relative to the repo root
    import os
    os.chdir(ROOT)

    print("1/5  Building staging, star schema and data-quality checks")
    for f in ["01_staging.sql", "02_star_schema.sql", "03_data_quality.sql"]:
        con.execute((SQL / f).read_text())
    con.sql("SELECT * FROM dq_results").df().to_csv(OUT / "data_quality_checks.csv", index=False)

    print("2/5  Running business questions (04) and early-warning backtest (05)")
    results = {}
    for f in ["04_analysis.sql", "05_early_warning_backtest.sql"]:
        text = (SQL / f).read_text()
        setup = re.split(r"^-- name:", text, maxsplit=1, flags=re.MULTILINE)[0]
        con.execute(setup)  # tables a file builds before its named queries
        for name, q in split_named_queries(text).items():
            results[name] = con.sql(q).df()
            print(f"     {name:28s} {len(results[name]):>4} rows")

    print("3/5  Saving results")
    for name, df in results.items():
        df.to_csv(OUT / f"{name}.csv", index=False)
    with pd.ExcelWriter(OUT / "analysis_results.xlsx", engine="openpyxl") as xw:
        con.sql("SELECT * FROM dq_results").df().to_excel(xw, sheet_name="data_quality", index=False)
        for name, df in results.items():
            df.to_excel(xw, sheet_name=name[:31], index=False)
            ws = xw.sheets[name[:31]]
            for col in ws.columns:  # readable column widths
                width = max(len(str(c.value)) if c.value is not None else 0 for c in col)
                ws.column_dimensions[col[0].column_letter].width = min(max(width + 2, 10), 50)

    print("4/5  Exporting star schema for Power BI -> data/processed/")
    for t in STAR_TABLES:
        con.sql(f"SELECT * FROM {t}").df().to_csv(PROCESSED / f"{t}.csv", index=False)

    con.close()

    print("5/5  Drawing charts")
    sys.path.insert(0, str(Path(__file__).parent))
    import make_charts
    make_charts.main()

    print("\nDone. Results in outputs/, charts in charts/, Power BI tables in data/processed/")


if __name__ == "__main__":
    main()
