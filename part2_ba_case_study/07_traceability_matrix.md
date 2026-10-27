# 7. Requirements traceability matrix

Every business requirement traces to the problem it solves (Part 1 evidence), the functional
requirements and rules that deliver it, the user stories that build it, and the tests that prove it.
No requirement is untested and no test is orphaned.

| BR | Evidence (Part 1) | FR | Business rules | Stories | Tests |
|---|---|---|---|---|---|
| **BR-01** Prompt sellers, know when they miss | Missed hand-off → 21.1% late vs 5.4%; 8.9% of orders missed | FR-01 | BRL-11 | US-01 | UAT-17 |
| | | FR-02 | BRL-12 | US-02 | UAT-05, 10, 11, 18 |
| | | FR-03 | BRL-12 | US-03 | UAT-B07 |
| **BR-02** Identify likely-late orders in time | 72% of late orders are carrier-driven; late orders spend 27.9 days in transit | FR-04 | BRL-02, 03 | US-04 | UAT-06, 07, 19 |
| | | FR-05 | BRL-01, 04, 05, 06, 16 | US-05 | UAT-01 – 04, UAT-B14, UAT-B15 |
| | | FR-06 | BRL-07 | US-06 | UAT-12, 13, 14 |
| | | FR-07 | BRL-08 | US-05 | UAT-B04 |
| **BR-03** Tell customers before the date passes | 36.9% of 1-star reviews from late orders; 1–3 days late costs a full star | FR-08 | BRL-09, 10 | US-07 | UAT-01, 15, 16, UAT-B01 – B04 |
| | | FR-09 | BRL-10 | US-08 | UAT-B05 |
| | | FR-10 | BRL-14 | US-09 | UAT-20, UAT-B06 |
| **BR-04** Escalate carriers with lane evidence | RJ = 24% of late orders; Northeast 12.8% late; interstate 8.1% vs 4.5% | FR-11 | BRL-13 | US-10 | UAT-21 – 24, UAT-B12 |
| | | FR-12 | n/a | US-10 | UAT-B12 |
| **BR-05** Respond to sudden disruption | Feb–Mar 2018: 16.6% late; rule caught only 21% in Feb ([backtest](08_rule_backtest.md)) | FR-14 | BRL-15 | US-12 | UAT-08, 09, UAT-B09 – B11 |
| **BR-06** Measure and tune | Pilot needed to prove review uplift | FR-13 | n/a | US-11 | UAT-B08 |
| | | FR-15 | n/a | US-13 | UAT-B13 |
| | | FR-16 | BRL-16 | US-05 | UAT-B14 |

## Coverage check
| | Count | Covered by a test |
|---|---|---|
| Business requirements | 6 | 6 |
| Functional requirements | 16 | 16 |
| Business rules | 16 | 16 (BRL-09 via UAT-B02, B04) |
| User stories | 13 | 13 |
