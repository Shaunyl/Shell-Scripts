#!/bin/ksh

# Setup environment for cron job
. ./oenv4cron.ksh

USERID=${USERID:-/}

usage() {
  echo "Usage: $0 [-n kills] [-p] [-e] [-h]"
  echo "  -h help: print this message"
  echo "  -n kills: number of top swap usage sessions to kill - defaults to 3"
  echo "  -e execute: execute script SQL by itself"
  echo "  -p pmap: print pmap output for processes picked"
  exit 1
}

# Handle options
while getopts "h:n:pe" opt; do
  case $opt in
  	h)
	  usage ;;
    n) KILLS=$OPTARG ;;
	e) IS_EXECUTE=Y ;;
	p) IS_PMAP=Y ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      ;;
  esac
done

DB_NAME=${ORACLE_SID}
KILLS=${KILLS:-3}
SQL_FILE=$LOGDIR/sskiller_${DB_NAME}-`date "+%d%m%H%M"`.sql
LOG_FILE=sskiller_${DB_NAME}-`date "+%d%m%H%M"`.log

echo
echo "Sskiller v1.2.3 - Filippo Testino"
echo

echo "+ The $KILLS processes using the most swap space:"
echo 

# Find processes which use the most swap space
swproc=$(ps -eo pcpu,user,vsz,pid,args,etime -u oracle | grep $DB_NAME | sort -k3 -r | head -$KILLS)

printf '%s\n' "%CPU     USER     VSZ   PID COMMAND                                                                              ELAPSED"
printf '%s\n' "----     ----     ---   --- -------                                                                              -------"
printf '%s\n' "${swproc[@]}"

swproc=$(echo "${swproc[@]}" | awk '{print $4}')

echo

# Execute pmap on pids if requested
param=
for proc in ${swproc[@]}
do
    if [ -n "${IS_PMAP}" ] ; then
      pmap -S $proc | egrep "$(echo $proc):|total|Address"
	fi
    param="${param} ${proc},"
done

param=${param%?}

echo
echo "+ Processes related sessions of Oracle:"

sqlplus -S ${USERID} as sysdba <<!
SET LINES 180 PAGES 30
COL username FOR A12 TRUNCATE
COL osuser FOR A12 TRUNCATE
COL spid FOR A8
COL machine FOR A18 TRUNCATE
COL terminal FOR A20 TRUNCATE
COL sql_id FOR A13
COL status FOR A14
COL sid FOR 999999
COL event FOR A20 TRUNCATE
COL program FOR A14 TRUNCATE
COL logon_time FOR A20
SELECT	s.sid, s.serial#, p.spid, s.username, s.program, s.machine,
	s.sql_id, s.status, last_call_et, s.event,
	TO_CHAR(s.logon_time, 'dd-mm-yy hh24:mi:ss') logon_time
FROM v\$session s JOIN v\$process p ON s.paddr = p.addr
WHERE s.type != 'BACKGROUND'
  AND (s.username IS NOT NULL OR s.username = 'SYS')
  AND p.spid IN ($param)
  AND s.status = 'INACTIVE'
ORDER BY logon_time;
exit;
!

(sqlplus -S ${USERID} as sysdba <<!
set echo on feed off head off lines 180 pages 0 trimspool on
prompt set sqlprompt "_CONNECT_IDENTIFIER> ";
prompt set feed off echo on timing on time on termout on;
prompt spool ${LOG_FILE}
SELECT 'ALTER SYSTEM KILL SESSION ''' || s.sid || ',' || s.serial# || ''';'
FROM v\$session s JOIN v\$process p ON s.paddr = p.addr
WHERE s.type != 'BACKGROUND'
  AND (s.username IS NOT NULL OR s.username = 'SYS')
  AND p.spid IN ($param)
  AND s.status = 'INACTIVE'
ORDER BY logon_time;
prompt spool off
prompt exit
exit;
!
) > ${SQL_FILE}

echo "+ SQL File '${SQL_FILE}' generated."

if [ -n "${IS_EXECUTE}" ] ; then
  echo "+ Executing SQL script.."
  sqlplus ${USERID} as sysdba @${SQL_FILE}
  echo "+ Sessions killed."
  echo
else
  echo "+ Automatic execution disabled. Add -e option to enable automatic execution."
  echo
fi

# Remove old logs
find log -mtime +${KEEP_LOG_DAYS} 2>/dev/null | while read filename
do
  rm -rf $filename
  echo "Old file $filename removed."
done

# Compress old logs
if [ ${COMPRESS_TOOL} != "none" ]
then
  ls -1 $LOGDIR/*.log $LOGDIR/*.sql $LOGDIR/*.out 2>/dev/null | while read filename
  do
    ${COMPRESS_TOOL} $filename
	echo "File $filename compressed."
  done
fi


