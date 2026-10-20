# Nova Grants — Agent Grounding

> Historical design artifact, not a deployed agent. Settlement and automatic
> Disbursed transitions mentioned below are not implemented financial operations.
> Use the [current architecture](../ARCHITECTURE.md) for actual safeguards,
> non-mutating outcomes and the separate mock synchronization state.

Fictional demonstration data only. Nova Scotia Economic Growth and Grant
Management Platform.

## Objects

- `Program__c` — funding program with a funding cap, co-pay percentage, and
  Active / Suspended / Closed status. Fields include `Program_Code__c`
  (required, unique), `Funding_Cap__c`, `Co_Pay_Percentage__c`,
  `Committed_Amount__c`, `Disbursed_Amount__c`.
- `Application__c` — grant application from a business to a program. Stage
  moves Draft, Submitted, Under Review, Approved, Rejected, Withdrawn.
  `Requested_Amount__c`, `Approved_Amount__c`, `Reimbursed_Amount__c`.
- `Claim__c` — reimbursement claim on an approved application. Status moves
  Draft, Submitted for Verification, Approved, Rejected, Disbursed. Requires
  proof of payment for approval.
- `Disbursement__c` — payment created when a claim is approved. Tracks
  `GL_Sync_Status__c`: Pending, Synced, Retrying, Failed.
- `Impact_Metric__c` — post-funding outcome measures.
- `Error_Log__c` — integration failures and retries.

## Adjudication rules

A claim can be approved only when all of the following hold:

- status is `Submitted for Verification`;
- `Proof_of_Payment_Verified__c` is true;
- the claim has a vendor invoice amount greater than zero;
- the parent program is `Active`;
- the parent application has remaining approved funding.

Reimbursement amount is the invoice amount multiplied by the program co-pay
percentage, rounded half-up, capped at the remaining approved funding on the
application. A disbursement is created with a unique payment reference, and the
claim moves to `Approved` (then `Disbursed` after settlement).

## Common questions

- Why can I not approve this claim? Check status, proof of payment, remaining
  funding, and program status.
- Where does the disbursement come from? Approved claims create a
  `Disbursement__c` with a `Pending` general ledger sync status.
- What do the sync statuses mean? `Synced` means the mock ledger accepted the
  payment. `Retrying` means the call is being retried. `Failed` means all
  retries were exhausted and an `Error_Log__c` was written.
