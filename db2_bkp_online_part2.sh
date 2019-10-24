#!/bin/bash
# db2_bkp_online_part2.sh
#  Version 2.2
#
#----------------------------------------------------------------------------------------------------
# Create By Victor Rybakovas on May/13/2015
#  Version 2.0 Create By Victor Rybakovas on Sep/04/2018
#  Version 2.2 Create By Victor Rybakovas on Feb/20/2019
# Contact rybakovas@gmail.com
#----------------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------------
# Check all Parameters
#----------------------------------------------------------------------------------------------------
exclDB=" " #PUT HERE THE EXCLUDE DB sample "db1 db2 db3"

inst_home="$(eval echo ~$db2instance)" #Take Inst Home From OS
CountX=0 #Number of Count X for loop
CountY=0 #Number of Count Y for loop
intDbName=0 #Number of DBs on Instance
strDbName=0 #Corrent DBs Name
strDb2InstanceName=`echo ${db2instance} | tr [A-Z] [a-z]`r
strDSMI_LOG=${inst_home}/sqllib/db2dump
strDSMI_CONFIG=${inst_home}/tsm_opt/dsm_db2.opt
strHost=`hostname -s`
strHOSTNAME=`echo ${strHost} | tr [a-z] [A-Z]`
TSMSession=4 #Number of Sessions on TSM
strLogFilesToKeep=15 #Number of days of the logs will be on Server
strDaysBackupToKeep=12 #Number of days to keep on TSM and DB2 (retation)
strDaysBackupToKeepFull=2 #Number of days to keep on TSM and DB2 (Full retation)
strFirst=0 #First Time Backup? Just For DEV

chmod 777 $strDSMI_DIR

#======================= Check just Indirect DB Directory - START===============================#
rm -f $strDSMI_DIR/CheckDBDirectory.log

    if [ `uname` == "Linux" ] ; then

        nohup su - ${db2instance} -c "${strDB2Command} list db directory | grep Indirect -B 5 | grep 'Database name' | awk '{print \$4}' | sort -u | uniq" > $strDSMI_DIR/CheckDBDirectory.log

    else

	 
        nohup su - ${db2instance} -c "${strDB2Command} list db directory | grep -p Indirect | grep  'Database name' | awk '{print \$4}' | sort -u | uniq > $strDSMI_DIR/CheckDBDirectory.log" >/dev/null 

    fi

    if [ ! -s $strDSMI_DIR/CheckDBDirectory.log ]; then #Error on Directory
    echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"=============================================================================" >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
    echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "` >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
    echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"Warning on Online Backup! For instance ${db2instance}! There is no Local Database or the database directory cannot be found on the indicated file system. Contact DB2 TEAM" >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
    echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"=============================================================================" >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
    
    fi
#======================= Check just Indirect DB Directory - FINISH===============================#

#======================= Check DB2 Userprofile Informations - START===============================#
    if [ ! -s "${inst_home}/sqllib/userprofile" ]
    then
        echo "export DSMI_DIR=$strDSMI_DIR"  > ${inst_home}/sqllib/userprofile
        echo "export DSMI_LOG=$strDSMI_LOG"  >> ${inst_home}/sqllib/userprofile
        echo "export DSMI_CONFIG=$strDSMI_CONFIG"  >> ${inst_home}/sqllib/userprofile
        echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"=============================================================================" >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
        echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"DB2 User Profile on instance ${db2instance} Was Empty Please do the DB2 bounce to Get the Correct Informations" >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
        echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"=============================================================================" >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
        rc=1
        RC_NEW=$RC_NEW+$rc
        continue #If find error go to next instance
    fi

    strBKPMsg="$(cat ${inst_home}/sqllib/userprofile| grep 'dsm.opt'| wc -l)"

    if [ ${strBKPMsg} -ne 0 ]; then
        echo "export DSMI_DIR=$strDSMI_DIR"  > ${inst_home}/sqllib/userprofile
        echo "export DSMI_LOG=$strDSMI_LOG"  >> ${inst_home}/sqllib/userprofile
        echo "export DSMI_CONFIG=$strDSMI_CONFIG"  >> ${inst_home}/sqllib/userprofile
        echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"=============================================================================" >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
        echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"DB2 User Profile information on instance ${db2instance} Was Wrong Please do the DB2 bounce to Get the Correct Informations" >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
        echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"=============================================================================" >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
        rc=1
        RC_NEW=$RC_NEW+$rc
        continue #If find error go to next instance
    fi
#======================= Check DB2 Userprofile Informations - FINISH===============================#

#======================= Create DB2 OPT - START====================================================#
    if [ ! -d "${inst_home}/tsm_opt" ]; then
    mkdir -p ${inst_home}/tsm_opt
    chmod 777 ${inst_home}/tsm_opt
    fi

    chmod 777 ${inst_home}/tsm_opt
    rm -f ${inst_home}/tsm_opt/dsm_db2.opt
    ln -s ${strDSMI_DIR}/dsm_${strHOSTNAME}_DB2.opt ${inst_home}/tsm_opt/dsm_db2.opt
#======================= Create DB2 OPT - FINISH====================================================#

for CountX in `cat $strDSMI_DIR/CheckDBDirectory.log` ; do

    strDbName=$CountX

    listcontains() {
    for word in $1; do
        [[ $word = $2 ]] && return 0
    done
    return 1
    }

    if listcontains "$exclDB" $strDbName
    then
       echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "` >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
       echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"The DB $word is EXCLUDE by script Exclude List! " >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
       continue
    fi

    strBackupLocation=${inst_home}/${strDbName}/backup #Path of the backup folder
    strMessagesDir=${strBackupLocation}/messages #Path of the backup log folder
    strMsgsLogFile=${strMessagesDir}/db2_bkp_online_${strDbName}_${strDateHour}.log #Backup log


    if [ ! -d "$strMessagesDir" ]; then
       mkdir -p $strMessagesDir
    fi

    exec > ${strMsgsLogFile} 2>&1

    echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "` >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
    echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"Start Online Backup For DB ${strDbName}! For instance ${db2instance}! " >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
    echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"Log on ${strMsgsLogFile} " >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log

    rm -f $strDSMI_DIR/GetDBPath.log

    nohup su - ${db2instance} -c "${strDB2GetCommand} ${strDbName} > $strDSMI_DIR/GetDBPath.log" >/dev/null

    strPENMsg="$(cat $strDSMI_DIR/GetDBPath.log |grep 'Backup pending'|grep 'YES' |wc -l)"
    if [ ${strPENMsg} -ne 0 ]; then

        echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"=============================================================================" >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
        echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"DB2 Instance ${db2instance} - DB ${strDbName} - Backup Pending Please Do manual offline Backup" >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
        echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"=============================================================================" >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
        rc=1
        RC_NEW=$RC_NEW+$rc
        continue #If find error go to next instance
    fi


   rm -f $strDSMI_DIR/ArchiveBackup.log
   echo "=========================================================================================================="
   echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
   echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"DB2 ARCHIVE LOG FOR DATABASE ${strDbName} IN EXECUTION."
   echo "=========================================================================================================="
   nohup su - ${db2instance} -c "${strDB2Command} terminate >> $strDSMI_DIR/ArchiveBackup.log" >/dev/null   
   nohup su - ${db2instance} -c "${strDB2ArchCommand} ${strDbName} >> $strDSMI_DIR/ArchiveBackup.log" >/dev/null 
   nohup su - ${db2instance} -c "${strDB2ArchCommand} ${strDbName} >> $strDSMI_DIR/ArchiveBackup.log" >/dev/null 
   nohup su - ${db2instance} -c "${strDB2ArchCommand} ${strDbName} >> $strDSMI_DIR/ArchiveBackup.log" >/dev/null 
   nohup su - ${db2instance} -c "${strDB2ArchCommand} ${strDbName} >> $strDSMI_DIR/ArchiveBackup.log" >/dev/null 
   sleep 40

   strLOGMsg="$(cat $strDSMI_DIR/ArchiveBackup.log)"

   echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
   echo $strLOGMsg
   echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`

   echo "=========================================================================================================="
   echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
   echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"DB2 CONFIG FOR DATABASE ${strDbName} IN EXECUTION."
   echo "=========================================================================================================="

   rm -f $strDSMI_DIR/DBConfig.log
   echo "${strDB2UpdCfgCommand} ${strDbName} using LOGARCHMETH1 TSM:DB_DATA_MGMT_CLASS immediate"
   nohup su - ${db2instance} -c "${strDB2UpdCfgCommand} ${strDbName} using LOGARCHMETH1 TSM:DB_DATA_MGMT_CLASS immediate > $strDSMI_DIR/DBConfig.log"  >/dev/null 

   strBKPMsg="$(cat $strDSMI_DIR/DBConfig.log |grep 'SQL1032N' | wc -l)"
   if [ ${strBKPMsg} -ne 0 ]; then
      echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "` >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
      echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"Error on Online Backup DB ${strDbName}! For instance ${db2instance}!  DB2 is DOWN ! Contact DB2 TEAM!" >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
      rc=1
      RC_NEW=$RC_NEW+$rc
      continue
   fi

   echo "${strDB2Command} connect to ${strDbName}"
   nohup su - ${db2instance} -c "${strDB2Command} connect to ${strDbName} >> $strDSMI_DIR/DBConfig.log" >/dev/null


   strLOGMsg="$(cat $strDSMI_DIR/DBConfig.log| grep 'SQL1776N'| wc -l)"

   if [ ${strLOGMsg} -ne 0 ]; then
      echo "${strDbName} from instance ${db2instance} Is a HADR please check the other node"

      echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "` >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
      echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"${strDbName} from instance ${db2instance} Is a HADR please check the other node" >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log

      continue
   fi

   echo "${strDB2UpdCfgCommand} ${strDbName} using TSM_MGMTCLASS NULL"
   nohup su - ${db2instance} -c "${strDB2UpdCfgCommand} ${strDbName} using TSM_MGMTCLASS NULL >> $strDSMI_DIR/DBConfig.log"  >/dev/null

   echo "${strDB2UpdCfgCommand} ${strDbName} using TSM_NODENAME NULL"
   nohup su - ${db2instance} -c "${strDB2UpdCfgCommand} ${strDbName} using TSM_NODENAME NULL >> $strDSMI_DIR/DBConfig.log"  >/dev/null

   echo "${strDB2UpdCfgCommand} ${strDbName} using TSM_OWNER NULL"
   nohup su - ${db2instance} -c "${strDB2UpdCfgCommand} ${strDbName} using TSM_OWNER NULL >> $strDSMI_DIR/DBConfig.log"  >/dev/null

   echo "${strDB2UpdCfgCommand} ${strDbName} using TSM_PASSWORD NULL"
   nohup su - ${db2instance} -c "${strDB2UpdCfgCommand} ${strDbName} using TSM_PASSWORD NULL >> $strDSMI_DIR/DBConfig.log"  >/dev/null

   echo "${strDB2UpdCfgCommand} ${strDbName} using LOGARCHOPT1 NULL"
   nohup su - ${db2instance} -c "${strDB2UpdCfgCommand} ${strDbName} using LOGARCHOPT1 NULL >> $strDSMI_DIR/DBConfig.log"  >/dev/null

   echo "${strDB2UpdCfgCommand} ${strDbName} using VENDOROPT NULL"
   nohup su - ${db2instance} -c "${strDB2UpdCfgCommand} ${strDbName} using VENDOROPT NULL >> $strDSMI_DIR/DBConfig.log"  >/dev/null

   echo "${strDB2UpdCfgCommand} ${strDbName} using LOGARCHCOMPR1 NULL"
   nohup su - ${db2instance} -c "${strDB2UpdCfgCommand} ${strDbName} using LOGARCHCOMPR1 NULL" >> $strDSMI_DIR/DBConfig.log

   echo "${strDB2UpdCfgCommand} ${strDbName} using TRACKMOD yes immediate"
   nohup su - ${db2instance} -c "${strDB2UpdCfgCommand} ${strDbName} using TRACKMOD yes immediate >> $strDSMI_DIR/DBConfig.log"  >/dev/null

   echo "${strDB2Command} connect reset"
   nohup su - ${db2instance} -c "${strDB2Command} connect reset >> $strDSMI_DIR/DBConfig.log"  >/dev/null

   strLOGMsg="$(cat $strDSMI_DIR/DBConfig.log)"

   echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
   echo $strLOGMsg
   echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`

   echo "=========================================================================================================="
   echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
   echo `date "+[%d/%m/%Y-%H:%M:%S] : "`" DAILY DB2 BACKUP! ${strDaysBackupToKeep} DAYS OF RETENTION - DB: ${strDbName} "
   echo "========================================================================================================== "

   echo "Backup log File: ${strMsgsLogFile} "

   echo "=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+="
   echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"ONLINE BACKUP OF DB [${strDbName}] START PROCESS - DAILY BACKUP"
   echo "=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+="

   echo "=========================================================================================================="
   echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
   echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"DB ${strDbName} BACKUP RUNNING - DAILY BACKUP "
   echo "=========================================================================================================="

   rm -f $strDSMI_DIR/BackupResult.log

   echo "=========================================================================================================="
   echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
   echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"BACKUP ${1} FOR DATABASE ${strDbName} TO TSM IN EXECUTION."
   echo "=========================================================================================================="

    if [ ${1} == "OFF" ]
    then

    echo "=========================================================================================================="
    echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
    echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"BACKUP OFFLINE ${1} FOR DATABASE ${strDbName} TO TSM IN EXECUTION."
    echo "=========================================================================================================="

    nohup su - ${db2instance} -c "${strDB2Command} connect reset"

    echo "${strDB2Command} force applications all"
    nohup su - ${db2instance} -c "${strDB2Command} force applications all" 

    echo "${strDB2StopCommand} force"
    nohup su - ${db2instance} -c "${strDB2StopCommand} force" 

    echo "${strDB2StartCommand}"
    nohup su - ${db2instance} -c "${strDB2StartCommand}"

    echo "${strDB2Command} BACKUP DB ${strDbName} USE TSM OPEN ${TSMSession} SESSIONS INCLUDE LOGS WITHOUT PROMPTING"
    nohup su - ${db2instance} -c "${strDB2Command} BACKUP DB ${strDbName} use tsm open ${TSMSession} sessions without prompting > $strDSMI_DIR/BackupResult.log" >/dev/null
    rc=${?}
    RC_NEW=$RC_NEW+$rc

    strLOGMsg="$(cat $strDSMI_DIR/BackupResult.log)"
    echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
    echo $strLOGMsg
    echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`

    fi

   if [ ${1} == "FULL" ]
   then
      echo "${strDB2Command} BACKUP DB ${strDbName} ONLINE USE TSM OPEN ${TSMSession} SESSIONS INCLUDE LOGS WITHOUT PROMPTING"
      nohup su - ${db2instance} -c "${strDB2Command} BACKUP DB ${strDbName} ONLINE USE TSM OPEN ${TSMSession} SESSIONS INCLUDE LOGS WITHOUT PROMPTING > $strDSMI_DIR/BackupResult.log"  >/dev/null
      rc=${?}
      RC_NEW=$RC_NEW+$rc

      strLOGMsg="$(cat $strDSMI_DIR/BackupResult.log)"
      echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
      echo $strLOGMsg
      echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
   fi

   if [ ${1} == "INCR" ]
   then
      echo "${strDB2Command} BACKUP DB ${strDbName} ONLINE INCREMENTAL USE TSM OPEN ${TSMSession} SESSIONS INCLUDE LOGS WITHOUT PROMPTING"
      nohup su - ${db2instance} -c "${strDB2Command} BACKUP DB ${strDbName} ONLINE INCREMENTAL USE TSM OPEN ${TSMSession} SESSIONS INCLUDE LOGS WITHOUT PROMPTING  > $strDSMI_DIR/BackupResult.log" >/dev/null
      rc=${?}
      RC_NEW=$RC_NEW+$rc

      strLOGMsg="$(cat $strDSMI_DIR/BackupResult.log)"
      echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
      echo $strLOGMsg
      echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`

      strBKPMsg="$(cat $strDSMI_DIR/BackupResult.log |grep 'SQL2426N' |wc -l)"
      if [ ${strBKPMsg} -ne 0 ]
      then
         RC_NEW=0

         echo "=========================================================================================================="
         echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
         echo `date "+[%d/%m/%Y-%H:%M:%S] : "`" FIRST BACKUP ${1} FOR DATABASE ${strDbName} TO TSM IN EXECUTION."
         echo "=========================================================================================================="


         echo "${strDB2Command} BACKUP DB ${strDbName} ONLINE USE TSM OPEN ${TSMSession} SESSIONS INCLUDE LOGS WITHOUT PROMPTING"
         nohup su - ${db2instance} -c "${strDB2Command} BACKUP DB ${strDbName} ONLINE USE TSM OPEN ${TSMSession} SESSIONS INCLUDE LOGS WITHOUT PROMPTING > $strDSMI_DIR/BackupResult.log" >/dev/null
         rc=${?}
         RC_NEW=$RC_NEW+$rc

         strLOGMsg="$(cat $strDSMI_DIR/BackupResult.log)"
         echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
         echo $strLOGMsg
         echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`

         echo "${strDB2Command} BACKUP DB ${strDbName} ONLINE INCREMENTAL USE TSM OPEN ${TSMSession} SESSIONS INCLUDE LOGS WITHOUT PROMPTING"
         nohup su - ${db2instance} -c "${strDB2Command} BACKUP DB ${strDbName} ONLINE INCREMENTAL USE TSM OPEN ${TSMSession} SESSIONS INCLUDE LOGS WITHOUT PROMPTING > $strDSMI_DIR/BackupResult.log"  >/dev/null
         rc=${?}
         RC_NEW=$RC_NEW+$rc

         strLOGMsg="$(cat $strDSMI_DIR/BackupResult.log)"
         echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
         echo $strLOGMsg
         echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
      fi
   fi

   if [ ${rc} -ne 0 ]
   then
      msgText="db2_bkp_online: Command [BACKUP DB ${strDbName} ONLINE ] Error!, RC=[${rc}]."
      msgText=${msgText}" Ckeck log [${strMsgsLogFile}], hostname=[${strHost}]"
      echo ${msgText}
      echo ${msgText} >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
      continue
   fi

   echo "=========================================================================================================="
   echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
   echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"SLEEP 40 SEC TO TAKE LOGS"
   echo "========================================================================================================== "
   sleep 40
   echo "=========================================================================================================="
   echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
   echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"DELETING OLD BACKUPS WITH MORE THAN ${strDaysBackupToKeep} DAY IN TSM"
   echo "========================================================================================================== "

   rm -f $strDSMI_DIR/DelResult.log

   if [ ${1} == "FULL" ]
   then
      echo "${strDB2AdutlCommand} delete nonincremental keep ${strDaysBackupToKeepFull} db ${strDbName} without prompting"
      nohup su - ${db2instance} -c "${strDB2AdutlCommand} delete nonincremental keep ${strDaysBackupToKeepFull} db ${strDbName} without prompting >> $strDSMI_DIR/DelResult.log" >/dev/null
      rc=${?}
      RC_NEW=$RC_NEW+$rc
   fi

    if [ ${1} == "OFF" ]
    then
    echo "${strDB2AdutlCommand} delete nonincremental keep ${strDaysBackupToKeepFull} db ${strDbName} without prompting"
    nohup ${strDB2AdutlCommand} delete nonincremental keep ${strDaysBackupToKeepFull} db ${strDbName} without prompting >> $strDSMI_DIR/DelResult.log
    rc=${?}
    RC_NEW=$RC_NEW+$rc
    fi

   if [ ${1} == "INCR" ]
   then
      echo "${strDB2AdutlCommand} delete incremental keep ${strDaysBackupToKeep} db ${strDbName} without prompting"
      nohup su - ${db2instance} -c "${strDB2AdutlCommand} delete incremental keep ${strDaysBackupToKeep} db ${strDbName} without prompting >> $strDSMI_DIR/DelResult.log" >/dev/null 
      rc=${?}
      RC_NEW=$RC_NEW+$rc
   fi

   strLOGMsg="$(cat $strDSMI_DIR/DelResult.log)"
   echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
   echo $strLOGMsg
   echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`

   if [ ${rc} -ne 0 ]
   then
      msgText="Delete process: Command [${strDB2AdutlCommand} delete incremental keep ${strDaysBackupToKeep} db ${strDbName} without prompting] Error!, RC=[${rc}]."
      msgText=${msgText}"Ckeck log [${strMsgsLogFile}], hostname=[${strHost}]"
      echo ${msgText}
      echo ${msgText} >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
      continue
   fi

   echo "=========================================================================================================="
   echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
   echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"LOOKING FOR ERROR"
   echo "========================================================================================================== "

   numBackupSuccessful="$(cat $strDSMI_DIR/BackupResult.log |grep 'Backup successful. The timestamp '| wc -l)"
   if [ ${numBackupSuccessful} -eq 0 ]
   then
      msgText="db2_bkp_online: Online Backup of DB ${strDbName} FAILED!."
      msgText=${msgText}"Check log [${strMsgsLogFile}], hostname=[${strHost}]"
      echo ${msgText}
      echo ${msgText} >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
      rc=1
      RC_NEW=$RC_NEW+$rc
      continue
   else
      echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
      echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"No Error of Online Backup of DB ${strDbName}"
      echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`

      strBKPMsg="$(cat $strDSMI_DIR/BackupResult.log |grep 'Backup successful. The timestamp ')"
   fi

   echo "=========================================================================================================="
   echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
   echo `date "+[%d/%m/%Y-%H:%M:%S] : "`" TIMESTAMP BACKUP ONLINE OF DB ${strDbName} "
   echo `date "+[%d/%m/%Y-%H:%M:%S] : "`" ${strBKPMsg} "
   echo "=========================================================================================================="

   echo `date "+[%d/%m/%Y-%H:%M:%S] : "`" ${strBKPMsg} " >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log

   echo "=========================================================================================================="
   echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
   echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"DB2 ARCHIVE LOG FOR DATABASE ${strDbName} IN EXECUTION."
   echo "=========================================================================================================="

   nohup su - ${db2instance} -c "${strDB2Command} terminate > $strDSMI_DIR/ArchiveBackup.log"  >/dev/null
   nohup su - ${db2instance} -c "${strDB2ArchCommand} ${strDbName} >> $strDSMI_DIR/ArchiveBackup.log" >/dev/null
   nohup su - ${db2instance} -c "${strDB2ArchCommand} ${strDbName} >> $strDSMI_DIR/ArchiveBackup.log" >/dev/null
   nohup su - ${db2instance} -c "${strDB2ArchCommand} ${strDbName} >> $strDSMI_DIR/ArchiveBackup.log" >/dev/null
   nohup su - ${db2instance} -c "${strDB2ArchCommand} ${strDbName} >> $strDSMI_DIR/ArchiveBackup.log" >/dev/null
   sleep 40

   strLOGMsg="$(cat $strDSMI_DIR/ArchiveBackup.log)"

   echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
   echo $strLOGMsg
   echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
   echo "=========================================================================================================="
   echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
   echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"DELETING OLD LOG FILES IN SERVER"
   echo "========================================================================================================== "
   strRmCommand="chmod 777 ${strMessagesDir}/*.log"
   ${strRmCommand}
   find ${strMessagesDir} -name '*.log' -mtime +20 -type f -exec rm {} \;
   strRmCommand="chmod 777 ${strDSMI_DIR}/*.log"
   ${strRmCommand}
   find ${strDSMI_DIR} -name '*.log' -mtime +20 -type f -exec rm {} \;
   echo "=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+="
   echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "`
   echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"ONLINE BACKUP OF DB [${strDbName}] END PROCESS - DAILY BACKUP"
   echo "=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+="
done

rm -f $strDSMI_DIR/CheckDBDirectory.log
rm -f $strDSMI_DIR/GetDBPath.log
rm -f $strDSMI_DIR/ArchiveBackup.log
rm -f $strDSMI_DIR/DBConfig.log
rm -f $strDSMI_DIR/BackupResult.log
rm -f $strDSMI_DIR/DelResult.log
rm -f $strDSMI_DIR/BackupList.log

