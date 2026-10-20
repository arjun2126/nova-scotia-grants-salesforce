// Nova Scotia Economic Growth and Grant Management Platform
// Fictional demonstration seed data only. No real businesses, people, or registry numbers.
// Idempotent: re-running updates records by external key.
// Approved disbursements are NOT seeded. Claims are seeded as submitted and are
// adjudicated by ClaimAdjudicationService so the required approval logic runs.

// ---------- Accounts ----------
List<Account> accounts = new List<Account>{
    new Account(
        Name = 'Atlantic Wave Analytics',
        NS_Business_Number__c = 'DEMO-NS-0001',
        Sector__c = 'Technology',
        Region__c = 'Halifax',
        Employee_Count__c = 120,
        Primary_Contact_Email__c = 'demo.contact1@example.invalid',
        Industry = 'Technology',
        BillingCity = 'Halifax',
        BillingState = 'NS',
        BillingCountry = 'Canada',
        Description = 'Fictional demonstration business. Not a real company.'
    ),
    new Account(
        Name = 'Cape Tide Ocean Systems',
        NS_Business_Number__c = 'DEMO-NS-0002',
        Sector__c = 'Ocean Technology',
        Region__c = 'Cape Breton',
        Employee_Count__c = 80,
        Primary_Contact_Email__c = 'demo.contact2@example.invalid',
        Industry = 'Technology',
        BillingCity = 'Sydney',
        BillingState = 'NS',
        BillingCountry = 'Canada',
        Description = 'Fictional demonstration business. Not a real company.'
    ),
    new Account(
        Name = 'Green Harbour Energy',
        NS_Business_Number__c = 'DEMO-NS-0003',
        Sector__c = 'Clean Technology',
        Region__c = 'Halifax',
        Employee_Count__c = 45,
        Primary_Contact_Email__c = 'demo.contact3@example.invalid',
        Industry = 'Energy',
        BillingCity = 'Dartmouth',
        BillingState = 'NS',
        BillingCountry = 'Canada',
        Description = 'Fictional demonstration business. Not a real company.'
    ),
    new Account(
        Name = 'Valley BioLabs',
        NS_Business_Number__c = 'DEMO-NS-0004',
        Sector__c = 'Life Sciences',
        Region__c = 'Annapolis Valley',
        Employee_Count__c = 210,
        Primary_Contact_Email__c = 'demo.contact4@example.invalid',
        Industry = 'Biotechnology',
        BillingCity = 'Kentville',
        BillingState = 'NS',
        BillingCountry = 'Canada',
        Description = 'Fictional demonstration business. Not a real company.'
    ),
    new Account(
        Name = 'Maritime Precision Works',
        NS_Business_Number__c = 'DEMO-NS-0005',
        Sector__c = 'Advanced Manufacturing',
        Region__c = 'Northeastern',
        Employee_Count__c = 320,
        Primary_Contact_Email__c = 'demo.contact5@example.invalid',
        Industry = 'Manufacturing',
        BillingCity = 'New Glasgow',
        BillingState = 'NS',
        BillingCountry = 'Canada',
        Description = 'Fictional demonstration business. Not a real company.'
    ),
    new Account(
        Name = 'South Shore Organics',
        NS_Business_Number__c = 'DEMO-NS-0006',
        Sector__c = 'Other',
        Region__c = 'South Shore',
        Employee_Count__c = 25,
        Primary_Contact_Email__c = 'demo.contact6@example.invalid',
        Industry = 'Agriculture',
        BillingCity = 'Bridgewater',
        BillingState = 'NS',
        BillingCountry = 'Canada',
        Description = 'Fictional demonstration business. Not a real company.'
    )
};
Database.upsert(accounts, Account.NS_Business_Number__c, false);

Map<String, Id> accountIdByKey = new Map<String, Id>();
for (Account acct : [
    SELECT Id, NS_Business_Number__c
    FROM Account
    WHERE NS_Business_Number__c LIKE 'DEMO-NS-%'
]) {
    accountIdByKey.put(acct.NS_Business_Number__c, acct.Id);
}

// ---------- Programs ----------
List<Program__c> programs = new List<Program__c>{
    new Program__c(
        Name = 'Digital Adoption Program',
        Program_Code__c = 'DAP-DEMO',
        Funding_Cap__c = 250000,
        Co_Pay_Percentage__c = 50,
        Program_Status__c = 'Active',
        Min_Employees__c = 1,
        Max_Employees__c = 500,
        Description__c = 'Illustrative 50 percent cost-match up to a program cap. Parameters are fictional demonstration values, not official program terms.'
    ),
    new Program__c(
        Name = 'Export Development Program',
        Program_Code__c = 'EDP-DEMO',
        Funding_Cap__c = 500000,
        Co_Pay_Percentage__c = 50,
        Program_Status__c = 'Active',
        Min_Employees__c = 1,
        Max_Employees__c = 1000,
        Description__c = 'Illustrative export scale-up cost-share. Parameters are fictional demonstration values, not official program terms.'
    ),
    new Program__c(
        Name = 'Productivity and Innovation Voucher Program',
        Program_Code__c = 'PIVP-DEMO',
        Funding_Cap__c = 150000,
        Co_Pay_Percentage__c = 75,
        Program_Status__c = 'Active',
        Min_Employees__c = 5,
        Max_Employees__c = 250,
        Description__c = 'Illustrative innovation voucher cost-share. Parameters are fictional demonstration values, not official program terms.'
    )
};
Database.upsert(programs, Program__c.Program_Code__c, false);

Map<String, Id> programIdByCode = new Map<String, Id>();
for (Program__c program : [
    SELECT Id, Program_Code__c
    FROM Program__c
    WHERE Program_Code__c LIKE '%-DEMO'
]) {
    programIdByCode.put(program.Program_Code__c, program.Id);
}

// ---------- Applications ----------
List<Application__c> applications = new List<Application__c>{
    new Application__c(
        External_Key__c = 'DEMO-APP-001',
        Account__c = accountIdByKey.get('DEMO-NS-0001'),
        Program__c = programIdByCode.get('DAP-DEMO'),
        Sector__c = 'Technology',
        Region__c = 'Halifax',
        Requested_Amount__c = 10000,
        Approved_Amount__c = 10000,
        Stage__c = 'Approved',
        Eligibility_Status__c = 'Eligible',
        Documents_Complete__c = true,
        Submitted_Date__c = Date.today().addDays(-40),
        Decision_Date__c = Date.today().addDays(-20)
    ),
    new Application__c(
        External_Key__c = 'DEMO-APP-002',
        Account__c = accountIdByKey.get('DEMO-NS-0002'),
        Program__c = programIdByCode.get('EDP-DEMO'),
        Sector__c = 'Ocean Technology',
        Region__c = 'Cape Breton',
        Requested_Amount__c = 40000,
        Approved_Amount__c = 30000,
        Stage__c = 'Approved',
        Eligibility_Status__c = 'Eligible',
        Documents_Complete__c = true,
        Submitted_Date__c = Date.today().addDays(-35),
        Decision_Date__c = Date.today().addDays(-15)
    ),
    new Application__c(
        External_Key__c = 'DEMO-APP-003',
        Account__c = accountIdByKey.get('DEMO-NS-0003'),
        Program__c = programIdByCode.get('DAP-DEMO'),
        Sector__c = 'Clean Technology',
        Region__c = 'Halifax',
        Requested_Amount__c = 8000,
        Approved_Amount__c = 8000,
        Stage__c = 'Approved',
        Eligibility_Status__c = 'Eligible',
        Documents_Complete__c = true,
        Submitted_Date__c = Date.today().addDays(-30),
        Decision_Date__c = Date.today().addDays(-10)
    ),
    new Application__c(
        External_Key__c = 'DEMO-APP-004',
        Account__c = accountIdByKey.get('DEMO-NS-0004'),
        Program__c = programIdByCode.get('PIVP-DEMO'),
        Sector__c = 'Life Sciences',
        Region__c = 'Annapolis Valley',
        Requested_Amount__c = 20000,
        Approved_Amount__c = 15000,
        Stage__c = 'Approved',
        Eligibility_Status__c = 'Eligible',
        Documents_Complete__c = true,
        Submitted_Date__c = Date.today().addDays(-28),
        Decision_Date__c = Date.today().addDays(-12)
    ),
    new Application__c(
        External_Key__c = 'DEMO-APP-005',
        Account__c = accountIdByKey.get('DEMO-NS-0005'),
        Program__c = programIdByCode.get('EDP-DEMO'),
        Sector__c = 'Advanced Manufacturing',
        Region__c = 'Northeastern',
        Requested_Amount__c = 60000,
        Approved_Amount__c = 50000,
        Stage__c = 'Approved',
        Eligibility_Status__c = 'Eligible',
        Documents_Complete__c = true,
        Submitted_Date__c = Date.today().addDays(-25),
        Decision_Date__c = Date.today().addDays(-8)
    ),
    new Application__c(
        External_Key__c = 'DEMO-APP-006',
        Account__c = accountIdByKey.get('DEMO-NS-0006'),
        Program__c = programIdByCode.get('DAP-DEMO'),
        Sector__c = 'Other',
        Region__c = 'South Shore',
        Requested_Amount__c = 5000,
        Approved_Amount__c = 5000,
        Stage__c = 'Approved',
        Eligibility_Status__c = 'Eligible',
        Documents_Complete__c = true,
        Submitted_Date__c = Date.today().addDays(-20),
        Decision_Date__c = Date.today().addDays(-5)
    )
};
Database.upsert(applications, Application__c.External_Key__c, false);

Map<String, Id> applicationIdByKey = new Map<String, Id>();
for (Application__c app : [
    SELECT Id, External_Key__c
    FROM Application__c
    WHERE External_Key__c LIKE 'DEMO-APP-%'
]) {
    applicationIdByKey.put(app.External_Key__c, app.Id);
}

// ---------- Claims (submitted only; adjudication creates disbursements) ----------
List<Claim__c> claims = new List<Claim__c>{
    new Claim__c(
        External_Key__c = 'DEMO-CLM-001',
        Application__c = applicationIdByKey.get('DEMO-APP-001'),
        Vendor_Invoice_Number__c = 'DEMO-INV-0001',
        Vendor_Invoice_Amount__c = 4000,
        Proof_of_Payment_Verified__c = true,
        Claim_Status__c = 'Submitted for Verification',
        Claim_Submitted_Date__c = Date.today().addDays(-6),
        Sector__c = 'Technology'
    ),
    new Claim__c(
        External_Key__c = 'DEMO-CLM-002',
        Application__c = applicationIdByKey.get('DEMO-APP-002'),
        Vendor_Invoice_Number__c = 'DEMO-INV-0002',
        Vendor_Invoice_Amount__c = 12000,
        Proof_of_Payment_Verified__c = true,
        Claim_Status__c = 'Submitted for Verification',
        Claim_Submitted_Date__c = Date.today().addDays(-5),
        Sector__c = 'Ocean Technology'
    ),
    new Claim__c(
        External_Key__c = 'DEMO-CLM-003',
        Application__c = applicationIdByKey.get('DEMO-APP-003'),
        Vendor_Invoice_Number__c = 'DEMO-INV-0003',
        Vendor_Invoice_Amount__c = 8000,
        Proof_of_Payment_Verified__c = true,
        Claim_Status__c = 'Submitted for Verification',
        Claim_Submitted_Date__c = Date.today().addDays(-9),
        Sector__c = 'Clean Technology'
    ),
    new Claim__c(
        External_Key__c = 'DEMO-CLM-004',
        Application__c = applicationIdByKey.get('DEMO-APP-004'),
        Vendor_Invoice_Number__c = 'DEMO-INV-0004',
        Vendor_Invoice_Amount__c = 8000,
        Proof_of_Payment_Verified__c = true,
        Claim_Status__c = 'Submitted for Verification',
        Claim_Submitted_Date__c = Date.today().addDays(-4),
        Sector__c = 'Life Sciences'
    ),
    new Claim__c(
        External_Key__c = 'DEMO-CLM-005',
        Application__c = applicationIdByKey.get('DEMO-APP-005'),
        Vendor_Invoice_Number__c = 'DEMO-INV-0005',
        Vendor_Invoice_Amount__c = 20000,
        Proof_of_Payment_Verified__c = true,
        Claim_Status__c = 'Submitted for Verification',
        Claim_Submitted_Date__c = Date.today().addDays(-3),
        Sector__c = 'Advanced Manufacturing'
    ),
    new Claim__c(
        External_Key__c = 'DEMO-CLM-006',
        Application__c = applicationIdByKey.get('DEMO-APP-006'),
        Vendor_Invoice_Number__c = 'DEMO-INV-0006',
        Vendor_Invoice_Amount__c = 1000,
        Proof_of_Payment_Verified__c = false,
        Claim_Status__c = 'Draft',
        Claim_Submitted_Date__c = Date.today().addDays(-2),
        Sector__c = 'Other'
    )
};
Database.upsert(claims, Claim__c.External_Key__c, false);

// ---------- Economic impact metrics ----------
List<Impact_Metric__c> metrics = new List<Impact_Metric__c>{
    new Impact_Metric__c(External_Key__c = 'DEMO-IMP-001', Account__c = accountIdByKey.get('DEMO-NS-0001'), Metric_Date__c = Date.today().addDays(-10), Jobs_Created__c = 12, Jobs_Retained__c = 40, Export_Revenue_Increase__c = 250000, Region__c = 'Halifax'),
    new Impact_Metric__c(External_Key__c = 'DEMO-IMP-002', Account__c = accountIdByKey.get('DEMO-NS-0002'), Metric_Date__c = Date.today().addDays(-9), Jobs_Created__c = 8, Jobs_Retained__c = 30, Export_Revenue_Increase__c = 400000, Region__c = 'Cape Breton'),
    new Impact_Metric__c(External_Key__c = 'DEMO-IMP-003', Account__c = accountIdByKey.get('DEMO-NS-0003'), Metric_Date__c = Date.today().addDays(-8), Jobs_Created__c = 5, Jobs_Retained__c = 20, Export_Revenue_Increase__c = 100000, Region__c = 'Halifax'),
    new Impact_Metric__c(External_Key__c = 'DEMO-IMP-004', Account__c = accountIdByKey.get('DEMO-NS-0004'), Metric_Date__c = Date.today().addDays(-7), Jobs_Created__c = 18, Jobs_Retained__c = 75, Export_Revenue_Increase__c = 320000, Region__c = 'Annapolis Valley'),
    new Impact_Metric__c(External_Key__c = 'DEMO-IMP-005', Account__c = accountIdByKey.get('DEMO-NS-0005'), Metric_Date__c = Date.today().addDays(-6), Jobs_Created__c = 22, Jobs_Retained__c = 140, Export_Revenue_Increase__c = 800000, Region__c = 'Northeastern'),
    new Impact_Metric__c(External_Key__c = 'DEMO-IMP-006', Account__c = accountIdByKey.get('DEMO-NS-0006'), Metric_Date__c = Date.today().addDays(-5), Jobs_Created__c = 3, Jobs_Retained__c = 12, Export_Revenue_Increase__c = 45000, Region__c = 'South Shore')
};
Database.upsert(metrics, Impact_Metric__c.External_Key__c, false);

// ---------- Recompute committed application dollars per program ----------
Map<Id, Decimal> committedByProgram = new Map<Id, Decimal>();
for (AggregateResult result : [
    SELECT Program__c programId, SUM(Approved_Amount__c) committed
    FROM Application__c
    WHERE Stage__c = 'Approved' AND Program__c IN :programIdByCode.values()
    GROUP BY Program__c
]) {
    committedByProgram.put((Id) result.get('programId'), (Decimal) result.get('committed'));
}

List<Program__c> programUpdates = new List<Program__c>();
for (Program__c program : [
    SELECT Id, Committed_Amount__c
    FROM Program__c
    WHERE Id IN :programIdByCode.values()
]) {
    Decimal committed = committedByProgram.containsKey(program.Id) ? committedByProgram.get(program.Id) : 0;
    if (program.Committed_Amount__c != committed) {
        program.Committed_Amount__c = committed;
        programUpdates.add(program);
    }
}
if (!programUpdates.isEmpty()) {
    update programUpdates;
}

System.debug('Nova Grants demo seed complete. Accounts: ' + accountIdByKey.size() + ', Programs: ' + programIdByCode.size() + ', Applications: ' + applicationIdByKey.size() + ', Claims: ' + claims.size());
