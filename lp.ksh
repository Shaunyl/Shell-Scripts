#!/bin/ksh

#
# Author: Filippo Testino
# Name: lp.ksh
# Description: Retrieve information processes like avg MEM%, CPU%, max CPU% grouped by CPU# and Oracle Instance
# Version: 1.1
#

USERID=${USERID:-/}
LOGDIR=/home/oracle/ft
OFILE=$LOGDIR/lp.out
SQL_FILE=$LOGDIR/osdiag_`hostname`-`date "+%d%m%H%M"`.sql
LOG_FILE=osdiag_`hostname`-`date "+%d%m%H%M"`.log
#FIX IT:
AVG_CPU_THRESHOLD=10
MAX_CPU_THRESHOLD=10

PAR1="$1"
DBS=${PAR1:-*}

printf '%s\n%s %s\n\n' "SNAPSHOT TIME" $(date +"%T %m-%d-%Y") > $OFILE

# Group by CPU#, then retrieve the avg CPU% for each group

ps r -o user,pid,psr,%cpu,%mem,vsz,rss,etime,args -p $(pgrep -f "^ora.*") | ./ftop.ksh \
 | grep -v USER | sort -n -k4 | awk '{$3="|"$3"|"$4"|"; $4=""; print $0}' | column -t > test.t

# Group by CPU#, then retrieve the max CPU% for each group

ps r -o user,pid,psr,%cpu,args -p $(pgrep -f "^ora.*") \
 | grep -v USER | sort -n -k4 | awk '{$3="|"$3"|"$4"|"; $4=""; print $0}' | column -t > gcpu.out

# Group by database name, then retrieve the avg CPU%, MEM% and N# for each group

ps r -o %cpu,%mem,args -p $(pgrep -f "^ora.*") \
 | grep -v "%CPU" | sort -n -k4 | column -t > cpumemdb.out

printf "%s\n" "# Average MEM% and CPU% grouped by instance (if at least one process is running)" >> $OFILE

cat cpumemdb.out | awk '{print $1" "$2" "$3}' | awk '{gsub("oracle","");print $0}' \
 | awk '{if (/ora_/) {print $1" "$2" "substr($3,10,length($3))} else { print $0 } }' > test3.t

print "DATABASE MEM%" "CPU%" "N#" > gawk3.out
gawk 'BEGIN{NR>0;NF==3} { sumCPU[$3] += $1; sumMEM[$3] += $2; N[$3]++ } 
          END     { for (key in sumCPU) {
                        avg = sumCPU[key] / N[key];
                        avgCPU[key] = avg;
                    }
                    for (key in sumMEM) {
                        avg = sumMEM[key] / N[key];
                        printf "%-10s %.2f %.2f %d\n", key, avg, avgCPU[key], N[key];
                    } }' test3.t | sort -n -k3 >> gawk3.out

cat gawk3.out | column -t >> $OFILE
rm gawk3.out
echo " " >> $OFILE

#printf "%s\n" "# Average CPU% grouped by each processor (CPU% > 20)" > gawk.out
print "CPU#" "CPU%" > gawk.out
 
gawk -F'|' 'BEGIN{NR>1;NF==4;AVG_CPU_THRESHOLD=10} { sum[$2] += $3; N[$2]++ } 
          END     { for (key in sum) {
                        avg = sum[key] / N[key];
                        if(avg > AVG_CPU_THRESHOLD) 
                          printf "%-10s %.2f\n", key, avg;
                    } }' test.t | sort -n -k2 >> gawk.out

printf "%s\n" "# Average CPU% grouped by each processor (CPU% > "$AVG_CPU_THRESHOLD")" >> $OFILE
cat gawk.out | column -t >> $OFILE
echo " " >> $OFILE
#printf "%s\n" "# Maximum CPU% grouped by each processor (CPU% > 40)" > gawk2.out
print "CPU#" "CPU%" "USER" "PID" "COMMAND" > gawk2.out

gawk -F'|' 'BEGIN{NR>1;NF==3;MAX_CPU_THRESHOLD=0} { pp[$2] = $1" "$4; max[$2] = !($2 in max) ? $3 : ($3 > max[$2]) ? $3 : max[$2] }
END     {   for (i in max) {
                if(max[i] > MAX_CPU_THRESHOLD)
                    printf "%-10s %-10s %-10s\n", i, max[i], pp[i];
            } }' gcpu.out | egrep "$DBS" | sort -n -k2 >> gawk2.out

# Get the last 3 pids and fetch relatives data from the database
#separate with commas
#pids=($(tail -3 $OFILE | awk '{printf "%s%s",sep,$4; sep=",\n"} END{print ""}'))

pids=($(awk '{if(NR>1)print}' gawk2.out | awk '{print $4}'))

# Extract sids from the last 3 lines

#sids=($(tail -3 $OFILE | awk '{gsub("oracle","");print $4}' | awk '{if (/^ora_/) {print substr($0,10,length($1))} else { print $0 } }'))
sids=($(awk '{if(NR>1)print}' gawk2.out | awk '{gsub("oracle","");print $4}' | awk '{if (/ora_/) {print substr($1,10,length($1))} else { print $0 } }'))

printf "%s\n" "# Maximum CPU% grouped by each processor (CPU% > "$MAX_CPU_THRESHOLD")" >> $OFILE
cat gawk2.out | column -t >> $OFILE

echo " " >> $OFILE
echo "# PGA memory usage statistics by above spids" >> $OFILE
echo "DATABASE PID SPID USED_MB ALLOC_MB FREE_MB MAX_MB" >> tsql.out
i=0
while [ $i -lt ${#sids[*]} ]
do
ORACLE_SID=${sids[$i]}
(sqlplus -S ${USERID} as sysdba <<!
set echo off feed off head off lines 160 pages 0 trimspool on
SELECT '$ORACLE_SID', pid, spid, pga_used_mem / 1048576 used_mb, pga_alloc_mem / 1048576 alloc_mb, pga_freeable_mem / 1048576 free_mb, pga_max_mem / 1048576 max_mb
FROM v\$process
WHERE spid IN (${pids[$i]});
exit;
!
) >> tsql.out
(( i=i+1 ))
done

cat tsql.out | column -t >> $OFILE
rm tsql.out

echo " " >> $OFILE
echo "# IO statistics by above spids" >> $OFILE
echo "DATABASE SPID VALUE UNIT" >> tsql.out
i=0
while [ $i -lt ${#sids[*]} ]
do
ORACLE_SID=${sids[$i]}
(sqlplus -S ${USERID} as sysdba <<!
set echo off feed off head off lines 160 pages 0 trimspool on
COL database FOR A8
COL name FOR A20
COL unit FOR A40
SELECT '$ORACLE_SID', p.spid
  , SUM(s.value) / POWER(1024, 1), REPLACE(REPLACE(n.name, 'physical read bytes', 'R/KB'), 'physical write bytes', 'W/KB') unit
FROM v\$sesstat s, v\$statname n, v\$process p, v\$session sess
WHERE n.name IN ('physical read bytes', 'physical write bytes')
AND n.statistic# = s.statistic#
AND sess.sid = s.sid
AND sess.paddr = p.addr
AND p.spid IN (${pids[$i]})
GROUP BY p.spid, n.name
ORDER BY 1, 4;
exit;
!
) >> tsql.out
(( i=i+1 ))
done

cat tsql.out | column -t >> $OFILE
rm tsql.out

usids=($(echo "${sids[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

echo " " >> $OFILE
echo "# IO metrics group by the databases reported above" >> $OFILE
echo "DATABASE BEGIN END Rb/s Wb/s R/s W/s OSLOAD" >> tsql.out
i=0
while [ $i -lt ${#usids[*]} ]
do
ORACLE_SID=${usids[$i]}
(sqlplus -S ${USERID} as sysdba <<!
set echo off feed off head off lines 160 pages 0 trimspool on
COL database FOR A8
alter session set nls_date_format='dd-mon-yyyy:hh24:mi:ss';
SELECT '$ORACLE_SID', MIN(begin_time) begin_time, MAX(end_time) end_time,
SUM(CASE metric_name WHEN 'Physical Read Total Bytes Per Sec' then value end) Phys_Read_Tot_Bps,
SUM(CASE metric_name WHEN 'Physical Write Total Bytes Per Sec' then value end) Phys_Write_Tot_Bps,
SUM(CASE metric_name WHEN 'Physical Read Total IO Requests Per Sec' then value end) Phys_Read_IOPS,
SUM(CASE metric_name WHEN 'Physical Write Total IO Requests Per Sec' then value end) Phys_write_IOPS,
SUM(CASE metric_name WHEN 'Current OS Load' then value end) OS_LOad
FROM v\$sysmetric;
exit;
!
) >> tsql.out
(( i=i+1 ))
done

cat tsql.out | column -t >> $OFILE

rm gcpu.out
rm test.t
rm gawk.out
rm gawk2.out
rm tsql.out
cat $OFILE
