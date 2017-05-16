#!/usr/bin/ksh

MAIL_FILE=sskiller_mail-`date "+%d%m%H%M"`.out
MAIL_LIST="your-mail-here"
HOSTNAME=`hostname`

echo
echo "+ Checking Swap Space Size and Usage"
echo

/etc/swap -l |awk '{ print $4 }' | grep -v blocks > temp.swapl
/etc/swap -l |awk '{ print $5}' | grep -v free > free.swap1

SWP=$(echo $(tr -s '\n' '+' < temp.swapl)0 | bc)
TSWP=$(echo "$SWP" "/" "2" |bc)

tswap=$(echo "$TSWP" "/" "1024" "/" "1024" | bc)
fswap=$(echo "scale=2;`awk '{total += $NF} END { print total }' free.swap1` "/" "2" "/" "1024" "/" "1024" "| bc)

pswap=$(echo "scale=2;$fswap*100/$tswap" | bc)

echo "Total swap: ${tswap}GB"
echo "Free swap: ${fswap}GB (${pswap}%)"
echo 

rm temp.swapl free.swap1

if [ "$pswap" -lt 20 ] ; then
  echo "Free swap is less than 20%! Invoking sskiller.ksh script.."
  ./sskiller.ksh -n 1 | tee $MAIL_FILE
  cat $MAIL_FILE | mailx -s "$HOSTNAME : Sskiller Report" ${MAIL_LIST}
  exit 1
else
  echo "Free swap is enough. No actions required."
  echo
  exit 0
fi
