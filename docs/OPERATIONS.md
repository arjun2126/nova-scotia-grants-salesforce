# Installation, deployment and operation

## What is validated

Root `force-app/` is a Nova-only snapshot synchronized with the demo org, including
the owner's final Claim Record Page and app assignment. No care-ledger component,
local auth state or diagnostic Next Button Check Flow is required.

Full root-source check-only `0AfRK00000uwyZq0AI` validated **156 components** and
34 test methods with zero failures. This proves metadata compatibility against
the **existing** org. It does not prove a fresh installation into an empty org:
no org was created, replaced or deleted for validation.

KPI changes are a separate nested proposal project under `proposals/kpi/`.
Do not include them in a root deployment until approved. Current root formula is
intentionally the deployed version, with its documented reporting defect.

## Environment prerequisites and non-packaged configuration

1. Use a Salesforce org with Lightning, Flow, Apex, custom reporting and a license
   supporting the custom objects and intended personas. Tests expect the standard
   profile named `Standard Platform User`. Profile/license availability in an
   independently provisioned target must be verified.
2. Use current Salesforce CLI and supported API 68.0. Project source API is 67.0;
   individual test/trigger metadata includes 68.0. Auth remains local, not in source.
3. Persona users, licenses, permission-set assignments, role assignments and public
   group membership are not deployed as user records. Assign `Nova_Grants_Admin`
   to the administrator and `Nova_Grants_Claims_Coordinator` to the reviewer.
4. `Nova_Grants_Reviewers` public-group definition is included; add intended users
   manually. Report/dashboard folders share View to that group. Group membership
   does not grant record Edit access.
5. Record-processing assignment is a targeted Application Read/Write share. Claim
   access inherits from it. Manual shares may be removed by ownership changes.
   Never share every application or grant Modify All to bypass assignment.
6. Configure `Nova_Grants_Setting__c` org defaults in mock mode with no real endpoint.
   Blank endpoint also defaults to mock. No remote credential or financial endpoint
   is required or bundled.
7. The dashboard is dynamic (`LoggedInUser`). Its org-specific owner/running-user
   fields are omitted in portable source; viewers still need folder and data access.
8. No scheduled Apex audit job was found. Configure a schedule separately only if
   approved; implementation tests do not constitute a running audit schedule.

These are the remaining clean-org installation prerequisites. Metadata users/group
membership, manual shares and demonstration data cannot be inferred or silently
created by deployment. Do not claim a one-command production installation.

## Safe validation against the existing org

```bash
sf project deploy start --dry-run --target-org nova-grants-demo \
  --source-dir force-app --test-level RunSpecifiedTests \
  --tests ClaimAdjudicationServiceTest --tests ClaimSubmissionAccessTest \
  --tests NovaGrantsAgentActionsTest --tests FinancialIntegrationQueueableTest \
  --tests ScheduledFinancialAuditTest

sf apex run test --target-org nova-grants-demo \
  --tests ClaimAdjudicationServiceTest --tests ClaimSubmissionAccessTest \
  --tests NovaGrantsAgentActionsTest --tests FinancialIntegrationQueueableTest \
  --tests ScheduledFinancialAuditTest --code-coverage --result-format human --wait 15
```

Every Salesforce command uses the explicit target. Neither command changes default
org or business data. Tests use isolated records. Check-only validation is not
deployment authorization. If source tracking reports a conflict, inspect the live
metadata and compare before overriding anything.

For an approved independent installation, deploy root source only after reviewing
these dependencies. Preserve schema/service/Flow/action/report-type/report/dashboard
dependencies as one reviewed package or in that order. Do not deploy the historical
care-ledger workspace or blindly include `proposals/`.

## Data setup and preservation

The existing demo already has seed and UAT records. Do not run reset scripts there.
`scripts/apex/nova_grants_seed.apex` and `nova_grants_adjudicate_demo.apex` are retained
historical setup artifacts, not safe reset tooling for final statuses. Upserts can
conflict with guards or reset review/financial state. They require review before
use in any separate authorized installation.

Intake program choices reference fictional codes `DAP-DEMO`, `EDP-DEMO`, and
`PIVP-DEMO`; an independent installation needs matching Active programs. Original
parameters are examples, not official program terms.

For this interview use Approved CLM-0006 and Synced DIS-0005 read-only. Never reset,
reapprove or create a replacement disbursement for that claim. Any future live
write demonstration needs separate isolated records and deliberate owner approval.

## UI source synchronization

`Program_Claim_Record_Page` was retrieved after the owner removed the embedded
Flow. It retains `force:detailPanel`, highlights and related/activity tabs; no
`flowruntime` component remains. `Nova_Grants` retains the app-specific desktop
Claim override, and the Claim layout retains Edit, Delete and Adjudicate Claim.
Never replace this page with an older local draft.

C1 headings and intake instructions are already deployed and synchronized. Final
Home redesign and extra branding are not included. Browser outcome remains owner
evidence; metadata presence alone is not an independent UI pass.

## Pending financial correction

See [KPI proposal](KPI-PROPOSAL.md). Only after approval should its four components
and the explicitly authorized isolated derived-total initialization be executed.
Seeded Program balances and paid financial records must not be edited. Existing
reports/dashboard bindings are preserved by that proposal.

## Publication hygiene

Run `python3 scripts/validate_portfolio.py` before staging. Ignore `.sf/`, `.sfdx/`,
`.local/`, environment files, tool configuration, logs and keys. Baseline snapshots
and diagnostic artifacts stay in `.local/`, never Git. No credentials, memberships
or personal user emails are needed in published examples. See [publication plan](PUBLICATION.md).
