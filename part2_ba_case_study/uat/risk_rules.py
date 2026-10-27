"""
risk_rules.py
-------------
Reference implementation of the BRD business rules (BRL-01 to BRL-15), written
so the UAT test cases can be executed and the rules have one unambiguous meaning.
It is a specification aid for Engineering, not production code.
"""
import hashlib
import math
from datetime import date, datetime, timedelta

HIGH_BELOW = 0.0      # BRL-06
MEDIUM_BELOW = 5.0    # BRL-06
LANE_MIN_ORDERS = 30  # BRL-02
LIVE_MIN_DELIVERIES = 20  # BRL-03
TIER_ORDER = {"LOW": 0, "MEDIUM": 1, "HIGH": 2}


def end_of_day(d: date) -> datetime:
    """BRL-01: the promise runs to midnight at the close of the promised date."""
    return datetime(d.year, d.month, d.day) + timedelta(days=1)


def days_between(start: datetime, end: datetime) -> float:
    return (end - start).total_seconds() / 86400


def seller_missed_deadline(ship_by: datetime, handoff: datetime | None, now: datetime | None = None) -> bool:
    """BRL-12: hand-off after the deadline, or no hand-off once the deadline has passed."""
    if handoff is None:
        return now is not None and now > ship_by
    return handoff > ship_by


def reminder_due(ship_by: datetime, handoff: datetime | None, now: datetime) -> bool:
    """BRL-11: remind 24h before the deadline if not yet handed over."""
    return handoff is None and ship_by - timedelta(hours=24) <= now < ship_by


def history_days(lane_orders: int, lane_p75: float, dest_p75: float) -> float:
    """BRL-02: lane benchmark if it has enough orders, else the customer state."""
    return lane_p75 if lane_orders >= LANE_MIN_ORDERS else dest_p75


def expected_days(history: float, live: float | None, live_deliveries: int, buffer_days: float = 0) -> float:
    """BRL-03 + BRL-04 + BRL-15."""
    live_used = live if (live is not None and live_deliveries >= LIVE_MIN_DELIVERIES) else 0
    return max(history, live_used) + buffer_days


def tier(slack: float, missed_deadline: bool) -> str:
    """BRL-06."""
    if slack < HIGH_BELOW:
        return "HIGH"
    if slack < MEDIUM_BELOW or missed_deadline:
        return "MEDIUM"
    return "LOW"


def score_at_handoff(handoff: datetime, promised: date, expected: float, missed: bool) -> dict:
    """BRL-01, BRL-05, BRL-06."""
    left = days_between(handoff, end_of_day(promised))
    slack = left - expected
    return {"days_left": round(left, 2), "slack_days": round(slack, 2), "tier": tier(slack, missed)}


def rescore(handoff: datetime, now: datetime, promised: date, expected: float,
            missed: bool, prior_tier: str) -> dict:
    """BRL-07: re-score in transit; expected remaining is at least 1 day; tiers only go up."""
    left = days_between(now, end_of_day(promised))
    remaining = max(expected - days_between(handoff, now), 1.0)
    slack = left - remaining
    new = tier(slack, missed)
    final = new if TIER_ORDER[new] > TIER_ORDER[prior_tier] else prior_tier
    return {"days_left": round(left, 2), "slack_days": round(slack, 2), "tier": final}


def revised_range(promised: date, slack: float) -> tuple[date, date]:
    """BRL-10: promised + (late_by - 2, min 1) to promised + (late_by + 2)."""
    late_by = math.ceil(-slack)
    return promised + timedelta(days=max(late_by - 2, 1)), promised + timedelta(days=late_by + 2)


def ab_group(order_id: str) -> str:
    """BRL-14: stable hash of order_id; even -> message, odd -> control."""
    return "message" if int(hashlib.md5(order_id.encode()).hexdigest(), 16) % 2 == 0 else "control"


def lanes_to_escalate(alerts: list[dict], as_of: datetime, last_escalated: dict[str, datetime]) -> list[str]:
    """BRL-13: >= 10 HIGH alerts in 7 days on orders handed over on time; at most once per 7 days."""
    window_start = as_of - timedelta(days=7)
    counts: dict[str, int] = {}
    for a in alerts:
        if a["created_at"] >= window_start and not a["seller_missed_deadline"]:
            counts[a["lane"]] = counts.get(a["lane"], 0) + 1
    out = []
    for lane, n in counts.items():
        recent = last_escalated.get(lane)
        if n >= 10 and (recent is None or as_of - recent >= timedelta(days=7)):
            out.append(lane)
    return sorted(out)
