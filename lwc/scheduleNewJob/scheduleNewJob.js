import { LightningElement, track, wire } from 'lwc';
import getApexClassNames from '@salesforce/apex/ScheduledJobApex.getApexClassNames';
import createScheduledJob from '@salesforce/apex/ScheduledJobApex.createScheduledJob';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import scheduledJobMessageChannel from '@salesforce/messageChannel/scheduledJobMessageChannel__c';
import { publish, MessageContext } from 'lightning/messageService';

export default class CreateScheduledJob extends LightningElement {
    @track jobNameOptions = [];

    jobNameValue;
    timeUnitTypeValue;
    timeUnitValue;

    @wire(MessageContext)
    messageContext;

    timeUnitTypeOptions = [
        {label : 'Second', value : 'Second'},
        {label : 'Minute', value : 'Minute'},
        {label : 'Hour', value : 'Hour'},
        {label : 'Month', value : 'Month'},
        {label : 'Year', value : 'Year'}
    ];
    
    jobNameChangeHandler(event){
        this.jobNameValue = event.detail.value;
    }

    timeUnitTypeChangeHandler(event){
        this.timeUnitTypeValue = event.detail.value;
    }

    timeUnitChangeHandler(event){
        this.timeUnitValue = event.detail.value;
    }

    clearOnClickHandler(){
        this.jobNameValue = '';
        this.timeUnitTypeValue = '';
        this.timeUnitValue = '';
    }

    saveOnClickHandler(){
        console.log(`VSD jobNameValue : ${this.jobNameValue}`);
        console.log(`VSD timeUnitTypeValue : ${this.timeUnitTypeValue}`);
        console.log(`VSD timeUnitValue : ${this.timeUnitValue}`);

        createScheduledJob({jobName : this.jobNameValue
            ,               timeUnitType : this.timeUnitTypeValue
            ,               timeUnit : this.timeUnitValue}).then(result=>{
            console.log('VSD result: ' + result);
            this.showToast('SUCCESS', 'Job Scheduled Successfully', 'success');
            this.jobNameValue = '';
            this.timeUnitTypeValue = '';
            this.timeUnitValue = '';
            const payload = { jobCreatedFlag: 'true'};
            publish(this.messageContext, scheduledJobMessageChannel, payload);
        }).catch(error=>{
            console.log('VSD error :: ' + error);
            console.log('VSD error :stringify: ' + JSON.stringify(error));
            this.showToast('ERROR', error.body.message, 'error');
        });

    }

    connectedCallback(){
        getApexClassNames().then(result=>{
            this.scheduledClasses = result;
            for(let i = 0; i < this.scheduledClasses.length; i++){
                const scheduledClass = this.scheduledClasses[i];
                const option = {label: scheduledClass.Name, value: scheduledClass.Name};
                this.jobNameOptions = [ ...this.jobNameOptions, option ];
            }
        }).catch(error=>{
            this.error=error;
        });
    }

    showToast(title, message, variant){
        const toastEvent = new ShowToastEvent({
            title : title,
            message : message,
            variant : variant
        });
        this.dispatchEvent(toastEvent);
    }

    /*@wire( getApexClassNames )
    scheduledClasses( { error, data } ) {
        if (data) {
            for(const list of data){
                const option = {
                    label: list.Name,
                    value: list.Name
                };
                // this.selectOptions.push(option);
                this.options = [ ...this.options, option ];
            }
        } else if (error) {
            console.error(error);
        }

    }*/
}