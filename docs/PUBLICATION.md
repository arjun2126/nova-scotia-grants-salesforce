# Proposed GitHub publication — do not execute without approval

## Suggested repository

- Name: `nova-scotia-grants-salesforce`
- Description: "Independent Salesforce Administrator portfolio: grant intake, secure claim adjudication, funding safeguards, mock GL integration, and executive reporting. Fictional Nova Scotia demonstration."
- Visibility: public only after source/privacy, licensing and owner approval.
- Default branch: `main` for this new standalone repository. The original
  Gotcare-Ledger repository is not initialized, committed or pushed by these steps.
- Topics: `salesforce`, `salesforce-administrator`, `apex`, `salesforce-flow`,
  `lightning`, `grant-management`, `portfolio`.

## Recommended initial contents

Root `force-app/` matches deployed Nova source, including owner-created final Claim
page, dependencies and public-group definition. `proposals/kpi/` is an explicitly
undeployed nested project, excluded from root package directories. Include its
tests/manifest and proposal documentation without claiming it is live.

Include README, NOTICE, Salesforce DX configuration, minimal prospective scratch
definition, docs, screenshot guide, historical setup scripts with warnings and the
portfolio validator. Five owner-captured screenshots have been integrated into the
README. Select and add LICENSE only after the owner approves its terms.

Exclude `.git/` from any source copy, `.sf/`, `.sfdx/`, `.local/`, auth/session files,
environment files, private keys, logs, local `opencode.json`/tool configuration,
unrelated generated files and care-ledger source. No remote or Git repository has
been initialized here during this work.

## Safety and deployability review

- Native source conversion and 156-component check-only validation passed against
  the existing org; no clean-org installation is claimed.
- Persona assignments, licenses, group membership and Application record shares
  are intentionally not public deployment data.
- Dynamic dashboard source omits scratch-org owner/running-user values; no report
  or chart binding was changed.
- The local validator checks XML/JSON, links/images, expected structure, ignored
  artifacts and selected credential patterns. This is a limited pattern scan,
  not a guarantee or a historical Git secret audit.
- `git diff --check` is not applicable before Git initialization. A non-index
  whitespace check of the README passed; Git remains uninitialized.
- Run the validator before staging and inspect the exact staged diff. Do not
  publish screenshots containing personal usernames, tokens or auth URLs.
- Capacity correction and screenshots are complete. License choice and final
  publication approval remain separate gates.

## Exact commands, only after explicit approval

Open a terminal in the standalone directory. The following are a plan, not executed
work. Stop if Git detects an existing repository instead of initializing another.

```bash
python3 scripts/validate_portfolio.py
git init -b main
git add .gitignore README.md NOTICE.md sfdx-project.json config force-app docs scripts proposals
# Add LICENSE separately only after its terms have been approved.
git status --short
git diff --cached --check
git diff --cached --stat
git diff --cached
# Review all staged files, privacy and license status before the next command.
git commit -m "feat: add Nova Grants Salesforce portfolio"

gh auth status
gh repo create nova-scotia-grants-salesforce --public --source=. --remote=origin --push \
  --description "Independent Salesforce Administrator portfolio for fictional grant intake, secure adjudication, mock GL integration, and reporting."
gh repo edit --add-topic salesforce --add-topic salesforce-administrator \
  --add-topic apex --add-topic salesforce-flow --add-topic grant-management --add-topic portfolio
gh repo view --web
```

`gh repo create --push` creates the remote and publishes the commit. Do not run it
under a documentation-only or KPI-deployment approval. No user/credential values
are embedded in these commands. The authenticated GitHub account determines the
owner; confirm that account and intended visibility before running them.
