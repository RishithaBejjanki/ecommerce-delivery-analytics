"""
run_uat.py
----------
Executes the automatable UAT cases against the reference rules in risk_rules.py
and writes the results to uat_results.md.

    python part2_ba_case_study/uat/run_uat.py
"""
import csv
from datetime import date, datetime, timedelta
from pathlib import Path

import risk_rules as r

HERE = Path(__file__).resolve().parent


def ts(s):
    return datetime.strptime(s, "%Y-%m-%d %H:%M") if s else None


def d(s):
    return date.fromisoformat(s) if s else None


def run_scoring_cases():
    results = []
    with open(HERE / "scoring_test_cases.csv", newline="") as f:
        for tc in csv.DictReader(f):
            handoff, ship_by, promised = ts(tc["handoff_at"]), ts(tc["ship_by_at"]), d(tc["promised_date"])
            missed = r.seller_missed_deadline(ship_by, handoff)
            live = float(tc["live_days"]) if tc["live_days"] else None
            exp = r.expected_days(float(tc["history_days"]), live, int(tc["live_deliveries"]),
                                  float(tc["buffer_days"]))
            if tc["mode"] == "rescore":
                s = r.rescore(handoff, ts(tc["rescore_at"]), promised, exp, missed, tc["prior_tier"])
            else:
                s = r.score_at_handoff(handoff, promised, exp, missed)
            rng = r.revised_range(promised, s["slack_days"]) if s["tier"] == "HIGH" and s["slack_days"] < 0 else (None, None)
            actual = {
                "tier": s["tier"],
                "missed": "yes" if missed else "no",
                "range_from": rng[0].isoformat() if rng[0] else "",
                "range_to": rng[1].isoformat() if rng[1] else "",
            }
            expected = {"tier": tc["expected_tier"], "missed": tc["expected_missed"],
                        "range_from": tc["expected_range_from"], "range_to": tc["expected_range_to"]}
            passed = actual == expected
            detail = f"days_left {s['days_left']}, expected {exp:.1f}, slack {s['slack_days']} → {s['tier']}"
            if actual["range_from"]:
                detail += f"; range {actual['range_from']} to {actual['range_to']}"
            if not passed:
                detail += f"  **expected {expected}**"
            results.append((tc["tc_id"], tc["requirement"], tc["scenario"], detail, passed))
    return results


def run_other_cases():
    results = []

    # UAT-17 reminder timing (FR-01, BRL-11)
    ship_by = datetime(2018, 5, 12, 18, 0)
    checks = [
        r.reminder_due(ship_by, None, datetime(2018, 5, 11, 18, 0)) is True,          # exactly 24h before
        r.reminder_due(ship_by, None, datetime(2018, 5, 11, 17, 59)) is False,        # too early
        r.reminder_due(ship_by, datetime(2018, 5, 11, 9, 0), datetime(2018, 5, 11, 18, 0)) is False,  # already handed over
    ]
    results.append(("UAT-17", "FR-01", "Reminder 24h before deadline only if not handed over",
                    "due at 24h; not before; not if handed over", all(checks)))

    # UAT-18 missed deadline with no hand-off (FR-02, BRL-12)
    ok = r.seller_missed_deadline(ship_by, None, now=datetime(2018, 5, 12, 18, 1)) is True \
        and r.seller_missed_deadline(ship_by, None, now=datetime(2018, 5, 12, 17, 0)) is False
    results.append(("UAT-18", "FR-02", "No hand-off by the deadline counts as missed",
                    "missed after deadline, not before", ok))

    # UAT-19 lane fallback (FR-04, BRL-02)
    ok = r.history_days(412, 12.0, 15.0) == 12.0 and r.history_days(7, 9.0, 15.0) == 15.0
    results.append(("UAT-19", "FR-04", "Thin lane (< 30 orders) falls back to customer state",
                    "412 orders → lane 12.0; 7 orders → state 15.0", ok))

    # UAT-20 A/B split is stable and balanced (FR-10, BRL-14)
    ids = [f"order-{i:05d}" for i in range(1000)]
    groups = [r.ab_group(i) for i in ids]
    share = groups.count("message") / len(groups)
    stable = groups == [r.ab_group(i) for i in ids]
    results.append(("UAT-20", "FR-10", "A/B assignment is repeatable and 45-55% balanced",
                    f"message share {share:.1%}, repeatable {stable}", stable and 0.45 <= share <= 0.55))

    # UAT-21/22/23 lane escalation (FR-11, BRL-13)
    as_of = datetime(2018, 5, 20, 6, 0)
    def alerts(lane, n_on_time, n_seller_late, days_ago=2):
        t = as_of - timedelta(days=days_ago)
        return ([{"lane": lane, "created_at": t, "seller_missed_deadline": False}] * n_on_time +
                [{"lane": lane, "created_at": t, "seller_missed_deadline": True}] * n_seller_late)
    a = alerts("SP>RJ", 10, 0) + alerts("SP>BA", 8, 4) + alerts("MG>PE", 10, 0, days_ago=9)
    out = r.lanes_to_escalate(a, as_of, {})
    results.append(("UAT-21", "FR-11", "Lane with 10 on-time HIGH alerts in 7 days is escalated",
                    f"escalated: {out}", "SP>RJ" in out))
    results.append(("UAT-22", "FR-11", "Seller-late orders don't count toward escalation",
                    "SP>BA has 12 alerts but only 8 on time → not escalated", "SP>BA" not in out))
    out2 = r.lanes_to_escalate(a, as_of, {"SP>RJ": as_of - timedelta(days=3)})
    results.append(("UAT-23", "FR-11", "No repeat escalation within 7 days",
                    f"escalated 3 days ago → {out2 or 'none'}", "SP>RJ" not in out2))
    results.append(("UAT-24", "FR-11", "Alerts older than 7 days are ignored",
                    "MG>PE has 10 alerts, all 9 days old → not escalated", "MG>PE" not in out))
    return results


def main():
    rows = run_scoring_cases() + run_other_cases()
    passed = sum(1 for *_, p in rows if p)
    lines = [
        "# UAT results: automated rule tests",
        "",
        f"Generated by `run_uat.py` against the reference rules in `risk_rules.py`. **{passed} of {len(rows)} passed.**",
        "",
        "| Test | Req | Scenario | Result detail | Status |",
        "|---|---|---|---|---|",
    ]
    for tc, req, scen, detail, ok in rows:
        lines.append(f"| {tc} | {req} | {scen} | {detail} | {'✅ Pass' if ok else '❌ Fail'} |")
    (HERE / "uat_results.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    for tc, req, scen, detail, ok in rows:
        print(f"{'PASS' if ok else 'FAIL'}  {tc}  {scen}  |  {detail}")
    print(f"\n{passed}/{len(rows)} passed")


if __name__ == "__main__":
    main()
