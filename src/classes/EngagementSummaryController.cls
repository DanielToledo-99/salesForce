public with sharing class EngagementSummaryController {

    @AuraEnabled(cacheable=true)
    public static Decimal queryOpportunityAmount(String engagementId) {
        try {
            if (String.isBlank(engagementId)) {
                throw new AuraHandledException('Engagement ID is required.');
            }

            Map<String, Schema.SObjectField> oppFields = Schema.SObjectType.Opportunity.fields.getMap();
            String soql = 'SELECT Amount FROM Opportunity WHERE StageName != \'Closed Lost\'';
            if (oppFields.containsKey('engagement__c')) {
                soql += ' AND Engagement__c = :engagementId';
            }
            soql += ' ORDER BY CreatedDate DESC LIMIT 1';

            List<Opportunity> opps = Database.queryWithBinds(
                soql,
                new Map<String, Object>{ 'engagementId' => engagementId },
                AccessLevel.USER_MODE
            );

            return opps.isEmpty() ? 0 : (opps[0].Amount != null ? opps[0].Amount : 0);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving opportunity amount: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Integer getCompletedTasksCount(String engagementId) {
        try {
            if (String.isBlank(engagementId)) {
                throw new AuraHandledException('Engagement ID is required.');
            }

            return [
                SELECT COUNT()
                FROM Task
                WHERE WhatId = :engagementId
                  AND Status = 'Completed'
                WITH SECURITY_ENFORCED
            ];
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving completed tasks count: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Integer getUpcomingEventsCount(String engagementId) {
        try {
            if (String.isBlank(engagementId)) {
                throw new AuraHandledException('Engagement ID is required.');
            }

            return [
                SELECT COUNT()
                FROM Event
                WHERE WhatId = :engagementId
                  AND StartDateTime >= :System.now()
                WITH SECURITY_ENFORCED
            ];
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving upcoming events count: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void createFollowUpTask(String engagementId, String engagementName) {
        try {
            if (String.isBlank(engagementId)) {
                throw new AuraHandledException('Engagement ID is required.');
            }

            if (!Schema.sObjectType.Task.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create tasks.');
            }

            Task followUp = new Task(
                Subject       = 'Follow-Up Call: ' + (String.isBlank(engagementName) ? 'Engagement' : engagementName),
                WhatId        = engagementId,
                OwnerId       = UserInfo.getUserId(),
                Status        = 'Not Started',
                Priority      = 'High',
                ActivityDate  = Date.today().addDays(1),
                Description   = 'Follow-up task created from Engagement Summary.'
            );

            insert followUp;
        } catch (AuraHandledException e) {
            throw e;
        } catch (DmlException e) {
            throw new AuraHandledException('Error creating follow-up task: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException('Unexpected error: ' + e.getMessage());
        }
    }
}
