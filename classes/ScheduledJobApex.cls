public with sharing class ScheduledJobApex {

    public class JobRecs { 
        String Id;
        String Name;
        String TimeSubmitted;
        String TimeNextRun;
        String TimeUnitType;
        String TimeUnit;
        
        public JobRecs( String Id,
                        String Name,
                        String TimeSubmitted,
                        String TimeNextRun,
                        String TimeUnitType,
                        String TimeUnit) { 
            this.Id                       = Id;
            this.Name                     = Name;
            this.TimeSubmitted            = TimeSubmitted;
            this.TimeNextRun              = TimeNextRun;
            this.TimeUnitType             = TimeUnitType;
            this.TimeUnit                 = TimeUnit;

        }
    }

    @AuraEnabled
    public static void deleteJobFromTile(String jobId){
        try {
            Scheduled_Job__c job = [SELECT Id FROM Scheduled_Job__c WHERE Id = :jobId];
            delete job;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String getJobDetails(){
        try {
            Set<Id> jobIds = new Set<Id>();
            List<Scheduled_Job__c> scheduledJobs = [SELECT  Id
                                                    ,       Name
                                                    ,       Perpetual_Time_Unit_Type__c
                                                    ,       Perpetual_Time_Unit__c
                                                    ,       Job_Id__c
                                                       FROM Scheduled_Job__c];

            for(Scheduled_Job__c job : scheduledJobs){
                jobIds.add(job.Job_Id__c);
            }

            List<CronTrigger> cronJobDetails = [SELECT  Id
                                                ,       format(EndTime) EndTime
                                                ,       format(NextFireTime) NextFireTime
                                                ,       format(PreviousFireTime) PreviousFireTime
                                                ,       format(StartTime) StartTime
                                                ,       TimesTriggered
                                                ,       State 
                                                   FROM CronTrigger
                                                  WHERE Id = :jobIds];

            Map<Id, CronTrigger> cronMap = new Map<Id, CronTrigger>();

            for(CronTrigger ct : cronJobDetails){
                cronMap.put(ct.Id, ct);
            }

            JSONGenerator gen = JSON.createGenerator(true);

            List<JobRecs> jobList = new List<JobRecs>();

            for(Scheduled_Job__c job : scheduledJobs){
                CronTrigger ct = cronMap.get(job.Job_Id__c);
                Map<String, Object> values = ct.getPopulatedFieldsAsMap();
                JobRecs rec = new JobRecs(String.valueOf(job.Id)
                                  ,       job.Name
                                  ,       String.valueOf(values.get('StartTime'))
                                  ,       String.valueOf(values.get('NextFireTime'))
                                  ,       job.Perpetual_Time_Unit_Type__c
                                  ,       String.valueOf(job.Perpetual_Time_Unit__c)
                );
                jobList.add(rec);
            }

            gen.writeStartObject();
            gen.writeObjectField('jobs', jobList);
            gen.writeEndObject();
            
            return gen.getAsString();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<ApexClass> getApexClassNames(){
        try {
            List<ApexClass> classes = [SELECT Id, Name, Body FROM ApexClass];
            List<ApexClass> scheduledClasses = new List<ApexClass>();
            for(ApexClass ac : classes){
                System.debug('ac.body :: ' + ac.body);
                if(ac.Body.contains('execute(SchedulableContext') && !ac.Name.equals('ScheduledJobApex')){
                    scheduledClasses.add(ac);
                }
            }
            return scheduledClasses;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void createScheduledJob(String jobName, String timeUnitType, String timeUnit){
        try {
            Scheduled_Job__c job = new Scheduled_Job__c(Name = jobName, Perpetual_Time_Unit_Type__c = timeUnitType, Perpetual_Time_Unit__c = Decimal.valueOf(timeUnit));
            insert job;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static void createNew(List<Scheduled_Job__c> scheduledJobs){
        Map<String, Id> jobNameMap = new Map<String, Id>();
        Set<String> jobNameSet = new Set<String>(); 
        
        for(Scheduled_Job__c job : scheduledJobs){
            jobNameSet.add(job.Name);
        }

        List<Scheduled_Job__c> jobsList = [SELECT Id, Name FROM Scheduled_Job__c WHERE Name = :jobNameSet];

        for(Scheduled_Job__c job : jobsList){
            jobNameMap.put(job.Name, job.Id);
        }

        System.debug('VSD jobNameMap :: ' + jobNameMap);

        for(Scheduled_Job__c job : scheduledJobs){
            if(jobNameMap.containsKey(job.Name)) {
                System.debug('VSD FOUND DUPLICATE');
                job.addError('Job \'' + job.Name + '\' is already scheduled');
             }
            System.debug('job.Name :: ' + job.Name);
            String jobExpression = getScheduleString(job.Perpetual_Time_Unit_Type__c, (Integer)job.Perpetual_Time_Unit__c);
            Type dynamicApexType = Type.forName(job.Name);
            String jobID = System.schedule(job.Name + '-init', jobExpression, (Schedulable)dynamicApexType.newInstance());
            job.Job_Id__c = jobID;
        }
    }
    
    public static void rescheduleJob(List<Scheduled_Job__c> scheduledJobs){
        for(Scheduled_Job__c job : scheduledJobs){
            if(job.Job_Id__c != null){
                try{
                    Boolean deleted = false;
                    Integer counter = 0;
                    while( !deleted && counter < 5 ){
                        System.abortJob(job.Job_Id__c);

                        /*
                        * Yes!  I know this is SOQL in a loop. Unfortunately, there is a problem where occassionally
                        * the job won't actually delete itself. 
                        *
                        * Doing the System.abortJob multiple times has proven to be a successful work around.
                        */ 
                        List<CronTrigger> crons = [Select Id From CronTrigger WHERE Id = :job.Job_Id__c LIMIT 1];

                        deleted = crons == null || crons.size() == 0;
                        counter++;
                    }
                } 
                catch( Exception e ){
                    System.debug('There was an error unscheduling the job: ' + e.getMessage());
                    job.addError('There was an error unscheduling the job \'' + job.Name + '\' ' + e.getMessage());
                }

                System.debug('job.Name :: ' + job.Name);
                String jobExpression = getScheduleString(job.Perpetual_Time_Unit_Type__c, (Integer)job.Perpetual_Time_Unit__c);
                Type dynamicApexType = Type.forName(job.Name);
                String jobID = System.schedule(job.Name, jobExpression, (Schedulable)dynamicApexType.newInstance());
                job.Job_Id__c = jobID;
                job.Rescheduled_Date__c = System.now();
            }
        }
    }

    public static void abortJob(List<Scheduled_Job__c> scheduledJobs){
        System.debug('Inside ABORTJOB');
        for(Scheduled_Job__c job : scheduledJobs){
            if(job.Job_Id__c != null){
                try{
                    Boolean deleted = false;
                    Integer counter = 0;
                    while( !deleted && counter < 5 ){
                        System.abortJob(job.Job_Id__c);

                        /*
                        * Yes!  I know this is SOQL in a loop. Unfortunately, there is a problem where occassionally
                        * the job won't actually delete itself. 
                        *
                        * Doing the System.abortJob multiple times has proven to be a successful work around.
                        */ 
                        List<CronTrigger> crons = [Select Id From CronTrigger WHERE Id = :job.Job_Id__c LIMIT 1];

                        deleted = crons == null || crons.size() == 0;
                        counter++;
                    }
                } 
                catch( Exception e ){
                    System.debug('There was an error unscheduling the job: ' + e.getMessage());
                    job.addError('There was an error unscheduling the job \'' + job.Name + '\' ' + e.getMessage());
                }
            }
        }
    }

    public static string getScheduleString(String perpetualTimeUnitType, Integer perpetualTimeUnit){
        DateTime nextScheduleRun = DateTime.now();
        //'second','minute','hour','day','month','year'
        if (perpetualTimeUnitType.equalsIgnoreCase('second') ){
            nextScheduleRun = nextScheduleRun.addSeconds(perpetualTimeUnit);
        }
        else if (perpetualTimeUnitType.equalsIgnoreCase('minute') ){
            nextScheduleRun = nextScheduleRun.addMinutes(perpetualTimeUnit);
        }
        else if (perpetualTimeUnitType.equalsIgnoreCase('hour') ){
            nextScheduleRun = nextScheduleRun.addHours(perpetualTimeUnit);
        }
        else if (perpetualTimeUnitType.equalsIgnoreCase('month') ){
            nextScheduleRun = nextScheduleRun.addMonths(perpetualTimeUnit);     
        }
        else if (perpetualTimeUnitType.equalsIgnoreCase('year') ){
            nextScheduleRun = nextScheduleRun.addDays(365*perpetualTimeUnit);    
        } 
        
        //*format is [sec min hour day month ? year]
        String strSchedule = '0 ' + string.valueOf(nextScheduleRun.minute().format() )
            + ' ' + string.valueOf(nextScheduleRun.hour().format()) 
            + ' ' + string.valueOf(nextScheduleRun.day().format()) 
            + ' ' + string.valueOf(nextScheduleRun.month())
            + ' ? ' 
            + string.valueOf(nextScheduleRun.year()) ;
        
        System.debug( 'FICO: ->strSchedule: ' + strSchedule );
        return strSchedule;
    }
}