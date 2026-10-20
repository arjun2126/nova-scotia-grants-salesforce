public with sharing class ClaimAdjudicationService {
    // This service performs privileged financial DML for authorized reviewers who lack CRUD/FLS on ledger records.
    // Public entry points require the dedicated custom permission; with sharing still enforces row-level access.
    public static final String STATUS_SUBMITTED = 'Submitted for Verification';
    public static final String STATUS_APPROVED = 'Approved';
    public static final String STATUS_DISBURSED = 'Disbursed';
    public static final String RESULT_ALREADY_PROCESSED = 'Already processed';
    public static final String RESULT_NOT_ELIGIBLE = 'Not eligible for approval';
    public static final String RESULT_REQUIRES_REVIEW = 'Requires correction or review';
    public static final String RESULT_SYSTEM_ERROR = 'System error';
    public static final String RESULT_UNAUTHORIZED = 'Unauthorized';

    @TestVisible
    private static Boolean adjudicationWriteInProgress = false;
    @TestVisible
    private static Boolean authorizationOverrideForTest;

    public static Boolean isAdjudicationWriteInProgress() {
        return adjudicationWriteInProgress;
    }

    public static Boolean hasAdjudicationPermission() {
        if (Test.isRunningTest() && authorizationOverrideForTest != null) {
            return authorizationOverrideForTest;
        }
        return FeatureManagement.checkPermission('Nova_Grants_Adjudicate_Claims');
    }

    public class Result {
        @AuraEnabled public Id claimId;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String status;
        @AuraEnabled public Id disbursementId;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String message;
    }

    @AuraEnabled
    public static List<Result> approveClaims(List<Id> claimIds) {
        if (claimIds == null || claimIds.isEmpty()) {
            throw new NovaGrantsException('At least one claim id is required.');
        }

        List<Result> results = new List<Result>();
        for (Id claimId : claimIds) {
            results.add(approveClaim(claimId));
        }
        return results;
    }

    @AuraEnabled
    public static Result approveClaim(Id claimId) {
        if (!isAuthorized()) {
            return outcome(claimId, false, RESULT_UNAUTHORIZED, 'You are not authorized to adjudicate claims.');
        }
        if (claimId == null) {
            return outcome(null, false, RESULT_NOT_ELIGIBLE, 'A claim id is required.');
        }

        try {
            List<Claim__c> initialClaims = [
                SELECT Id, Application__c
                FROM Claim__c
                WHERE Id = :claimId
                LIMIT 1
            ];
            if (initialClaims.isEmpty() || initialClaims[0].Application__c == null) {
                return outcome(claimId, false, RESULT_NOT_ELIGIBLE, 'Claim or application was not found.');
            }
            UserRecordAccess claimAccess = [
                SELECT RecordId, HasEditAccess FROM UserRecordAccess
                WHERE UserId = :UserInfo.getUserId() AND RecordId = :claimId
            ];
            if (!claimAccess.HasEditAccess) {
                return outcome(claimId, false, RESULT_UNAUTHORIZED,
                    'You need edit access to this claim before adjudication.');
            }

            Application__c application = [
                SELECT Id, Approved_Amount__c, Reimbursed_Amount__c, Program__c
                FROM Application__c
                WHERE Id = :initialClaims[0].Application__c
                FOR UPDATE
            ];
            if (application.Program__c == null) {
                return outcome(claimId, false, RESULT_REQUIRES_REVIEW, 'The application has no funding program.');
            }

            Program__c program = [
                SELECT Id, Funding_Cap__c, Disbursed_Amount__c,
                    Co_Pay_Percentage__c, Program_Status__c
                FROM Program__c
                WHERE Id = :application.Program__c
                FOR UPDATE
            ];

            Claim__c claim = [
                SELECT Id, Claim_Status__c, Vendor_Invoice_Amount__c,
                    Proof_of_Payment_Verified__c, Sector__c, External_Key__c,
                    Application__c
                FROM Claim__c
                WHERE Id = :claimId
                FOR UPDATE
            ];

            String paymentReference = paymentReferenceFor(claim);
            if (claim.Claim_Status__c == STATUS_APPROVED || claim.Claim_Status__c == STATUS_DISBURSED) {
                return alreadyProcessed(claim, paymentReference);
            }
            if (claim.Claim_Status__c != STATUS_SUBMITTED) {
                return outcome(claimId, false, RESULT_NOT_ELIGIBLE,
                    'Only claims with status "' + STATUS_SUBMITTED + '" can be approved.');
            }
            if (claim.Proof_of_Payment_Verified__c != true) {
                return outcome(claimId, false, RESULT_REQUIRES_REVIEW, 'Proof of payment must be verified first.');
            }
            if (program.Program_Status__c != 'Active') {
                return outcome(claimId, false, RESULT_NOT_ELIGIBLE, 'The funding program is not active.');
            }

            List<Disbursement__c> existing = [
                SELECT Id, Claim__c, Approved_Amount__c
                FROM Disbursement__c
                WHERE Payment_Reference__c = :paymentReference
                LIMIT 1
            ];
            if (!existing.isEmpty()) {
                if (existing[0].Claim__c == claim.Id) {
                    return outcome(claimId, false, RESULT_SYSTEM_ERROR,
                        'An existing disbursement conflicts with the claim status. Reconcile the claim before retrying.');
                }
                return outcome(claimId, false, RESULT_SYSTEM_ERROR,
                    'Payment reference is already assigned to another claim.');
            }

            Decimal remainingApplication = valueOrZero(application.Approved_Amount__c)
                - valueOrZero(application.Reimbursed_Amount__c);
            if (remainingApplication <= 0) {
                return outcome(claimId, false, RESULT_REQUIRES_REVIEW,
                    'No remaining approved application funding is available.');
            }
            if (program.Co_Pay_Percentage__c == null) {
                return outcome(claimId, false, RESULT_REQUIRES_REVIEW,
                    'Program co-pay percentage is missing; claim requires review.');
            }
            Decimal copay = program.Co_Pay_Percentage__c;
            Decimal reimbursement = (valueOrZero(claim.Vendor_Invoice_Amount__c) * copay / 100)
                .setScale(2, System.RoundingMode.HALF_UP);
            if (reimbursement > remainingApplication) {
                reimbursement = remainingApplication;
            }
            if (reimbursement <= 0) {
                return outcome(claimId, false, RESULT_REQUIRES_REVIEW, 'Computed reimbursement is zero.');
            }

            Decimal projectedDisbursed = valueOrZero(program.Disbursed_Amount__c) + reimbursement;
            AggregateResult approvedCommitments = [
                SELECT SUM(Approved_Amount__c) totalApproved
                FROM Application__c
                WHERE Program__c = :program.Id
                AND Stage__c = 'Approved'
            ];
            // Program.Committed_Amount__c has no current writer; use live approved Applications as commitment source.
            Decimal committedFromApplications = (Decimal) approvedCommitments.get('totalApproved');
            Result capOutcome = checkFundingCap(
                program.Funding_Cap__c,
                committedFromApplications,
                program.Disbursed_Amount__c,
                reimbursement
            );
            if (capOutcome != null) {
                capOutcome.claimId = claimId;
                return capOutcome;
            }

            Disbursement__c disbursement = new Disbursement__c(
                Claim__c = claim.Id,
                Approved_Amount__c = reimbursement,
                Payment_Reference__c = paymentReference,
                GL_Sync_Status__c = NovaGrantsConfig.INTEGRATION_STATUS_PENDING,
                GL_Sync_Attempts__c = 0,
                GL_Sync_Requested__c = System.now(),
                Audit_Flagged__c = false,
                Sector__c = claim.Sector__c
            );

            Savepoint sp = Database.setSavepoint();
            try {
                Database.insert(disbursement, AccessLevel.SYSTEM_MODE);
            } catch (DmlException dmlEx) {
                Database.rollback(sp);
                if (isDuplicateValue(dmlEx)) {
                    return alreadyProcessed(claim, paymentReference);
                }
                return outcome(claimId, false, RESULT_SYSTEM_ERROR,
                    'Disbursement could not be created. No claim or funding totals were changed.');
            }

            try {
                adjudicationWriteInProgress = true;
                Database.update(new Claim__c(
                    Id = claim.Id,
                    Claim_Status__c = STATUS_APPROVED,
                    Approval_Date__c = Date.today(),
                    Reimbursement_Amount__c = reimbursement,
                    Disbursement_Created__c = true
                ), AccessLevel.SYSTEM_MODE);
                adjudicationWriteInProgress = false;

                Database.update(new Application__c(
                    Id = application.Id,
                    Reimbursed_Amount__c = valueOrZero(application.Reimbursed_Amount__c) + reimbursement
                ), AccessLevel.SYSTEM_MODE);
                new ProgramTotalsWriter().updateDisbursed(program.Id, projectedDisbursed);
                enqueueIntegration(disbursement.Id);
            } catch (Exception ex) {
                adjudicationWriteInProgress = false;
                Database.rollback(sp);
                return outcome(claimId, false, RESULT_SYSTEM_ERROR,
                    'Claim adjudication failed. No claim, disbursement, or funding totals were changed.');
            }

            return outcome(claimId, true, STATUS_APPROVED, 'Claim approved and disbursement created.',
                disbursement.Id, reimbursement);
        } catch (Exception ex) {
            adjudicationWriteInProgress = false;
            return outcome(claimId, false, RESULT_SYSTEM_ERROR,
                'Claim could not be adjudicated. No financial changes were made.');
        }
    }

    // The coordinator must not receive Program Edit access to update this one service-computed total.
    // Only this class can call the writer, after permission, claim Edit access, row locks and cap checks.
    private without sharing class ProgramTotalsWriter {
        private void updateDisbursed(Id programId, Decimal amount) {
            Database.update(new Program__c(Id = programId, Disbursed_Amount__c = amount), AccessLevel.SYSTEM_MODE);
        }
    }

    private static Boolean isAuthorized() {
        return hasAdjudicationPermission();
    }

    @TestVisible
    private static Result checkFundingCap(
        Decimal fundingCap,
        Decimal committedAmount,
        Decimal disbursedAmount,
        Decimal newDisbursement
    ) {
        if (fundingCap == null) {
            return outcome(null, false, RESULT_REQUIRES_REVIEW,
                'Program funding cap is missing; claim requires review.');
        }
        if (fundingCap <= 0) {
            return outcome(null, false, RESULT_NOT_ELIGIBLE,
                'Program funding cap is zero; no disbursement is allowed.');
        }

        Decimal projectedDisbursed = valueOrZero(disbursedAmount) + valueOrZero(newDisbursement);
        Decimal committed = valueOrZero(committedAmount);
        // Committed approvals already include their later disbursements; count only any disbursement excess.
        Decimal projectedExposure = committed > projectedDisbursed ? committed : projectedDisbursed;
        return projectedExposure > fundingCap
            ? outcome(null, false, RESULT_REQUIRES_REVIEW,
                'Program funding cap would be exceeded; claim requires review.')
            : null;
    }

    @TestVisible
    private static void enqueueIntegration(Id disbursementId) {
        if (!Test.isRunningTest()) {
            System.enqueueJob(new FinancialIntegrationQueueable(new List<Id>{ disbursementId }));
        }
    }

    private static Result alreadyProcessed(Claim__c claim, String paymentReference) {
        List<Disbursement__c> existing = [
            SELECT Id, Claim__c, Approved_Amount__c
            FROM Disbursement__c
            WHERE Payment_Reference__c = :paymentReference
            LIMIT 1
        ];
        if (existing.isEmpty() || existing[0].Claim__c != claim.Id) {
            return outcome(claim.Id, false, RESULT_SYSTEM_ERROR,
                'Claim has a final status but its matching disbursement is missing. Reconcile before retrying.');
        }
        return outcome(claim.Id, true, RESULT_ALREADY_PROCESSED,
            'Claim was already adjudicated; no new disbursement was created.',
            existing[0].Id, existing[0].Approved_Amount__c);
    }

    private static Boolean isDuplicateValue(DmlException dmlEx) {
        for (Integer i = 0; i < dmlEx.getNumDml(); i++) {
            if (dmlEx.getDmlStatusCode(i) == 'DUPLICATE_VALUE') {
                return true;
            }
        }
        return false;
    }

    private static Result outcome(Id claimId, Boolean success, String status, String message) {
        return outcome(claimId, success, status, message, null, null);
    }

    private static Result outcome(
        Id claimId,
        Boolean success,
        String status,
        String message,
        Id disbursementId,
        Decimal amount
    ) {
        Result result = new Result();
        result.claimId = claimId;
        result.success = success;
        result.status = status;
        result.message = message;
        result.disbursementId = disbursementId;
        result.amount = amount;
        return result;
    }

    private static String paymentReferenceFor(Claim__c claim) {
        String key = String.isBlank(claim.External_Key__c)
            ? String.valueOf(claim.Id)
            : claim.External_Key__c;
        return 'DISB-' + key;
    }

    private static Decimal valueOrZero(Decimal value) {
        return value == null ? 0 : value;
    }

}