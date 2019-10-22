#!/bin/bash
# db2_bkp_online.sh
#  Version 2.0
#
#----------------------------------------------------------------------------------------------------
# Create By Victor Rybakovas on May/13/2015
#  Version 2.0 Create By Victor Rybakovas on Sep/04/2018
# Contact rybakovas@gmail.com
#----------------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------------
# Check all Parameters
#----------------------------------------------------------------------------------------------------
#set -o x
if [ $# != 1 ]
then
   echo
   echo "\tUsage:: $0 Backup Type INCR or FULL or OFF"
   echo
   exit 2
fi
#----------------------------------------------------------------------------------------------------
exclInst=" " #PUT HERE THE EXCLUDE INSTANCES sample "db2inst1 db2inst2 db2instn"

RC_NEW=0
strDateHour=`date +"%Y%m%d_%H%M%S"` #Keep System date
strDSMI_DIR="$(find /*/tivoli/tsm/client/api -type d -print | grep "bin64$")" #Keep DSM DIR
strSCRIPT_DIR="$(find /*/tivoli/tsm -name db2_bkp_online.sh|sed 's/\/db2_bkp_online.sh//g')" #Keep Script DIR

#======================================FIX PATH BUG START===========================

    if [ `uname` == "Linux" ] ; then

        PATH="$(eval echo $PATH':/sbin:/bin:/usr/sbin:/usr/bin:/opt/tivoli/tsm/client/api/bin64:/opt/tivoli/tsm/client/ba/bin')"

    else

        PATH="$(eval echo '${PATH%??}'':/usr/tivoli/tsm/client/api/bin64:/usr/tivoli/tsm/client/ba/bin64')"

    fi
#======================================FIX PATH BUG FINISH===========================



> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log #Create Resume Log

for db2ilist in $(db2ls |awk '{print $1}'|awk 'NR>=4' |awk -F: '{print $1"/bin/db2ilist "$2}') ; do # for to Take db2Instance

    for db2instance in $(eval ${db2ilist}) ; do # For to take Element of the List db2ilist

        DB2VerPath="$(echo $db2ilist|sed 's/\/db2ilist//g')"
        DB2VeradmPath="$(echo ${DB2VerPath}|sed 's/bin/adm/g')"
        strDB2Command=${DB2VerPath}/db2 # Var To db2 Commands
        strDB2AdutlCommand=${DB2VerPath}/db2adutl # Var To db2adutl Commands
        strDB2StopCommand=${DB2VeradmPath}/db2stop # Var To db2stop Commands
        strDB2StartCommand=${DB2VeradmPath}/db2start # Var To db2start Commands
        strDB2ArchCommand="${DB2VerPath}/db2 archive log for database "
        strDB2GetCommand="${DB2VerPath}/db2 get db cfg for "
        strDB2UpdCfgCommand="${DB2VerPath}/db2 update db cfg for "
        strDB2HistoryCommand="${DB2VerPath}/db2 list history backup since `date +%Y%m` for "

        export strDSMI_DIR
        export db2instance
        export strDB2Command
        export strDB2AdutlCommand
        export strDB2StopCommand
        export strDB2StartCommand
        export strDB2ArchCommand
        export strDB2GetCommand
        export strDB2UpdCfgCommand
        export strDB2HistoryCommand
        export strDateHour
        export RC_NEW
        export PATH

        listcontains() {
        for word in $1; do
            [[ $word = $2 ]] && return 0
        done
        return 1
        }    

        if listcontains "$exclInst" $db2instance
        then
           echo ""`date "+[%d/%m/%Y-%H:%M:%S] : "` >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
           echo `date "+[%d/%m/%Y-%H:%M:%S] : "`"The instance $word is EXCLUDE by script Exclude List! " >> $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log
           continue
        fi

        $strSCRIPT_DIR/db2_bkp_online_part2.sh ${1}

    done
done

strBKPMsg="$(cat $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log |grep 'Error' |wc -l)"

if [ ${strBKPMsg} -ne 0 ]; then
   RC_NEW=1
fi

if [ -s $strDSMI_DIR/db2_${1}_backup_error_${strDateHour}.log ]; then
   RC_NEW=$RC_NEW
else
   RC_NEW=1
fi

exit $RC_NEW

