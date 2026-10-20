@isTest
private class ClaimAdjudicationServiceTest {
    @TestSetup
    static void createAdminUser() {
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard Platform User' LIMIT 1];
        User admin = new User(
            Alias = 'ngadmin',
            Email = 'admin-ng@example.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Admin Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_CA',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'America/Halifax',
            Username = 'admin-ng-' + DateTime.now().getTime() + '@example.invalid'
        );
        insert admin;
        insert new PermissionSetAssignment(
            AssigneeId = admin.Id,
            PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Nova_Grants_Admin'].Id
        );
    }

    @isTest
    static void approvesClaimAndCreatesDisbursement() {
        authorizeTest();
        Account account = NovaGrantsTestData.createAccount('A1');
        Program__c program = NovaGrantsTestData.createProgram('P1', 50);
        Application__c application = NovaGrantsTestData.createApplication(
            account.Id,
            program.Id,
            10000
        );
        Claim__c claim = NovaGrantsTestData.createClaim(application.Id, 1000, true);

        Test.startTest();
        ClaimAdjudicationService.Result result = ClaimAdjudicationService.approveClaim(claim.Id);
        Test.stopTest();

        Assert.isTrue(result.success, result.message);
        Assert.areEqual(500, result.amount, 'Reimbursement should apply the 50% co-pay.');

        Claim__c updatedClaim = [
            SELECT Claim_Status__c, Reimbursement_Amount__c, Disbursement_Created__c
            FROM Claim__c
            WHERE Id = :claim.Id
        ];
        Assert.areEqual('Approved', updatedClaim.Claim_Status__c);
        Assert.areEqual(500, updatedClaim.Reimbursement_Amount__c);
        Assert.isTrue(updatedClaim.Disbursement_Created__c);

        List<Disbursement__c> disbursements = [
            SELECT Id, Approved_Amount__c, GL_Sync_Status__c
            FROM Disbursement__c
            WHERE Claim__c = :claim.Id
        ];
        Assert.areEqual(1, disbursements.size(), 'Exactly one disbursement should be created.');
        Assert.areEqual(500, disbursements[0].Approved_Amount__c);
        Assert.areEqual('Pending', disbursements[0].GL_Sync_Status__c);

        Application__c updatedApplication = [
            SELECT Reimbursed_Amount__c
            FROM Application__c
            WHERE Id = :application.Id
        ];
        Assert.areEqual(500, updatedApplication.Reimbursed_Amount__c);

        Program__c updatedProgram = [SELECT Disbursed_Amount__c FROM Program__c WHERE Id = :program.Id];
        Assert.areEqual(500, updatedProgram.Disbursed_Amount__c);
    }

    @isTest
    static void isIdempotentOnRepeatApproval() {
        authorizeTest();
        Account account = NovaGrantsTestData.createAccount('A2');
        Program__c program = NovaGrantsTestData.createProgram('P2', 100);
        Application__c application = NovaGrantsTestData.createApplication(
            account.Id,
            program.Id,
            5000
        );
        Claim__c claim = NovaGrantsTestData.createClaim(application.Id, 1000, true);

        Test.startTest();
        ClaimAdjudicationService.Result first = ClaimAdjudicationService.approveClaim(claim.Id);
        ClaimAdjudicationService.Result second = ClaimAdjudicationService.approveClaim(claim.Id);
        Test.stopTest();

        Assert.isTrue(first.success);
        Assert.isTrue(second.success);
        Assert.areEqual('Already processed', second.status);
        Assert.isNotNull(second.disbursementId);

        Integer disbursementCount = [
            SELECT COUNT()
            FROM Disbursement__c
            WHERE Claim__c = :claim.Id
        ];
        Assert.areEqual(1, disbursementCount, 'Repeat approval must not duplicate disbursements.');

        Program__c updatedProgram = [SELECT Disbursed_Amount__c FROM Program__c WHERE Id = :program.Id];
        Assert.areEqual(1000, updatedProgram.Disbursed_Amount__c);
    }

    @isTest
    static void requiresCorrectionWhenProofNotVerified() {
        authorizeTest();
        Account account = NovaGrantsTestData.createAccount('A3');
        Program__c program = NovaGrantsTestData.createProgram('P3', 100);
        Application__c application = NovaGrantsTestData.createApplication(
            account.Id,
            program.Id,
            5000
        );
        Claim__c claim = NovaGrantsTestData.createClaim(application.Id, 1000, false);

        Test.startTest();
        ClaimAdjudicationService.Result result = ClaimAdjudicationService.approveClaim(claim.Id);
        Test.stopTest();

        Assert.isFalse(result.success);
        Assert.areEqual(ClaimAdjudicationService.RESULT_REQUIRES_REVIEW, result.status);

        Claim__c updatedClaim = [
            SELECT Claim_Status__c, Rejection_Reason__c
            FROM Claim__c
            WHERE Id = :claim.Id
        ];
        Assert.areEqual('Submitted for Verification', updatedClaim.Claim_Status__c);
        Assert.isNull(updatedClaim.Rejection_Reason__c);

        Integer disbursementCount = [
            SELECT COUNT()
            FROM Disbursement__c
            WHERE Claim__c = :claim.Id
        ];
        Assert.areEqual(0, disbursementCount);
    }

    @isTest
    static void requiresReviewWhenNoRemainingApplicationBudget() {
        authorizeTest();
        Account account = NovaGrantsTestData.createAccount('A4');
        Program__c program = NovaGrantsTestData.createProgram('P4', 100);
        Application__c application = NovaGrantsTestData.createApplication(
            account.Id,
            program.Id,
            1000
        );
        Claim__c claim = NovaGrantsTestData.createClaim(application.Id, 1000, true);

        Test.startTest();
        ClaimAdjudicationService.Result first = ClaimAdjudicationService.approveClaim(claim.Id);
        Claim__c secondClaim = NovaGrantsTestData.createClaim(application.Id, 1000, true);
        ClaimAdjudicationService.Result second = ClaimAdjudicationService.approveClaim(secondClaim.Id);
        Test.stopTest();

        Assert.isTrue(first.success);
        Assert.isFalse(second.success, 'Second claim must not exceed remaining application funding.');
        Assert.areEqual(ClaimAdjudicationService.RESULT_REQUIRES_REVIEW, second.status);
        Claim__c unchangedSecondClaim = [
            SELECT Claim_Status__c
            FROM Claim__c
            WHERE Id = :secondClaim.Id
        ];
        Assert.areEqual('Submitted for Verification', unchangedSecondClaim.Claim_Status__c);
    }

    @isTest
    static void capsReimbursementAtRemainingBudget() {
        authorizeTest();
        Account account = NovaGrantsTestData.createAccount('A5');
        Program__c program = NovaGrantsTestData.createProgram('P5', 100);
        Application__c application = NovaGrantsTestData.createApplication(
            account.Id,
            program.Id,
            500
        );
        Claim__c claim = NovaGrantsTestData.createClaim(application.Id, 100000, true);

        Test.startTest();
        ClaimAdjudicationService.Result result = ClaimAdjudicationService.approveClaim(claim.Id);
        Test.stopTest();

        Assert.isTrue(result.success);
        Assert.areEqual(500, result.amount, 'Reimbursement must be capped at remaining budget.');
    }

    @isTest
    static void approvesMultipleClaims() {
        authorizeTest();
        Account account = NovaGrantsTestData.createAccount('A6');
        Program__c program = NovaGrantsTestData.createProgram('P6', 100);
        Application__c application = NovaGrantsTestData.createApplication(
            account.Id,
            program.Id,
            10000
        );
        Claim__c claimOne = NovaGrantsTestData.createClaim(application.Id, 1000, true);
        Claim__c claimTwo = NovaGrantsTestData.createClaim(application.Id, 2000, true);

        Test.startTest();
        List<ClaimAdjudicationService.Result> results = ClaimAdjudicationService.approveClaims(
            new List<Id>{ claimOne.Id, claimTwo.Id }
        );
        Test.stopTest();

        Assert.areEqual(2, results.size());
        Assert.isTrue(results[0].success);
        Assert.isTrue(results[1].success);

        Program__c updatedProgram = [SELECT Disbursed_Amount__c FROM Program__c WHERE Id = :program.Id];
        Assert.areEqual(3000, updatedProgram.Disbursed_Amount__c);
    }

    @isTest
    static void usesExternalKeyForPaymentReference() {
        authorizeTest();
        Account account = NovaGrantsTestData.createAccount('A7');
        Program__c program = NovaGrantsTestData.createProgram('P7', 100);
        Application__c application = NovaGrantsTestData.createApplication(
            account.Id,
            program.Id,
            5000
        );
        Claim__c claim = NovaGrantsTestData.createClaim(application.Id, 1000, true);
        update new Claim__c(Id = claim.Id, External_Key__c = 'DEMO-CLM-KEY');

        Test.startTest();
        ClaimAdjudicationService.Result result = ClaimAdjudicationService.approveClaim(claim.Id);
        Test.stopTest();

        Assert.isTrue(result.success, result.message);
        Disbursement__c disbursement = [
            SELECT Payment_Reference__c
            FROM Disbursement__c
            WHERE Claim__c = :claim.Id
        ];
        Assert.areEqual('DISB-DEMO-CLM-KEY', disbursement.Payment_Reference__c);
    }

    @isTest
    static void doesNotMutateClaimWhenProgramInactive() {
        authorizeTest();
        Account account = NovaGrantsTestData.createAccount('INACTIVE');
        Program__c program = NovaGrantsTestData.createProgram('INACTIVE', 100);
        Application__c application = NovaGrantsTestData.createApplication(account.Id, program.Id, 1000);
        Claim__c claim = NovaGrantsTestData.createClaim(application.Id, 100, true);
        update new Program__c(Id = program.Id, Program_Status__c = 'Suspended');

        ClaimAdjudicationService.Result result = ClaimAdjudicationService.approveClaim(claim.Id);

        Assert.areEqual(ClaimAdjudicationService.RESULT_NOT_ELIGIBLE, result.status);
        Assert.areEqual('Submitted for Verification', [SELECT Claim_Status__c FROM Claim__c WHERE Id = :claim.Id].Claim_Status__c);
        Assert.areEqual(0, [SELECT COUNT() FROM Disbursement__c WHERE Claim__c = :claim.Id]);
    }

    @isTest
    static void failsClosedForNullAndZeroFundingCaps() {
        authorizeTest();
        Assert.areEqual(ClaimAdjudicationService.RESULT_REQUIRES_REVIEW,
            ClaimAdjudicationService.checkFundingCap(null, 0, 0, 1).status);
        Assert.areEqual(ClaimAdjudicationService.RESULT_NOT_ELIGIBLE,
            ClaimAdjudicationService.checkFundingCap(0, 0, 0, 1).status);
    }

    @isTest
    static void zeroOrMissingCopayNeverDefaultsToFullReimbursement() {
        authorizeTest();
        Account account = NovaGrantsTestData.createAccount('COPAY');
        Program__c zeroCopayProgram = NovaGrantsTestData.createProgram('COPAY_ZERO', 0);
        Program__c missingCopayProgram = NovaGrantsTestData.createProgram('COPAY_NULL', null);
        Application__c zeroCopayApplication = NovaGrantsTestData.createApplication(account.Id, zeroCopayProgram.Id, 1000);
        Application__c missingCopayApplication = NovaGrantsTestData.createApplication(account.Id, missingCopayProgram.Id, 1000);
        Claim__c zeroCopayClaim = NovaGrantsTestData.createClaim(zeroCopayApplication.Id, 100, true);
        Claim__c missingCopayClaim = NovaGrantsTestData.createClaim(missingCopayApplication.Id, 100, true);

        Assert.areEqual(ClaimAdjudicationService.RESULT_REQUIRES_REVIEW,
            ClaimAdjudicationService.approveClaim(zeroCopayClaim.Id).status);
        Assert.areEqual(ClaimAdjudicationService.RESULT_REQUIRES_REVIEW,
            ClaimAdjudicationService.approveClaim(missingCopayClaim.Id).status);
        Set<Id> claimIds = new Set<Id>{ zeroCopayClaim.Id, missingCopayClaim.Id };
        Assert.areEqual(0, [SELECT COUNT() FROM Disbursement__c WHERE Claim__c IN :claimIds]);
    }

    @isTest
    static void blocksApplicationsWhoseCommitmentsExceedOneProgramCap() {
        authorizeTest();
        Account account = NovaGrantsTestData.createAccount('MULTIAPP');
        Program__c program = NovaGrantsTestData.createProgram('MULTIAPP', 100);
        update new Program__c(Id = program.Id, Funding_Cap__c = 1000, Committed_Amount__c = 0);
        Application__c firstApplication = NovaGrantsTestData.createApplication(account.Id, program.Id, 800);
        Application__c secondApplication = NovaGrantsTestData.createApplication(account.Id, program.Id, 800);
        Claim__c firstClaim = NovaGrantsTestData.createClaim(firstApplication.Id, 800, true);
        Claim__c secondClaim = NovaGrantsTestData.createClaim(secondApplication.Id, 800, true);

        ClaimAdjudicationService.Result first = ClaimAdjudicationService.approveClaim(firstClaim.Id);
        ClaimAdjudicationService.Result second = ClaimAdjudicationService.approveClaim(secondClaim.Id);

        Assert.areEqual(ClaimAdjudicationService.RESULT_REQUIRES_REVIEW, first.status);
        Assert.areEqual(ClaimAdjudicationService.RESULT_REQUIRES_REVIEW, second.status);
        Assert.isNull([SELECT Disbursed_Amount__c FROM Program__c WHERE Id = :program.Id].Disbursed_Amount__c);
        Set<Id> claimIds = new Set<Id>{ firstClaim.Id, secondClaim.Id };
        Assert.areEqual(0, [SELECT COUNT() FROM Disbursement__c WHERE Claim__c IN :claimIds]);
        Assert.areEqual('Submitted for Verification', [SELECT Claim_Status__c FROM Claim__c WHERE Id = :secondClaim.Id].Claim_Status__c);
    }

    @isTest
    static void committedAndDisbursedAmountsAreNotDoubleCounted() {
        authorizeTest();
        Account account = NovaGrantsTestData.createAccount('NO_DOUBLE_COUNT');
        Program__c program = NovaGrantsTestData.createProgram('NO_DOUBLE_COUNT', 100);
        update new Program__c(Id = program.Id, Funding_Cap__c = 1000, Committed_Amount__c = 600, Disbursed_Amount__c = 600);
        Application__c application = NovaGrantsTestData.createApplication(account.Id, program.Id, 1000);
        Claim__c claim = NovaGrantsTestData.createClaim(application.Id, 300, true);

        ClaimAdjudicationService.Result result = ClaimAdjudicationService.approveClaim(claim.Id);

        Assert.isTrue(result.success, result.message);
        Assert.areEqual(300, result.amount);
        Assert.areEqual(900, [SELECT Disbursed_Amount__c FROM Program__c WHERE Id = :program.Id].Disbursed_Amount__c);
    }

    @isTest
    static void reportsNonDuplicateDmlFailureAndRollsBack() {
        authorizeTest();
        Account account = NovaGrantsTestData.createAccount('DMLERROR');
        Program__c program = NovaGrantsTestData.createProgram('DMLERROR', 100);
        Application__c application = NovaGrantsTestData.createApplication(account.Id, program.Id, 1000);
        Claim__c claim = NovaGrantsTestData.createClaim(application.Id, 100, true);
        String longKey = '';
        for (Integer i = 0; i < 80; i++) {
            longKey += 'X';
        }
        update new Claim__c(Id = claim.Id, External_Key__c = longKey);

        ClaimAdjudicationService.Result result = ClaimAdjudicationService.approveClaim(claim.Id);

        Assert.areEqual(ClaimAdjudicationService.RESULT_SYSTEM_ERROR, result.status);
        Assert.isFalse(result.success);
        Assert.areEqual(0, [SELECT COUNT() FROM Disbursement__c WHERE Claim__c = :claim.Id]);
        Assert.areEqual('Submitted for Verification', [SELECT Claim_Status__c FROM Claim__c WHERE Id = :claim.Id].Claim_Status__c);
        Assert.isNull([SELECT Reimbursed_Amount__c FROM Application__c WHERE Id = :application.Id].Reimbursed_Amount__c);
        Assert.isNull([SELECT Disbursed_Amount__c FROM Program__c WHERE Id = :program.Id].Disbursed_Amount__c);
    }

    @isTest
    static void unauthorizedUserCannotAdjudicate() {
        Account account = NovaGrantsTestData.createAccount('UNAUTHORIZED');
        Program__c program = NovaGrantsTestData.createProgram('UNAUTHORIZED', 100);
        Application__c application = NovaGrantsTestData.createApplication(account.Id, program.Id, 1000);
        Claim__c claim = NovaGrantsTestData.createClaim(application.Id, 100, true);
        User unauthorized = createUser(false);
        ClaimAdjudicationService.Result result;
        Boolean proofBlocked = false;

        System.runAs(unauthorized) {
            Assert.isFalse(FeatureManagement.checkPermission('Nova_Grants_Adjudicate_Claims'));
            result = ClaimAdjudicationService.approveClaim(claim.Id);
        }
        ClaimAdjudicationService.authorizationOverrideForTest = false;
        try {
            update new Claim__c(Id = claim.Id, Proof_of_Payment_Verified__c = false);
        } catch (DmlException ex) {
            proofBlocked = true;
        }

        Assert.areEqual(ClaimAdjudicationService.RESULT_UNAUTHORIZED, result.status);
        Assert.isTrue(proofBlocked, 'Unauthorized users cannot change proof verification.');
        Assert.areEqual(0, [SELECT COUNT() FROM Disbursement__c WHERE Claim__c = :claim.Id]);
        Assert.areEqual('Submitted for Verification', [SELECT Claim_Status__c FROM Claim__c WHERE Id = :claim.Id].Claim_Status__c);
    }

    @isTest
    static void coordinatorPermissionSetGrantsAdjudicationPermission() {
        User reviewer = createUser(true);
        User unauthorized = createUser(false);

        System.runAs(reviewer) {
            Assert.isTrue(FeatureManagement.checkPermission('Nova_Grants_Adjudicate_Claims'));
        }
        System.runAs(unauthorized) {
            Assert.isFalse(FeatureManagement.checkPermission('Nova_Grants_Adjudicate_Claims'));
        }
    }

    @isTest
    static void adminPermissionSetGrantsAdjudicationPermission() {
        User admin = createUserWithPermissionSet('Nova_Grants_Admin');
        User unauthorized = createUser(false);

        System.runAs(admin) {
            Assert.isTrue(FeatureManagement.checkPermission('Nova_Grants_Adjudicate_Claims'));
        }
        System.runAs(unauthorized) {
            Assert.isFalse(FeatureManagement.checkPermission('Nova_Grants_Adjudicate_Claims'));
        }
    }

    @isTest
    static void adminCanAdjudicateEndToEnd() {
        User admin = [SELECT Id FROM User WHERE Alias = 'ngadmin' LIMIT 1];
        Account account = NovaGrantsTestData.createAccount('ADMIN');
        Program__c program = NovaGrantsTestData.createProgram('ADMIN', 50);
        Application__c application = NovaGrantsTestData.createApplication(account.Id, program.Id, 1000);
        Claim__c claim = NovaGrantsTestData.createClaim(application.Id, 200, true);

        ClaimAdjudicationService.Result result;
        System.runAs(admin) {
            result = ClaimAdjudicationService.approveClaim(claim.Id);
        }

        Assert.isTrue(result.success, result.message);
        Assert.areEqual(100, result.amount);
        Assert.areEqual('Approved', [SELECT Claim_Status__c FROM Claim__c WHERE Id = :claim.Id].Claim_Status__c);
        Assert.areEqual(1, [SELECT COUNT() FROM Disbursement__c WHERE Claim__c = :claim.Id]);
    }

    @isTest
    static void authorizedReviewerCannotDirectlyApproveOrChangePayoutFields() {
        authorizeTest();
        Account account = NovaGrantsTestData.createAccount('BYPASS');
        Program__c program = NovaGrantsTestData.createProgram('BYPASS', 100);
        Application__c application = NovaGrantsTestData.createApplication(account.Id, program.Id, 1000);
        Claim__c claim = NovaGrantsTestData.createClaim(application.Id, 100, false);
        Boolean statusBlocked = false;
        Boolean amountBlocked = false;

        update new Claim__c(Id = claim.Id, Proof_of_Payment_Verified__c = true);
        try {
            update new Claim__c(Id = claim.Id, Claim_Status__c = 'Approved');
        } catch (DmlException ex) {
            statusBlocked = true;
        }
        try {
            update new Claim__c(Id = claim.Id, Reimbursement_Amount__c = 1);
        } catch (DmlException ex) {
            amountBlocked = true;
        }

        Assert.isTrue(statusBlocked, 'Direct status approval must be blocked.');
        Assert.isTrue(amountBlocked, 'Direct reimbursement edits must be blocked.');
        Assert.isTrue([SELECT Proof_of_Payment_Verified__c FROM Claim__c WHERE Id = :claim.Id].Proof_of_Payment_Verified__c);
        Assert.areEqual('Submitted for Verification', [SELECT Claim_Status__c FROM Claim__c WHERE Id = :claim.Id].Claim_Status__c);
        Assert.areEqual(0, [SELECT COUNT() FROM Disbursement__c WHERE Claim__c = :claim.Id]);
    }

    @isTest
    static void handlesNullClaimId() {
        authorizeTest();
        Test.startTest();
        ClaimAdjudicationService.Result result = ClaimAdjudicationService.approveClaim(null);
        Test.stopTest();

        Assert.isFalse(result.success);
        Assert.isNotNull(result.message);
    }

    @isTest
    static void rejectsEmptyClaimList() {
        Boolean threw = false;
        Test.startTest();
        try {
            ClaimAdjudicationService.approveClaims(new List<Id>());
        } catch (NovaGrantsException ex) {
            threw = true;
        }
        Test.stopTest();

        Assert.isTrue(threw, 'Empty claim list should throw.');
    }

    private static User createUser(Boolean authorize) {
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard Platform User' LIMIT 1];
        String suffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User user = new User(
            Alias = 'uatuser',
            Email = 'claim-test-' + suffix + '@example.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Claim Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_CA',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'America/Halifax',
            Username = 'claim-test-' + suffix + '@example.invalid'
        );
        insert user;

        if (authorize) {
            PermissionSet coordinator = [
                SELECT Id
                FROM PermissionSet
                WHERE Name = 'Nova_Grants_Claims_Coordinator'
                LIMIT 1
            ];
            insert new PermissionSetAssignment(AssigneeId = user.Id, PermissionSetId = coordinator.Id);
        }

        return user;
    }

    private static User createUserWithPermissionSet(String permissionSetName) {
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard Platform User' LIMIT 1];
        String suffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User user = new User(
            Alias = 'psuser',
            Email = 'ps-' + suffix + '@example.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Permission Set Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_CA',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'America/Halifax',
            Username = 'ps-' + suffix + '@example.invalid'
        );
        insert user;
        insert new PermissionSetAssignment(
            AssigneeId = user.Id,
            PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = :permissionSetName LIMIT 1].Id
        );
        return user;
    }

    private static void authorizeTest() {
        ClaimAdjudicationService.authorizationOverrideForTest = true;
    }
}