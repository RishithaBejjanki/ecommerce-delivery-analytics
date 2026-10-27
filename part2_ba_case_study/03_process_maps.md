# 3. Process maps

## 3.1 Current state (as-is)
Nothing in today's process looks at an order between the seller notification and the customer complaint.

```mermaid
flowchart TD
    subgraph Customer
        A[Places order<br/>sees promised date] --> W{Arrived by<br/>promised date?}
        W -- No --> X[Contacts CS:<br/>'Where is my order?']
        W -- Yes --> R[Review request]
        LATE[Delivered late] --> R
        R --> RV[Leaves review<br/>1-star share: 7% on time, 70% at 8+ days late]
    end
    subgraph Seller
        B[Notified of order] --> C[Picks and packs<br/>no reminder]
        C --> D[Hands to carrier<br/>8.9% after ship-by deadline]
    end
    subgraph Carrier
        E[Transit<br/>late orders: 27.9 days avg] --> F[Delivers]
    end
    subgraph CS["Customer Service"]
        Y[Agent looks up order<br/>manually on carrier site] --> Z[Replies with<br/>best guess]
    end
    A --> B
    D --> E
    F --> W
    X --> Y
    Z --> LATE

    classDef pain fill:#fde3d9,stroke:#eb6834,color:#0b0b0b
    class C,D,E,X,Y,Z pain
```
*Orange = pain point.*

### Pain points
| # | Pain point | Evidence (Part 1) | Who feels it |
|---|---|---|---|
| P1 | Sellers get no reminder before the ship-by deadline | 8.9% of orders handed over late | Sellers, customers |
| P2 | A missed hand-off isn't flagged to anyone | Missed hand-off → 21.1% late vs 5.4% | Seller Success |
| P3 | No one watches orders in transit | Late orders spend 27.9 days with the carrier | Ops, carriers |
| P4 | The customer finds out the order is late before we do | 36.9% of 1-star reviews come from late orders | Customers, CS |
| P5 | CS investigates each case manually | Agent checks the carrier site order by order | CS |
| P6 | Carrier problems are anecdotal, not lane-level | RJ = 24% of late orders, Northeast 12.8% late, no lane report | Carrier Mgr |

## 3.2 Future state (to-be)
New steps are in **blue**. Numbers refer to the functional requirements in the [BRD](04_brd.md).

```mermaid
flowchart TD
    subgraph Customer
        A[Places order<br/>sees promised date] --> W{Arrives by<br/>promised date?}
        M[Gets proactive message<br/>with revised date range] --> W
        W --> R[Review request] --> RV[Leaves review]
    end
    subgraph Seller
        B[Notified of order] --> C[Picks and packs]
        N1[Reminder 24h before<br/>ship-by deadline<br/>FR-01] --> C
        C --> D[Hands to carrier]
    end
    subgraph System["Risk engine (new)"]
        S0{Handed over 24h<br/>before deadline?} -- No --> N1
        S1{Missed ship-by<br/>deadline?} -- Yes --> F1[Flag seller<br/>FR-02]
        D --> SC[Score risk at hand-off<br/>FR-04 to FR-06]
        SC --> T{Risk tier}
        T -- HIGH --> H[Create alert<br/>FR-07]
        T -- MEDIUM --> MD[Watch list<br/>re-score daily FR-06]
        T -- LOW --> L[No action]
        MD -- becomes HIGH --> H
    end
    subgraph Carrier
        E[Transit] --> FD[Delivers]
        ESC[Receives lane escalation<br/>FR-11, FR-12]
    end
    subgraph Ops["Ops / CS / Seller Success"]
        DB[Risk dashboard<br/>FR-13] 
        H --> CS1[CS case opened with reason<br/>FR-09]
        F1 --> AM[Account manager review<br/>FR-03]
        WK[Weekly pack: alerts,<br/>catch rate, reviews<br/>FR-15]
        DM[Ops can switch on<br/>disruption mode<br/>FR-14]
    end
    A --> B
    B --> S0
    C --> S1
    D --> E
    FD --> W
    H --> M
    H --> ESC
    H --> DB
    MD --> DB
    DM -.adds buffer days.-> SC

    classDef new fill:#dbe8fa,stroke:#2a78d6,color:#0b0b0b
    class N1,S0,S1,F1,SC,T,H,MD,M,ESC,DB,CS1,AM,WK,DM new
```

### What a HIGH alert looks like end to end
```mermaid
sequenceDiagram
    participant S as Seller
    participant E as Risk engine
    participant C as Customer
    participant CS as CS agent
    participant L as Carrier Mgr
    S->>E: Hands order to carrier (hand-off event)
    E->>E: days_left 9.4, expected 13.0 → slack -3.6 → HIGH
    E->>C: "Your order may arrive 2–6 days after the original date"
    E->>CS: Case opened with reason and revised dates
    E->>L: Lane SP→BA added to escalation queue
    Note over E: Re-scored daily until delivered
    C-->>CS: (If customer replies) agent already has context
```

## 3.3 Gap analysis
| Area | Current | Future | Gap to close | Requirement |
|---|---|---|---|---|
| Seller deadline | No reminder | Reminder 24h before; flag if missed | Reminder logic, seller notification channel | FR-01, FR-02, FR-03 |
| Risk visibility | None until complaint | Every order scored at hand-off and daily | Lane benchmarks, live signal, scoring job | FR-04 – FR-06 |
| Customer comms | Reactive (customer asks) | Proactive for HIGH risk | Message templates, consent check, A/B split | FR-07, FR-08, FR-10 |
| CS handling | Manual carrier look-up | Case pre-filled with reason and dates | CS case integration | FR-09 |
| Carrier management | Anecdotal | Lane-level escalation with evidence | Escalation queue and report | FR-11, FR-12 |
| Disruptions | No mechanism | Ops can add buffer days by region | Config screen | FR-14 |
| Measurement | Late % only | Catch rate, alert volume, review uplift | Weekly pack, A/B tracking | FR-15, FR-16 |
