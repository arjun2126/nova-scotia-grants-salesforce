trigger ClaimAdjudicationGuard on Claim__c (before update) {
    if (!ClaimAdjudicationService.isAdjudicationWriteInProgress()) {
        Boolean canVerifyProof = ClaimAdjudicationService.hasAdjudicationPermission();
        for (Claim__c claim : Trigger.new) {
            Claim__c prior = Trigger.oldMap.get(claim.Id);
            Boolean terminalStatusChanged = claim.Claim_Status__c != prior.Claim_Status__c
                && (prior.Claim_Status__c == ClaimAdjudicationService.STATUS_APPROVED
                    || prior.Claim_Status__c == ClaimAdjudicationService.STATUS_DISBURSED
                    || claim.Claim_Status__c == ClaimAdjudicationService.STATUS_APPROVED
                    || claim.Claim_Status__c == ClaimAdjudicationService.STATUS_DISBURSED
                    || claim.Claim_Status__c == 'Rejected');
            if (terminalStatusChanged) {
                claim.Claim_Status__c.addError('Approval, disbursement, and rejection statuses can only be set by adjudication.');
            }

            if (claim.Approval_Date__c != prior.Approval_Date__c
                || claim.Reimbursement_Amount__c != prior.Reimbursement_Amount__c
                || claim.Disbursement_Created__c != prior.Disbursement_Created__c
                || claim.Rejection_Reason__c != prior.Rejection_Reason__c) {
                claim.addError('Adjudication-managed fields can only be changed by the claim adjudication service.');
            }

            if (claim.Proof_of_Payment_Verified__c != prior.Proof_of_Payment_Verified__c
                && (!canVerifyProof || prior.Claim_Status__c == ClaimAdjudicationService.STATUS_APPROVED
                    || prior.Claim_Status__c == ClaimAdjudicationService.STATUS_DISBURSED)) {
                claim.Proof_of_Payment_Verified__c.addError('Only an authorized claim reviewer can verify proof before adjudication.');
            }
        }
    }
}