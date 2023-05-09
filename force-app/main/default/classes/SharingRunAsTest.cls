@isTest
private with sharing class SharingRunAsTest {
    static CustomObject__c createRecord() {
        CustomObject__c record = new CustomObject__c(Name='test');
        insert record;
        return record;
    }

    static User createUser(String alias) {
        /*  using a profile that has read and edit 
            on an object that has OWD set to private */
        User newUser = new User(
            Alias = alias,
            Email = alias + '@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = alias,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'TestProfile'].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = alias + '@test.com'
        );
        insert newUser;
        return newUser;
    }   

    static void createShare(String userId, String recordId) {
        insert new CustomObject__share(
            ParentId = recordId,
            UserOrGroupId = userId,
            RowCause = 'MySharingReason__c', // a sharing reason that exists on CustomObject__c
            AccessLevel = 'Read'
        );
    }

    @isTest
    static void runTest() {
        CustomObject__c record = createRecord();
        User userA = createUser('user_a'); // user that won't have access
        User userB = createUser('user_b'); // user that will have access

        createShare(userB.Id, record.Id);
    
        // Now I have a test record created, shared to user b, but not shared to user A
        // I would like to assert that user A does not have access to this record
        // In this simplified scenario, you could argue that I should just test whether or
        // not user A has access to any records, but our actual feature has more complicated
        // scenarios, such as testing that a user has access to some but not all records, 
        // and/or they have read but not edit access, etc

        System.runAs(userA) {

            CustomObject__c[] results = [
                SELECT 
                    Name, 
                    UserRecordAccess.HasReadAccess, 
                    UserRecordAccess.HasEditAccess
                FROM CustomObject__c
            ];

            System.debug(results.size()); // 0... great! what I'd expect

            SystemModeQuery query = new SystemModeQuery();
            CustomObject__c[] resultsWithSystemMode = query.getRecords();

            System.debug(resultsWithSystemMode.size()); // 1... great! what I'd expect

            /* !!! WEIRD STUFF HERE !!! */
            
            System.debug(resultsWithSystemMode[0].UserRecordAccess.HasReadAccess); // this returns true???
            System.debug(resultsWithSystemMode[0].UserRecordAccess.HasEditAccess); // this returns true???
        }
    }
        // If I directly query UserRecordAccess without using System

    without sharing class SystemModeQuery {

        SystemModeQuery() {}

        CustomObject__c[] getRecords() { 
            return [
                SELECT Name, UserRecordAccess.HasReadAccess, UserRecordAccess.HasEditAccess
                FROM CustomObject__c
                WITH SYSTEM_MODE
            ];
        }
    }
}