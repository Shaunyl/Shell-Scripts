#!/bin/ksh

if [[ -z "$1" || -z "$2" ]]; then
   usage
fi

usage() {
  echo "Usage: $0 (user) (filename)"
  echo "  user: schema with which to execute the script"
  echo "  filename: relative path to the script to be executed"
  echo "Example: ./exec.ksh sys create_table.sql"
  exit 1
}

CFILE="./data.cfg"

if [[ -r "$CFILE" ]]; then
        echo "Configuration file found [$CFILE]"
else
        echo "Error: configuration file not found [$CFILE]"
        exit 1
fi

export _UPWD=$(cat $CFILE | grep $ORACLE_SID | grep -i $1/ | cut -d '/' -f 2)

case "$1" in
    "SYS" | "sys")
        _UNAME=""
        _UPWD=" as sysdba"
        ;;
    *)
        _UNAME=$1
esac

echo "Using [ $_UNAME/$_UPWD ]"

if [[ ! -r $2 ]]; then
        echo "Error: File $2 not found."
        exit 1
fi

echo "sqlplus $_UNAME/$_UPWD @$2"

#sqlplus $_UNAME/$_UPWD @$2

sqlplus -S $_UNAME/$_UPWD <<!
@$2
exit;
!

exit $?
