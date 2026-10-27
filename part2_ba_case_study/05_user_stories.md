# 5. User stories

Format: *As a [role], I want [capability], so that [benefit].* Acceptance criteria are written in
Given / When / Then form so they turn straight into tests (see [UAT plan](06_uat_plan.md)).
Points are relative effort (Fibonacci), agreed with the Product Manager.

## Epics
| Epic | Goal | Stories | Requirements |
|---|---|---|---|
| E1 Seller deadline | Fewer late hand-offs | US-01, US-02, US-03 | FR-01 – FR-03 |
| E2 Risk scoring | Know which orders will be late | US-04, US-05, US-06 | FR-04 – FR-07 |
| E3 Customer and CS | Tell customers first | US-07, US-08, US-09 | FR-08 – FR-10 |
| E4 Carrier escalation | Lane-level evidence | US-10 | FR-11, FR-12 |
| E5 Ops control and reporting | Run, tune and measure | US-11, US-12, US-13 | FR-13 – FR-16 |

## Release plan
| Sprint | Stories | Outcome |
|---|---|---|
| 1 | US-04, US-05, US-01, US-02 | Orders are scored; sellers get reminders and flags |
| 2 | US-07, US-08, US-09, US-11 | Pilot can start: messages, CS cases, A/B split, dashboard |
| 3 | US-06, US-10, US-12, US-03, US-13 | Daily re-score, carrier escalation, disruption mode, reporting |

---

## E1 Seller deadline

### US-01 Seller reminder · Must · 3 pts
**As a** seller, **I want** a reminder before my ship-by deadline, **so that** I hand the order to the carrier in time.

```gherkin
Scenario: Reminder sent when order not yet handed over
  Given an order with ship-by deadline 12 May 18:00
  And no hand-off event has been recorded
  When the time reaches 11 May 18:00
  Then the seller receives one reminder naming the order and the deadline

Scenario: No reminder when already handed over
  Given an order with ship-by deadline 12 May 18:00
  And the hand-off was recorded at 11 May 09:00
  When the time reaches 11 May 18:00
  Then no reminder is sent
```

### US-02 Missed-deadline flag · Must · 2 pts
**As a** Seller Success manager, **I want** orders handed over after the deadline to be flagged, **so that** I can see which sellers need help.

```gherkin
Scenario: Hand-off after the deadline
  Given an order with ship-by deadline 12 May 18:00
  When the hand-off is recorded at 12 May 19:30
  Then the order is flagged "seller missed deadline"

Scenario: No hand-off by the deadline
  Given an order with ship-by deadline 12 May 18:00
  And no hand-off is recorded by 12 May 18:00
  Then the order is flagged "seller missed deadline"

Scenario: Several items, several deadlines
  Given an order with items due 12 May 18:00 and 14 May 18:00
  When the hand-off is recorded at 13 May 10:00
  Then the order is flagged, because the earliest deadline applies
```

### US-03 Seller view for account managers · Should · 3 pts
**As an** account manager, **I want** each seller's missed-deadline rate for the last 30 and 90 days, **so that** I can prioritise coaching.

```gherkin
Scenario: Seller rate shown
  Given a seller had 40 orders in the last 30 days and 6 missed the deadline
  When I open that seller's page
  Then I see "Missed deadline: 6 of 40 (15.0%), last 30 days"
```

## E2 Risk scoring

### US-04 Nightly route benchmarks · Must · 5 pts
**As the** risk engine, **I want** fresh transit benchmarks every night, **so that** scores reflect recent carrier performance.

```gherkin
Scenario: Lane with enough history uses the lane benchmark
  Given lane SP→BA has 412 delivered orders in the last 12 months
  When the nightly job runs
  Then history_days for SP→BA is the 75th percentile of their transit times

Scenario: Thin lane falls back to the customer state
  Given lane AC→BA has 7 delivered orders in the last 12 months
  When the nightly job runs
  Then history_days for AC→BA equals the 75th percentile for all orders delivered to BA

Scenario: Live signal needs enough deliveries
  Given 12 orders were delivered to RR in the last 14 days
  When the nightly job runs
  Then live_days for RR is empty and is not used
```

### US-05 Score at hand-off · Must · 5 pts
**As an** Ops manager, **I want** every order scored when it's handed to the carrier, **so that** we know the risk while there's still time to act.

```gherkin
Scenario Outline: Tier assignment
  Given an order handed over with <days_left> days left
  And expected_days is <expected>
  And seller missed deadline is <missed>
  When the order is scored
  Then the risk tier is <tier>

  Examples:
    | days_left | expected | missed | tier   |
    | 9.6       | 13.0     | no     | HIGH   |
    | 13.0      | 13.0     | no     | MEDIUM |
    | 17.9      | 13.0     | no     | MEDIUM |
    | 18.0      | 13.0     | no     | LOW    |
    | 25.0      | 13.0     | yes    | MEDIUM |

Scenario: Score stored with its inputs
  When any order is scored
  Then days_left, history_days, live_days, buffer_days, slack_days and rule_version are stored
```

### US-06 Daily re-score in transit · Should · 3 pts
**As an** Ops manager, **I want** MEDIUM orders re-checked daily, **so that** orders that slip are caught.

```gherkin
Scenario: MEDIUM order slips to HIGH
  Given a MEDIUM order handed over 6 days ago with expected_days 13.0
  And 5.0 days are left until the end of the promised date
  When the daily re-score runs
  Then expected remaining is 7.0 days, slack is -2.0, and the tier becomes HIGH
  And an alert is created

Scenario: Tiers never go down
  Given a HIGH order
  When the daily re-score would give MEDIUM
  Then the order stays HIGH
```

## E3 Customer and CS

### US-07 Proactive customer message · Must · 5 pts
**As a** customer, **I want** to be told early if my order may arrive late, with a new date range, **so that** I'm not left wondering.

```gherkin
Scenario: HIGH order in the message group
  Given a HIGH alert with slack_days -3.4 and promised date 19 May
  And the order is in the message group
  And the customer has not opted out
  When the alert is created at 10:05 customer local time
  Then one message is sent: "Your order may arrive between 21 May and 25 May"

Scenario: Quiet hours
  Given a HIGH alert created at 23:10 customer local time
  Then the message is queued and sent at 08:00

Scenario: Opted out
  Given the customer opted out of transactional messages
  Then no message is sent and message_status is "suppressed_opt_out"

Scenario: Only one message per order
  Given a message has already been sent for this order
  When the alert is updated
  Then no second message is sent
```

### US-08 CS case with reason · Must · 3 pts
**As a** CS agent, **I want** a case already open with the reason and revised dates, **so that** I can answer the customer without investigating.

```gherkin
Scenario: Case created for a HIGH alert
  Given a HIGH alert on lane SP→BA with days_left 9.6 and expected_days 13.0
  When the alert is created
  Then a CS case opens with the reason
    "Route SP→BA usually takes 13 days; 9.6 days were left at hand-off"
  And the revised date range 21 May – 25 May
```

### US-09 Pilot A/B assignment · Must · 2 pts
**As the** sponsor, **I want** half of HIGH alerts held back from messaging, **so that** we can prove whether messages help.

```gherkin
Scenario: Stable random assignment
  Given a HIGH alert
  When the group is assigned
  Then it is "message" or "control" from a hash of order_id
  And re-running the assignment gives the same group
  And over 1,000 alerts each group is between 45% and 55%
```

## E4 Carrier escalation

### US-10 Lane escalation · Should · 5 pts
**As the** Carrier Manager, **I want** lanes with repeated HIGH alerts escalated with evidence, **so that** I can hold carriers to account.

```gherkin
Scenario: Lane reaches the threshold
  Given lane SP→RJ has 10 HIGH alerts in the last 7 days on orders handed over on time
  When the escalation check runs
  Then SP→RJ is added to the escalation queue with order IDs, median transit and benchmark
  And no customer personal data is included

Scenario: Seller-late orders don't count
  Given lane SP→RJ has 12 HIGH alerts in 7 days, of which 4 were handed over late
  Then only 8 count and the lane is not escalated

Scenario: No repeat escalation within 7 days
  Given SP→RJ was escalated 3 days ago
  When it reaches the threshold again
  Then it is not escalated again until 7 days have passed
```

## E5 Ops control and reporting

### US-11 Risk dashboard · Must · 5 pts
**As an** Ops manager, **I want** today's HIGH and MEDIUM orders on one screen, **so that** I can see where problems are building.

```gherkin
Scenario: Filter by state
  Given there are 40 HIGH orders today, 12 of them to customers in RJ
  When I filter the dashboard to customer state RJ
  Then I see 12 HIGH orders, each with its reason and revised date range
```

### US-12 Disruption mode · Should · 3 pts
**As an** Ops manager, **I want** to add buffer days for regions hit by a disruption, **so that** the alerts react immediately instead of waiting for the live signal.

```gherkin
Scenario: Switch on for selected states
  Given I have the Ops Manager role
  When I switch on disruption mode for BA and PE with 3 buffer days and reason "carrier strike"
  Then orders to BA and PE are scored with expected_days + 3
  And the change is logged with my name, the time and the reason

Scenario: Expiry
  Given disruption mode was switched on 14 days ago and not renewed
  Then it switches off automatically

Scenario: Role check
  Given I do not have the Ops Manager role
  Then I cannot switch disruption mode on or off
```

### US-13 Weekly performance pack · Must · 3 pts
**As the** sponsor, **I want** a weekly pack of alert performance, **so that** I can decide whether to roll out and how to tune the rule.

```gherkin
Scenario: Pack contents
  When the weekly pack is produced
  Then it shows alerts per day, precision, catch rate, median warning time,
    review score of late orders by A/B group, WISMO contacts by A/B group,
    and the top 20 sellers by missed deadlines
```
