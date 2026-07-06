// Seeds demo data for the Bedrock badge demo (S4 indirect accounts + process launcher, S5 talk track).
// Re-runnable: removes prior 'Bedrock Demo -' accounts (cascades to their contacts/opps/cases/ACRs) first.

// ---------- 0. Cleanup prior demo data ----------
List<Account> existing = [SELECT Id FROM Account WHERE Name LIKE 'Bedrock Demo -%'];
if (!existing.isEmpty()) {
    delete existing; // cascades to child Contacts, Opportunities, Cases, and AccountContactRelations
}

// ---------- 1. Accounts (AnnualRevenue drives "lifetime value") ----------
Account globex   = new Account(Name='Bedrock Demo - Globex Financial',     Industry='Finance',        AnnualRevenue=5000000,  Type='Customer', Description='Hub client used to demo indirect relationships.');
Account initech  = new Account(Name='Bedrock Demo - Initech Health',       Industry='Healthcare',     AnnualRevenue=3000000,  Type='Customer');
Account umbrella = new Account(Name='Bedrock Demo - Umbrella Energy',      Industry='Energy',         AnnualRevenue=8000000,  Type='Customer');
Account soylent  = new Account(Name='Bedrock Demo - Soylent Retail',       Industry='Retail',         AnnualRevenue=1500000,  Type='Prospect');
Account stark    = new Account(Name='Bedrock Demo - Stark Manufacturing',  Industry='Manufacturing',  AnnualRevenue=12000000, Type='Customer');
insert new List<Account>{ globex, initech, umbrella, soylent, stark };

// ---------- 2. Contacts (primary account auto-creates a direct AccountContactRelation) ----------
Contact alice = new Contact(FirstName='Alice', LastName='Advisor',  AccountId=globex.Id,  Title='CFO',        Email='alice@globex.demo');
Contact bob   = new Contact(FirstName='Bob',   LastName='Banker',   AccountId=globex.Id,  Title='Controller', Email='bob@globex.demo');
Contact carol = new Contact(FirstName='Carol', LastName='Counsel',  AccountId=globex.Id,  Title='Counsel',    Email='carol@globex.demo');
Contact dave  = new Contact(FirstName='Dave',  LastName='Director', AccountId=initech.Id, Title='Director',   Email='dave@initech.demo');
insert new List<Contact>{ alice, bob, carol, dave };

// ---------- 3. Indirect relationships via AccountContactRelation ----------
// Shared contacts make other accounts appear as "indirect" relative to Globex, with these counts:
//   Initech  -> shared by Alice, Bob, Dave   (count 3)
//   Umbrella -> shared by Alice, Carol        (count 2)
//   Soylent  -> shared by Bob                  (count 1)
//   Stark    -> shared by Carol                (count 1)
insert new List<AccountContactRelation>{
    new AccountContactRelation(AccountId=initech.Id,  ContactId=alice.Id, Roles='Decision Maker'),
    new AccountContactRelation(AccountId=umbrella.Id, ContactId=alice.Id),
    new AccountContactRelation(AccountId=initech.Id,  ContactId=bob.Id),
    new AccountContactRelation(AccountId=soylent.Id,  ContactId=bob.Id),
    new AccountContactRelation(AccountId=umbrella.Id, ContactId=carol.Id),
    new AccountContactRelation(AccountId=stark.Id,    ContactId=carol.Id),
    new AccountContactRelation(AccountId=globex.Id,   ContactId=dave.Id, Roles='Influencer') // Dave (primary Initech) also touches Globex
};

// ---------- 4. Opportunities (for S4B launcher on Opportunity + S5 order-sync talk track) ----------
Date soon = Date.today().addDays(30);
insert new List<Opportunity>{
    new Opportunity(Name='Bedrock Demo - Globex Platform Renewal', AccountId=globex.Id,   StageName='Negotiation/Review', Amount=250000, CloseDate=soon),
    new Opportunity(Name='Bedrock Demo - Globex Expansion (Won)',  AccountId=globex.Id,   StageName='Closed Won',         Amount=480000, CloseDate=Date.today().addDays(-5)),
    new Opportunity(Name='Bedrock Demo - Initech Upgrade',         AccountId=initech.Id,  StageName='Prospecting',        Amount=90000,  CloseDate=soon),
    new Opportunity(Name='Bedrock Demo - Umbrella Grid Project',   AccountId=umbrella.Id, StageName='Proposal/Price Quote', Amount=620000, CloseDate=soon)
};

// ---------- 5. A Case on Globex (for S4B launcher reuse on a different object) ----------
insert new Case(Subject='Bedrock Demo - Online banking outage', AccountId=globex.Id, Status='New', Priority='High', Origin='Phone');

System.debug('=== Globex (open this to demo indirect accounts + AI insight): ' + globex.Id);
System.debug('=== Globex Platform Renewal opp: open any Bedrock Demo opportunity to demo the Process Launcher chevrons');
