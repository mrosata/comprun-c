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
filename=
outputname=
compiler_flags=
input_command=
watching=0
watch_pattern=
argvs=
verbose=0

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
 
 - to compile some_file.c to some_file and run:
     $0 -f some_file
 - to compile some_file.c to other_file and run:
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
  [ $loglevel -eq 0 ] && echo -en "\r${colors[bold]}$message${colors[reset]}"
  [ $loglevel -eq 1 ] && echo -e "${colors[blue]}$message${colors[reset]}"
  [ $loglevel -eq 2 ] && echo -e "${colors[red]}$message${colors[reset]}"
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
      outputname=`echo "$1"`
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
      shift
      [ $1 -gt 0 ] && watching=$1
      shift
      ;;
    
    -wp|--wpattern) # Use a pattern to watch for additional files
      shift
      [ -n "$1" ] && wpattern="$1"
      shift
      ;;
    
    -a|--argvs) # argv to pass to the executable
      shift
      [ -n "$1" ] && argvs="$1"
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
basefilename=`basename "$outputname"`
if [ "$basefilename" = "$outputname" ]; then
  outputname="./$outputname"
fi
unset basefilename

compile_file () {
  local cfile="$1"
  local ofile="$2"
  local cflags="${3-}"
  if gcc $cflags "$cfile" -o "$ofile"; then
    echo "1"
  else
    echo "0"
  fi
}

read_pipe () {
  read "$@" <&0
}

compile_and_run () {
  cfile="${1:-$filename}.c"
  ofile="${2:-$outputname}"
  pipecmd="${3:-$input_command}"
  cflags="${4:-$compiler_flags}"
  argvs="${5:-$argvs}"
  msg=

  #### Compile source (-f).c into target (-o|-f)
  if [ "`compile_file "$cfile" "$ofile" "$cflags"`" = "1" ] ; then
    logger 1 " - Compiled Successfully."
  else
    logger 2 " - Compile Error."
    # echo $ERRNO_COMPILE
    return ;
  fi
  
  #### Test that compiled file exists
  sleep 0.5 # Try to avoid problem where file not present
  if [ ! -f "$ofile" ]; then
    logger 2 "Unable to find output file!"
    echo $ERRNO_RUNTIME
    return ;
  fi
 
  msg="Command:"
  if [ -n "$pipecmd" ]; then
    msg="$msg $pipecmd | "
  fi
  msg="$msg ${ofile}"
  if [ -n "$argvs" ]; then
    msg="$msg $argvs"
  fi
  msg="$msg\n - Running..."
  logger 1 "$msg"
  unset msg
  

  if [ -n "$pipecmd" ]; then
    if $pipecmd 2>&1 | "$ofile" $argvs ; then
      logger 1 "\n\n ---- DONE ----"
    else
      logger 2 "Runtime Error $? - $pipecmd | $ofile"
      # echo $ERRNO_RUNTIME
      return ;
    fi
  elif "$ofile $argvs" ; then
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
  # Create a tempfile to track time
  tmp_ctime_file="$(tempfile)"
  # Now loop every -w seconds and check if file was updated, then run again.
  logger 1 "${colors[blue]}Waiting for update in $filename.c${colors[reset]}"
  
  while true; do 
    update_time=`stat -c %Y "$filename.c"`
    current_time=`date --date="$watching seconds ago" +%s`
    declare -a updated_files

    if [ -n "$wpattern" ]; then
      # There are other files to watch, search for updated *.c files
      updated_files=($(find $wpattern -type f -iregex ".*\.c$" \
        -cnewer "$tmp_ctime_file"))

      if [ ${#updated_files[@]} -gt 0 ]; then
        clear ;
        for next_file in ${updated_files[@]}; do
          [ ! -f "$next_file" ] && break ;
          
          next_file_h="$(echo "$next_file" | perl -pe 's/(.*)\.c$/$1/i')"
          [ -z "$next_file_h" -o "$next_file" = "$filename.c" ] && break ;

          if compile_file "$next_file" "next_file_h"; then
            logger 1 "Compiled file: $next_file into $next_file_h"
          else
            logger 2 "Failed to compile: $next_file"
          fi
          unset next_file_h
        done
      fi
    fi

    # Check if file has been changed before compiling
    if [ $[$current_time] -lt $[$update_time] ]; then
      clear ;
      msg="${colors[green]}Updated File $filename.c at $(date +%c)"
      msg="${msg}${colors[reset]}"
      logger 1 "$msg"
      compile_and_run "$filename" "$outputname" "$input_command" "$compiler_flags"
    else
      logger 0 "Main file not updated since $current_time"
    fi

    # Update the time last checked for updates
    touch --time=modify "$tmp_ctime_file"
    unset updated_files
    sleep $watching
  done
 
  # Remove the time file
  rm "$tmp_ctime_file"
fi

