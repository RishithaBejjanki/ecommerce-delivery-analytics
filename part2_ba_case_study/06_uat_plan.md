# 6. User Acceptance Testing (UAT) plan

## Purpose
Confirm with business users that Delivery Risk Alerts does what the [BRD](04_brd.md) says,
before the pilot starts.

## Approach
UAT has two layers:

| Layer | What | How |
|---|---|---|
| **A. Rule tests (automated)** | Tier calculation, deadlines, date ranges, A/B split, lane escalation | 24 test cases run against a reference implementation of the business rules: [`uat/scoring_test_cases.csv`](uat/scoring_test_cases.csv), [`uat/risk_rules.py`](uat/risk_rules.py), [`uat/run_uat.py`](uat/run_uat.py). Engineering's build must give the same results on the same inputs. |
| **B. Workflow tests (manual)** | Messages, CS cases, dashboard, roles, reporting | Business testers follow the scripts below in the test environment |

Writing the rules as executable tests found two ambiguities before any build started:
- "End of the promised date" could mean 23:59:59 or midnight. It's now fixed as midnight (BRL-01).
- What happens to the expected time once an order has been in transit longer than expected? It's now floored at 1 day (BRL-07).

**Current result for layer A: 24 of 24 pass.** See [`uat/uat_results.md`](uat/uat_results.md).

## Entry criteria
- All Must stories (US-01, 02, 04, 05, 07, 08, 09, 11, 13) deployed to the test environment
- Test data loaded (below)
- Message templates approved by CRM and Legal
- Testers trained (30 minutes)

## Exit criteria
- 100% of layer A tests pass on the built system
- All layer B Must tests pass
- No open Critical or High defects; Medium defects have an agreed fix date
- Sign-off from Ops Head, CS Lead and Product Manager

## Test data
Scenario orders are taken from [`uat/scoring_test_cases.csv`](uat/scoring_test_cases.csv), plus:
- one customer opted out of transactional messages
- one customer in a different time zone (Manaus, UTC−4) to test quiet hours
- a lane with 10 seeded HIGH alerts in the last 7 days (SP→RJ)
- one user with the Ops Manager role and one without

## Testers
| Area | Tester |
|---|---|
| Seller reminders and flags | Seller Success account manager |
| Customer messages | CRM specialist |
| CS cases | 2 CS agents |
| Dashboard, disruption mode, weekly pack | Ops analyst |
| Carrier escalation | Carrier Manager's analyst |

## Layer B: workflow test scripts
| ID | Req / Story | Steps | Expected result | Priority |
|---|---|---|---|---|
| UAT-B01 | FR-08 / US-07 | Trigger HIGH alert for UAT-01 order (message group) at 10:05 local | One message: "Your order may arrive between 21 May and 25 May", in Portuguese | Must |
| UAT-B02 | FR-08 / US-07 | Trigger HIGH alert at 23:10 local | Message queued; sent at 08:00 local | Must |
| UAT-B03 | FR-08 / US-07 | Trigger HIGH alert for opted-out customer | No message; status `suppressed_opt_out`; CS case still opened | Must |
| UAT-B04 | FR-08 / US-07 | Re-score the UAT-01 order so the alert updates | No second message sent | Must |
| UAT-B05 | FR-09 / US-08 | Open the CS case for UAT-01 | Reason reads "Route SP→BA usually takes 13 days; 9.6 days were left at hand-off"; dates 21–25 May | Must |
| UAT-B06 | FR-10 / US-09 | Trigger HIGH alert for an order in the control group | No message; status `control`; CS case opened | Must |
| UAT-B07 | FR-03 / US-03 | Open a seller with 6 misses in 40 orders | Shows "6 of 40 (15.0%), last 30 days" | Should |
| UAT-B08 | FR-13 / US-11 | Filter dashboard to RJ | Only RJ orders shown, each with reason and date range | Must |
| UAT-B09 | FR-14 / US-12 | As Ops Manager, switch on disruption mode for BA, PE (3 days, "carrier strike") | Orders to BA and PE re-scored with +3 days; audit log shows user, time, reason | Should |
| UAT-B10 | FR-14 / US-12 | As a user without the role, try to switch on disruption mode | Action not available | Should |
| UAT-B11 | FR-14 / US-12 | Set system date 14 days after switch-on | Disruption mode off automatically; logged | Should |
| UAT-B12 | FR-11 / US-10 | Run escalation check with seeded SP→RJ alerts | Lane in queue with order IDs, median transit, benchmark; no customer names, emails or addresses | Should |
| UAT-B13 | FR-15 / US-13 | Generate weekly pack | All 7 metrics present; A/B split shown for reviews and contacts | Must |
| UAT-B14 | FR-05 / US-05 | Check stored score for any test order | days_left, history_days, live_days, buffer_days, slack_days, rule_version all stored | Must |
| UAT-B15 | NFR-01 | Record hand-off event; time the score | Score appears within 60 minutes | Must |

## Defect severity
| Severity | Definition | Example |
|---|---|---|
| Critical | Wrong customer impact at scale, or data protection breach | Messages sent to opted-out customers; customer data in carrier report |
| High | Rule gives wrong tier or wrong date range | Slack −1 scored as MEDIUM |
| Medium | Feature works with a workaround | Dashboard filter needs a page refresh |
| Low | Cosmetic | Label typo |

## Sign-off
| Role | Name | Pass / Fail | Date |
|---|---|---|---|
| Head of Marketplace Ops | | | |
| CS Lead | | | |
| Product Manager | | | |
