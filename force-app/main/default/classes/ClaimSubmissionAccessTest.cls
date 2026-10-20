@IsTest
private with sharing class ClaimSubmissionAccessTest {
    @TestSetup
    static void createReviewer() {
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard Platform User' LIMIT 1];
        User reviewer = new User(
            Alias = 'ngreview', LastName = 'Submission Reviewer',
            Email = 'submission-reviewer@example.invalid',
            Username = 'submission-' + UserInfo.getOrganizationId() + '-' + DateTime.now().getTime() + '@example.invalid',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_CA',
            TimeZoneSidKey = 'America/Halifax', ProfileId = profile.Id
        );
        insert reviewer;
        insert new PermissionSetAssignment(
            AssigneeId = reviewer.Id,
            PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Nova_Grants_Claims_Coordinator'].Id
        );
    }

    @IsTest
    static void parentEditShareEnablesSubmissionButNotApprovalBypass() {
        User reviewer = [SELECT Id FROM User WHERE Alias = 'ngreview' LIMIT 1];
        Account business = NovaGrantsTestData.createAccount('SHARE');
        Program__c program = NovaGrantsTestData.createProgram('SHARE', 50);
        Application__c application = NovaGrantsTestData.createApplication(business.Id, program.Id, 1000);
        Claim__c claim = NovaGrantsTestData.createClaim(application.Id, 200, false);
        update new Claim__c(Id = claim.Id, Claim_Status__c = 'Draft');

        assertEditAccess(reviewer.Id, claim.Id, false);
        insert new Application__Share(
            ParentId = application.Id, UserOrGroupId = reviewer.Id,
            AccessLevel = 'Edit', RowCause = Schema.Application__Share.RowCause.Manual
        );
        assertEditAccess(reviewer.Id, claim.Id, true);

        System.runAs(reviewer) {
            Assert.isTrue(FeatureManagement.checkPermission('Nova_Grants_Adjudicate_Claims'));
            update as user new Claim__c(
                Id = claim.Id, Claim_Status__c = 'Submitted for Verification',
                Proof_of_Payment_Verified__c = true
            );
            Boolean approvalBlocked = false;
            try {
                update as user new Claim__c(Id = claim.Id, Claim_Status__c = 'Approved');
            } catch (DmlException ex) {
                approvalBlocked = true;
                Assert.isTrue(ex.getMessage().contains('adjudication'));
            }
            Assert.isTrue(approvalBlocked, 'A parent share must not bypass the financial trigger.');

            Boolean payoutBlocked = false;
            try {
                update as user new Claim__c(Id = claim.Id, Reimbursement_Amount__c = 200);
            } catch (Exception ex) {
                payoutBlocked = true;
            }
            Assert.isTrue(payoutBlocked, 'Payout fields remain read-only for the coordinator.');
        }
        Claim__c submitted = [SELECT Claim_Status__c, Proof_of_Payment_Verified__c FROM Claim__c WHERE Id = :claim.Id];
        Assert.areEqual('Submitted for Verification', submitted.Claim_Status__c);
        Assert.isTrue(submitted.Proof_of_Payment_Verified__c);
        Assert.areEqual(0, [SELECT COUNT() FROM Disbursement__c WHERE Claim__c = :claim.Id]);
    }

    @IsTest
    static void shareDoesNotGrantEditOnAnotherApplication() {
        User reviewer = [SELECT Id FROM User WHERE Alias = 'ngreview' LIMIT 1];
        Account business = NovaGrantsTestData.createAccount('OTHER');
        Program__c program = NovaGrantsTestData.createProgram('OTHER', 50);
        Application__c assigned = NovaGrantsTestData.createApplication(business.Id, program.Id, 1000);
        Application__c unrelated = NovaGrantsTestData.createApplication(business.Id, program.Id, 1000);
        Claim__c claim = NovaGrantsTestData.createClaim(unrelated.Id, 200, false);
        update new Claim__c(Id = claim.Id, Claim_Status__c = 'Draft');
        insert new Application__Share(
            ParentId = assigned.Id, UserOrGroupId = reviewer.Id,
            AccessLevel = 'Edit', RowCause = Schema.Application__Share.RowCause.Manual
        );

        assertEditAccess(reviewer.Id, claim.Id, false);
        System.runAs(reviewer) {
            Assert.areEqual('Unauthorized', ClaimAdjudicationService.approveClaim(claim.Id).status,
                'Custom permission alone must not authorize an unrelated claim.');
            Boolean blocked = false;
            try {
                update as user new Claim__c(Id = claim.Id, Claim_Status__c = 'Submitted for Verification');
            } catch (Exception ex) {
                blocked = true;
            }
            Assert.isTrue(blocked, 'Read access must not allow updates to unrelated claims.');
        }
        Assert.areEqual('Draft', [SELECT Claim_Status__c FROM Claim__c WHERE Id = :claim.Id].Claim_Status__c);
    }

    @IsTest
    static void sharedReviewerCompletesIsolatedFinancialLifecycle() {
        User reviewer = [SELECT Id FROM User WHERE Alias = 'ngreview' LIMIT 1];
        Account business = NovaGrantsTestData.createAccount('LIFECYCLE');
        Program__c program = NovaGrantsTestData.createProgram('LIFECYCLE', 50);
        Application__c application = NovaGrantsTestData.createApplication(business.Id, program.Id, 1000);
        Claim__c claim = NovaGrantsTestData.createClaim(application.Id, 200, false);
        update new Claim__c(Id = claim.Id, Claim_Status__c = 'Draft');
        insert new Application__Share(
            ParentId = application.Id, UserOrGroupId = reviewer.Id,
            AccessLevel = 'Edit', RowCause = Schema.Application__Share.RowCause.Manual
        );
        ClaimAdjudicationService.Result result;
        Test.startTest();
        System.runAs(reviewer) {
            update as user new Claim__c(
                Id = claim.Id, Claim_Status__c = 'Submitted for Verification',
                Proof_of_Payment_Verified__c = true
            );
            result = ClaimAdjudicationService.approveClaim(claim.Id);
            Assert.isTrue(result.success, result.message);
            Assert.areEqual(100, result.amount);
            Assert.areEqual('Already processed', ClaimAdjudicationService.approveClaim(claim.Id).status);
            // Adjudication suppresses enqueue in tests; exercise the same worker as the reviewer explicitly.
            System.enqueueJob(new FinancialIntegrationQueueable(new List<Id>{ result.disbursementId }));
        }
        Test.stopTest();
        Disbursement__c payment = [
            SELECT GL_Sync_Status__c, Approved_Amount__c, External_Transaction_ID__c
            FROM Disbursement__c WHERE Id = :result.disbursementId
        ];
        Assert.areEqual('Synced', payment.GL_Sync_Status__c);
        Assert.areEqual(100, payment.Approved_Amount__c);
        Assert.isTrue(payment.External_Transaction_ID__c.startsWith('MOCK-'));
        Assert.areEqual(1, [SELECT COUNT() FROM Disbursement__c WHERE Claim__c = :claim.Id]);
        insert new Impact_Metric__c(Account__c = business.Id, Metric_Date__c = Date.today(), Jobs_Created__c = 2);
        AggregateResult impact = [SELECT SUM(Jobs_Created__c) jobs FROM Impact_Metric__c WHERE Account__c = :business.Id];
        Assert.areEqual(2, (Decimal) impact.get('jobs'));
    }

    private static void assertEditAccess(Id userId, Id recordId, Boolean expected) {
        UserRecordAccess access = [
            SELECT RecordId, HasReadAccess, HasEditAccess FROM UserRecordAccess
            WHERE UserId = :userId AND RecordId = :recordId
        ];
        Assert.isTrue(access.HasReadAccess);
        Assert.areEqual(expected, access.HasEditAccess);
    }
}