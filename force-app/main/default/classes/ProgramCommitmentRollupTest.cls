@IsTest
private class ProgramCommitmentRollupTest {
    @IsTest
    static void lifecycleReparentDeleteAndUndeleteStaySynchronized() {
        Account business = NovaGrantsTestData.createAccount('KPI');
        Program__c first = NovaGrantsTestData.createProgram('KPI_FIRST', 50);
        Program__c second = NovaGrantsTestData.createProgram('KPI_SECOND', 50);
        Application__c application = NovaGrantsTestData.createApplication(business.Id, first.Id, 1000);
        assertCommitment(first.Id, 1000, 0.1);
        update new Application__c(Id = application.Id, Stage__c = 'Withdrawn');
        assertCommitment(first.Id, 0, 0);
        update new Application__c(Id = application.Id, Stage__c = 'Rejected');
        assertCommitment(first.Id, 0, 0);
        update new Application__c(Id = application.Id, Stage__c = 'Approved', Approved_Amount__c = 500);
        assertCommitment(first.Id, 500, 0.05);
        update new Application__c(Id = application.Id, Program__c = second.Id);
        assertCommitment(first.Id, 0, 0);
        assertCommitment(second.Id, 500, 0.05);
        delete application;
        assertCommitment(second.Id, 0, 0);
        undelete application;
        assertCommitment(second.Id, 500, 0.05);
    }

    @IsTest
    static void approvalsAndDisbursementsDoNotDoubleCount() {
        Account business = NovaGrantsTestData.createAccount('KPI_PAID');
        Program__c program = NovaGrantsTestData.createProgram('KPI_PAID', 50);
        update new Program__c(Id = program.Id, Funding_Cap__c = 1000);
        Application__c approved = NovaGrantsTestData.createApplication(business.Id, program.Id, 1000);
        assertCommitment(program.Id, 1000, 100);
        Claim__c claim = NovaGrantsTestData.createClaim(approved.Id, 200, true);
        ClaimAdjudicationService.authorizationOverrideForTest = true;
        ClaimAdjudicationService.Result result = ClaimAdjudicationService.approveClaim(claim.Id);
        Assert.isTrue(result.success, result.message);
        Assert.areEqual(100, result.amount);
        assertCommitment(program.Id, 1000, 100);
        Program__c paid = [SELECT Disbursed_Amount__c FROM Program__c WHERE Id = :program.Id];
        Assert.areEqual(100, paid.Disbursed_Amount__c);
        Application__c another = NovaGrantsTestData.createApplication(business.Id, program.Id, 100);
        assertCommitment(program.Id, 1100, 110);
        Claim__c extra = NovaGrantsTestData.createClaim(another.Id, 100, true);
        Assert.isFalse(ClaimAdjudicationService.approveClaim(extra.Id).success);
    }

    @IsTest
    static void bulkAggregationUsesApprovedApplicationsOnly() {
        Account business = NovaGrantsTestData.createAccount('KPI_BULK');
        Program__c program = NovaGrantsTestData.createProgram('KPI_BULK', 50);
        List<Application__c> applications = new List<Application__c>();
        for (Integer i = 0; i < 200; i++) {
            applications.add(new Application__c(
                Account__c = business.Id, Program__c = program.Id,
                Stage__c = i < 100 ? 'Approved' : 'Submitted',
                Approved_Amount__c = 100, Requested_Amount__c = 100
            ));
        }
        Test.startTest();
        insert applications;
        Test.stopTest();
        assertCommitment(program.Id, 10000, 1);
        delete applications;
        assertCommitment(program.Id, 0, 0);
    }

    @IsTest
    static void zeroCapIsRejectedByExistingValidation() {
        Program__c program = NovaGrantsTestData.createProgram('KPI_ZERO', 50);
        Database.SaveResult result = Database.update(new Program__c(Id = program.Id, Funding_Cap__c = 0), false);
        Assert.isFalse(result.isSuccess());
        Assert.areEqual(StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, result.getErrors()[0].getStatusCode());
        assertCommitment(program.Id, 0, 0);
    }

    @IsTest
    static void seededAndUatScenariosUseIsolatedReplicas() {
        Account business = NovaGrantsTestData.createAccount('KPI_SCENARIOS');
        List<Decimal> caps = new List<Decimal>{ 250000, 500000, 150000, 1000 };
        List<Decimal> commitments = new List<Decimal>{ 23000, 80000, 15000, 1000 };
        List<Decimal> payments = new List<Decimal>{ 6000, 16000, 6000, 100 };
        List<Decimal> expected = new List<Decimal>{ 9.2, 16, 10, 100 };
        for (Integer i = 0; i < caps.size(); i++) {
            Program__c program = NovaGrantsTestData.createProgram('KPI_SCENARIO_' + i, 50);
            update new Program__c(Id = program.Id, Funding_Cap__c = caps[i], Disbursed_Amount__c = payments[i]);
            NovaGrantsTestData.createApplication(business.Id, program.Id, commitments[i]);
            assertCommitment(program.Id, commitments[i], expected[i]);
        }
    }

    private static void assertCommitment(Id programId, Decimal amount, Decimal percentage) {
        Program__c program = [
            SELECT Committed_Amount__c, Capacity_Utilization__c FROM Program__c WHERE Id = :programId
        ];
        Assert.areEqual(amount, program.Committed_Amount__c == null ? 0 : program.Committed_Amount__c);
        Assert.areEqual(percentage, program.Capacity_Utilization__c);
    }
}
