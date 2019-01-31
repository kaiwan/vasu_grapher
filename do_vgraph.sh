#!/bin/bash
# do_vgraph.sh
# https://github.com/kaiwan/vasu_grapher.git
#
# Quick Description:
# Don't invoke this directly, run the 'vasu_grapher' wrapper instead.
# do_vgraph.sh: Support script for the vasu_grapher project; really, it's
# where the stuff actually happens :)
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
# Our prep_mapsfile.sh script is invoked via the vasu_grapher wrapper to do
# precisely this.
#
# TODO
# [+] show Null trap vpage 0
# [+] show sparse regions of the VAS
# [+] separate config file
#     - move config vars to a config file for user convenience
# [ ] Validation: check input file for correct format
# [.] Statistics
#     [+] # VMAs, # sparse regions
#     [+] space taken by valid regions & by sparse (%age as well of total)
#     [ ] space taken by text, data, libs, stacks, ... regions (with %age)
# [.] Segment Attributes
#     [.] seg size
#         [ ] RSS   [ ] PSS  [ ] Swap  [ ] Locked (?)    [use smaps!]
#     [ ] seg permissions
# [ ] Graphical stuff-
#  convert to reqd format
#     [ ] write to SVG !
#     [ ] interactive GUI
#
# Last Updated : 31jan2019
# Created      : 26jul2017
# 
# Author:
# Kaiwan N Billimoria
# kaiwan -at- kaiwantech -dot- com
# kaiwan -dot- billimoria -at- gmail -dot- com
# kaiwanTECH
# License: MIT.
name=$(basename $0)
source ./common.sh || {
 echo "${name}: fatal: could not source common.sh , aborting..."
 exit 1
}
source ./config || {
 echo "${name}: fatal: could not source configuration in file 'config', aborting..."
 exit 1
}

########### Functions follow #######################

#-------------------- p r e p _ f i l e -------------------------------
prep_file()
{
# Get rid of comment lines
sed --in-place '/^#/d' ${gINFILE}
} # end prep_file()

#------------------- g e t _ r a n g e _ i n f o ----------------------
get_range_info()
{
# Get the process user VAS (virtual addr space) range: start - end
#  -the first and last numbers!
local int_start=$(head -n1 ${gINFILE} |cut -d"${gDELIM}" -f1 |sed 's/ //') # also trim
local int_end=$(tail -n2 ${gINFILE} |head -n1 |cut -d"${gDELIM}" -f2 |sed 's/ //')
#decho "int_start = $int_start int_end $int_end"
#local int_end=$(tail -n1 ${gINFILE} |cut -d"${gDELIM}" -f2 |sed 's/ //')

# RELOOK : int value overflows here w/ large 64-bit # as input
# Fixed: use printf w/ %llu fmt
local start_dec=$(printf "%llu" 0x${int_start})   #$(echo $((16#${int_start})))
local end_dec=$(printf "%llu" 0x${int_end})
gTotalLen=$(printf "%llu" $((end_dec-start_dec)))
gFileLines=$(wc -l ${gINFILE} |awk '{print $1}')  # = # of VMAs
decho "range: [${start_dec} to ${end_dec}]: total size=${gTotalLen}"

# 32 or 64 bit OS?
IS_64_BIT=1
which getconf >/dev/null || {
  echo "${name}: WARNING! getconf(1) missing, assuming 64-bit OS!"
} && {
  local bitw=$(getconf -a|grep -w LONG_BIT|awk '{print $2}')
  [ ${bitw} -eq 32 ] && IS_64_BIT=0  # implies 32-bit
}
decho "64-bit OS? ${IS_64_BIT}"
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

LIMIT_SCALE_SZ=10

#---------------------- g r a p h i t ---------------------------------
# Iterates over the global '4d' array gArr[] 'drawing' the vgraph.
# Data driven tech!
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
    # "integer expression expected" err; hence, use bc(1):
    szGB=0
    if (( $(echo "${szMB} > 1024" |bc -l) )); then
      szGB=$(bc <<< "scale=2; ${szMB}/1024.0")
    fi

    #--- Drawing :-p  !
    #fg_blue
    [ ${IS_64_BIT} -eq 1 ] && { 
     printf "%s %016lx\n" "${LIN}" "0x${num1}"
    } || {
     printf "%s %08x\n" "${LIN}" "0x${num1}"
    }
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

[ ${IS_64_BIT} -eq 1 ] && { 
 printf "%s %016lx\n" "${LIN}" "0x${num2}"
} || {
 printf "%s %08x\n" "${LIN}" "0x${num2}"
}
} # end graphit()

gNumSparse=0
gTotalSparseSize=0
gTotalSegSize=0

#------------------ i n t e r p r e t _ r e c -------------------------
# Interpret a record: a CSV 'line' from the input stream:
# Format:
#  start_uva,start_uva,segment_name   ; uva = user virtual address
# eg.
#  7f3390031000,7f3390053000,/lib/x86_64-linux-gnu/libc-2.28.so
# Parameters:
#  $1 : the above CSV format string tuple {start_uva,end_uva, segname}
#  $2 : loop index
# Populate the global '4d' array gArray.
interpret_rec()
{
#echo "num=$# p=$@"
local gap=0
local start_uva=$(echo "${1}" |cut -d"${gDELIM}" -f1)
local end_uva=$(echo "${1}" |cut -d"${gDELIM}" -f2)

# Skip comment lines
echo "${start_uva}" | grep -q "^#" && return

local segment=$(echo "${1}" |cut -d"${gDELIM}" -f3)
[ -z "${segment}" ] && segment=" [-unnamed-] "

# Convert hex to dec
local start_dec=$(printf "%llu" 0x${start_uva})
local end_dec=$(printf "%llu" 0x${end_uva})
local seg_sz=$(printf "%llu" $((end_dec-start_dec)))  # in bytes

# The global 4d-array's format is:
#          col0   col1   col2   col3
# row'n' [label],[size],[num1],[num2]
#        segnm,  segsz,start-uva,end-uva

# Show null trap, vpage 0
NULLTRAP_STR="[ NULL trap ]"
if [ ${NULL_TRAP_SHOW} -eq 1 -a $2 -eq 0 ]; then
  gArray[${gRow}]="${NULLTRAP_STR}"
  let gRow=gRow+1
  gArray[${gRow}]=${PAGE_SIZE}
  let gRow=gRow+1
  gArray[${gRow}]=0
  let gRow=gRow+1
  gArray[${gRow}]=$(printf "%x" ${PAGE_SIZE})
  let gRow=gRow+1
fi

#------------ Sparse Detection
if [ ${SPARSE_SHOW} -eq 1 ]; then

DetectedSparse=0
SPARSE_ENTRY="<< ... Sparse Region ... >>"

[ $2 -eq 0 ] && prevseg_end_uva=${PAGE_SIZE}

# Detect sparse region, and if present, insert into the gArr[].
# Sparse region detected by condition:
#  gap = this-segment-start - prev-segment-end > 1 page
if [ $2 -eq 0 ] ; then   # first segment in the process
  [ ${start_dec} -gt 0 ] && {
    gap=${start_dec}
    DetectedSparse=1
  }
else
  decho "start_dec=${start_dec} prevseg_end_uva=${prevseg_end_uva}"
  #printf "%x  %x\n" ${start_dec} ${prevseg_end_uva}
  gap=$((${start_dec} - ${prevseg_end_uva}))
  [ ${gap} -gt ${PAGE_SIZE} ] && {
    decho "gap = ${gap}"
    DetectedSparse=1
  }
fi

[ ${DetectedSparse} -eq 1 ] && {
    # name / label
    gArray[${gRow}]="${SPARSE_ENTRY}"
    let gRow=gRow+1

    # segment size (bytes)
    [ ${NULL_TRAP_SHOW} -eq 0 ] && {
      gArray[${gRow}]=${gap}
    } || {
      let gap=$gap-$PAGE_SIZE
      gArray[${gRow}]=${gap}
    }
    let gRow=gRow+1

    # start uva
    if [ $2 -eq 0 ]; then  # first entry
      [ ${NULL_TRAP_SHOW} -eq 0 ] && gArray[${gRow}]=0 || gArray[${gRow}]=1000
    else
      local prevseg_end_uva_hex=$(printf "%x" ${prevseg_end_uva})
      gArray[${gRow}]=${prevseg_end_uva_hex}
    fi
    let gRow=gRow+1

    # end uva
    # the end addr is 1 page (0x1000) before the next one
    gArray[${gRow}]=$(printf "%x" $((0x${start_uva} - 0x1000)))
    let gRow=gRow+1

    # Stats
    [ ${STATS_SHOW} -eq 1 ] && {
      let gNumSparse=gNumSparse+1
      let gTotalSparseSize=gTotalSparseSize+gap
    }
}
prevseg_end_uva=${end_dec}
fi
#--------------

#--- Populate the global array
gArray[${gRow}]=${segment}
let gRow=gRow+1
gArray[${gRow}]=${seg_sz}
let gRow=gRow+1
gArray[${gRow}]=${start_uva}
let gRow=gRow+1
gArray[${gRow}]=${end_uva}
let gRow=gRow+1

[ ${STATS_SHOW} -eq 1 ] && {
  let gTotalSegSize=${gTotalSegSize}+${seg_sz}
  # does NOT include the null trap; that's correct
}
} # end interpret_rec()

# Display the number passed.
# As appropriate, also in KB, MB, GB, TB.
# $1 : the (large) number to display
# $2 : the total space size 'out of' (for percentage calculation)
#    percent = ($1/$2)*100
# $3 : the message string
largenum_display()
{
 local szKB=0 szMB=0 szGB=0 szTB=0

     # !EMB: if we try and use simple bash arithmetic comparison, we get a 
     # "integer expression expected" err; hence, use bc(1):
     [ ${1} -ge 1024 ] && szKB=$(bc <<< "scale=6; ${1}/1024.0") || szKB=0
     #[ ${szKB} -ge 1024 ] && szMB=$(bc <<< "scale=6; ${szKB}/1024.0") || szMB=0
     if (( $(echo "${szKB} > 1024" |bc -l) )); then
       szMB=$(bc <<< "scale=6; ${szKB}/1024.0")
     fi
     if (( $(echo "${szMB} > 1024" |bc -l) )); then
       szGB=$(bc <<< "scale=6; ${szMB}/1024.0")
     fi
     if (( $(echo "${szGB} > 1024" |bc -l) )); then
       szTB=$(bc <<< "scale=6; ${szGB}/1024.0")
     fi

     printf " $3 %llu bytes = %9.6f KB" ${1} ${szKB}
     if (( $(echo "${szKB} > 1024" |bc -l) )); then
       printf " = %9.6f MB" ${szMB}
       if (( $(echo "${szMB} > 1024" |bc -l) )); then
         printf " =  %9.6f GB" ${szGB}
       fi
       if (( $(echo "${szGB} > 1024" |bc -l) )); then
         printf " =  %9.6f TB" ${szTB}
       fi
     fi

     #local pcntg=$(bc <<< "scale=12; (${1}/(128.0*1024*1024*1024*1024))*100.0")
     local pcntg=$(bc <<< "scale=12; (${1}/${2})*100.0")
     printf "\n  i.e. %2.6f%%" ${pcntg}
}

#--------------------------- p r o c _ s t a r t -----------------------
proc_start()
{
 local szKB szMB szGB

 prep_file
 get_range_info
 export IFS=$'\n'
 local i=0

 #--- Header
 tput bold
 printf "\n[================---   V A S U _ G R A P H E R   ---===================]\n"
 printf "Virtual Address Space Usermode (VASU) process GRAPHER (via /proc/$1/maps)\n"
 printf " https://github.com/kaiwan/vasu_grapher\n"
 color_reset
 date
 local nm=$(head -n1 /proc/$1/comm)
 printf "\n[==============--- Start memory map PID %d (%s) ---===============]\n" $1 ${nm}

 # Redirect to stderr what we don't want in the log
 printf "\n%s: Processing, pl wait ...\n" "${name}" 1>&2

 # Populate the global '4d' array gArray.
 local REC
 for REC in $(cat ${gINFILE})
 do 
   #echo "REC: $REC"
   interpret_rec ${REC} ${i}
   printf "=== %06d / %06d\r" ${i} ${gFileLines}
   let i=i+1
 done 1>&2

#showArray
graphit

TB_128=$(bc <<< "scale=6; 128.0*1024.0*1024.0*1024.0*1024.0")

 #--- Footer
 tput bold
 printf "[===--- End memory map PID %d (%s) ---===]\n" $1 ${nm}
 [ ${STATS_SHOW} -eq 1 ] && {
   # Paranoia
   local numvmas=$(wc -l /proc/$1/maps |awk '{print $1}')
   [ ${gFileLines} -ne ${numvmas} ] && printf " [!] Warning! # VMAs does not match /proc/$1/maps\n"
   printf "Stats:\n %d VMAs (segments)" ${gFileLines}
   [ ${SPARSE_SHOW} -eq 1 ] && {
     printf ", %d sparse regions\n" ${gNumSparse}
     largenum_display ${gTotalSparseSize} ${TB_128} "Total space that is Sparse :"
   } # sparse show

   # Valid regions (segments) total size
   largenum_display ${gTotalSegSize} ${TB_128} "\n Total space that is valid memory (segments) :"
   printf "\n"
 } # stats show
 color_reset
} # end proc_start()


##### 'main' : execution starts here #####

which bc >/dev/null || {
  echo "${name}: bc(1) package missing, pl install. Aborting..."
  exit 1
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
