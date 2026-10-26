# Memo: Reducing late deliveries

**To:** Head of Marketplace Operations
**From:** Business Analyst, Operations Analytics
**Re:** Why 6.8% of orders arrive late, what it costs, and where to act first
**Data:** 96,004 delivered orders, Jan 2017 – Aug 2018 (Olist public dataset)

---

## Bottom line
Late deliveries are a small share of orders (6.8%) but a large share of unhappy
customers (**36.9% of all 1-star reviews**). Most late orders lose their time in
**carrier transit**, concentrated on **Rio de Janeiro and Northeast lanes** and in
**peak periods**. Seller hand-off delays are the second driver and are concentrated in
a short list of sellers. I recommend four actions, starting with a carrier lane review
and a seller SLA programme. Halving lateness would remove ~1,500 one-star reviews.

## What the data shows

| Finding | Evidence |
|---|---|
| Lateness drives bad reviews | Avg review 4.29 on time → 3.29 at 1–3 days late → 1.70 at 8+ days late. 1-star share rises from 7% to 70%. |
| The carrier leg is the main driver | Late orders: 27.9 days in transit vs 8.0 for on-time. 72% of late orders had a seller who shipped on time. |
| Seller hand-off is the second driver | Missing the ship-by deadline raises the late rate from 5.4% to 21.1% (3.9x). |
| Geography | Northeast 12.8% late vs Southeast 6.1%. Rio de Janeiro: 12.2% late, 24% of all late orders. Interstate 8.1% vs same-state 4.5%. |
| Peaks | Nov–Dec 2017: 10.3% late. Feb–Mar 2018: 16.6%. Other months: 4.2%. Volume was ~50% above normal in both windows, but the promised delivery time stayed at ~24 days. |
| Concentration | 98 sellers (3.3%) account for half of late orders. |

## Recommendations

### 1. Carrier lane review: Rio de Janeiro and the Northeast *(highest impact)*
- **Why:** carrier transit is the biggest gap, and these destinations hold the largest
  pools of late orders (RJ 1,495; Northeast 1,149).
- **What:** set transit-time SLAs per origin–destination lane; review carrier
  performance monthly; re-tender or add a second carrier on the worst lanes.
- **Measure:** RJ and Northeast late rate, average transit days by lane.

### 2. Seller ship-by SLA programme
- **Why:** a missed hand-off nearly quadruples late risk, and the problem sits in a short list.
- **What:** start with the 44-seller watchlist (`outputs/q12_seller_watchlist.csv`;
  4,972 orders, R$736k GMV, 758 late orders).
  - **19 seller-driven** (≥20% of orders miss ship-by): account-manager coaching,
    handling-time targets, escalation after two missed months.
  - **25 route-driven** (ship on time, still late): not a seller issue; route to the
    lane review in recommendation 1.
- **Measure:** % of orders shipped by the deadline, watchlist late rate.

### 3. Peak-season promise dates
- **Why:** in both peak windows volume rose ~50% but the promise didn't move, so the
  late rate rose 2.5–4x (from 4.2% to 10.3% and 16.6%).
- **What:** when weekly order volume runs well above normal, automatically add buffer
  days to the promised date, by region.
- **Trade-off:** longer promises can lower conversion. Test on Northeast orders first and
  compare conversion against late rate.
- **Measure:** peak-period late rate, checkout conversion.

### 4. Late-delivery early warning *(specified in Part 2)*
- **Why:** even 1–3 days late costs a full review star. Telling the customer before the
  promise breaks is cheaper than fixing the review afterwards.
- **What:** flag orders at risk (seller missed hand-off, long lane, peak period) and notify
  the customer and seller proactively.
- **Measure:** review score on flagged orders vs a control group.

## Expected impact

| Scenario | 1-star reviews avoided | Avg review |
|---|---|---|
| Today | – | 4.16 |
| Halve lateness | ~1,500 (16% of all 1-star) | 4.22 |
| Eliminate lateness | ~3,000 (32% of all 1-star) | 4.29 |

Customers whose first order arrived late came back less often (2.72% vs 3.51% repeat
rate). Repeat buying is rare on this platform, so treat that as directional, not a revenue forecast.

## Caveats
- The data doesn't say *why* Feb–Mar 2018 spiked. It hit every region, which points to
  network-wide carrier capacity rather than a single seller or lane. This is worth confirming
  with the logistics team.
- Orders with several sellers (1.3%) are attributed to the seller of the highest-priced item.
- Promised dates were shortened sharply in mid-2018 (to ~16 days in August), which reduces
  the buffer and could push lateness up; it should be monitored.
