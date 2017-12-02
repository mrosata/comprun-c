#!/usr/bin/env bash
######################################################################
#### Compile C file and then run script
#### 
#### I wrote this to quickly compile and run c files from VIM
####
#### - Set file to compile with flag -f|--file (no extension needed)
#### - Explicit output filename flag -o|--output (requires extension)
#### - Optionally set command that pipes into the ran compiled file by
####   setting value on the flag -c|--command
#### - Add flags to C Compiler as single argument to -s|--set
#### - Turn on bash message/error logging with flag -v|--verbose
#### - Automatically recompile and run on change. This simply checks 
####   ctime of source file every n seconds. Set using -w|--watch
####   Note: must pass a positive number for `n`
####


clear ;
#### Error Codes
ERRNO_HELP=1
ERRNO_ARGS=2
ERRNO_COMPILE=3
ERRNO_RUNTIME=4
ERRNO_NOFILE=5

#### Variables
verbose=0
watching=0
input_command=
compiler_flags=
filename=
outputname=
src_ctime=

#### Colors
declare -A colors
colors=(
  [reset]="\e[0m"
  [red]="\e[91m"
  [green]="\e[32m"
  [yellow]="\e[33m"
  [blue]="\e[34m"
  [magenta]="\e[35m"
  [cyan]="\e[36m"
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
     $0 -f some_file -c "cat ./foo"
 - Custom flags for C Compiler
     $0 -f some_file -s "-Wall -Wextra -Werror -O0 -ansi -pedantic -std=c11"
 - Watch for changes in file and automagically compile and run
     $0 -f some_file -w 2
     # Where -w 2 means check every 2 seconds for a write to some_file.c
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
      input_command="$1"
      shift
      ;;
     
    -s|--set) # Pass a string for extra arguments to compiler
      shift
      compiler_flags="$1"
      shift
      ;;

    -w|--watch) # Watch every n seconds and run again after any changes
      # Don't copy this argument to orig_argv
      shift
      [ $1 -gt 0 ] && watching=$1
      shift
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


compile_and_run () {
  cfile="${1:-$filename}.c"
  ofile="${2:-$outputname}.h"
  pipecmd="${3:-$input_command}"
  cflags="${4:-$compiler_flags}"
  msg=

  #### Compile source (-f).c into target (-o|-f).h
  if gcc $cflags "$cfile" -o "$ofile"; then
    logger 1 " - Compiled Successfully."
  else
    logger 2 " - Compile Error."
    echo $ERRNO_COMPILE
    return ;
  fi
  
  if [ ! -f "$ofile" ]; then
    logger 2 "Unable to find output file!"
    echo $ERRNO_RUNTIME
    return ;
  fi
  
  msg="Command: ${pipecmd} | ${outputname}.h\n"
  msg="$msg - Running..."
  logger 1 "$msg"
  unset msg
  
  if [ -n "$pipecmd" ]; then
    if $pipecmd 2>&1 | "$ofile" ; then
      logger 1 "\n\n ---- DONE ----"
    else
      logger 2 "Runtime Error $? - $pipecmd | $ofile"
      # echo $ERRNO_RUNTIME
      return ;
    fi
  elif "$ofile" ; then
    logger 1 "\n\n ---- DONE ---- "
  else
    logger 2 " ---- EXIT $? ---- "
    # echo $ERRNO_RUNTIME
    return ;
  fi
  # Done
}


if [ ! $watching -gt 0 ]; then
  # Compile the file, run it once and then exit
  compile_and_run "$filename" "$outputname" "$input_command" "$compiler_flags"
  
  exit 0 ;
else
  # Now loop every -w seconds and check if file was updated, then run again.
  echo -e "${colors[blue]}Waiting for update in $filename.c${colors[reset]}"
  
  while true; do 
    update_time=`stat -c %Y "$filename.c"`
    current_time=`date --date="$watching seconds ago" +%s`
    # Check if file has been changed before compiling
    if [ $[$current_time] -lt $[$update_time] ]; then
      clear ; echo -e "${colors[green]}Updated File $filename.c at $(date +%c)"
      echo -e "${colors[reset]}"
      sleep 0.2
      compile_and_run "$filename" "$outputname" "$input_command" "$compiler_flags"
    fi

    sleep $watching  
  done

fi

