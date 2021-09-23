#!/bin/bash
echo 'PID|TTY|STAT|TIME|COMMAND' > /tmp/ps_ax.txt
ls -1 /proc/ | grep '^[0-9]' | sort -n > /tmp/procDir.txt
dirVol=$(cat /tmp/procDir.txt | wc -l)
for ((i=1; i <= $dirVol; i++))
do
numDir=$(sed -n ${i}p /tmp/procDir.txt)
if [ -f "/proc/$numDir/stat" ];then
PID=$(cut -f1 -d' ' /proc/$numDir/stat)
checkTTY=$(ls -l /proc/$numDir/fd/ | grep ' 0 ->' | grep -v '/dev/null' | grep /dev/ | sed 's|.*/dev/\(.*\)|\1|')
if [ -n "$checkTTY" ];then
  TTY=$checkTTY
else
  TTY=?
fi

####STAT###
STAT=''
state=''
nice=''
session=''
num_threads=''
tpgid=''
locked_memory=''

state=$(cut -f3 -d' ' /proc/$numDir/stat)

checkNice=$(cut -f19 -d' ' /proc/$numDir/stat)
if [[ "$checkNice" -gt 0 ]];then
  nice=N
elif [[ "$checkNice" -lt 0 ]];then
  nice='<'
fi

checklockedMemory=$(grep VmLck /proc/$numDir/status | sed 's|  *| |' | cut -f2 -d' ')
if [[ "$checklockedMemory" -gt 0 ]];then
  locked_memory=L
fi

checkSession=$(cut -f6 -d' ' /proc/$numDir/stat)
if [[ "$checkSession" -eq "$PID" ]];then
  session=s
fi

checkNum_threads=$(cut -f20 -d' ' /proc/$numDir/stat)
if [[ "$checkNum_threads" -gt "1" ]];then
  num_threads=l
fi

checkTpgid=$(cut -f8 -d' ' /proc/$numDir/stat)
if [[ "$checkTpgid" -eq "$PID" ]];then
  tpgid='+'
fi

STAT=$(echo "${state}${nice}${locked_memory}${session}${num_threads}${tpgid}")
####STAT###

utime=$(cut -f14 -d' ' /proc/$numDir/stat)
stime=$(cut -f15 -d' ' /proc/$numDir/stat)

ustime=$((($utime+$stime)*10/1000))
min=$(($ustime/60))
if [ -n "$min" ];then
  sec=$(($ustime-$min*60))
else
  sec=$ustime
  min=0
fi

if [[ "$sec" -lt 10 ]];then
  sec=$(echo "0$sec")
fi

TIME=$(echo "$min:$sec")

COMMAND=$(cat -vE /proc/$numDir/cmdline |sed 's/\^\@/ /g';echo)
if [ -z "$COMMAND" ];then
  COMMAND=$(echo "[$(cut -f2 -d' ' /proc/$numDir/stat| tr -d '()')]")
fi

echo "$PID|$TTY|$STAT|$TIME|$COMMAND" >> /tmp/ps_ax.txt
fi
done
column -s "|" -t /tmp/ps_ax.txt

