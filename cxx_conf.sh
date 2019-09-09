#!/bin/bash

# usage
#   source cxx_conf.sh <test.cfg> <cxx_conf.h>
# require
#   function mkd
#   declare CXXDIR2
#   declare CXX

#------------------------------------------------------------------------------
# init lib

source "$CXXDIR/ext/echox" --color=none
mshex_echox_prog="mcxx($CXXDIR) +config"

function cxx/config/help {
  local bold=$'\e[1m=\e[m'
  local ul=$'\e[4m=\e[24m'
  local cyan=$'\e[36m=\e[39m'
  source "$CXXDIR/ext/ifold" -s --indent='( |[-*] )+' -w 80 <<EOF

usage: cxx +${bold/=/config} [${cyan/=/OPTIONS}...] ${cyan/=/SCRIPTFILE}...

  Generate a header file with various compiler tests. \
This command can be used to generate a header like ${ul/=/config.h}. \
The results of the compiler tests are cached for each compiler setting to reduce the test time.

${cyan/=/OPTIONS}

  ${bold/=/--help}
    Show this help and exit.

  ${bold/=/-o ${cyan/=/FILE}}
    Specify the output header file name. The default output file is determined using the first ${cyan/=/SCRIPTFILE} argument.

  ${bold/=/--cache=${cyan/=/CACHEDIR}}
    Specify the directory to save the results of the compiler tests.

  ${bold/=/--log=${cyan/=/LOGFILE}}
    Specify the log file for the output of the compiler tests.

  ${bold/=/--}
    This option indicates that that the later arguments are treated as options for the compiler.

${cyan/=/SCRIPTFILE}

  The input file, ${cyan/=/SCRIPTFILE}, is a GNU Bash Script to generate the content of the output header file. \
In this script file, the following special commands can be used to output the content of the output header. \
Some commands perform compiler tests to output the corresponding \`${ul/=/#define}'s. \
If multiple ${cyan/=/SCRIPTFILE}s are specified, the scripts are executed via ${ul/=/source} command in order.

  == Special Commands ==

  P ${cyan/=/line}
    Output ${cyan/=/line} to the output header.

  D ${cyan/=/MACRO} [${cyan/=/value}]
    Define or undefine the specified macro.
    * ${cyan/=/MACRO} = the name of the macro to be defined.
    * ${cyan/=/value} = the value of the macro. If this is omitted, the macro will be undefined.

  H ${cyan/=/foobar.h} [${cyan/=/MWGCONF_HEADER_FOOBAR_H}]
    Test if the specified headers are available or not.
    * ${cyan/=/foobar.h} = include file to check its existence
    * ${cyan/=/MWGCONF_HEADER_FOOBAR_H}
      = macro defined when ${cyan/=/foobar.h} exists.
      The default value is "${ul/=/MWGCONF_HEADER_${cyan/=/FOOBAR_H}}".

  M ${cyan/=/name} ${cyan/=/headers} ${cyan/=/macro}
    Test if the specified macro is defined or not.
    * ${cyan/=/name} = name of the test.
    * ${cyan/=/headers} = headers to include separated with spaces.
    * ${cyan/=/macro} = macro name to test.
    MWGCONF_${cyan/=/NAME} will be defined when the expression is valid.

  X ${cyan/=/name} ${cyan/=/headers} ${cyan/=/expression}
    Test if the expression is valid or not.
    * ${cyan/=/name} = name of the test.
    * ${cyan/=/headers} = headers to include separated with spaces.
    * ${cyan/=/expression} = expression to test.
    MWGCONF_HAS_${cyan/=/NAME} will be defined when the expression is valid.

  S ${cyan/=/name} ${cyan/=/headers} ${cyan/=/source}
    Test if the code is valid or not.
    * ${cyan/=/name} = name of the test.
    * ${cyan/=/headers} = headers to include separated with spaces.
    * ${cyan/=/source} = C++ source code to test.
    MWGCONF_${cyan/=/NAME} will be defined when the expression is valid.

EOF
  return
}

#------------------------------------------------------------------------------

fname_input=()
fname_output=
CACHEDIR=
FLOG=
arg_cxx_options=()
function arg_set_output {
  if [[ ! $1 ]]; then
    echoe "the specified output filename is empty."
    exit 1
  elif [[ $fname_output ]]; then
    echoe "The output filename '$fname_output' is overwritten by '$1'."
  fi

  fname_output="$1"
}
function arg_add_input {
  if [[ ! $1 ]]; then
    echoe "the specified input filename is empty."
    exit 1
  elif [[ ! -f $1 ]]; then
    echoe "the specified input file does not exist."
    exit 1
  fi

  fname_input[${#fname_input[@]}]="$1"
}
function arg_set_cachedir {
  if [[ ! $1 ]]; then
    echoe "The specified cache directory name is empty."
    exit 1
  elif [[ $CACHEDIR ]]; then
    echoe "The cache directory name '$CACHEDIR' is overwritten by '$1'."
  fi

  CACHEDIR=$1
}
function arg_set_logfile {
  if [[ ! $1 ]]; then
    echoe "The specified log file name is empty."
    exit 1
  elif [[ $FLOG ]]; then
    echoe "The log file name '$FLOG' is overwritten by '$1'."
  fi

  FLOG="$1"
}

fERROR=
fDONE=
while (($#)); do
  arg="$1"
  shift
  if [[ $arg == -* ]]; then
    case "$arg" in
    (-o)        arg_set_output "$1"; shift ;;
    (-o*)       arg_set_output "${arg:2}"  ;;
    (--cache=*) arg_set_cachedir "${arg#--cache=}" ;;
    (--log=*)   arg_set_logfile "${arg#--log=}" ;;
    (--)        arg_cxx_options+=("$@"); break ;;
    (--help)    cxx/config/help; fDONE=1 ;;
    (*)         echoe "Unrecognized option '$arg'."; fERROR=1 ;;
    esac
  else
    arg_add_input "$arg"
  fi
done

[[ $fDONE ]] && return
[[ $fERROR ]] && exit 1

: ${CACHEDIR:="$CXXDIR2/cxx_conf"}
: ${FLOG:="$CXXDIR2/cxx_conf.log"}

if [[ ${#fname_input[@]} -eq 0 ]]; then
  fname_input_default=config.sh
  if [[ -f $fname_input_default ]]; then
    echom "The intut file is not specified. Instead, the file $fname_input_default is used."
    arg_add_input "$fname_input_default"
  else
    echoe "The input file is not specified. The default file $fname_input_default is not a valid file."
    exit 1
  fi
fi

if [[ ! $fname_output ]]; then
  fname_output="${fname_input%.in}"
  fname_output="${fname_output%.sh}"
  fname_output="${fname_output%.h}.h"
  if [[ "$fname_input" == "$fname_output" ]]; then
    fname_output="${fname_output%.h}.out.h"
  fi
fi

if [[ $fname_output == ?*/* && ! -d ${fname_output%/*} ]]; then
  echoe "the directory of the output file '$fname_output' does not exist."
  exit 1
fi

# if (($#!=1&&$#!=2)); then
#   echo "usage: $0 +config <input> [<output>]" >&2
#   exit 1
# fi
# fname_input="${1-config.sh}"
# fname_output="$2"
# if [[ ! -f $fname_input ]]; then
#   if test $# -eq 0; then
#     echoe "input files are not specified, and the default file '$fname_input' is not a valid file."
#   else
#     echoe "the specified file '$fname_input' is not a valid file."
#   fi
#   exit 1
# fi
# if [[ ! $fname_output ]]; then
#   fname_output="${fname_input%.in}"
#   fname_output="${fname_output%.sh}"
#   fname_output="${fname_output%.h}.h"
#   # while test -e "$fname_output"; do
#   #   fname_output="${fname_output%.h}+.h"
#   # done
#   if test "$fname_input" == "$fname_output"; then
#     fname_output="${fname_output%.h}.out.h"
#   fi
# fi

#------------------------------------------------------------------------------
# setup mconf

source "$CXXDIR/mconf.sh"
mconf_cxx_options=("${arg_cxx_options[@]}")
mconf_flags=lcosh
mconf_cxx=$CXXDIR/cxx
mconf_cache_dir=$CACHEDIR

# setup header
if [[ $fname_output == /dev/stderr ]]; then
  exec 5>&2
elif [[ $fname_output == /dev/stdout || $fname_output == - ]]; then
  exec 5>&1 1>&2
elif [[ $fname_output =~ ^/dev/fd/[0-9]+$ ]]; then
  exec 5>&${fname_output#/dev/fd/}
elif [[ -f $fname_output || ! -e $fname_output ]]; then
  exec 5>"$fname_output.part"
  fname_output_flag_part=1
else
  exec 5>"$fname_output"
fi

# setup logfile
exec 6>>"$FLOG"

#------------------------------------------------------------------------------
# execute

function P { mconf/header/print "$@"; }
function D { mconf/header/define "$@"; }
function H { mconf/test/header "$@"; }
function M { mconf/test/macro "$@"; }
function X { mconf/test/expression "$@"; }
function S { mconf/test/source "$@"; }
#function N { mconf/test/named "$@"; }

# ※ ./ をつけないと /usr/bin の中のコマンドなどを source してしまう。
[[ $fname_input != /* ]] && fname_input="./$fname_input"

source "$fname_input" || return

if [[ $fname_output_flag_part ]]; then
  mv -f "$fname_output.part" "$fname_output"
fi
