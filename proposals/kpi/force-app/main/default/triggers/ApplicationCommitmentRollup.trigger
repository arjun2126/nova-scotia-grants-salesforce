trigger ApplicationCommitmentRollup on Application__c (after insert, after update, after delete, after undelete) {
    Set<Id> programIds = new Set<Id>();
    if (Trigger.isDelete) {
        for (Application__c application : Trigger.old) {
            programIds.add(application.Program__c);
        }
    } else {
        for (Application__c application : Trigger.new) {
            Application__c prior = Trigger.isUpdate ? Trigger.oldMap.get(application.Id) : null;
            if (prior == null || application.Stage__c != prior.Stage__c
                || application.Approved_Amount__c != prior.Approved_Amount__c
                || application.Program__c != prior.Program__c) {
                programIds.add(application.Program__c);
                if (prior != null) {
                    programIds.add(prior.Program__c);
                }
            }
        }
    }
    programIds.remove(null);
    ProgramCommitmentRollup.recalculate(programIds);
}
