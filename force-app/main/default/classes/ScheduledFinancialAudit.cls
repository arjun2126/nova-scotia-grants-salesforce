public class ScheduledFinancialAudit implements Schedulable {
    private static final Integer STALE_DAYS = 7;
    private static final Integer BATCH_LIMIT = 2000;

    public void execute(SchedulableContext context) {
        DateTime cutoff = System.now().addDays(-STALE_DAYS);

        List<Disbursement__c> staleDisbursements = [
            SELECT Id
            FROM Disbursement__c
            WHERE Audit_Flagged__c = false
            AND GL_Sync_Status__c != :NovaGrantsConfig.INTEGRATION_STATUS_SYNCED
            AND CreatedDate < :cutoff
            LIMIT :BATCH_LIMIT
        ];

        if (staleDisbursements.isEmpty()) {
            return;
        }

        DateTime now = System.now();
        for (Disbursement__c disbursement : staleDisbursements) {
            disbursement.Audit_Flagged__c = true;
            disbursement.Last_Audit_Date__c = now;
        }
        update staleDisbursements;
    }
}