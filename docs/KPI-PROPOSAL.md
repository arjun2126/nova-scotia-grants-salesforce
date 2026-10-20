# Financial capacity KPI correction — deployed

**Status: deployed to `nova-grants-demo` and initialized for the isolated UAT Program.**

## What changed and why

The original `Capacity_Utilization__c` formula added disbursed dollars to committed
approved dollars. Because disbursements are a subset of approved commitments, the
field double-counted paid obligations.

The corrected definition is **current Approved Application commitments / Program
funding cap**. Disbursements continue to be reported separately through
`Disbursed_Amount__c` and the Disbursement ledger.

Only `Stage__c = Approved` contributes. Withdrawn/Rejected Applications no longer
count toward current commitments; their paid history remains in the ledger but is
not duplicated in the utilization percentage.

## Deployed components

| Component | Purpose |
| --- | --- |
| `Program__c.Capacity_Utilization__c` | Formula `IF(Funding_Cap__c > 0, Committed_Amount__c / Funding_Cap__c, 0)` with corrected description. |
| `ProgramCommitmentRollup` | Locks affected Programs, aggregates Approved Application amounts, and writes only changed `Committed_Amount__c` values in system mode. No approval or payment logic. |
| `ApplicationCommitmentRollup` | Trigger after insert/update/delete/undelete; recomputes old and new Programs when Stage, Approved Amount or Program changes. Skips reimbursement-only updates. |
| `ProgramCommitmentRollupTest` | Lifecycle, bulk, paid-overlap, zero-cap, overcommitment and seeded/UAT replica coverage. |

## Deployment and test evidence

- Source conflict on `Capacity_Utilization__c` resolved by retrieving live metadata,
  preserving unrelated settings, and reapplying only the approved formula and
description. Backup saved under `.local/kpi-live-field-backup/`.
- `sf project reset tracking --target-org nova-grants-demo` aligned source-tracking
  after reconciliation.
- Deployment ID `0AfRK00000uwl9a0AA`: **4 components deployed, 39 tests run, 0 failures.**
- KPI class/trigger coverage: **100%**.
- Full regression run ID `707RK0000BVzdPz`: **41 tests passed, 0 failures**, org-wide
  coverage **92%**.

## Initialization

Demo Approval Test (`DEMO-APPROVAL-2026`) was initialized from $0 to $1,000
committed. The deployment-time trigger also recalculated the isolated Program once
its live Approved Application total was verified at exactly $1,000. Three seeded
Programs already reconciled and were not mutated.

## Before/after reconciliation

| Program | Cap | Approved | Disbursed | Before % | After % |
| --- | ---: | ---: | ---: | ---: | ---: |
| Digital Adoption | 250,000 | 23,000 | 6,000 | 11.6 | 9.2 |
| Export Development | 500,000 | 80,000 | 16,000 | 19.2 | 16.0 |
| Productivity and Innovation Voucher | 150,000 | 15,000 | 6,000 | 14.0 | 10.0 |
| Demo Approval Test | 1,000 | 1,000 | 100 | 10.0 | 100.0 |

Financial preservation verified:
- `CLM-0006` remains Approved, $100 reimbursement, Disbursement Created.
- `DIS-0005` remains Synced, Payment Reference `DISB-a01RK00002nKnU0YAK`, External
  Transaction ID `MOCK-DISB-a01RK00002nKnU0YAK`.
- Application, Claim, Disbursement, report and dashboard metadata snapshots are
  unchanged except formula-derived percentages.

## Report/dashboard note

The existing dashboard’s fourth chart groups by **Program Status** and averages
`Capacity_Utilization__c`. That is an unweighted group mean, not a weighted
portfolio ratio.

To prevent the isolated Demo Approval Test Program from distorting the executive
view, the `Program Capacity Utilization` report now excludes
`Program_Code__c = DEMO-APPROVAL-2026`. The dashboard component still references
the same report and was not edited. After refreshing the dashboard as a viewer,
the **Active** bar shows the average of the three operational Programs
(approximately **11.7%**).

## Re-running validation

From the `proposals/kpi/` nested project:

```bash
sf project deploy start --dry-run --target-org nova-grants-demo \
  --manifest manifest/package.xml --test-level RunSpecifiedTests \
  --tests ProgramCommitmentRollupTest --tests ClaimAdjudicationServiceTest \
  --tests ClaimSubmissionAccessTest --tests NovaGrantsAgentActionsTest \
  --tests FinancialIntegrationQueueableTest --tests ScheduledFinancialAuditTest
```

## Remaining risks

- New Program locks on Application changes can cause contention under parallel load.
- Overcommitted Programs can exceed 100% utilization; the writer does not clamp.
- Direct edits to the derived cache are possible until the next relevant Application
  event triggers recalculation.
- Dashboard refresh and screenshot capture require browser access, which was
  unavailable during this session.

## Historical proposal

The original undeployed proposal and check-only validations are preserved under
`proposals/kpi/`. This document reflects the live state after approved deployment.
