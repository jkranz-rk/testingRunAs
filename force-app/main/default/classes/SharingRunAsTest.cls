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

            CustomObject__c[] recordsJoinedWithAccess = [
                SELECT 
                    Name, 
                    UserRecordAccess.HasReadAccess, 
                    UserRecordAccess.HasEditAccess
                FROM CustomObject__c
            ];

            System.debug('==== recordsJoinedWithAccess ====');
            System.debug(recordsJoinedWithAccess.size()); // 0... great! what I'd expect

            UserRecordAccess[] userRecordAccessQuery = [
                SELECT RecordId, HasReadAccess, HasEditAccess
                FROM UserRecordAccess
                WHERE RecordId = :record.Id
                AND UserId = :userA.Id
            ];

            System.debug('==== userRecordAccessQuery ====');
            System.debug('size: ' + userRecordAccessQuery.size());  // 1 
            System.debug('hasReadAccess: ' + userRecordAccessQuery[0].HasReadAccess); // false
            System.debug('hasEditAccess: ' + userRecordAccessQuery[0].HasEditAccess); // false


            WithoutSharingQuery query = new WithoutSharingQuery();
            
            UserRecordAccess[] userRecordAccessQueryWithoutSharing = query.getRecordAccess(userA.Id);

            System.debug('==== userRecordAccessQueryWithoutSharing ====');
            System.debug('size: ' + userRecordAccessQueryWithoutSharing.size()); // 1
            System.debug('hasReadAccess: ' + userRecordAccessQueryWithoutSharing[0].HasReadAccess); // false
            System.debug('hasEditAccess: ' + userRecordAccessQueryWithoutSharing[0].HasEditAccess); // false
            
            CustomObject__c[] recordsJoinedWithAccessWithoutSharing = query.getRecords();

            System.debug('==== recordsJoinedWithAccessWithoutSharing ====');
            System.debug('size: ' + recordsJoinedWithAccessWithoutSharing.size()); // 1
            /* !!! WEIRD STUFF HERE !!! */
            System.debug('hasReadAccess: ' + recordsJoinedWithAccessWithoutSharing[0].UserRecordAcces.HasReadAccess); // this returns true???
            System.debug('hasEditAccess: ' + recordsJoinedWithAccessWithoutSharing[0].UserRecordAccess.HasEditAccess); // this returns true???
        }
    }

    without sharing class WithoutSharingQuery {

        WithoutSharingQuery() {}

        CustomObject__c[] getRecords() { 
            return [
                SELECT Name, UserRecordAccess.HasReadAccess, UserRecordAccess.HasEditAccess
                FROM CustomObject__c
            ];
        }


        UserRecordAccess[] getRecordAccess(String userId) {
            Map<Id, CustomObject__c> records = new Map<Id, CustomObject__c>(getRecords());
            return [
                SELECT RecordId, HasReadAccess, HasEditAccess
                FROM UserRecordAccess
                WHERE RecordId IN :records.keySet()
                AND UserId = :userId
            ];
        }
    }
}