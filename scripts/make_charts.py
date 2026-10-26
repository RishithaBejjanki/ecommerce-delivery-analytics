"""
make_charts.py
--------------
Draws the README charts from the CSVs in outputs/ (run run_pipeline.py first).
Every number on a chart comes from a saved result file, so charts and README
always agree.
"""
from pathlib import Path

import duckdb
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "outputs"
CHARTS = ROOT / "charts"

# Palette: one emphasis colour for "late / problem", one for "normal", grey for context
BLUE = "#2a78d6"     # normal / on time
ORANGE = "#eb6834"   # late / problem
AQUA = "#1baf7a"     # third stage colour
GREY = "#b9b8b2"
INK = "#0b0b0b"
INK2 = "#52514e"
GRID = "#e6e5e0"

plt.rcParams.update({
    "font.family": "DejaVu Sans", "font.size": 11,
    "axes.edgecolor": GRID, "axes.labelcolor": INK2, "axes.titlecolor": INK,
    "axes.titlesize": 14, "axes.titleweight": "bold", "axes.titlelocation": "left",
    "axes.spines.top": False, "axes.spines.right": False,
    "xtick.color": INK2, "ytick.color": INK2,
    "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.8,
    "figure.facecolor": "white", "axes.facecolor": "white",
    "savefig.dpi": 150, "savefig.bbox": "tight",
})


def subtitle(ax, text):
    ax.text(0, 1.02, text, transform=ax.transAxes, color=INK2, fontsize=10.5, va="bottom")


def save(fig, name):
    fig.savefig(CHARTS / name)
    plt.close(fig)
    print(f"     charts/{name}")


def chart_monthly_trend():
    df = pd.read_csv(OUT / "q02_monthly_trend.csv")
    df["date"] = pd.to_datetime(df["year_month"])
    avg = pd.read_csv(OUT / "q01_headline_kpis.csv")["late_pct"].iloc[0]
    fig, ax = plt.subplots(figsize=(10, 4.6))
    for start, end in [("2017-10-15", "2017-12-15"), ("2018-01-15", "2018-03-15")]:
        ax.axvspan(pd.Timestamp(start), pd.Timestamp(end), color=ORANGE, alpha=0.08, lw=0)
    ax.axhline(avg, color=GREY, lw=1.2, ls="--")
    ax.text(df["date"].iloc[0], avg + 0.4, f"Average {avg:.1f}%", color=INK2, fontsize=9.5)
    ax.plot(df["date"], df["late_pct"], color=ORANGE, lw=2.2, marker="o", ms=5,
            markeredgecolor="white", markeredgewidth=1.2)
    peak = df.loc[df["late_pct"].idxmax()]
    ax.annotate(f"{peak.late_pct:.1f}% ({peak.date:%b %Y})", (peak.date, peak.late_pct),
                xytext=(10, 2), textcoords="offset points", color=INK, fontsize=10)
    nov = df[df["year_month"] == "2017-11"].iloc[0]
    ax.annotate(f"Black Friday {nov.late_pct:.1f}%", (nov.date, nov.late_pct),
                xytext=(-40, 12), textcoords="offset points", color=INK, fontsize=10)
    ax.set_ylabel("Orders delivered late (%)")
    ax.set_ylim(0, df["late_pct"].max() * 1.2)
    ax.set_title("Late deliveries spike in two windows", pad=24)
    subtitle(ax, "Share of delivered orders arriving after the promised date, by purchase month")
    ax.grid(axis="x", visible=False)
    save(fig, "01_monthly_late_trend.png")


def chart_reviews():
    df = pd.read_csv(OUT / "q03_review_by_lateness.csv")
    labels = [b.split(". ")[1] for b in df["lateness_bucket"]]
    colors = [BLUE] + [ORANGE] * (len(df) - 1)
    fig, ax = plt.subplots(figsize=(8.5, 4.4))
    bars = ax.bar(labels, df["avg_review_score"], color=colors, width=0.6)
    for b, v, o in zip(bars, df["avg_review_score"], df["one_star_pct"]):
        ax.text(b.get_x() + b.get_width() / 2, v + 0.08, f"{v:.2f}", ha="center",
                color=INK, fontsize=11, fontweight="bold")
        ax.text(b.get_x() + b.get_width() / 2, 0.15, f"{o:.0f}% 1-star", ha="center",
                color="white", fontsize=9.5)
    ax.set_ylim(0, 5)
    ax.set_ylabel("Average review score (1-5)")
    ax.set_title("Every extra day late costs review stars", pad=24)
    subtitle(ax, "Average review score and share of 1-star reviews, by how late the order arrived")
    ax.grid(axis="x", visible=False)
    save(fig, "02_review_by_lateness.png")


def chart_stages():
    df = pd.read_csv(OUT / "q05_stage_breakdown.csv").set_index("outcome").loc[["On time", "Late"]]
    stages = [("approval_days", "Payment approval", GREY),
              ("seller_handling_days", "Seller handling", BLUE),
              ("carrier_transit_days", "Carrier transit", ORANGE)]
    fig, ax = plt.subplots(figsize=(10, 3.6))
    left = [0, 0]
    for col, name, c in stages:
        vals = df[col].values
        ax.barh(df.index, vals, left=left, color=c, height=0.55, label=name,
                edgecolor="white", linewidth=2)
        for i, (l, v) in enumerate(zip(left, vals)):
            if v >= 2:
                ax.text(l + v / 2, i, f"{v:.1f}d", ha="center", va="center", color="white",
                        fontsize=10, fontweight="bold")
        left = [l + v for l, v in zip(left, vals)]
    for i, p in enumerate(df["promised_days"]):
        ax.plot([p, p], [i - 0.34, i + 0.34], color=INK, lw=2)
        ax.text(p + 0.4, i - 0.30, f"promised {p:.0f}d", ha="left", va="center",
                color=INK, fontsize=9, bbox=dict(facecolor="white", edgecolor="none", pad=1))
    ax.set_xlabel("Average days from purchase")
    ax.set_ylim(-0.6, 1.6)
    ax.invert_yaxis()
    ax.legend(loc="lower left", frameon=False, ncol=3, bbox_to_anchor=(0, -0.45))
    ax.set_title("Late orders lose most of their time in carrier transit", pad=24)
    subtitle(ax, "Average days spent in each stage, on-time vs late orders")
    ax.grid(axis="y", visible=False)
    save(fig, "03_stage_breakdown.png")


def chart_regions():
    df = pd.read_csv(OUT / "q07_region_performance.csv").sort_values("late_pct")
    avg = pd.read_csv(OUT / "q01_headline_kpis.csv")["late_pct"].iloc[0]
    colors = [ORANGE if v > avg * 1.5 else BLUE for v in df["late_pct"]]
    fig, ax = plt.subplots(figsize=(8.5, 3.8))
    bars = ax.barh(df["customer_region"], df["late_pct"], color=colors, height=0.6)
    for b, v, n in zip(bars, df["late_pct"], df["orders"]):
        ax.text(v + 0.2, b.get_y() + b.get_height() / 2, f"{v:.1f}%  ({n:,} orders)",
                va="center", color=INK, fontsize=10)
    ax.axvline(avg, color=GREY, ls="--", lw=1.2)
    ax.set_xlim(0, df["late_pct"].max() * 1.45)
    ax.set_xlabel("Orders delivered late (%)")
    ax.set_title("The Northeast is late twice as often as the Southeast", pad=24)
    subtitle(ax, f"Late-delivery rate by customer region (dashed line = platform average {avg:.1f}%)")
    ax.grid(axis="y", visible=False)
    save(fig, "04_region_late_rate.png")


def chart_sla():
    df = pd.read_csv(OUT / "q06_seller_sla_effect.csv")
    df = df.set_index("seller_sla").loc[["Seller shipped on time", "Seller missed ship-by date"]]
    fig, ax = plt.subplots(figsize=(8, 3.4))
    bars = ax.barh(df.index, df["late_pct"], color=[BLUE, ORANGE], height=0.55)
    for b, v, n in zip(bars, df["late_pct"], df["orders"]):
        ax.text(v + 0.3, b.get_y() + b.get_height() / 2, f"{v:.1f}% late  ({n:,} orders)",
                va="center", color=INK, fontsize=10)
    ax.set_xlim(0, df["late_pct"].max() * 1.6)
    ax.invert_yaxis()
    ax.set_xlabel("Orders delivered late (%)")
    ratio = df["late_pct"].iloc[1] / df["late_pct"].iloc[0]
    ax.set_title(f"A missed seller hand-off makes lateness {ratio:.1f}x likelier", pad=24)
    subtitle(ax, "Late-delivery rate by whether the seller met the ship-by deadline")
    ax.grid(axis="y", visible=False)
    save(fig, "05_seller_sla_effect.png")


def chart_pareto():
    con = duckdb.connect(str(ROOT / "data" / "olist.duckdb"), read_only=True)
    df = con.sql("""
        SELECT primary_seller_id, COUNT(*) FILTER (WHERE is_late) AS late
        FROM fact_orders WHERE in_analysis GROUP BY 1 ORDER BY late DESC
    """).df()
    con.close()
    df["cum_share"] = df["late"].cumsum() / df["late"].sum() * 100
    df["seller_pct"] = (range(1, len(df) + 1))
    df["seller_pct"] = df["seller_pct"] / len(df) * 100
    s = pd.read_csv(OUT / "q11_seller_concentration.csv").iloc[0]
    fig, ax = plt.subplots(figsize=(8.5, 4.4))
    ax.plot(df["seller_pct"], df["cum_share"], color=ORANGE, lw=2.2)
    ax.plot([0, 100], [0, 100], color=GREY, ls="--", lw=1)
    ax.text(62, 55, "if lateness were\nspread evenly", color=INK2, fontsize=9.5)
    x50 = s["pct_of_sellers_50"]
    ax.scatter([x50], [50], s=60, color=ORANGE, edgecolor="white", linewidth=2, zorder=3)
    ax.annotate(f"{int(s['sellers_for_50pct_of_late'])} sellers ({x50:.1f}% of all)\n= half of all late orders",
                (x50, 50), xytext=(14, -28), textcoords="offset points", color=INK, fontsize=10)
    ax.set_xlim(0, 100); ax.set_ylim(0, 102)
    ax.set_xlabel("% of sellers (ranked by late orders)")
    ax.set_ylabel("Cumulative % of late orders")
    ax.set_title("Late orders are concentrated in a few sellers", pad=24)
    subtitle(ax, "Cumulative share of late orders by seller")
    save(fig, "06_seller_concentration.png")


def main():
    CHARTS.mkdir(exist_ok=True)
    chart_monthly_trend()
    chart_reviews()
    chart_stages()
    chart_regions()
    chart_sla()
    chart_pareto()


if __name__ == "__main__":
    main()
