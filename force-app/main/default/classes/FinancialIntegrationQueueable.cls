public class FinancialIntegrationQueueable implements Queueable, Database.AllowsCallouts {
    private static final Integer DEFAULT_TIMEOUT_MS = 20000;

    private List<Id> disbursementIds;

    public FinancialIntegrationQueueable(List<Id> disbursementIds) {
        this.disbursementIds = disbursementIds == null ? new List<Id>() : disbursementIds;
    }

    public void execute(QueueableContext context) {
        if (disbursementIds.isEmpty()) {
            return;
        }

        List<Disbursement__c> disbursements = [
            SELECT
                Id,
                Approved_Amount__c,
                Payment_Reference__c,
                GL_Sync_Attempts__c,
                GL_Sync_Status__c,
                External_Transaction_ID__c,
                Error_Message__c
            FROM Disbursement__c
            WHERE Id IN :disbursementIds
            AND GL_Sync_Status__c IN (:NovaGrantsConfig.INTEGRATION_STATUS_PENDING, :NovaGrantsConfig.INTEGRATION_STATUS_RETRYING)
        ];

        List<Disbursement__c> updates = new List<Disbursement__c>();
        List<Id> retryIds = new List<Id>();
        List<Error_Log__c> logs = new List<Error_Log__c>();

        for (Disbursement__c disbursement : disbursements) {
            Integer attempts = valueOrZero(disbursement.GL_Sync_Attempts__c) + 1;
            disbursement.GL_Sync_Attempts__c = attempts;
            disbursement.GL_Last_Attempt__c = System.now();

            try {
                String transactionId = postToGeneralLedger(disbursement);
                disbursement.GL_Sync_Status__c = NovaGrantsConfig.INTEGRATION_STATUS_SYNCED;
                disbursement.External_Transaction_ID__c = transactionId;
                disbursement.Error_Message__c = null;
            } catch (Exception ex) {
                disbursement.Error_Message__c = ex.getMessage();
                if (attempts < NovaGrantsConfig.maxRetries()) {
                    disbursement.GL_Sync_Status__c = NovaGrantsConfig.INTEGRATION_STATUS_RETRYING;
                    retryIds.add(disbursement.Id);
                } else {
                    disbursement.GL_Sync_Status__c = NovaGrantsConfig.INTEGRATION_STATUS_FAILED;
                    logs.add(
                        new Error_Log__c(
                            Flow_Name__c = 'FinancialIntegrationQueueable',
                            Record_Id__c = String.valueOf(disbursement.Id),
                            Error_Message__c = ex.getMessage(),
                            Severity__c = 'Error',
                            Payload__c = String.valueOf(disbursement.Payment_Reference__c),
                            Resolved__c = false,
                            Occurred_At__c = System.now()
                        )
                    );
                }
            }
            updates.add(disbursement);
        }

        if (!updates.isEmpty()) {
            // Ledger CRUD remains unavailable to coordinators; this background worker writes only integration results.
            Database.update(updates, AccessLevel.SYSTEM_MODE);
        }
        if (!logs.isEmpty()) {
            Database.insert(logs, AccessLevel.SYSTEM_MODE);
        }
        if (!retryIds.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(new FinancialIntegrationQueueable(retryIds));
        }
    }

    @TestVisible
    private static String postToGeneralLedger(Disbursement__c disbursement) {
        if (NovaGrantsConfig.mockMode()) {
            return 'MOCK-' + disbursement.Payment_Reference__c;
        }

        String endpoint = NovaGrantsConfig.endpoint();

        Map<String, Object> payload = new Map<String, Object>{
            'reference' => disbursement.Payment_Reference__c,
            'amount' => disbursement.Approved_Amount__c,
            'glAccount' => NovaGrantsConfig.glAccountCode()
        };

        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setBody(JSON.serialize(payload));
        request.setTimeout(DEFAULT_TIMEOUT_MS);

        HttpResponse response = new Http().send(request);
        Integer statusCode = response.getStatusCode();
        if (statusCode >= 200 && statusCode < 300) {
            return 'GL-' + disbursement.Id;
        }
        throw new NovaGrantsException('General ledger post failed with status ' + statusCode);
    }

    private static Integer valueOrZero(Decimal inputValue) {
        return inputValue == null ? 0 : inputValue.intValue();
    }
}