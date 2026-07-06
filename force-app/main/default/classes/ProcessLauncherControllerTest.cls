@isTest
private class ProcessLauncherControllerTest {

    // Custom metadata records seeded in the repo are visible to tests, so we assert on the
    // shipped Opportunity configuration rather than inserting CMDT (which is not DML-insertable).

    @isTest
    static void returnsActiveActionsForObjectInSortOrder() {
        Test.startTest();
        List<ProcessLauncherController.ActionConfig> actions =
            ProcessLauncherController.getActions('Opportunity');
        Test.stopTest();

        System.assert(!actions.isEmpty(), 'Opportunity should have configured actions');

        Decimal previous = -1;
        for (ProcessLauncherController.ActionConfig a : actions) {
            System.assertNotEquals(null, a.label, 'Each action should have a label');
            if (a.sortOrder != null) {
                System.assert(a.sortOrder >= previous, 'Actions should be returned in sort order');
                previous = a.sortOrder;
            }
        }
    }

    @isTest
    static void returnsEmptyForBlankOrUnknownObject() {
        Test.startTest();
        List<ProcessLauncherController.ActionConfig> blank =
            ProcessLauncherController.getActions('');
        List<ProcessLauncherController.ActionConfig> unknown =
            ProcessLauncherController.getActions('ThisObjectDoesNotExist__x');
        Test.stopTest();

        System.assertEquals(0, blank.size(), 'Blank object name returns no actions');
        System.assertEquals(0, unknown.size(), 'Unknown object returns no actions');
    }
}
