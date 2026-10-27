# 4. Business Requirements Document: Delivery Risk Alerts

| | |
|---|---|
| **Version** | 1.0 (for sign-off) |
| **Sponsor** | Head of Marketplace Operations |
| **Author** | Business Analyst, Operations Analytics |
| **Related** | [Business case](01_business_case.md) · [Stakeholders](02_stakeholders.md) · [Process maps](03_process_maps.md) · [User stories](05_user_stories.md) · [UAT plan](06_uat_plan.md) · [Traceability](07_traceability_matrix.md) · [Rule backtest](08_rule_backtest.md) |

## Contents
1. Purpose · 2. Background · 3. Business objectives · 4. Scope · 5. Business requirements ·
6. Functional requirements · 7. Business rules · 8. Data requirements · 9. Non-functional requirements ·
10. Assumptions, constraints, dependencies · 11. Reporting and measurement · 12. Risks · 13. Open questions · 14. Sign-off

---

## 1. Purpose
Define what the Delivery Risk Alerts capability must do so that the Product, Engineering, CRM and
Operations teams can build, test and run it. This document says **what** is needed and **why**; the
technical design is owned by Engineering.

## 2. Background
Part 1 found that 6.8% of orders arrive late, producing 36.9% of all 1-star reviews. Two signals
appear before the promise breaks: the seller missing the ship-by deadline (late rate 21.1% vs 5.4%),
and an order handed to the carrier with less time left than the route normally takes. Today neither
signal triggers any action. See the [process maps](03_process_maps.md#31-current-state-as-is).

## 3. Business objectives
| ID | Objective | Target |
|---|---|---|
| O1 | Reduce late seller hand-offs | 8.9% → ≤ 6.0% |
| O2 | Reduce late deliveries | 6.8% → ≤ 5.0% |
| O3 | Reduce review damage on late orders | Avg review of alerted late orders ≥ 2.60 (baseline 2.27) |
| O4 | Reduce "where is my order?" contacts | −20% vs baseline |

## 4. Scope
**In:** seller reminders and flags, risk scoring, HIGH-risk customer messages, CS cases, carrier lane
escalation, disruption mode, dashboard and weekly reporting, rule configuration.
**Out:** promised-date calculation at checkout, compensation, live carrier tracking feeds, ML models.

## 5. Business requirements
| ID | Requirement | Objective | Priority |
|---|---|---|---|
| BR-01 | The business must prompt sellers before they miss the ship-by deadline and know when they do. | O1 | Must |
| BR-02 | The business must identify orders likely to miss the promised date while there is still time to act. | O2, O3 | Must |
| BR-03 | Customers with a likely-late order must hear about it from us before the promised date passes. | O3, O4 | Must |
| BR-04 | Carrier performance problems must be raised with lane-level evidence. | O2 | Should |
| BR-05 | Operations must be able to respond to sudden network-wide disruption. | O2, O3 | Should |
| BR-06 | The business must be able to measure whether the alerts work, and tune them. | All | Must |

## 6. Functional requirements
Priority uses MoSCoW (Must / Should / Could / Won't this phase).

### Seller deadline (BR-01)
| ID | The system shall… | Priority | Rules |
|---|---|---|---|
| FR-01 | send the seller a reminder 24 hours before the ship-by deadline for any order not yet handed to the carrier | Must | BRL-11 |
| FR-02 | flag an order as **seller missed deadline** when the hand-off happens after the ship-by deadline, or has not happened by it | Must | BRL-12 |
| FR-03 | show account managers each seller's missed-deadline count and rate for the last 30 and 90 days | Should | BRL-12 |

### Risk scoring (BR-02)
| ID | The system shall… | Priority | Rules |
|---|---|---|---|
| FR-04 | recalculate route benchmarks (history and live) every night | Must | BRL-02, BRL-03 |
| FR-05 | score each order within 60 minutes of the carrier hand-off event and assign HIGH, MEDIUM or LOW | Must | BRL-01 – BRL-06 |
| FR-06 | re-score every in-transit MEDIUM order daily, and raise it to HIGH when the rule says so (tiers never go down) | Should | BRL-07 |
| FR-07 | create exactly one alert record per order when it first becomes HIGH | Must | BRL-08 |

### Customer and CS (BR-03)
| ID | The system shall… | Priority | Rules |
|---|---|---|---|
| FR-08 | send the customer one proactive message for a HIGH alert, with a revised delivery date range, unless the order is in the control group or the customer has opted out of transactional messages | Must | BRL-09, BRL-10, BRL-14 |
| FR-09 | open a CS case for every HIGH alert, pre-filled with the reason in plain language (e.g. "Route SP→BA usually takes 13 days; 9 days were left at hand-off") and the revised date range | Must | BRL-10 |
| FR-10 | randomly assign 50% of HIGH alerts to a control group that receives no customer message during the pilot | Must | BRL-14 |

### Carrier (BR-04)
| ID | The system shall… | Priority | Rules |
|---|---|---|---|
| FR-11 | add a lane to the carrier escalation queue when it reaches the escalation threshold, counting only orders the seller handed over on time | Should | BRL-13 |
| FR-12 | produce a weekly lane report per carrier: orders, HIGH alerts, late rate, median transit vs benchmark | Should | n/a |

### Operations (BR-05, BR-06)
| ID | The system shall… | Priority | Rules |
|---|---|---|---|
| FR-13 | provide a risk dashboard: today's HIGH and MEDIUM orders, filterable by customer state, seller and carrier, with each order's reason | Must | n/a |
| FR-14 | let an Ops Manager switch on **disruption mode** for selected customer states, adding buffer days to expected transit; every change is logged with user, time and reason | Should | BRL-15 |
| FR-15 | produce a weekly performance pack (see §11) | Must | n/a |
| FR-16 | let authorised users change rule thresholds without a code release; every change creates a new rule version stored on each score | Could | BRL-16 |

## 7. Business rules
These rules are the ones tested in the [backtest](08_rule_backtest.md) and in [`sql/05_early_warning_backtest.sql`](../sql/05_early_warning_backtest.sql).

| ID | Rule |
|---|---|
| BRL-01 | **days_left** = time from the carrier hand-off to the end of the promised date (midnight at the close of that day), in days. |
| BRL-02 | **history_days** = 75th-percentile carrier transit time for the seller-state → customer-state lane over the last 12 months, if the lane has at least 30 delivered orders. Otherwise use the 75th percentile for the customer state. |
| BRL-03 | **live_days** = 75th-percentile transit time of orders delivered to the same customer state in the 14 days before scoring. Only used when there are at least 20 such deliveries. |
| BRL-04 | **expected_days** = the larger of history_days and live_days, plus any disruption buffer (BRL-15). |
| BRL-05 | **slack_days** = days_left − expected_days. |
| BRL-06 | **Tier:** HIGH if slack_days < 0. MEDIUM if slack_days < 5, or the seller missed the ship-by deadline. LOW otherwise. |
| BRL-07 | **Daily re-score** of in-transit MEDIUM orders: days_left = now → end of promised date; expected remaining = max(expected_days − days already in transit, 1). Tiers can only go up. |
| BRL-08 | One alert per order. A second HIGH result on the same order updates the existing alert. |
| BRL-09 | At most one proactive customer message per order. No messages between 22:00 and 08:00 customer local time; queue them for 08:00. |
| BRL-10 | **Revised date range** = promised date + (late_by − 2, minimum 1) to promised date + (late_by + 2) days, where late_by = round-up of −slack_days. |
| BRL-11 | Seller reminder at ship-by deadline − 24h if there is no hand-off event yet. One reminder per order. |
| BRL-12 | Seller missed deadline = hand-off after the ship-by deadline, or no hand-off when the deadline passes. When an order has several items, use the earliest ship-by deadline. |
| BRL-13 | **Lane escalation:** a lane is escalated when it has 10 or more HIGH alerts in a rolling 7 days, counting only orders handed over on time. A lane is escalated at most once per 7 days. |
| BRL-14 | **Pilot control group:** assign by a stable hash of order_id (even → message, odd → control) so assignment is random and repeatable. |
| BRL-15 | **Disruption mode:** adds N buffer days (default 3, allowed 1–7) to expected_days for the selected customer states. It switches off automatically after 14 days unless renewed. |
| BRL-16 | Each score stores the rule version and the inputs used (days_left, history_days, live_days, buffer). |

### Worked example
Order handed to the carrier **10 May 10:00**, promised **19 May**, lane SP → BA.
- days_left = 10 May 10:00 → end of 19 May = **9.6 days** (BRL-01)
- history_days = **12.0** (lane p75), live_days = **13.0** (last 14 days) → expected_days = **13.0** (BRL-04)
- slack_days = 9.6 − 13.0 = **−3.4** → **HIGH** (BRL-06)
- late_by = 4 → revised range **21 May – 25 May** (BRL-10)

## 8. Data requirements
### Inputs
| Data | Source | Used for |
|---|---|---|
| Order: purchase time, promised date, status | Order platform | All rules |
| Item: seller, ship-by deadline | Order platform | BRL-11, BRL-12 |
| Hand-off event (timestamp) | Seller portal / carrier pickup | BRL-01, BRL-12 |
| Delivery event (timestamp) | Carrier | BRL-02, BRL-03, outcomes |
| Seller state, customer state | Seller and customer records | Lanes |
| Customer messaging consent | CRM | FR-08 |
| Review score | Reviews service | Measurement |

### Alert record (new)
| Field | Description |
|---|---|
| alert_id | Unique ID |
| order_id | Order |
| created_at / updated_at | Timestamps |
| risk_tier | HIGH (alerts are only created for HIGH) |
| days_left, history_days, live_days, buffer_days, slack_days | Inputs and result (BRL-16) |
| rule_version | Version of thresholds used |
| reason_text | Plain-language reason shown to CS |
| revised_date_from / revised_date_to | BRL-10 |
| ab_group | message / control (BRL-14) |
| message_status | not_sent / queued / sent / suppressed_opt_out / control |
| cs_case_id | Linked CS case |
| lane_id | seller_state → customer_state |
| outcome_delivered_at, outcome_is_late, outcome_review_score | Filled in after delivery, for measurement |

## 9. Non-functional requirements
| ID | Category | Requirement |
|---|---|---|
| NFR-01 | Timeliness | Score within 60 minutes of the hand-off event; nightly benchmarks done by 06:00 BRT |
| NFR-02 | Capacity | Handle 3x current peak daily volume. The backtest saw up to ~76 HIGH alerts/day in a month with shortened promise dates |
| NFR-03 | Availability | Scoring job 99.5% monthly. A failed run retries, and alerts Engineering after 2 failures |
| NFR-04 | Auditability | Every score reproducible from stored inputs and rule version (BRL-16) |
| NFR-05 | Privacy | Complies with LGPD. Carrier escalations contain no customer personal data, only order IDs and lanes |
| NFR-06 | Language | Customer messages in Brazilian Portuguese; CS and dashboard text in Portuguese and English |
| NFR-07 | Security | Disruption mode and threshold changes are limited to the Ops Manager role |

## 10. Assumptions, constraints, dependencies
**Assumptions**
- A reliable hand-off event exists for each order (true for over 99.9% of delivered orders in the data).
- Customers already consent to transactional messages about their orders.
- Transit patterns in the 12-month history are representative, with the live signal covering sudden changes.

**Constraints**
- No live carrier tracking in phase 1; scoring uses hand-off and delivery events only.
- The pilot must not change promised dates shown at checkout.

**Dependencies**
- CRM team for message templates and sending (FR-08)
- CS platform API for case creation (FR-09)
- Legal sign-off on message wording (NFR-05)

## 11. Reporting and measurement
**Weekly performance pack (FR-15)**
| Metric | Definition |
|---|---|
| Alerts | HIGH alerts created, per day and per customer state |
| Precision | % of HIGH alerts that were actually late |
| Catch rate | % of late orders that had a HIGH alert before the promised date |
| Warning time | Median days between alert and promised date |
| Review uplift | Avg review of late orders: message group vs control group |
| WISMO contacts | CS contacts per 1,000 orders: message group vs control |
| Seller hand-off | % orders handed over late, top 20 sellers by misses |

**Pilot design**
- 6 weeks, all HIGH alerts, 50/50 message vs control (BRL-14).
- **Primary metric:** average review of late HIGH orders, message vs control.
- **Go criteria:** review uplift ≥ +0.3 with no increase in 1-star share on on-time HIGH orders (the false alarms).
- **Backtest benchmarks** to compare against: precision 18.9%, catch rate 39.4%, median warning 11.8 days.

## 12. Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| False alarms (81% of HIGH orders arrive on time) annoy customers | Medium | Medium | Soft wording ("may"), pilot measures the effect on on-time HIGH orders |
| Slow reaction to sudden disruption | Medium | High | Disruption mode (FR-14); live signal updates daily |
| Alert volume spikes when promised dates are shortened | Medium | Medium | Capacity requirement NFR-02; monitor in weekly pack |
| Sellers dispute flags | Low | Medium | Reminder always comes first; flags based on the seller's own deadline |
| Hand-off events missing or late | Low | High | Data-quality check in nightly job; orders without hand-off are scored at deadline + 1 day |

## 13. Open questions
| # | Question | Owner | Needed by |
|---|---|---|---|
| Q1 | Are 35 HIGH alerts a day acceptable for CS capacity, or should we start with option A (16/day)? | CS Lead | Sprint 1 planning |
| Q2 | Do carrier contracts allow lane-level escalation with penalties? | Carrier Mgr | Before FR-11 build |
| Q3 | Which channels: email only, or app push as well? | CRM | Sprint 2 |
| Q4 | Should MEDIUM orders also trigger a seller message? | Seller Success | After pilot |

## 14. Sign-off
| Role | Name | Decision | Date |
|---|---|---|---|
| Sponsor, Head of Marketplace Ops | | | |
| Product Manager, Order Platform | | | |
| Logistics & Carrier Manager | | | |
| Customer Service Lead | | | |
| Legal / Data Protection | | | |
