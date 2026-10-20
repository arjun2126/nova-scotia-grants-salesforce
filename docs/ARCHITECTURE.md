# Nova Grants architecture

## Data model and platform

Nova Grants uses native Lightning, Screen Flows, record-triggered Flow, Apex,
permission sets, a custom permission, sharing, custom report types and dashboards.
No custom frontend framework or Agentforce runtime is required.

| Object | Role and relationships |
| --- | --- |
| Account | Standard Business Account; Application lookup parent and Impact Metric master. |
| Program__c | Funding cap, percentage, employee thresholds and program status; Application lookup parent. |
| Application__c | Requested/approved/reimbursed amounts and lifecycle stage; lookups to Business and Program; Private sharing. |
| Claim__c | Invoice, verification and adjudication snapshot; master-detail to Application; Controlled by Parent. |
| Disbursement__c | Unique payment reference, amount and integration state; master-detail to Claim. |
| Impact_Metric__c | Dated jobs/export outcomes; master-detail to Account, not Application. |
| Error_Log__c | Supporting operational errors with text record reference. |
| Nova_Grants_Setting__c | Hierarchy setting for mock mode, endpoint, attempts limit and GL account code. |

## Execution paths

```text
New_Grant_Application Screen Flow
  -> find/create Business -> find active Program -> Submitted Application

Owner shares assigned Application with coordinator
  -> user-mode Claim submission and proof verification
  -> top-right Claim Quick Action -> Adjudicate_Grant_Claim
  -> NovaGrantsAgentActions.adjudicateClaims(List<ClaimInput>)
  -> ClaimAdjudicationService.approveClaims(List<Id>) / approveClaim(Id)
  -> Disbursement + Claim/Application/Program total updates
  -> Queueable mock synchronization / retry / error log
```

The Adjudication Flow accepts String input `recordId` and maps it to invocable
`claimId`; it displays status, message, success and reimbursement outputs. It does
not directly update financial fields. The retrieved Claim record page contains
details/highlights and no embedded Flow. The Nova Grants app retains the owner's
app-specific assignment to that page.

Intake reuses Accounts by illustrative business number and creates a Submitted
Application. Eligibility/document review and Application approval are manual
business steps, not automatic underwriting. Intake can create an Account before
it discovers that a Program is unavailable; the screen copy acknowledges that.

## Security and transaction boundaries

Both intended personas have `Nova_Grants_Adjudicate_Claims` through their respective
permission sets. `FeatureManagement.checkPermission` evaluates user authorization;
system-mode DML or an administrator profile is not a substitute for assigning the
custom permission. Earlier speculation that the Flow run mode itself explained
Bailey's permission result is not established evidence. The confirmed missing grant
was on the Admin permission set; both assignments are now verified.

The service retains `with sharing` queries and explicitly checks Claim Edit access.
Financial DML uses explicit system mode only after authorization, record access,
eligibility, locks and cap checks. A private `without sharing` writer changes only
the computed Program Disbursed total. It is not an externally callable API.

`ClaimAdjudicationGuard` blocks direct terminal-status, reimbursement, approval-date,
disbursement-created and rejection-reason updates. It permits the service's scoped
write flag and authorized proof verification before a final status. The coordinator
has no Disbursement Create/Edit, Program Edit, Modify All or admin grant.

The Queueable's inputs are record IDs only. Its query restricts work to Pending or
Retrying disbursements; caller-provided amounts/field maps are not accepted. It writes
integration-state fields and error logs in system mode. There is no `@AuraEnabled`,
REST or invocable worker method, and the coordinator's enabled Apex surface is the
guarded service/adapter. Trusted Apex can enqueue it; that is not a user-facing
generic update API. Production retry authorization and external reconciliation need
a broader operational design before any real GL connection.

## Calculation and financial integrity

```text
applicationRemaining = approvedAmount - reimbursedAmount
reimbursement = min(round(invoiceAmount * percentage / 100, 2), applicationRemaining)
liveCommitments = SUM(Approved_Amount__c for Approved Applications under the Program)
projectedDisbursed = Program.Disbursed_Amount__c + reimbursement
programExposure = MAX(liveCommitments, projectedDisbursed)
```

The service locks Application, Program and Claim. The shared Program lock serializes
claim processing across Applications. Missing/nonpositive cap or missing percentage
cannot silently create a full payout; zero percentage does not default to 100%.

Unique payment references and repeat checks prevent ordinary duplicate insertion.
Only confirmed duplicate DML can take the duplicate path. Other failures return
System error; financial writes after the savepoint roll back together. Failed
approval attempts do not become business rejection. Explicit rejection is out of
scope for this submission.

`Payment_Reference__c` is `DISB-` plus Claim external key or ID. Mock external
transaction IDs are `MOCK-` plus that reference. The two identifiers are not the
same field. No payment or live financial connection is implemented.

## Reporting and proposed KPI synchronization

The deployed capacity formula still adds cached commitments and disbursed dollars.
It is a known defect, not the calculation used to authorize payouts. Four current
reports and charts are otherwise owner-verified and remain unchanged.

The isolated [KPI proposal](KPI-PROPOSAL.md) uses current Approved commitments/cap
and maintains the commitment cache on all relevant Application lifecycle events.
Withdrawal/rejection removes an Application from this metric even if it has
historical payments; paid dollars remain visible separately. It is therefore
**current approved commitments**, not total lifetime expenditure or authoritative
remaining spendable cash. No proposal component is deployed yet.

## Operational automation

`Application_Low_Budget_Alert` creates an owner Task on crossing below 25% remaining
Application approval. `ScheduledFinancialAudit` can flag stale unsynced records;
no active scheduled Apex audit job was found. Its implementation is tested,
but an actual schedule is not claimed.

## Known limitations

- Current capacity display is defective until the separately approved proposal
  and isolated cache initialization are applied.
- Browser UAT supports the reported lifecycle, not independent successful runs
  for both personas. Intake final full-browser rehearsal remains separate.
- Verification is a reviewer's attestation, not automated document analysis or
  a four-eyes control. Impact Metrics are business-level observations, not causation.
- Claim update guards are not a complete immutable-ledger policy for every insert,
  deletion, privileged administrator and integration path.
- Direct Application approvals do not reserve funding before approval under a
  common cap service; live overcommitment blocks payouts but is not prevented at
  Application review time. The KPI proposal reports overcommitment above 100%.
- Live financial aggregation uses service sharing; intended reviewers currently
  have View All. A future narrower visibility model needs aggregate review.
- Parallel transactions have not been stress-tested. List processing is sequential,
  not a bulk-import engine. Locks can produce retryable contention errors.
- Mock integration has no real authentication, payment execution, external
  reconciliation or production retry-backoff design.
- Existing View Setup on the standard coordinator profile was not changed.
- Home redesign and Agentforce are not implemented. Historical AI prompt documents
  are design artifacts only.
- Existing seed scripts are not safe reset tools for already adjudicated records.
- Clean-org installation has not been executed; dependency validation used the
  existing org. See [operations](OPERATIONS.md) for exact environment dependencies.
