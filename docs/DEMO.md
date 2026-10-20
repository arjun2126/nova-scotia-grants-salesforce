# Ten-minute administrator interview demonstration

Use the existing verified records **read-only**. Do not reset, resubmit or
re-adjudicate CLM-0006. Separate browser evidence for both personas is not available;
describe persona tests accurately. All data/program terms are fictional.

| Time | Demonstration | Concise talking points and fallback |
| --- | --- | --- |
| 0:00–1:00 | Open Nova Grants app and navigation | "This independent demo connects grant intake, verified claims, controlled reimbursements and oversight. It is not an official government implementation." If session fails, use captured app/dashboard images. |
| 1:00–2:00 | Open intake form without submitting | Explain fictional business number, Account reuse, program choice and CAD request. Do not click Next merely for presentation. If Flow fails, use its screenshot and existing Application. |
| 2:00–3:00 | APP-0007 and five-object model | Show Account/Program links, Approved ceiling of 1,000 and reimbursed total 100. Distinguish manual review from automatic approval. Impact Metrics belong to Account. |
| 3:00–4:00 | Claims Coordinator security | Explain permission sets/FLS versus Private Application sharing. A targeted parent Edit share enabled the assigned Claim without Modify All. Custom permission is explicitly assigned to Admin and Coordinator. |
| 4:00–5:00 | CLM-0006 Details and top-right action presence | Show Approved, proof verified, invoice 200, reimbursement 100, protected payout fields. Explain confirmation and result flow; do not execute it again. No embedded duplicate Flow remains. Use captured result evidence if available. |
| 5:00–6:00 | DIS-0005 | Explain 200 × 50% = 100, one ledger record and unique `DISB-...` payment reference. Status is Synced. `MOCK-...` is the external transaction ID, not the payment reference. No money or live GL. |
| 6:00–7:00 | Duplicate and funding safeguards | Show existing Already processed evidence and test suite. Explain Application remainder, live Program cap check, locks, unique reference and rollback. Do not manufacture another payout. |
| 7:00–8:00 | Financial reports | Show grouped requested/approved/reimbursed totals, claim statuses and GL states. Explain restricted reporting-folder View access. If session fails, use actual report screenshot. |
| 8:00–9:00 | Executive dashboard and economic outcomes | Show four charts; identify value versus count. Capacity now reflects corrected approved commitments/cap after deployment; refresh the dashboard to render updated values. Show a dated Account-level Impact Metric; do not claim actual economic impact or an impact dashboard. |
| 9:00–10:00 | Architecture, tests and close | "Native Lightning/Flow handles the process. Focused Apex handles locked financial transactions, idempotency and privileged writes. Latest deployed regression: 36 passed, 92% org-wide coverage. KPI correction is deployed and initialized. Agentforce is not implemented." |

## Likely hiring-panel questions

**Why Apex instead of only Flow?**
Flow handles intake/confirmation and an owner alert. Apex centralizes locking,
funding math, transaction rollback and ordinary duplicate protection so UI/API
paths cannot implement competing payout rules.

**Why did Edit fail despite object Edit permission?**
CRUD is not record sharing. The Claim inherits its Private Application master;
parent Edit access was missing. One application share fixed assignment access.

**Does system mode authorize every user?**
No. Custom permission and actual Claim Edit checks still gate the service before
privileged writes. Admin profile alone did not automatically grant that custom
permission. Row sharing, FLS and business authorization are distinct layers.

**How do you avoid duplicates or partial updates?**
Unique payment reference, processed-status checks, row locks and a transaction
savepoint. A repeated approved Claim returns the existing result. Non-duplicate
errors are not reported as success. This is not a parallel-load certification.

**Why was capacity reporting corrected?**
The original formula double-counted paid obligations by adding disbursements to
commitments. The deployed correction defines approved commitments/cap and
synchronizes the cache on Application lifecycle events. Disbursements are still
shown separately in `Disbursed_Amount__c` and the Disbursement ledger.

**Is the integration real?**
No. Queueable Apex simulates GL outcomes, retries and logging. A real adapter needs
credential management, external idempotency/reconciliation and operational review.

**What would you productionize next?**
Approved KPI synchronization, assignment automation, explicit rejection,
immutable ledger controls, aggregate visibility review, bulk/concurrency tests,
and a credential-managed integration. Not speculative AI features.

## Rehearsal and fallback

- Prepare admin and coordinator sessions, with no credentials in screenshots.
- Keep record IDs and login context out of the public presentation where unnecessary.
- If the browser/Flow fails, show genuine screenshots and automated evidence;
  do not change permissions or repair live in the interview.
- The KPI correction is deployed and the executive dashboard report excludes the
  isolated Demo Approval Test Program; refresh the dashboard before presenting the
  capacity chart. Expect the Active bar at approximately 11.7%. Never describe
  capacity percentages as reconciled available cash.
- Finish on business value and administrator decisions, not an unapproved deployment.
