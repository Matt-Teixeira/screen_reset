#!/bin/bash
#
# 2021.08.17  Created by Simplexable to support 1st generation Siemens RDU (TIM magnet). (crw)
#
# 2021.08.19  Changed curl to use HTTPS. (crw)
#
# full credit to Bach Nguyen (Samei, Inc.) for original implementation which forms a large part of this script

# echo "RDU V1 9600 baud script for TIM MSUP is running. This logs to msup-full.log."

#11/12/22 Updated script to reflect magnet type this includes screen / screipt and log file with standard name Siemens-4####Joe Anello#####

# STORES CAPTURE DATETIMES AND SUCCESSFUL OR FAILED READINGS FROM QA
logfile_path=~/siemens_4k.log

# QA LOG IS A TEMP WHICH HOLDS ATTEMPTED READINGS
logfile_path_qa=~/siemens_4k_qa.log

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

screen=$(ps -aux | grep 'SCREEN -dmS *siemens_4k*' | grep -v grep)

# SET THIS OUTPUT JUST TO TEST IF A PROCESS WAS RETURNED (SCREEN SESSION EXISTS)

set -- $screen

# IF THERE WAS NO RESULT FROM SET, WE NEED TO START A SCREEN SESSION NOW

if (($# == 0)); then

   echo "[info] creating a new screen session for siemens 4k msup" | tee -a "$logfile_path"

   screen -dmS siemens_4k /dev/ttyUSB0 9600

else

   echo "[info] connecting to existing screen for the Siemens 4k MSUP" | tee -a "$logfile_path"

fi

# WRITE THE RDU SCREEN TO QA FILE (THREE ATTEMPTS ARE MADE)
for a in {1..3}; do
   # TRUNCATE QA FILE FOR A CLEAN READING
   : > $logfile_path_qa

   # WRITING THE SCREEN SCRAPE TO QA.LOG
   echo "[info] capturing the MSUP screen (attempt $a/3)" | tee -a "$logfile_path_qa"

   echo "[reading]" >> $logfile_path_qa

   screen -S siemens_4k -X eval "hardcopy_append on" "hardcopy siemens_4k_qa.log"

   # SLEEP TO ENSURE [/reading] APPEND IS AFTER screen EVENT
   sleep 3
   echo "[/reading]" >> $logfile_path_qa

   # DID WE LOCATE THE BASIC PARAMETERS SCREEN (STRUCTURAL TEST OF THE DATA)?

   check1=$(grep "He Parameters" $logfile_path_qa | wc -l)

   if [ $check1 -gt 0 ]; then

      echo "[success] helium data was located" | tee -a "$logfile_path_qa"

   else

      echo "[failure] helium data is missing" | tee -a "$logfile_path_qa"

   fi

   check2=$(grep "Compressor" $logfile_path_qa | wc -l)

   if [ $check2 -gt 0 ]; then

      echo "[success] compressor data was located" | tee -a "$logfile_path_qa"

   else

      echo "[failure] compressor data is missing" | tee -a "$logfile_path_qa"

   fi

   # IF BOTH ARE PRESENT, WE CAN GET OUT OF THE LOOP

   if [ $check1 -gt 0 ] && [ $check2 -gt 0 ]; then

      echo "[success] all data is present" | tee -a "$logfile_path_qa"
      break

      # IF NOT, WE RESET TO MAIN MENU, WAIT A BIT, AND RE-ENTER MONITORING MODE

   else

      # ESC TO GET INTO THE MAIN MENU

      echo "[reset 1/2] now resetting the MSUP screen due to missing data (3 sec delay)" | tee -a "$logfile_path_qa"

      screen -S siemens_4k -X -p 0 stuff '\033\n\n'
      sleep 3

      # GET US BACK INTO THE MONITOR MODE
      echo "[reset 2/2] now attempting to re-enter monitoring mode (5 sec delay)" | tee -a "$logfile_path_qa"
      screen -S siemens_4k -X -p 0 stuff '\n\nR\n\n'
      sleep 5

      # NOW WE START OVER AGAIN
      echo "[retry] now we will make another attempt to read data" | tee -a "$logfile_path_qa"

   fi

done

# IF WE TRIED THREE TIMES AND CANNOT GET DATA, WE HAVE TO BAIL OUT

if [ $check1 -eq 0 ] || [ $check2 -eq 0 ]; then

   echo "[failure] could not get helium and compressor data after three tries, aborting now..." | tee -a "$logfile_path"

fi

# APPEND THIS READING TO FULL RDU LOG
cat $logfile_path_qa >> $logfile_path

# APPEND END CAP BLOCK
echo "[END CAPTURE BLOCK : ${now_ISO8601}]" | tee -a "$logfile_path"

echo "" >>$logfile_path