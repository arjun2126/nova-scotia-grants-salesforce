# Genuine Salesforce screenshot capture guide

Images were supplied by the owner and reorganized so that each filename matches
its actual content. Unused originals are preserved in `.local/screenshots-originals/`.

| Filename | Actual page and persona | Visible evidence | Business capability |
| --- | --- | --- | --- |
| `nova-grants-app.png` | Programs list, Bailey Murphy | App tabs, four Programs, corrected capacity percentages | Native Lightning operating model |
| `executive-dashboard.png` | Nova Grants → Dashboards → Nova Grants Overview, Bailey Murphy | All four charts; Program Capacity Utilization **Active 11.7%** | Operational oversight with restricted access |
| `grant-application-flow.png` | Program Application record form, Administrator | Standard record layout with application fields | Application data model; production intake uses the `New_Grant_Application` Screen Flow |
| `claim-processing.png` | Adjudicate Claim action modal | Confirmation prompt listing claim-status, proof, program, funding and approval prerequisites | Verified reimbursement and guarded record action |
| `financial-reports.png` | Disbursement Ledger DIS-0005, Bailey Murphy | **Synced** GL status, `DISB-...` payment reference, `MOCK-...` external transaction ID | Simulated GL synchronization and ledger oversight |

## Privacy and accuracy caveats

- Several original captures display the user's email address and full name in the
  top-right corner. Hide personal menus, emails, and profile details before using
  these in a public repository or presentation.
- Record IDs and org URLs are visible in some captures. Crop unnecessary IDs from
  address bars and screenshots where possible.
- `grant-application-flow.png` shows the **standard Program Application record
  form**, not the custom `New_Grant_Application` Screen Flow. The README caption
  reflects this accurately; replace it with a true Screen Flow intake screenshot
  if you want to highlight guided applicant intake.
- Use only fictional demonstration data. No credentials or tokens may appear.
- A screenshot from one persona does not prove independent UAT by both personas.

## Integrating screenshots

Save PNGs under `docs/screenshots/` using the exact filenames above, then run:

```bash
python3 scripts/validate_portfolio.py
```

Missing expected images are reported as pending; any rendered image link to a
missing file is an error.
