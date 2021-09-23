## Описание файлов в директории
ps_ax.sh - скрипт кторый собирает информацию и выводит информацию как утилита с ключами ps ax  
example.txt - пример вывода скрипта в ВМ

## Описание как запустить скрипт (кратко)
Запустить скрипт ps_ax.sh и подождать когда он выведет нужную информацию
```
./ps_ax.sh
```

## Полное описание как работает скрипт
### ps_ax.sh
```
#!/bin/bash
echo 'PID|TTY|STAT|TIME|COMMAND' > /tmp/ps_ax.txt
```
В файле /tmp/ps_ax.txt будет храниться вся собранная информация. Разделителем является |
```
ls -1 /proc/ | grep '^[0-9]' | sort -n > /tmp/procDir.txt
dirVol=$(cat /tmp/procDir.txt | wc -l)
```
Собираем список всех папок PID и считаем их количество, количество папок нам нужно для цикла
```
for ((i=1; i <= $dirVol; i++))
do
numDir=$(sed -n ${i}p /tmp/procDir.txt)
```
Работаем с каждым PID по одельности
```
if [ -f "/proc/$numDir/stat" ];then
```
Проверяем что пока мы готовились процесс не успел завершиться. Если файл существует, то мы начинаем работать. Если нет, то мы завершаем работу с этим PID и переходим к следующему
```
PID=$(cut -f1 -d' ' /proc/$numDir/stat)
```
pid %d - (1) The process ID (man proc).  
Сохраняем PID в переменную
```
checkTTY=$(ls -l /proc/$numDir/fd/ | grep ' 0 ->' | grep -v '/dev/null' | grep /dev/ | sed 's|.*/dev/\(.*\)|\1|')
if [ -n "$checkTTY" ];then
  TTY=$checkTTY
else
  TTY=?
fi
```
Если ссылка на терминал имеется, то записываем ее в переменной TTY, если нет то записываем знак ?.
```
####STAT###
STAT=''
state=''
nice=''
session=''
num_threads=''
tpgid=''
locked_memory=''
state=$(cut -f3 -d' ' /proc/$numDir/stat)
```
state %c    (3) One character from the string "RSDZTW" where R is running, S is sleeping in an interruptible wait, D is waiting in uninter-ruptible disk sleep, Z is zombie, T is traced or stopped (on a signal), and W is paging.  
state - стадии в жизненом цикле процесса. Третья позиция в файле /proc/[PID]/stat 
```
checkNice=$(cut -f19 -d' ' /proc/$numDir/stat)
if [[ "$checkNice" -gt 0 ]];then
  nice=N
elif [[ "$checkNice" -lt 0 ]];then
  nice='<'
fi
```
nice %ld  (19) The nice value (see setpriority(2)), a value in the range 19 (low priority) to -20 (high priority).  
● <    high-priority (not nice to other users)  
● N    low-priority (nice to other users)  
nice - позволяет понять какой приорите у процесса. "<" - если значение меньше нуля. "N" - если значение больше нуля. Девятнадцатая позиция в файле /proc/[PID]/stat  
```
checklockedMemory=$(grep VmLck /proc/$numDir/status | sed 's|  *| |' | cut -f2 -d' ')
if [[ "$checklockedMemory" -gt 0 ]];then
  locked_memory=L
fi
```
● L    has pages locked into memory (for real-time and custom IO)  
Если значение VmLck в фале не равно нулю, то ставлю L.  
```
checkSession=$(cut -f6 -d' ' /proc/$numDir/stat)
if [[ "$checkSession" -eq "$PID" ]];then
  session=s
fi
```
session %d  (6) The session ID of the process.  
● s    is a session leader  
Если session совпадает с PID процесса то ставлю s.
```
checkNum_threads=$(cut -f20 -d' ' /proc/$numDir/stat)
if [[ "$checkNum_threads" -gt "1" ]];then
  num_threads=l
fi
```
num_threads %ld (20)  Number  of threads in this process (since Linux 2.6).  Before kernel 2.6, this field was hard coded to 0 as a placeholder for an earlier removed field.  
● l    is multi-threaded (using CLONE_THREAD, like NPTL pthreads do)  
Если num_threads больше одного, то ставлю l
```
checkTpgid=$(cut -f8 -d' ' /proc/$numDir/stat)
if [[ "$checkTpgid" -eq "$PID" ]];then
  tpgid='+'
fi
```
tpgid %d    (8) The ID of the foreground process group of the controlling terminal of the process.  
● +    is in the foreground process group  
Если tpgid совпадает с PID процесса то ставлю +.
```
STAT=$(echo "${state}${nice}${locked_memory}${session}${num_threads}${tpgid}")
```
Собираю все значения в одной переменной
```
####STAT###

utime=$(cut -f14 -d' ' /proc/$numDir/stat)
stime=$(cut -f15 -d' ' /proc/$numDir/stat)
```
utime %lu   (14)   Amount   of   time   that  this  process  has  been  scheduled  in  user  mode,  measured  in  clock  ticks  (divide  by sysconf(_SC_CLK_TCK)).  This includes guest time, guest_time (time spent running a virtual CPU, see below),  so  that  applica tions that are not aware of the guest time field do not lose that time from their calculations.  
stime %lu   (15)   Amount   of  time  that  this  process  has  been  scheduled  in  kernel  mode,  measured  in  clock  ticks  (divide  by sysconf(_SC_CLK_TCK)).  
Время выполнения в пользовательском режиме utime, и в режиме ядра stime.
```
ustime=$((($utime+$stime)*10/1000))
```
Складываем время utime и stime. Чтобы время перевести из ticks (jiffies) в мс, умножаем на 10. И делим на 1000 чтобы получить секунды.  
ticks (jiffies) перевести в мс зависит от ядра системы. Видимо в моей он составляет 10 мс.
```
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
```
Выполненую комманду нахожу в файле /proc/[PID]/cmdline.  
Если там пусто, то беру значение comm в /proc/[PID]/stat  
comm %s     (2) The filename of the executable, in parentheses.  This is visible whether or not the executable is swapped out.
```
echo "$PID|$TTY|$STAT|$TIME|$COMMAND" >> /tmp/ps_ax.txt
```
Собираю все нужные переменные в одну сточку и складываю в подготовленный файл /tmp/ps_ax.txt
```
fi
done
column -s "|" -t /tmp/ps_ax.txt
```
С помощью утилиты column строю таблицу