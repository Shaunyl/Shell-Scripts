#!/bin/ksh

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

ORACLE_SID='SID-here'
ORACLE_BASE=/app/oracle
ORACLE_HOME=/app/oracle/product/10.2.0
PATH=/usr/bin::.:/usr/local/bin:/usr/ccs/bin:$ORACLE_HOME/bin
LD_LIBRARY_PATH=$ORACLE_HOME/lib
NLS_LANG=AMERICAN_AMERICA.UTF8

export ORACLE_SID ORACLE_BASE ORACLE_HOME PATH LD_LIBRARY_PATH NLS_LANG

KEEP_LOG_DAYS=5
COMPRESS_TOOL=gzip

export KEEP_LOG_DAYS COMPRESS_TOOL

mkdir -p log

LOGDIR=./log
export LOGDIR
