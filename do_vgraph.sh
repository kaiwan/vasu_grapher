#!/bin/bash
# do_vgraph.sh
# https://github.com/kaiwan/vasu_grapher.git
#
# Quick Description:
# Don't invoke this directly, run the 'vasu_grapher' wrapper instead.
# Support script for the vasu_grapher project; really, it's where the stuff
# actually happens :)
# "Draw" out, (somewhat) to scale, ranges of numbers in a vertically tiled 
# format. For eg.: the output of /proc/iomem, /proc/vmalloc, 
# /proc/<.pid>/maps, etc etc
# 
# We EXPECT as input a file; the file must be in CSV format with 3 columns;
# col 1 and col 2 are ASSumed to be in hexadecimal.
# (as of this very early ver at least). 
# FORMAT ::
#   [...]
# field1,field2,field3
# field1,field2,field3
#   [...]
#
# (As of now):
# field1: integer value (often an address of some sort)
# field2: integer value (often an address of some sort)
# field3: string: descriptive
#
# You must generate the file. For eg.
# you can do:
# awk '{print $1, $6}' /proc/self/maps
# -to get the output of the 'maps' file as 3 columns. Now you must of course
# change the delimiter to a comma ',' (CSV) (could use sed for this). 
# Then pass this script this file.
#
# TODO
# - convert to reqd format
# - check input file for correct format
# - write to SVG !
# - interactive GUI
#
# Last Updated : 28jan2019
# Created      : 26jul2017
# 
# Author:
# Kaiwan N Billimoria
# kaiwan -at- kaiwantech -dot- com
# kaiwanTECH
# License: MIT.
name=$(basename $0)
source ./common.sh || {
 echo "${name}: fatal: could not source common.sh , aborting..."
 exit 1
}

########### Globals follow #########################
export PHYADDR_HEX=1
export EMB=0  # simpler [no float point, etc]
DEBUG=0
gDELIM=","

########### Functions follow #######################

#------------------------- d i s p ------------------------------------
# eg. disp ${numspc} ${pa_name} ${pa_start_dec} ${pa_end_dec} ${sz}
# Params:
#  $1 : left indentation length
#  $2 : Region
#  $3 : start phy addr
#  $4 : end phy addr
#  $5 : size of region in bytes
disp()
{
local sp=$(($1+1))
local fmtname=$((30-${sp}))
local szKB=$(($5/1024))
local szMB=0
local szGB=0

[ ${PHYADDR_HEX} -eq 0 ] && {
  printf "%${sp}s%-${fmtname}s:%16d   %16d [%9d" \
		" " "${2}" "${3}" "${4}" ${szKB}
} || {
  printf "%${sp}s%-${fmtname}s:%16lx   %16lx [%9d" \
		" " "${2}" "${3}" "${4}" ${szKB}
}

# Calculate sizes in MB and GB if required
[ ${EMB} -eq 0 ] && {
  [ ${szKB} -ge 1024 ] && szMB=$(bc <<< "scale=2; ${szKB}/1024.0")
  # !EMB: if we try and use simple bash arithmetic comparison, we get a 
  # "integer expression expected" err; hence, use bc:
  if (( $(echo "${szMB} > 1024" |bc -l) )); then
    szGB=$(bc <<< "scale=2; ${szMB}/1024.0")
  fi

  if (( $(echo "${szMB} > 0" |bc -l) )); then
    printf "  %6.2f" ${szMB}
  fi
  if (( $(echo "${szGB} > 0" |bc -l) )); then
    printf "  %4.2f" ${szGB}
  fi
} || {  # embedded sys: simpler
  [ ${szKB} -ge 1024 ] && szMB=$((${szKB}/1024))
  [ ${szMB} -ge 1024 ] && szGB=$((${szMB}/1024))
  [ ${szMB} -gt 0 ] && printf "  %6d" ${szMB}
  [ ${szGB} -gt 0 ] && printf "  %4d" ${szGB}
}

printf "]\n"
} # end disp()

#-------------------- p r e p _ f i l e -------------------------------
prep_file()
{
# Get rid of comment lines
sed --in-place '/^#/d' ${gINFILE}
} # end prep_file()

#------------------- g e t _ r a n g e _ i n f o ----------------------
get_range_info()
{
# Get the range: start - end
#  -the first and last numbers!
local int_start=$(head -n1 ${gINFILE} |cut -d"${gDELIM}" -f1 |sed 's/ //') # also trim
local int_end=$(tail -n1 ${gINFILE} |cut -d"${gDELIM}" -f2 |sed 's/ //')

# RELOOK : int value overflows here w/ large 64-bit # as input
# Fixed: use printf w/ %llu fmt
local start_dec=$(printf "%llu" 0x${int_start})   #$(echo $((16#${int_start})))
local end_dec=$(printf "%llu" 0x${int_end})
gTotalLen=$(printf "%llu" $((end_dec-start_dec)))
gFileLines=$(wc -l ${gINFILE} |awk '{print $1}')
decho "range: [${start_dec}-${end_dec}]: size=${gTotalLen}"
} # end get_range_info()

#---
# We require a 4d array: each 'row' will hold these values:
#
#          col0   col1   col2   col3
# row'n' [label],[size],[num1],[num2]
#
# HOWEVER, bash only actually supports 1d array; we thus treat a simple 1d
# array as an 'n'd (n=4) array! 
# So we just populate a 1d array like this:
#  [val1] [val2] [val3] [val4] [val5] [val6] [val7] [val8] [...]
# but INTERPRET it as 4d like so:
#  ([val1],[val2],[val3],[val4]) ([val5],[val6],[val7],[val8]) [...]
declare -a gArray
gRow=0
#---

#-----------------------s h o w A r r a y -----------------------------
showArray()
{
local i k
echo
decho "gRow = ${gRow}"
# TODO / FIXME : soft-code, rm the '4'
for ((i=0; i<${gRow}; i+=4))
do
    printf "[%s, " "${gArray[${i}]}"
	let k=i+1
    printf "%d," "${gArray[${k}]}" 
	let k=i+2
    printf "%x," "0x${gArray[${k}]}" 
	let k=i+3
    printf "%x]\n" "0x${gArray[${k}]}" 
done
} # end showArray()

SCALE_FACTOR=100000000 #20 #200
LIMIT_SCALE_SZ=10

#---------------------- g r a p h i t ---------------------------------
graphit()
{
local i k
local label seg_sz num1 num2
local szKB=0 szMB=0 szGB=0
local         LIN="+------------------------------------------------------+"
local ELLIPSE_LIN="~ .       .       .       .       .       .        .   ~"
local BOX_RT_SIDE="|                                                      |"
local oversized=0

local DIM=4
for ((i=0; i<${gRow}; i+=${DIM}))
do
    #--- Retrieve values from the array
    label=${gArray[${i}]}  # col 1 [str: the label]
     #printf "%s: " "${gArray[${i}]}"
	let k=i+1
    seg_sz=${gArray[${k}]}  # col 2 [int: the size]
     #printf "%d\n" "${gArray[${k}]}"
	let k=i+2
    num1=${gArray[${k}]}  # col 3 [int: the first number]
     #printf "%d\n" "${gArray[${k}]}"
	let k=i+3
    num2=${gArray[${k}]}  # col 4 [int: the second number]
     #printf "%d\n" "${gArray[${k}]}"

    szKB=$((${seg_sz}/1024))
    [ ${szKB} -ge 1024 ] && szMB=$(bc <<< "scale=2; ${szKB}/1024.0") || szMB=0
    # !EMB: if we try and use simple bash arithmetic comparison, we get a 
    # "integer expression expected" err; hence, use bc:
    szGB=0
    if (( $(echo "${szMB} > 1024" |bc -l) )); then
      szGB=$(bc <<< "scale=2; ${szMB}/1024.0")
    fi

    #--- Drawing :-p  !
    #fg_blue
    printf "%s %x\n" "${LIN}" "0x${num1}"
    printf "|%20s  [%d KB" ${label} ${szKB}
    if (( $(echo "${szKB} > 1024" |bc -l) )); then
      tput bold; printf "  %6.2f MB" ${szMB}
      if (( $(echo "${szMB} > 1024" |bc -l) )); then
        printf "  %4.2f GB" ${szGB}
      fi
    fi
    color_reset
    printf "]\n"

    #--- NEW CALC for SCALING
    # Simplify: We base the 'height' of each segment on the number of digits
    # in the segment size (in bytes)!
    segscale=${#seg_sz}    # strlen(seg_sz)
    [ ${segscale} -lt 4 ] && {   # min seg size is 4096 bytes
        echo "${name}: fatal error, segscale (# digits) <= 3! Aborting..."
	echo "Kindly report this as a bug, thanks!"
	exit 1
    }
    decho "seg_sz = ${seg_sz} segscale=${segscale}"

    local box_height=0
    # for segscale range [1-4]
    # i.e. from 1-4 digits, i.e., 0 to 9999 bytes (ie. ~ 0 to 9.8 KB, single line
    if [ ${segscale} -ge 1 -a ${segscale} -le 4 ]; then
	box_height=0
    # for segscale range [5-7]
    # i.e. for 5 digits, i.e., ~  10 KB to  99 KB, 1 line box
    # i.e. for 6 digits, i.e., ~ 100 KB to 999 KB ~= 1 MB, 2 line box
    # i.e. for 7 digits, i.e., ~ 1 MB to 9.9 MB, 3 line box
    elif [ ${segscale} -ge 5 -a ${segscale} -le 7 ]; then
	let box_height=segscale-4
    else
    # for segscale >= 8 digits
    # i.e. for 8 digits, i.e., from ~ 10 MB onwards, show an oversized ellipse box
	box_height=10
    fi
    #---

    # draw the sides of the 'box'
    [ ${box_height} -ge ${LIMIT_SCALE_SZ} ] && {
   	box_height=${LIMIT_SCALE_SZ}
   	oversized=1
    }

    decho "box_height = ${box_height} oversized=${oversized}"
    for ((x=1; x<${box_height}; x++))
    do
   	printf "%s\n" "${BOX_RT_SIDE}"
   	if [ ${oversized} -eq 1 ] ; then
   		[ ${x} -eq $(((LIMIT_SCALE_SZ-1)/2)) ] && printf "%s\n" "${ELLIPSE_LIN}"
   	fi
    done
    #---
   #printf "%s\n" ${LIN}
   #color_reset
   #---
    oversized=0
done

printf "%s %x\n" "${LIN}" "0x${num2}"
} # end graphit()

#------------------ i n t e r p r e t _ r e c -------------------------
# Interpret a record: a 'line' from the input stream:
# Format:
#  num1,num2,label
# eg.
#  7f3390031000,7f3390053000,/lib/x86_64-linux-gnu/libc-2.28.so
# This above string will be passed as the parameter to this function.
# Populate the global '4d' array gArray.
interpret_rec()
{
#echo "num=$# p=$@"
local int_start=$(echo "${@}" |cut -d"${gDELIM}" -f1)
local int_end=$(echo "${@}" |cut -d"${gDELIM}" -f2)

# Skip comment lines
echo "${int_start}" | grep -q "^#" && return

local label=$(echo "${@}" |cut -d"${gDELIM}" -f3)
[ -z "${label}" ] && label=" [-unnamed-] "

# Convert hex to dec
local start_dec=$(printf "%llu" 0x${int_start})
local end_dec=$(printf "%llu" 0x${int_end})

#numspc=$(grep -o " " <<< ${pa_start} |wc -l)
 # ltrim: now get rid of the leading spaces

local seg_sz=$(printf "%llu" $((end_dec-start_dec)))  # in bytes

#--- Populate the global array
gArray[${gRow}]=${label}
let gRow=gRow+1
gArray[${gRow}]=${sz}
let gRow=gRow+1
gArray[${gRow}]=${int_start}
let gRow=gRow+1
gArray[${gRow}]=${int_end}
let gRow=gRow+1

} # end interpret_rec()

#--------------------------- p r o c _ s t a r t -----------------------
proc_start()
{
 prep_file
 get_range_info
 export IFS=$'\n'
 local i=0

 #--- Header
 printf "\n[==================---   V A S U _ G R A P H   ---=====================]\n"
 printf "Virtual Address Space Usermode (VASU) process GRAPHer (via /proc/$1/maps)\n"
 printf " https://github.com/kaiwan/vasu_grapher\n"
 date
 local nm=$(head -n1 /proc/$1/comm)
 printf "\n[==============--- Start memory map PID %d (%s) ---===============]\n" $1 ${nm}
# printf "<< Memory Map for process PID %d, best guess: %s >>\n\n" $1 "${nm}"

 # Redirect to stderr what we don't want in the log
 printf "\n%s: Processing, pl wait ...\n" "${name}" 1>&2

 # Populate the global '4d' array gArray.
 local REC
 for REC in $(cat ${gINFILE})
 do 
   #echo "REC: $REC"
   interpret_rec ${REC}
   printf "=== %06d / %06d\r" ${i} ${gFileLines}
   let i=i+1
 done 1>&2

 graphit

 printf "\n[==============--- End memory map PID %d (%s) ---===============]\n" $1 ${nm}
} # end proc_start()


##### 'main' : execution starts here #####

[ ${EMB} -eq 0 ] && {
   which bc >/dev/null || {
     echo "${name}: bc(1) package missing, pl install. Aborting..."
     exit 1
   }
}

[ $# -ne 2 ] && {
  echo "Usage: ${name} PID-of-process input-CSV-filename(3 column format)"
  exit 1
}
[ ! -f $2 ] && {
  echo "${name}: input-CSV-filename \"$2\" invalid? Aborting..."
  exit 1
}
[ ! -r $2 ] && {
  echo "${name}: input-CSV-filename \"$2\" not readable? Aborting..."
  exit 1
}

gINFILE=$2
proc_start $1
exit 0
