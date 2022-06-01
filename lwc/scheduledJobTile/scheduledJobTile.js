import { LightningElement, api } from 'lwc';
import deleteJobFromTile from '@salesforce/apex/ScheduledJobApex.deleteJobFromTile';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ScheduledJobTile extends LightningElement {
    @api jobDetail;
    showDeleteModal = false;
    showJobDetailModal = false;

    deleteHandler(){
        console.log('VSD this.jobDetail.Id :: ' + this.jobDetail.Id);

        deleteJobFromTile({jobId : this.jobDetail.Id}).then(result=>{
            console.log('VSD result :: ' + result);
            const deleteEvent = new CustomEvent('deletejob');
            this.dispatchEvent(deleteEvent);
            this.showToast('SUCCESS', 'Job deleted successfully', 'success');
            this.showDeleteModal = false;
        }).catch(error=>{
            console.log('VSD error :: ' + error);
            console.log('VSD error :stringify: ' + JSON.stringify(error));
            this.showToast('ERROR', error.body.message, 'error');
            this.showDeleteModal = false;
        });
    }

    cancelModalHandler(){
        this.showDeleteModal = false;
    }

    showDeleteModalHandler(){
        this.showDeleteModal = true;
    }

    showToast(title, message, variant){
        const toastEvent = new ShowToastEvent({
            title : title,
            message : message,
            variant : variant
        });
        this.dispatchEvent(toastEvent);
    }

    showJobDetailModalHandler(){
        this.showJobDetailModal = true;
    }

    closeJobDetailModalHandler(){
        this.showJobDetailModal = false;
    }
}