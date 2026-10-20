// Recomputes only a derived commitment total; does not approve applications or authorize payments.
public without sharing class ProgramCommitmentRollup {
    public static void recalculate(Set<Id> programIds) {
        if (programIds.isEmpty()) {
            return;
        }
        // Lock the same parent records used by adjudication. Aggregate all Applications,
        // regardless of the updating user's visibility, so sharing cannot understate the total.
        List<Program__c> programs = [
            SELECT Id, Committed_Amount__c FROM Program__c WHERE Id IN :programIds FOR UPDATE
        ];
        Map<Id, Decimal> totals = new Map<Id, Decimal>();
        for (AggregateResult total : [
            SELECT Program__c programId, SUM(Approved_Amount__c) approved
            FROM Application__c
            WHERE Program__c IN :programIds AND Stage__c = 'Approved'
            GROUP BY Program__c
        ]) {
            Decimal approved = (Decimal) total.get('approved');
            totals.put((Id) total.get('programId'), approved == null ? 0 : approved);
        }
        List<Program__c> updates = new List<Program__c>();
        for (Program__c program : programs) {
            Decimal approved = totals.containsKey(program.Id) ? totals.get(program.Id) : 0;
            if (program.Committed_Amount__c != approved) {
                updates.add(new Program__c(Id = program.Id, Committed_Amount__c = approved));
            }
        }
        if (!updates.isEmpty()) {
            Database.update(updates, AccessLevel.SYSTEM_MODE);
        }
    }
}
