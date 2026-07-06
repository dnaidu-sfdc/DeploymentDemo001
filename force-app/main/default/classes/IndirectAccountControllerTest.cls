@isTest
private class IndirectAccountControllerTest {

    @testSetup
    static void setup() {
        Account viewed = new Account(Name = 'Viewed Co', Industry = 'Technology', AnnualRevenue = 1000000);
        Account related1 = new Account(Name = 'Alpha Partners', Industry = 'Finance', AnnualRevenue = 500000);
        Account related2 = new Account(Name = 'Beta Holdings', Industry = 'Energy', AnnualRevenue = 750000);
        insert new List<Account>{ viewed, related1, related2 };

        // Two contacts whose primary account is the viewed account (auto-creates direct ACRs).
        Contact c1 = new Contact(LastName = 'Smith', AccountId = viewed.Id);
        Contact c2 = new Contact(LastName = 'Jones', AccountId = viewed.Id);
        insert new List<Contact>{ c1, c2 };

        // Indirect relationships: both contacts also relate to related1, only c1 relates to related2.
        insert new List<AccountContactRelation>{
            new AccountContactRelation(AccountId = related1.Id, ContactId = c1.Id),
            new AccountContactRelation(AccountId = related1.Id, ContactId = c2.Id),
            new AccountContactRelation(AccountId = related2.Id, ContactId = c1.Id)
        };
    }

    @isTest
    static void returnsIndirectAccountsSortedByRelationshipCount() {
        Account viewed = [SELECT Id FROM Account WHERE Name = 'Viewed Co' LIMIT 1];

        Test.startTest();
        List<IndirectAccountController.RelatedAccount> results =
            IndirectAccountController.getRelatedAccounts(viewed.Id, 5, 'relationshipCount');
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Both indirect accounts should be returned');
        System.assertEquals('Alpha Partners', results[0].name, 'Highest relationship count should be first');
        System.assertEquals(2, results[0].relationshipCount, 'Alpha is shared by two contacts');
        System.assertEquals(2, results[0].numberOfContacts, 'Alpha relates to two contacts');
        System.assertEquals(1, results[1].relationshipCount, 'Beta is shared by one contact');
    }

    @isTest
    static void returnsIndirectAccountsSortedByName() {
        Account viewed = [SELECT Id FROM Account WHERE Name = 'Viewed Co' LIMIT 1];

        Test.startTest();
        List<IndirectAccountController.RelatedAccount> results =
            IndirectAccountController.getRelatedAccounts(viewed.Id, 5, 'name');
        Test.stopTest();

        System.assertEquals('Alpha Partners', results[0].name, 'Alphabetical order expected');
        System.assertEquals('Beta Holdings', results[1].name, 'Alphabetical order expected');
    }

    @isTest
    static void respectsMaxItems() {
        Account viewed = [SELECT Id FROM Account WHERE Name = 'Viewed Co' LIMIT 1];

        Test.startTest();
        List<IndirectAccountController.RelatedAccount> results =
            IndirectAccountController.getRelatedAccounts(viewed.Id, 1, 'relationshipCount');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'maxItems should cap the result size');
    }

    @isTest
    static void handlesNullAndNoRelationships() {
        Account lonely = new Account(Name = 'Lonely Co');
        insert lonely;

        Test.startTest();
        List<IndirectAccountController.RelatedAccount> none =
            IndirectAccountController.getRelatedAccounts(null, 5, null);
        List<IndirectAccountController.RelatedAccount> empty =
            IndirectAccountController.getRelatedAccounts(lonely.Id, 5, null);
        Test.stopTest();

        System.assertEquals(0, none.size(), 'Null account id returns empty list');
        System.assertEquals(0, empty.size(), 'Account with no contacts returns empty list');
    }
}
