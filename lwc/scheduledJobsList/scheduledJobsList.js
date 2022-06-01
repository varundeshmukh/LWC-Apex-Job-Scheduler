import { LightningElement, track, wire } from 'lwc';
import getJobDetails from '@salesforce/apex/ScheduledJobApex.getJobDetails';
import {
    subscribe,
    unsubscribe,
    APPLICATION_SCOPE,
    MessageContext
} from 'lightning/messageService';
import scheduledJobMessageChannel from '@salesforce/messageChannel/scheduledJobMessageChannel__c';

export default class ScheduledJobsList extends LightningElement {
    @track jobDetails;
    subscribe;

    @wire(MessageContext)
    messageContext;

    connectedCallback(){
        this.callApexGetJobDetails();
        this.subscribeToMessageChannel();
    }

    callApexGetJobDetails(){
        getJobDetails().then(result=>{
            this.jobDetails = (JSON.parse(result)).jobs;
            console.log('VSD Result :: ' + result);
        }).catch(error=>{
            console.log('VSD error :: ' + error);
            console.log('VSD error :stringify: ' + JSON.stringify(error));
        });
    }

    refreshHandler(){
        console.log('Refresh Clicked');
        this.callApexGetJobDetails();
    }

    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                scheduledJobMessageChannel,
                (message) => this.refreshHandler(),
                { scope: APPLICATION_SCOPE }
            );
        }
    }

    unsubscribeToMessageChannel() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    disconnectedCallback(){
        this.unsubscribeToMessageChannel()
    }

}