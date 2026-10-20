public with sharing class NovaGrantsConfig {
    public static final String INTEGRATION_STATUS_PENDING = 'Pending';
    public static final String INTEGRATION_STATUS_SYNCED = 'Synced';
    public static final String INTEGRATION_STATUS_RETRYING = 'Retrying';
    public static final String INTEGRATION_STATUS_FAILED = 'Failed';

    public static Nova_Grants_Setting__c getSetting() {
        Nova_Grants_Setting__c setting = Nova_Grants_Setting__c.getOrgDefaults();
        if (setting == null) {
            setting = new Nova_Grants_Setting__c();
        }
        return setting;
    }

    public static Integer maxRetries() {
        Decimal configured = getSetting().Max_Retries__c;
        if (configured == null || configured.intValue() < 1) {
            return 3;
        }
        return configured.intValue();
    }

    public static String endpoint() {
        return getSetting().Endpoint__c;
    }

    public static Boolean mockMode() {
        if (String.isBlank(endpoint())) {
            return true;
        }
        Boolean configured = getSetting().Mock_Mode__c;
        return configured == null ? true : configured;
    }

    public static String glAccountCode() {
        String configured = getSetting().GL_Account_Code__c;
        return configured == null ? 'DEMO-GL-0000' : configured;
    }
}