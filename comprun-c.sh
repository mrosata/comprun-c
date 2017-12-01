#!/usr/bin/env bash
######################################################################
#### Compile C file and then run script
#### 
#### I wrote this to quickly compile and run c files from VIM
####
#### - Set file to compile with flag -f|--file (no extension needed)
#### - Explicit output filename flag -o|--output (requires extension)
####
#### - Optionally set command that pipes into the ran compiled file by
####   setting value on the flag -c|--command
####
#### - Turn on message/error logging with flag (-v|--verbose)
####


#### Error Codes
ERRNO_HELP=1
ERRNO_ARGS=2
ERRNO_COMPILE=3
ERRNO_RUNTIME=4

#### Variables
verbose=0
input_command=
filename=
outputname=

#### Colors
declare -A colors
colors=(
  [reset]="\e[0m"
  [red]="\e[91m"
  [bold]="\e[1m"
)


#### Output the help text
read_help () {
  cat << EOM
 [HELP] ---- Compile then Run a C Program ---- 
 
 - to compile some_file.c to some_file.h and run:
     $0 -f some_file
 - to compile some_file.c to other_file.h and run:
     $0 -f some_file -o other_file 
 - echo out status messages (verbose)
     $0 -f some_file -v
 - A command which will pipe stdIn/Out to compiled file
     $0 -f some_file -c \"cat ./foo\"
  
 - There is no man page for this program.
EOM
}


#### Logger
####  @1 {int} level
####  @2 {text} message
logger () {
  loglevel=${1:-0}
  message="$2"
  [ $loglevel -eq 1 ] && echo -e "${colors[bold]}$message${colors[reset]}"
  [ $loglevel -eq 2 ] && echo -e "\"${colors[red]}$message${colors[reset]}"
}


while test $# -gt 0; do
  #### Parse Command Line Arguments
  
  case "$1" in 
    #### Required Parameters ####
    
    -f|--file) # A c file to compile (source)
      shift
      filename=`echo "$1" | perl -pe 's/^(.*)(\.c)$/$1/'`
      shift
      ;;
    
    #### Optional Parameters ####
    
    -o|--output) # The compiled filed (target)
      shift
      outputname=`echo "$1" | perl -pe 's/^(.*)(\.h)$/$1/'`
      shift
      ;;
    
    -c|--command) # A Command to pipe into executed program
      shift
      if [ -n "$1" ]; then
        input_command="$1"
        shift
      fi
      ;;
    
    -v|--verbose)  # Turn on verbose logging
      verbose=1
      shift
      ;;
    
    -h|--help|*)  # View "help" and return 0 since help was asked for
     read_help
     exit 0
     ;;

  esac
done


if [ -z "$filename" ]; then
  read_help
  exit $ERRNO_HELP;
elif [ ! -f "$filename.c" ]; then
  logger 2 "$filename.c is not a file!"
  read_help
  exit $ERRNO_ARGS;
fi

# Make sure we have either relative or absolute path to file
basefilename=`basename $filename.c`
if [ "$basefilename" = "$filename.c" ]; then
  filename="./$filename"
fi
outputname="${outputname:-$filename}"
basefilename=`basename $outputname.h`
if [ "$basefilename" = "$outputname.h" ]; then
  outputname="./$outputname"
fi
unset basefilename

#### Compile source (-f).c into target (-o|-f).h
if gcc "$filename.c" -o "$outputname.h" ; then
  logger 1 " ---- Compiled Successfully ---- "
else
  logger 2 " ---- Compile Error ---- "
  exit $ERRNO_COMPILE ;
fi

if [ ! -f "$outputname.h" ]; then
  logger 2 "Unable to find output file!"
  exit $ERRNO_RUNTIME ;
fi

msg="Command: ${input_command}${outputname}.h\n"
msg="$msg ---- RUNNING ---- "
logger 1 "$msg"
unset msg

if [ -n "$input_command" ]; then
  if $input_command 2>&1 | "$outputname.h" ; then
    logger 1 " ---- DONE ---- "
  else
    logger 2 "Command Exit $? - $input_command | $outputname.h"
    exit $ERRNO_RUNTIME ;
  fi
elif "$outputname.h" ; then
  logger 1 " ---- DONE ---- "
else
  logger 2 " ---- EXIT $? ---- "
  exit $ERRNO_RUNTIME ;
fi

exit 0
