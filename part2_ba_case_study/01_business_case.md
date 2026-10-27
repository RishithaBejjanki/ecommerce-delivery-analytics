# 1. Business case: Delivery Risk Alerts

| | |
|---|---|
| **Initiative** | Delivery Risk Alerts (late-delivery early warning) |
| **Sponsor** | Head of Marketplace Operations |
| **Prepared by** | Business Analyst, Operations Analytics |
| **Version** | 1.0 |
| **Evidence** | [Part 1 analysis](../README.md#part-1-delivery-performance-analysis), [rule backtest](08_rule_backtest.md) |

> Portfolio scenario: the data and every number are real (Olist public dataset). The organisation,
> roles and decisions are a realistic scenario built around that data.

## Problem statement
**6.8% of delivered orders arrive after the promised date, and those orders generate 36.9% of all
1-star reviews.** Today nobody knows an order is going to be late until the customer complains or the
date has passed. By then the review damage is done: even 1–3 days late drops the average review from
4.29 to 3.29.

Late orders mostly lose their time with the carrier (27.9 vs 8.0 days in transit), and a seller who
misses the ship-by deadline makes lateness 3.9x likelier. **Both problems are visible days before
the promise breaks, but no process acts on them.**

## Proposed solution
A rule-based early-warning process that:
1. **Reminds sellers** before their ship-by deadline, and flags those who miss it.
2. **Scores every order for late-delivery risk** when the seller hands it to the carrier, and again daily while it's in transit.
3. **Acts on HIGH-risk orders**: tells the customer early with a revised date, and escalates the lane to the carrier.
4. **Reports** alert volumes, catch rate and customer outcomes weekly, so the rule can be tuned.

## Why a rule, not a machine-learning model (for phase 1)
- The rule is explainable to sellers, carriers and customer service ("expected 14 days, 9 left").
- It was backtested on real data: HIGH-risk orders were late **18.9%** of the time vs **3.9%** for LOW,
  catching **39%** of late orders with a median of **11.8 days' warning**. See [08_rule_backtest.md](08_rule_backtest.md).
- It can go live with data Olist already has (timestamps, promise dates, states).
- An ML model is a phase-2 option once outcome data from the pilot exists.

## Objectives (SMART)
| # | Objective | Measure | Baseline | Target (6 months after launch) |
|---|---|---|---|---|
| O1 | Fewer sellers miss the ship-by deadline | % orders handed over late | 8.9% | ≤ 6.0% |
| O2 | Fewer late deliveries | % orders delivered after promise | 6.8% | ≤ 5.0% |
| O3 | Less review damage when an order *is* late | Avg review of late orders that were alerted | 2.27* | ≥ 2.60 |
| O4 | Fewer "where is my order?" contacts | WISMO contacts per 1,000 orders | *to be baselined* | −20% |

\* Average review of all late orders in Part 1 ([q03](../outputs/q03_review_by_lateness.csv), weighted).
The pilot measures alerted vs non-alerted late orders directly (see A/B design in the [BRD](04_brd.md#11-reporting-and-measurement)).

## Scope
**In scope**
- Seller reminder and missed-deadline flag
- Risk scoring at carrier hand-off and daily while in transit
- Proactive customer message for HIGH-risk orders (email and app notification)
- Carrier escalation for lanes with repeated HIGH-risk orders
- Ops dashboard and weekly performance pack
- Rule configuration (thresholds, "disruption mode")

**Out of scope (phase 1)**
- Changing how promised dates are calculated at checkout (separate initiative; see Part 1 recommendation 3)
- Compensation or vouchers for late orders
- Real-time carrier tracking integration (we use hand-off and delivery events only)
- Machine-learning prediction

## Benefits
| Benefit | Basis |
|---|---|
| ~1,500 fewer 1-star reviews if lateness halves | Part 1 [q13](../outputs/q13_opportunity_sizing.csv) |
| Average review up from 4.16 toward 4.22 | Part 1 [q13](../outputs/q13_opportunity_sizing.csv) |
| Fewer CS contacts from proactive messaging | To be measured in pilot |
| Better carrier negotiations with lane-level evidence | Escalation log becomes a data source |

## Costs and effort (indicative)
| Item | Estimate |
|---|---|
| Engineering (scoring job, notifications, dashboard) | 3 sprints, 1 squad |
| CRM templates and translations (PT-BR) | 1 week |
| CS training | 2 hours per agent |
| Running cost | Daily batch job; notification fees for ~35 HIGH alerts/day |

## Key risks
| Risk | Mitigation |
|---|---|
| Too many false alarms annoy customers (81% of HIGH orders still arrive on time) | Message says "may be delayed", not "is late"; A/B pilot measures review effect before full rollout |
| Rule is slow to react to sudden network-wide disruption (caught only 21% in Feb 2018) | Ops-controlled **disruption mode** (FR-14) |
| Sellers see reminders as noise | Only send when not yet handed over 24h before deadline |
| Customer data protection (Brazil's LGPD) | Use existing transactional-message consent; Legal review before launch |

## Recommendation
Approve a **6-week pilot on HIGH-risk orders**, with a 50/50 split between proactive message and no
message, followed by a go/no-go decision on full rollout based on objectives O2–O4.
