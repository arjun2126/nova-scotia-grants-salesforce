public with sharing class NovaGrantsAgentActions {
    public class ClaimInput {
        @InvocableVariable(required=true label='Claim Record ID')
        public String claimId;
    }

    public class ClaimOutput {
        @InvocableVariable(label='Claim Record ID')
        public String claimId;
        @InvocableVariable(label='Succeeded')
        public Boolean success;
        @InvocableVariable(label='Result Status')
        public String status;
        @InvocableVariable(label='Reimbursement Amount')
        public Decimal reimbursementAmount;
        @InvocableVariable(label='Message')
        public String message;
    }

    @InvocableMethod(label='Adjudicate Grant Claims' description='Evaluates one or more submitted grant claims and returns the adjudication outcome for each. Fictional demonstration only.')
    public static List<ClaimOutput> adjudicateClaims(List<ClaimInput> inputs) {
        List<ClaimOutput> outputs = new List<ClaimOutput>();
        if (inputs == null || inputs.isEmpty()) {
            return outputs;
        }

        List<Id> validClaimIds = new List<Id>();
        for (ClaimInput input : inputs) {
            String raw = input == null ? null : input.claimId;
            try {
                validClaimIds.add((Id) raw);
            } catch (Exception e) {
                // Invalid or blank ids are returned as outputs below.
            }
        }

        Map<Id, ClaimAdjudicationService.Result> resultsByClaim = new Map<Id, ClaimAdjudicationService.Result>();
        if (!validClaimIds.isEmpty()) {
            for (ClaimAdjudicationService.Result result : ClaimAdjudicationService.approveClaims(validClaimIds)) {
                resultsByClaim.put(result.claimId, result);
            }
        }

        for (ClaimInput input : inputs) {
            ClaimOutput output = new ClaimOutput();
            output.claimId = input == null ? null : input.claimId;
            Id claimId = toId(input == null ? null : input.claimId);
            ClaimAdjudicationService.Result result = claimId == null ? null : resultsByClaim.get(claimId);
            if (result == null) {
                output.success = false;
                output.status = ClaimAdjudicationService.RESULT_NOT_ELIGIBLE;
                output.message = claimId == null
                    ? 'A valid claim record id is required.'
                    : 'Claim was not evaluated. Retry or contact an administrator.';
            } else {
                output.success = result.success;
                output.status = result.status;
                output.reimbursementAmount = result.amount;
                output.message = result.message;
            }
            outputs.add(output);
        }
        return outputs;
    }

    private static Id toId(String value) {
        try {
            return String.isBlank(value) ? null : (Id) value;
        } catch (Exception e) {
            return null;
        }
    }
}