import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import queryOpportunityAmount  from '@salesforce/apex/EngagementSummaryController.queryOpportunityAmount';
import getCompletedTasksCount  from '@salesforce/apex/EngagementSummaryController.getCompletedTasksCount';
import getUpcomingEventsCount  from '@salesforce/apex/EngagementSummaryController.getUpcomingEventsCount';
import createFollowUpTask      from '@salesforce/apex/EngagementSummaryController.createFollowUpTask';

import NAME_FIELD from '@salesforce/schema/Engagement__c.Name';

const ENGAGEMENT_FIELDS = [NAME_FIELD];

export default class EngagementSummary extends LightningElement {

    @api recordId;

    @track opportunityAmount   = 0;
    @track completedTasksCount = 0;
    @track upcomingEventsCount = 0;
    @track engagementName      = '';
    @track error               = null;
    @track isLoading           = true;
    @track isActionLoading     = false;

    @wire(getRecord, { recordId: '$recordId', fields: ENGAGEMENT_FIELDS })
    wiredEngagement({ error, data }) {
        if (data) {
            this.engagementName = getFieldValue(data, NAME_FIELD) || '';
            this.loadSummaryData();
        } else if (error) {
            this.handleError('Error loading engagement record.', error);
            this.isLoading = false;
        }
    }

    async loadSummaryData() {
        this.isLoading = true;
        this.error     = null;

        try {
            const [amount, tasks, events] = await Promise.all([
                queryOpportunityAmount({ engagementId: this.recordId }),
                getCompletedTasksCount({ engagementId: this.recordId }),
                getUpcomingEventsCount({ engagementId: this.recordId })
            ]);

            this.opportunityAmount   = amount  ?? 0;
            this.completedTasksCount = tasks   ?? 0;
            this.upcomingEventsCount = events  ?? 0;
        } catch (err) {
            this.handleError('Error loading summary data.', err);
        } finally {
            this.isLoading = false;
        }
    }

    async handleCreateFollowUp() {
        this.isActionLoading = true;
        try {
            await createFollowUpTask({
                engagementId:   this.recordId,
                engagementName: this.engagementName
            });

            this.dispatchEvent(new ShowToastEvent({
                title:   'Task Created',
                message: 'Follow-up call task has been created successfully.',
                variant: 'success'
            }));

            await this.loadSummaryData();
        } catch (err) {
            this.handleError('Could not create follow-up task.', err);
        } finally {
            this.isActionLoading = false;
        }
    }

    get formattedAmount() {
        return new Intl.NumberFormat('en-US', {
            style:    'currency',
            currency: 'USD',
            maximumFractionDigits: 0
        }).format(this.opportunityAmount || 0);
    }

    handleError(message, err) {
        const detail = err?.body?.message || err?.message || JSON.stringify(err);
        this.error = `${message} ${detail}`;
        this.dispatchEvent(new ShowToastEvent({
            title:   'Error',
            message: this.error,
            variant: 'error',
            mode:    'sticky'
        }));
    }
}
