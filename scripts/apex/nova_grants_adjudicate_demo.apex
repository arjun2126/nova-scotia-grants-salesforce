// Nova Scotia Economic Growth and Grant Management Platform
// Adjudicates the seeded submitted claims through ClaimAdjudicationService so the
// approval logic, disbursement creation, and GL integration path all run.
// Fictional demonstration data only.

List<Id> claimIds = new List<Id>();
for (Claim__c claim : [
    SELECT Id
    FROM Claim__c
    WHERE External_Key__c LIKE 'DEMO-CLM-%'
    AND Claim_Status__c = 'Submitted for Verification'
    ORDER BY External_Key__c
]) {
    claimIds.add(claim.Id);
}

List<ClaimAdjudicationService.Result> results = ClaimAdjudicationService.approveClaims(claimIds);

for (ClaimAdjudicationService.Result result : results) {
    System.debug(
        'Claim ' +
        result.claimId +
        ' success=' +
        result.success +
        ' status=' +
        result.status +
        ' amount=' +
        result.amount +
        ' disbursement=' +
        result.disbursementId +
        ' message=' +
        result.message
    );
}

System.debug('Nova Grants demo adjudication complete. Claims processed: ' + results.size());
