#!/bin/bash

# STORES CAPTURE DATETIMES AND SUCCESSFUL OR FAILED READINGS FROM QA
logfile_path=~/corrupt_screen.log

# QA LOG IS A TEMP WHICH HOLDS ATTEMPTED READINGS
logfile_path_qa=~/corrupt_screen_qa.log

# GET A TIMESTAMP REFERENCE, HARD SET SEC -> 00
now_ISO8601=$(date -u +"%Y-%m-%dT%H:%M:00Z")

# TOUCH IN CASE IT WAS DELETED FOR SOMEREASON
touch $logfile_path_qa

# PRINT BLOCK START
echo "[START CAPTURE BLOCK : ${now_ISO8601}]" | tee -a "$logfile_path"

# CHECK FOR AN EXISTING SCREEN SESSION RUNNING AS RDU
# THIS LISTS ALL PROCESSES INCLUDING NON-TERMINAL ONES LIKE THE SCREEN SESSION
# LOOKS FOR A MATCH ON THE SCREEN COMMAND
# AND REMOVES THIS GREP PROCESS FROM THE RESULTS

screen=$(screen -list | grep -Eo '[[:digit:]]+\.rdu' | wc -l)

# IF THERE WAS NO RESULT FROM SET, WE NEED TO START A SCREEN SESSION NOW

if [ $screen -eq 0 ]; then

   echo "[info] creating a new screen session for rdu" | tee -a "$logfile_path"

   screen -dmS rdu /dev/ttyUSB0 9600

else

   echo "[info] connecting to existing screen for the rdu" | tee -a "$logfile_path"

fi

# WRITE THE RDU SCREEN TO QA FILE (THREE ATTEMPTS ARE MADE)
for a in {1..3}; do
   # TRUNCATE QA FILE FOR A CLEAN READING
   : > $logfile_path_qa

   # WRITING THE SCREEN SCRAPE TO QA.LOG
   echo "[info] capturing the rud screen (attempt $a/3)" | tee -a "$logfile_path_qa"

   echo "[reading]" >> $logfile_path_qa

   screen -S rdu -X eval "hardcopy_append on" "hardcopy corrupt_screen_qa.log"

   # SLEEP TO ENSURE [/reading] APPEND IS AFTER screen EVENT
   sleep 3
   echo "[/reading]" >> $logfile_path_qa

   # DID WE LOCATE THE BASIC PARAMETERS SCREEN (STRUCTURAL TEST OF THE DATA)?

   check1=$(grep "He Parameters" $logfile_path_qa | wc -l)

   if [ $check1 -gt 0 ]; then

      echo "[success] helium data was located" | tee -a "$logfile_path"

   else

      echo "[failure] helium data is missing" | tee -a "$logfile_path"

   fi

   check2=$(grep "Compressor:" $logfile_path_qa | wc -l)

   if [ $check2 -gt 0 ]; then

      echo "[success] compressor data was located" | tee -a "$logfile_path"

   else

      echo "[failure] compressor data is missing" | tee -a "$logfile_path"

   fi

   check3=$(grep "3;10H" $logfile_path_qa | wc -l)

   if [ $check3 -eq 1 ]; then

      echo "[failure] corrupt screen detected: '3;10H'" | tee -a "$logfile_path"

   else

      echo "[success] corruption not detected" | tee -a "$logfile_path"

   fi

   # IF BOTH ARE PRESENT, WE CAN GET OUT OF THE LOOP

   if [ $check1 -gt 0 ] && [ $check2 -gt 0 ] && [ $check3 -lt 1 ]; then

      echo "[success] all data is present" | tee -a "$logfile_path"
      break

      # IF NOT, WE RESET TO MAIN MENU, WAIT A BIT, AND RE-ENTER MONITORING MODE

   else

      # ESC TO GET INTO THE MAIN MENU

      echo "[reset 1/2] now resetting the MSUP screen due to missing data (3 sec delay)" | tee -a "$logfile_path"

      screen -S rdu -X -p 0 stuff '\033\n\n'
      sleep 3

      # GET US BACK INTO THE MONITOR MODE
      echo "[reset 2/2] now attempting to re-enter monitoring mode (5 sec delay)" | tee -a "$logfile_path"
      screen -S rdu -X -p 0 stuff '\n\nR\n\n'
      sleep 5

      # NOW WE START OVER AGAIN
      echo "[retry] now we will make another attempt to read data" | tee -a "$logfile_path"

   fi

done

# IF WE TRIED THREE TIMES AND CANNOT GET DATA, WE HAVE TO BAIL OUT

if [ $check1 -eq 0 ] || [ $check2 -eq 0 ] || [ $check3 -gt 0 ]; then

   echo "[failure] could not reset data after three tries, aborting now..." | tee -a "$logfile_path"

fi