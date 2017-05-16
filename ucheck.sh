#!/bin/bash
#
# =========================================
# Date          : 9/11/2014
# Title         : ucheck.sh
# Description   : Check if specific user exists on multiple remote hosts using ssh
# Author        : Filippo Testino
# Version       : 0.3.1
#               
# Syntax        : ucheck.sh <user> [<loguser>]
# =========================================
#

defvalue='filippo'

while read hostn sid logu; do

   v_sid=$sid;
   v_arg=$1;
   v_logu=${$2:-${defvalue}}
  
   if [ ! "$1" ]; then
      echo "Sintax: ucheck.sh <user> [<loguser>]"
      exit
   elif [ ! "$2" ]; then 
      if [ ! -z "$logu" ]; then
            v_logu=$logu
      fi
   fi 
   
   /usr/sbin/ping $hostn 5 >/dev/null 2>&1

   if [ $? = 0 ]; then

    key=$(cat ~/.ssh/id_rsa.pub)
    ssh -o ConnectTimeout=7 -o ConnectionAttempts=1 -q $v_logu@$hostn /bin/ksh <<EOF
     grep -s "$key" /home/$v_logu/.ssh/authorized_keys >/dev/null 2>&1
     if [ \$? != 0 ]; then
        echo $key >/dev/null 2>&1 >> /home/$v_logu/.ssh/authorized_keys || (mkdir /home/$v_logu/.ssh ; echo $key >> /home/$v_logu/.ssh/authorized_keys)
     fi   
     chmod 700 /home/$v_logu/.ssh && chmod 600 /home/$v_logu/.ssh/* 

     vkk=\$(grep '$v_arg:' /etc/passwd);

     if [ -z "\$vkk" ]; then
        printf '%s ' "User $v_arg not found"
     else
        printf '%s ' "The user $v_arg exists"
     fi

     printf '%s.\n' 'on $hostn ($v_sid)'
     exit
EOF
   if [ $? = 1 ]; then
      echo "Connection to host $hostn timed out."
   fi

   else
      echo "Host $hostn not found."
   fi

done < hostlist.txt

# =========================================
#
