# Completed claim-access and financial-processing repairs

Historical P0 repairs are deployed. They are not pending approval or proposed
changes in this portfolio completion cycle.

- Missing Application Edit sharing caused the coordinator's Draft Claim Save
  failure despite correct CRUD/FLS. APP-0007 received one manual Read/Write share
  to Bailey; CLM-0006 inherited Edit. No global OWD/Modify All change was needed.
- Restricted-persona tests exposed ledger DML and Program-total write failures.
  Scoped service/worker changes made financial DML explicit, retained the custom
  permission and Claim Edit gate, and used a private Program-total writer.
- Worker processes only Pending/Retrying IDs, writing synchronization fields and
  error logs rather than accepting generic field values.
- Admin permission set explicitly gained the adjudication custom permission;
  coordinator retained its grant. Flow default context is restored. Custom
  permission assignment, not a guessed system-context bypass, is the confirmed
  authorization requirement.
- Admin test setup was separated from business-record DML after a mixed-DML
  regression. Latest five-suite run reports 36 passed, zero failed, 91% coverage.

Owner browser UAT confirms CLM-0006 Approved, invoice 200, reimbursement 100,
DIS-0005 Synced and no duplicate on Already processed. The top-right action has
displayed its result, and the temporary embedded Flow was removed by the owner.
Do not imply both personas independently completed browser approval.

Deployment evidence: P0 `0AfRK00000uwMDj0AM`; C1/Flow `0AfRK00000uwePp0AI`;
authorization `0AfRK00000uwgLB0AY`; test-only follow-up `0AfRK00000uwgjN0AQ`.
Read [validation](VALIDATION.md) for current evidence. Financial capacity is a
different, still-undeployed [proposal](KPI-PROPOSAL.md).
