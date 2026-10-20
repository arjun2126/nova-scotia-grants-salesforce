@isTest
private class ScheduledFinancialAuditTest {
    private static Disbursement__c createDisbursement(String suffix, String status) {
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
            GL_Sync_Status__c = status
        );
        insert disbursement;
        return disbursement;
    }

    @isTest
    static void flagsStaleUnsyncedDisbursements() {
        Disbursement__c stale = createDisbursement('A1', 'Pending');
        Disbursement__c synced = createDisbursement('A2', 'Synced');
        Disbursement__c fresh = createDisbursement('A3', 'Pending');

        Test.setCreatedDate(stale.Id, System.now().addDays(-10));
        Test.setCreatedDate(synced.Id, System.now().addDays(-10));

        Test.startTest();
        new ScheduledFinancialAudit().execute(null);
        Test.stopTest();

        Assert.isTrue(
            [SELECT Audit_Flagged__c FROM Disbursement__c WHERE Id = :stale.Id].Audit_Flagged__c,
            'Stale unsynced disbursement should be flagged.'
        );
        Assert.isFalse(
            [SELECT Audit_Flagged__c FROM Disbursement__c WHERE Id = :synced.Id].Audit_Flagged__c,
            'Synced disbursement should not be flagged.'
        );
        Assert.isFalse(
            [SELECT Audit_Flagged__c FROM Disbursement__c WHERE Id = :fresh.Id].Audit_Flagged__c,
            'Recently created disbursement should not be flagged.'
        );
    }

    @isTest
    static void handlesNoStaleRecords() {
        Disbursement__c fresh = createDisbursement('A4', 'Pending');
        Test.setCreatedDate(fresh.Id, System.now().addDays(-1));

        Test.startTest();
        new ScheduledFinancialAudit().execute(null);
        Test.stopTest();

        Assert.isFalse(
            [SELECT Audit_Flagged__c FROM Disbursement__c WHERE Id = :fresh.Id].Audit_Flagged__c
        );
    }
}