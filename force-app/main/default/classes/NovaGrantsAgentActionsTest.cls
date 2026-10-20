@isTest
private class NovaGrantsAgentActionsTest {
    @isTest
    static void adjudicatesSubmittedClaim() {
        ClaimAdjudicationService.authorizationOverrideForTest = true;
        Account account = NovaGrantsTestData.createAccount('AA');
        Program__c program = NovaGrantsTestData.createProgram('AA', 60);
        Application__c application = NovaGrantsTestData.createApplication(account.Id, program.Id, 10000);
        Claim__c claim = NovaGrantsTestData.createClaim(application.Id, 1500, true);

        Test.startTest();
        NovaGrantsAgentActions.ClaimInput input = new NovaGrantsAgentActions.ClaimInput();
        input.claimId = claim.Id;
        List<NovaGrantsAgentActions.ClaimOutput> outputs = NovaGrantsAgentActions.adjudicateClaims(
            new List<NovaGrantsAgentActions.ClaimInput>{ input }
        );
        Test.stopTest();

        System.assertEquals(1, outputs.size(), 'One output per input');
        System.assertEquals(claim.Id, outputs[0].claimId, 'Claim id echoed back');
        System.assertEquals(ClaimAdjudicationService.STATUS_APPROVED, outputs[0].status, 'Submitted claim approved');
        System.assertEquals(true, outputs[0].success, 'Success returned to Flow');
        System.assertNotEquals(null, outputs[0].reimbursementAmount, 'Amount returned');
    }

    @isTest
    static void returnsNotEligibleForInvalidInput() {
        Test.startTest();
        NovaGrantsAgentActions.ClaimInput badId = new NovaGrantsAgentActions.ClaimInput();
        badId.claimId = 'not-an-id';
        NovaGrantsAgentActions.ClaimInput blank = new NovaGrantsAgentActions.ClaimInput();
        List<NovaGrantsAgentActions.ClaimOutput> outputs = NovaGrantsAgentActions.adjudicateClaims(
            new List<NovaGrantsAgentActions.ClaimInput>{ badId, blank }
        );
        Test.stopTest();

        System.assertEquals(2, outputs.size(), 'One output per input');
        System.assertEquals(ClaimAdjudicationService.RESULT_NOT_ELIGIBLE, outputs[0].status);
        System.assertEquals(ClaimAdjudicationService.RESULT_NOT_ELIGIBLE, outputs[1].status);
        System.assertEquals(false, outputs[0].success);
        System.assertEquals(false, outputs[1].success);
    }

    @isTest
    static void unauthorizedUserCannotInvokeInvocableAction() {
        ClaimAdjudicationService.authorizationOverrideForTest = false;
        Account account = NovaGrantsTestData.createAccount('AGENT_DENIED');
        Program__c program = NovaGrantsTestData.createProgram('AGENT_DENIED', 100);
        Application__c application = NovaGrantsTestData.createApplication(account.Id, program.Id, 1000);
        Claim__c claim = NovaGrantsTestData.createClaim(application.Id, 100, true);
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard Platform User' LIMIT 1];
        String suffix = String.valueOf(DateTime.now().getTime());
        User unauthorized = new User(
            Alias = 'agentno',
            Email = 'agent-denied-' + suffix + '@example.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Agent Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_CA',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'America/Halifax',
            Username = 'agent-denied-' + suffix + '@example.invalid'
        );
        insert unauthorized;

        List<NovaGrantsAgentActions.ClaimOutput> outputs;
        System.runAs(unauthorized) {
            NovaGrantsAgentActions.ClaimInput input = new NovaGrantsAgentActions.ClaimInput();
            input.claimId = claim.Id;
            outputs = NovaGrantsAgentActions.adjudicateClaims(new List<NovaGrantsAgentActions.ClaimInput>{ input });
        }

        System.assertEquals(ClaimAdjudicationService.RESULT_UNAUTHORIZED, outputs[0].status);
        System.assertEquals(false, outputs[0].success);
        System.assertEquals(0, [SELECT COUNT() FROM Disbursement__c WHERE Claim__c = :claim.Id]);
    }

    @isTest
    static void returnsEmptyForNoInput() {
        Test.startTest();
        List<NovaGrantsAgentActions.ClaimOutput> outputs = NovaGrantsAgentActions.adjudicateClaims(null);
        Test.stopTest();

        System.assertEquals(0, outputs.size(), 'No outputs without input');
    }
}