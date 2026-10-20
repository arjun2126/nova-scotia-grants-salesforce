#!/usr/bin/env python3
"""Read-only source, documentation, and limited public-source safety checks."""

import json
import os
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
SKIP = {".git", ".sf", ".sfdx", ".local", "node_modules", "__pycache__", ".venv"}
NS = {"m": "http://soap.sforce.com/2006/04/metadata"}
EXPECTED_IMAGES = (
    "nova-grants-app.png", "executive-dashboard.png", "grant-application-flow.png",
    "claim-processing.png", "financial-reports.png",
)
CREDENTIAL_PATTERNS = {
    "Salesforce auth URL": r"force://[A-Za-z0-9_:.!@/+\-=]{25,}",
    "Salesforce session": r"00D[A-Za-z0-9]{12,15}![A-Za-z0-9_.]{20,}",
    "private key": r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----",
    "AWS access key": r"\bAKIA[0-9A-Z]{16}\b",
    "GitHub token": r"\bgh[pousr]_[A-Za-z0-9]{30,}\b",
    "personal email": r"\b[A-Za-z0-9._%+\-]+@(?:gmail|icloud|hotmail|outlook)\.com\b",
    "local home path": r"/Users/[A-Za-z0-9_\-]+/",
}


def main():
    errors = []
    files = []
    for directory, children, names in os.walk(ROOT):
        children[:] = [name for name in children if name not in SKIP]
        files.extend(Path(directory) / name for name in names)

    for path in files:
        relative = path.relative_to(ROOT)
        if path.suffix.lower() in {".png", ".jpg", ".jpeg", ".zip"}:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeError:
            errors.append(f"Review non-text artifact: {relative}")
            continue
        if path.name in {"opencode.json", "opencode.jsonc", ".env"}:
            errors.append(f"Remove local configuration from publication: {relative}")
        for name, pattern in CREDENTIAL_PATTERNS.items():
            if re.search(pattern, text):
                # Print only the rule/path, never the suspected secret or matched line.
                errors.append(f"Safety review required ({name}): {relative}")
        try:
            if path.suffix == ".xml":
                ET.fromstring(text)
            elif path.suffix == ".json":
                json.loads(text)
        except (ET.ParseError, json.JSONDecodeError) as exc:
            errors.append(f"Invalid structured source {relative}: {exc}")

        if path.suffix == ".md":
            rendered = re.sub(r"```.*?```", "", text, flags=re.S)
            for destination in re.findall(r"!?\[[^\]]*\]\(([^)]+)\)", rendered):
                target = destination.strip().strip("<>")
                parsed = urlsplit(target)
                if parsed.scheme or not parsed.path:
                    continue
                resolved = (path.parent / unquote(parsed.path)).resolve()
                if not resolved.is_relative_to(ROOT) or not resolved.exists():
                    errors.append(f"Broken/outside local link in {relative}: {target}")

    project = json.loads((ROOT / "sfdx-project.json").read_text())
    if project["name"] != "nova-scotia-grants-salesforce":
        errors.append("Incorrect standalone project name")
    if project["packageDirectories"] != [{"path": "force-app", "default": True}]:
        errors.append("Root package must not implicitly include undeployed proposals")

    source = ROOT / "force-app/main/default"
    for forbidden in ("Care_Plan__c", "Care_Claim__c", "Funding_Allocation__c", "Ledger_Entry__c"):
        if (source / "objects" / forbidden).exists():
            errors.append(f"Unrelated legacy object present: {forbidden}")
    if (source / "classes/CareLedgerService.cls").exists():
        errors.append("Unrelated care-ledger service present")

    page = ET.parse(source / "flexipages/Program_Claim_Record_Page.flexipage-meta.xml")
    components = [item.text for item in page.findall(".//m:componentName", NS)]
    if "force:detailPanel" not in components or "force:highlightsPanel" not in components:
        errors.append("Final Claim page lost details or highlights")
    if any("flowruntime" in name.lower() for name in components):
        errors.append("Duplicate embedded Flow remains on final Claim page")
    layout = ET.parse(source / "layouts/Claim__c-Program Claim Layout.layout-meta.xml")
    actions = [item.text for item in layout.findall(".//m:actionName", NS)]
    if "Claim__c.Adjudicate_Claim" not in actions:
        errors.append("Top-right adjudication action missing from Claim layout")
    dashboard = ET.parse(source / "dashboards/Nova_Grants_Dashboard/Nova_Grants_Overview.dashboard-meta.xml")
    if len(dashboard.findall(".//m:dashboardGridComponents", NS)) != 4:
        errors.append("Dashboard no longer contains four components")

    ignore = (ROOT / ".gitignore").read_text()
    for entry in (".sf/", ".sfdx/", ".local/", "opencode.json", ".env"):
        if entry not in ignore.splitlines():
            errors.append(f"Missing publication ignore rule: {entry}")
    pending = [name for name in EXPECTED_IMAGES if not (ROOT / "docs/screenshots" / name).is_file()]
    print(f"Checked {len(files)} source/documentation files (auth, snapshots and Git state excluded).")
    print("Screenshots pending: " + (", ".join(pending) if pending else "none"))
    print("License: owner selection/approval required before publication.")
    if errors:
        print("\n".join(errors))
        return 1
    print("PASS: XML/JSON, local links/rendered image paths, Nova scope, final Claim page/actions,")
    print("four-chart structure, ignore rules, and selected credential/privacy patterns.")
    print("Not a complete secret audit, browser test, or clean-org deployment proof.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
