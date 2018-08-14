#!/bin/bash
ssdmodel="SSDSC2BA40"
hddmodel="HUS724040AL"
debug=0
errorly=0

get_osd_count() {
  osd_count=$(pgrep -c '[c]eph-osd')
}

get_ssd_array() {
  ssds=""
  for ssd in $(lsblk --output KNAME,MODEL | awk '/'${ssdmodel}'/ {print $1}');
  do
    ssds=( ${ssds[@]} "${ssd}" )
  done
}

get_hdd_array() {
  hdds=""
  for hdd in $(lsblk --output KNAME,MODEL | grep -v 'PK1334PBKXKJDX' | awk '/'${hddmodel}'/ {print $1}');
  do
    hdds=( ${hdds[@]} "${hdd}" )
  done
}

create_osd_bluestore_ssd_hdd() {
  phdd=$1
  pssd=$2
  tried=1
  cephcmd="ceph-disk -v prepare --dmcrypt --dmcrypt-key-dir /etc/ceph/dmcrypt-keys --block.db /dev/${pssd}  --block.wal /dev/${pssd}  --bluestore --cluster ceph --fs-type xfs -- /dev/${phdd}"
  if [[ ${debug} -gt 0 ]]
  then
    echo "${cephcmd}"
  else
    ${cephcmd}
    while [[ $? -gt 0 ]] && [[ ${errorly} -gt 0 ]]
    do 
      sleep 2
      echo "----------------------FAILURE--------------------------"
      echo "${cephcmd}"
      ${cephcmd}
    done
    sleep 5
  fi
}

create_osd_bluestore_hdd() {
  phdd=$1
  tried=1
  cephcmd="ceph-disk -v prepare --dmcrypt --dmcrypt-key-dir /etc/ceph/dmcrypt-keys --bluestore --cluster ceph --fs-type xfs -- /dev/${phdd}"
  if [[ ${debug} -gt 0 ]]
  then
    echo "${cephcmd}"
  else
    ${cephcmd}
    while [[ $? -gt 0 ]] && [[ ${errorly} -gt 0 ]]
    do 
      sleep 2
      echo "----------------------FAILURE--------------------------"
      echo "${cephcmd}"
      ${cephcmd}
    done
    sleep 5
  fi
}

check_ssd_parts() {
  pssd=$1
  jparts_actual=$(( $(grep -c -iE "\b${pssd}([0-9]+)\b" /proc/partitions) ))
}



debugly() {
if [[ ${debug} -gt 0 ]];
then
  echo "----------------------------------------------------------------------DEBUG----------------------------------------------------------------------"
  echo "${osd_count}"
  echo "${ssds[@]}  || ${#ssds[@]} || ${ssds[ $(( ${#ssds[@]} - 1 )) ]}"
  echo "${hdds[@]}  || ${#hdds[@]} || ${hdds[ $(( ${#hdds[@]} - 1 )) ]}"
  echo "ceph cmd || ${cephcmd}"
  echo "phdd || ${phdd}"
  echo "shdd || ${shdd}"
  echo "ssd partitions || check number || actual number"
  echo "${pssd}    ||  ${jparts_actual} || ${jparts_check}"
  echo "----------------------------------------------------------------------DEBUG----------------------------------------------------------------------"
  echo ""
  echo ""
fi
}

mainloop() {
    unset hdd
    unset sdd
    unset phdd
    unset pssd
    ittor=1
    ittly=0
    ssdindex=0

    for hdd in ${hdds[@]};
    do
       pssd=${ssds[ ${ssdindex} ]}

       jparts_check=$(( 2 * $(( ${ittor} - 1 )) ))
       check_ssd_parts ${pssd}

       if [[ ${jparts_actual} -gt ${jparts_check} ]] && [[ ${debug} -lt 1 ]]
       then
           debugly
           exit 1
       fi
       
       create_osd_bluestore_ssd_hdd ${hdd} ${pssd}   
       debugly
       if [[ ${ittor} -ge 5 ]];
       then
         ssdindex=$(( ${ssdindex} + 1))
         ittor=1
       else
         ittor=$(( ${ittor} + 1))
       fi
       ittly=$(( ${ittly} + 1 ))
       get_osd_count
       if [[ ${debug} -lt 1 ]]
       then
           while [[ ${ittly} -gt ${osd_count} ]];
           do
             echo "${ittly} is greater than ${osd_count} .. sleeping"
             sleep 5
           done
       fi
    done
}

get_osd_count
get_ssd_array
get_hdd_array
mainloop
