@isTest
public class NovaGrantsTestData {
    private static Integer sequence = 0;

    private static Integer nextSequence() {
        sequence++;
        return sequence;
    }

    public static Account createAccount(String suffix) {
        Account account = new Account(
            Name = 'Nova Test Co ' + suffix,
            NS_Business_Number__c = 'NS' + suffix.leftPad(7, '0'),
            Sector__c = 'Technology',
            Region__c = 'Halifax',
            Employee_Count__c = 25,
            Primary_Contact_Email__c = 'test' + suffix + '@example.com'
        );
        insert account;
        return account;
    }

    public static Program__c createProgram(String suffix, Decimal coPayPercentage) {
        Program__c program = new Program__c(
            Name = 'Nova Program ' + suffix,
            Program_Code__c = 'NP-' + suffix,
            Funding_Cap__c = 1000000,
            Co_Pay_Percentage__c = coPayPercentage,
            Program_Status__c = 'Active'
        );
        insert program;
        return program;
    }

    public static Application__c createApplication(Id accountId, Id programId, Decimal approvedAmount) {
        Application__c application = new Application__c(
            Account__c = accountId,
            Program__c = programId,
            Requested_Amount__c = approvedAmount,
            Approved_Amount__c = approvedAmount,
            Stage__c = 'Approved',
            Eligibility_Status__c = 'Eligible'
        );
        insert application;
        return application;
    }

    public static Claim__c createClaim(Id applicationId, Decimal invoiceAmount, Boolean proofVerified) {
        Claim__c claim = new Claim__c(
            Application__c = applicationId,
            Vendor_Invoice_Number__c = 'INV-' + String.valueOf(DateTime.now().getTime()) + '-' + nextSequence(),
            Vendor_Invoice_Amount__c = invoiceAmount,
            Proof_of_Payment_Verified__c = proofVerified,
            Claim_Status__c = 'Submitted for Verification',
            Claim_Submitted_Date__c = Date.today().addDays(-3)
        );
        insert claim;
        return claim;
    }
}