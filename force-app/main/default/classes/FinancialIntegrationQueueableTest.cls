@isTest
private class FinancialIntegrationQueueableTest {
    private static Disbursement__c createDisbursement(String suffix) {
        Account account = NovaGrantsTestData.createAccount(suffix);
        Program__c program = NovaGrantsTestData.createProgram(suffix, 100);
        Application__c application = NovaGrantsTestData.createApplication(
            account.Id,
            program.Id,
            10000
        );
        Claim__c claim = NovaGrantsTestData.createClaim(application.Id, 1000, true);

        Disbursement__c disbursement = new Disbursement__c(
            Claim__c = claim.Id,
            Approved_Amount__c = 1000,
            Payment_Reference__c = 'DISB-' + suffix,
            GL_Sync_Status__c = 'Pending',
            GL_Sync_Attempts__c = 0,
            GL_Sync_Requested__c = System.now()
        );
        insert disbursement;
        return disbursement;
    }

    @isTest
    static void syncsInMockMode() {
        resetSetting(true, 3, null);
        Disbursement__c disbursement = createDisbursement('A1');

        Test.startTest();
        System.enqueueJob(new FinancialIntegrationQueueable(new List<Id>{ disbursement.Id }));
        Test.stopTest();

        Disbursement__c updated = [
            SELECT GL_Sync_Status__c, External_Transaction_ID__c, GL_Sync_Attempts__c
            FROM Disbursement__c
            WHERE Id = :disbursement.Id
        ];
        Assert.areEqual('Synced', updated.GL_Sync_Status__c);
        Assert.isTrue(updated.External_Transaction_ID__c.startsWith('MOCK-'));
        Assert.areEqual(1, updated.GL_Sync_Attempts__c);
    }

    @isTest
    static void retriesOnCalloutFailure() {
        configureIntegration(3);
        Disbursement__c disbursement = createDisbursement('A2');

        Test.setMock(HttpCalloutMock.class, new FailingMock());
        Test.startTest();
        System.enqueueJob(new FinancialIntegrationQueueable(new List<Id>{ disbursement.Id }));
        Test.stopTest();

        Disbursement__c updated = [
            SELECT GL_Sync_Status__c, GL_Sync_Attempts__c, Error_Message__c
            FROM Disbursement__c
            WHERE Id = :disbursement.Id
        ];
        Assert.areEqual('Retrying', updated.GL_Sync_Status__c);
        Assert.areEqual(1, updated.GL_Sync_Attempts__c);
        Assert.isNotNull(updated.Error_Message__c);
    }

    @isTest
    static void failsAndLogsAfterMaxRetries() {
        configureIntegration(1);
        Disbursement__c disbursement = createDisbursement('A3');

        Test.setMock(HttpCalloutMock.class, new FailingMock());
        Test.startTest();
        System.enqueueJob(new FinancialIntegrationQueueable(new List<Id>{ disbursement.Id }));
        Test.stopTest();

        Disbursement__c updated = [
            SELECT GL_Sync_Status__c, GL_Sync_Attempts__c
            FROM Disbursement__c
            WHERE Id = :disbursement.Id
        ];
        Assert.areEqual('Failed', updated.GL_Sync_Status__c);
        Assert.areEqual(1, updated.GL_Sync_Attempts__c);

        Integer logCount = [SELECT COUNT() FROM Error_Log__c WHERE Record_Id__c = :String.valueOf(disbursement.Id)];
        Assert.areEqual(1, logCount, 'A failed integration must log an error.');
    }

    @isTest
    static void syncsWithSuccessfulCallout() {
        configureIntegration(3);
        Disbursement__c disbursement = createDisbursement('A4');

        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        System.enqueueJob(new FinancialIntegrationQueueable(new List<Id>{ disbursement.Id }));
        Test.stopTest();

        Disbursement__c updated = [
            SELECT GL_Sync_Status__c, External_Transaction_ID__c
            FROM Disbursement__c
            WHERE Id = :disbursement.Id
        ];
        Assert.areEqual('Synced', updated.GL_Sync_Status__c);
        Assert.isTrue(updated.External_Transaction_ID__c.startsWith('GL-'));
    }

    @isTest
    static void mocksWhenEndpointMissing() {
        resetSetting(false, 3, null);

        Test.startTest();
        String transactionId = FinancialIntegrationQueueable.postToGeneralLedger(
            new Disbursement__c(Payment_Reference__c = 'X', Approved_Amount__c = 1)
        );
        Test.stopTest();

        Assert.areEqual('MOCK-X', transactionId, 'A blank endpoint must fall back to simulation.');
    }

    private static void configureIntegration(Integer maxRetries) {
        resetSetting(false, maxRetries, 'https://example.com/gl');
    }

    private static void resetSetting(Boolean mockMode, Integer maxRetries, String endpoint) {
        List<Nova_Grants_Setting__c> existing = [SELECT Id FROM Nova_Grants_Setting__c];
        if (!existing.isEmpty()) {
            delete existing;
        }
        insert new Nova_Grants_Setting__c(
            Mock_Mode__c = mockMode,
            Max_Retries__c = maxRetries,
            Endpoint__c = endpoint,
            GL_Account_Code__c = 'GL-TEST'
        );
    }

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"status":"ok"}');
            return response;
        }
    }

    private class FailingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(500);
            response.setBody('{"status":"error"}');
            return response;
        }
    }
}