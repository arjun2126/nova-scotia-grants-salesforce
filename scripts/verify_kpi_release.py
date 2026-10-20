#!/usr/bin/env python3
"""Capture read-only financial release snapshots and reject unexpected changes."""

import argparse
import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
SNAPSHOTS = ROOT / ".local"
QUERIES = {
    "programs": "SELECT Id, Name, Program_Code__c, Funding_Cap__c, Co_Pay_Percentage__c, Program_Status__c, Committed_Amount__c, Disbursed_Amount__c, Capacity_Utilization__c, LastModifiedDate FROM Program__c ORDER BY Id",
    "applications": "SELECT Id, Name, Account__c, Program__c, Stage__c, Requested_Amount__c, Approved_Amount__c, Reimbursed_Amount__c, LastModifiedDate FROM Application__c ORDER BY Id",
    "claims": "SELECT Id, Name, Application__c, Claim_Status__c, Proof_of_Payment_Verified__c, Vendor_Invoice_Amount__c, Reimbursement_Amount__c, Disbursement_Created__c, Approval_Date__c, LastModifiedDate FROM Claim__c ORDER BY Id",
    "disbursements": "SELECT Id, Name, Claim__c, Approved_Amount__c, Payment_Reference__c, GL_Sync_Status__c, GL_Sync_Attempts__c, External_Transaction_ID__c, Audit_Flagged__c, LastModifiedDate FROM Disbursement__c ORDER BY Id",
    "approved_totals": "SELECT Program__c, SUM(Approved_Amount__c) approved FROM Application__c WHERE Stage__c = 'Approved' GROUP BY Program__c",
    "reports": "SELECT Id, DeveloperName, LastModifiedDate FROM Report WHERE FolderName = 'Nova_Grants_Reports' ORDER BY Id",
    "dashboard": "SELECT Id, DeveloperName, LastModifiedDate FROM Dashboard WHERE DeveloperName = 'Nova_Grants_Overview'",
}


def query(soql):
    result = subprocess.run(
        ["sf", "data", "query", "--target-org", "nova-grants-demo", "--query", soql, "--json"],
        check=True, capture_output=True, text=True, cwd=ROOT,
    )
    records = json.loads(result.stdout)["result"]["records"]
    return sorted(
        [{k: v for k, v in record.items() if k != "attributes"} for record in records],
        key=lambda record: json.dumps(record, sort_keys=True),
    )


def capture(phase):
    path = SNAPSHOTS / f"kpi-release-{phase}.json"
    if path.exists():
        raise RuntimeError(f"Snapshot already exists; preserve original baseline: {path.name}")
    snapshot = {name: query(soql) for name, soql in QUERIES.items()}
    SNAPSHOTS.mkdir(exist_ok=True)
    path.write_text(json.dumps(snapshot, indent=2) + "\n")
    print(f"Captured {path.name}; snapshots stay ignored and local.")
    for program in snapshot["programs"]:
        print(program["Name"], "cap", program["Funding_Cap__c"],
              "committed", program["Committed_Amount__c"], "disbursed", program["Disbursed_Amount__c"],
              "capacity", program["Capacity_Utilization__c"])


def compare(phase):
    before = json.loads((SNAPSHOTS / "kpi-release-before.json").read_text())
    after = json.loads((SNAPSHOTS / f"kpi-release-{phase}.json").read_text())
    for name in QUERIES:
        if name != "programs":
            assert before[name] == after[name], f"Unexpected {name} change; STOP"
    initial = {record["Id"]: record for record in before["programs"]}
    final = {record["Id"]: record for record in after["programs"]}
    assert initial.keys() == final.keys(), "Unexpected Program insertion/deletion; STOP"
    totals = {row["Program__c"]: row["approved"] for row in after["approved_totals"]}
    for program_id, prior in initial.items():
        current = dict(final[program_id])
        isolated = prior["Program_Code__c"] == "DEMO-APPROVAL-2026" and prior["Name"] == "Demo Approval Test"
        expected_committed = 1000 if isolated and phase == "after" else prior["Committed_Amount__c"]
        assert current["Committed_Amount__c"] == expected_committed, "Unexpected commitment change; STOP"
        cap = current["Funding_Cap__c"] or 0
        expected_capacity = round(100 * (expected_committed or 0) / cap, 2) if cap > 0 else 0
        assert current["Capacity_Utilization__c"] == expected_capacity, "Unexpected formula result; STOP"
        expected = dict(prior)
        current.pop("Capacity_Utilization__c")
        expected.pop("Capacity_Utilization__c")
        if isolated and phase == "after":
            assert totals[program_id] == 1000, "Isolated approved total drifted; STOP"
            current.pop("Committed_Amount__c")
            expected.pop("Committed_Amount__c")
            current.pop("LastModifiedDate")
            expected.pop("LastModifiedDate")
        assert current == expected, f"Unexpected stored Program change for {prior['Name']}; STOP"
    print("PASS: only authorized isolated commitment/audit and formula-derived values differ.")
    print("Application, Claim, Disbursement, report and dashboard snapshots are unchanged.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("operation", choices=("capture", "compare"))
    parser.add_argument("phase", choices=("before", "formula", "after"))
    args = parser.parse_args()
    if args.operation == "capture":
        capture(args.phase)
    else:
        assert args.phase != "before", "Choose formula or after for comparison"
        compare(args.phase)
