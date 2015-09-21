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
mwg_echox_prog="mcxx($CXXDIR) +config"

if test -t 1; then
  if test -s "$MWGDIR/share/mshex/shrc/mwg_term.sh"; then
    source "$MWGDIR/share/mshex/shrc/mwg_term.sh"
    mwg_term.set t_sgr34 fDB
    mwg_term.set t_sgr35 fDM
    mwg_term.set t_sgr94 fHB
    mwg_term.set t_sgr95 fHM
    mwg_term.set t_sgr0  sgr0
  elif type tput &>/dev/null; then
    t_sgr34="$(tput setaf 4)"
    t_sgr35="$(tput setaf 5)"
    t_sgr94="$(tput setaf 12)"
    t_sgr95="$(tput setaf 13)"
    t_sgr0="$(tput sgr0)"
  else
    t_sgr34='[34m'
    t_sgr35='[35m'
    t_sgr94='[94m'
    t_sgr95='[95m'
    t_sgr0='[m'
  fi
fi

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

CompilerOptions=()
fname_input=()
fname_output=
CACHEDIR=
FLOG=
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

  CACHEDIR="$1"
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
    (--)        CompilerOptions+=("$@"); break ;;
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

msg_ok="${t_sgr94}ok${t_sgr0}"
msg_missing="${t_sgr95}missing${t_sgr0}"
msg_invalid="${t_sgr95}invalid${t_sgr0}"

#------------------------------------------------------------------------------
# output

mkd "$CACHEDIR"

if [[ $fname_output == /dev/stderr ]]; then
  fdout=2
elif [[ $fname_output == /dev/stdout || $fname_output == - ]]; then
  fdout=5
  exec 5>&1 1>&2
elif [[ $fname_output =~ ^/dev/fd/[0-9]+$ ]]; then
  fdout="${fname_output#/dev/fd/}"
else
  #exec {fdout}>"$fname_output" # bash-4.1
  fdout=5; exec 5>"$fname_output.part"
  fname_output_flag_part=1
fi
fdout.print() {
  echo "$*" >&$fdout
}
fdout.define () {
  local name="$1"
  if test -n "$2"; then
    echo "#undef $name"        >&$fdout
    echo "#define $name $2"    >&$fdout
    echo                       >&$fdout
  else
    echo "#undef $name"        >&$fdout
    echo "/* #define $name */" >&$fdout
    echo                       >&$fdout
  fi
}
function P { fdout.print "$@"; }
function D { fdout.define "$@"; }

#exec {fdlog}>>"$FLOG" # bash-4.1
fdlog=6; exec 6>>"$FLOG"
fdlog.print_title() {
  {
    echo '-------------------------------------------------------------------------------'
    echo "$*"
    echo
  } >&$fdlog
}

#------------------------------------------------------------------------------
# utils
declare -i mwg_bash='BASH_VERSINFO[0]*10000+BASH_VERSINFO[1]*100+BASH_VERSINFO[2]'
if ((mwg_bash>=40100)); then
  declare -A mwg_char_table
  function mwg_char.get {
    local c="${1::1}"
    mwg_char=${mwg_char_table[x$c]}
    [[ $mwg_char ]] && return

    printf -v mwg_char '%d' "'$c"

    mwg_char_table[x$c]="$mwg_char"
  }
else
  declare mwg_char_table
  function mwg_char_table.init {
    local table00=$'\x3f\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f'
    local table01=$'\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f'
    local table02=$'\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2a\x2b\x2c\x2d\x2e\x2f'
    local table03=$'\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3a\x3b\x3c\x3d\x3e\x3f'
    local table04=$'\x40\x41\x42\x43\x44\x45\x46\x47\x48\x49\x4a\x4b\x4c\x4d\x4e\x4f'
    local table05=$'\x50\x51\x52\x53\x54\x55\x56\x57\x58\x59\x5a\x5b\x5c\x5d\x5e\x5f'
    local table06=$'\x60\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6a\x6b\x6c\x6d\x6e\x6f'
    local table07=$'\x70\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7a\x7b\x7c\x7d\x7e\x7f'
    local table08=$'\x80\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c\x8d\x8e\x8f'
    local table09=$'\x90\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9a\x9b\x9c\x9d\x9e\x9f'
    local table0a=$'\xa0\xa1\xa2\xa3\xa4\xa5\xa6\xa7\xa8\xa9\xaa\xab\xac\xad\xae\xaf'
    local table0b=$'\xb0\xb1\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xbb\xbc\xbd\xbe\xbf'
    local table0c=$'\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce\xcf'
    local table0d=$'\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xd7\xd8\xd9\xda\xdb\xdc\xdd\xde\xdf'
    local table0e=$'\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee\xef'
    local table0f=$'\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xff'
    mwg_char_table="$table00$table01$table02$table03$table04$table05$table06$table07$table08$table09$table0a$table0b$table0c$table0d$table0e$table0f"
  }
  mwg_char_table.init

  declare -i mwg_char
  function mwg_char.get {
    local c="${1::1}"
    if [[ $c == '?' ]]; then
      mwg_char=63
    elif [[ $c == '*' ]]; then
      mwg_char=42
    else
      local tmp="${mwg_char_table%%$c*}"
      mwg_char="${#tmp}"
    fi
  }
fi

# declare mwg_char_hex
# mwg_char_hex.get() {
#   local -i n="$1"
#   local hi=$((n/16))
#   local lo=$((n%16))

#   case "$hi" in
#   10) hi=a ;;
#   11) hi=b ;;
#   12) hi=c ;;
#   13) hi=d ;;
#   14) hi=e ;;
#   15) hi=f ;;
#   esac
#   case "$lo" in
#   10) lo=a ;;
#   11) lo=b ;;
#   12) lo=c ;;
#   13) lo=d ;;
#   14) lo=e ;;
#   15) lo=f ;;
#   esac
#   mwg_char_hex="$hi$lo"
# }

# mwg.hex() {
#   local text="$*"
#   local code=

#   local i
#   for((i=0;i<${#text};i++));do
#     mwg_char.get "${text:$i:1}"
#     mwg_char_hex.get "$mwg_char"
#     code="$code$mwg_char_hex"
#   done

#   echo "$code"
# }

#mwg_base64_table='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
mwg_base64_table='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+%'
mwg.base64.set() {
  local varname="$1"; shift
  local text="$*" i j s
  local code=
  for((i=0;i<${#text};i+=3)); do
    local cook="${text:$i:3}"

    let s=0
    for((j=0;j<3;j++));do
      mwg_char.get "${cook:$j:1}"
      let s=s*256+mwg_char
    done

    local quartet=
    for((j=3;j>=0;j--));do
      if test $j -gt ${#cook}; then
        quartet="=$quartet"
      else
        quartet="${mwg_base64_table:$((s%64)):1}$quartet"
      fi
      let s/=64
    done

    code="$code$quartet"
  done

  eval "$varname='$code'"
}

if ((mwg_bash>=40100)); then
  function mwg.uppercase.set {
    local varname="$1" ; shift
    eval "$varname='${*^^?}'"
  }
else
  function mwg.uppercase.set {
    local varname="$1" ; shift
    eval "$varname='$(echo -n "$*"|tr a-z A-Z)'"
  }
fi

if [[ $COMSPEC && -x $COMSPEC ]]; then
  # for slow forks in Windows
  # 0.522s in linux

  # @var[out] _var
  # @var[out] _ret
  function mcxx.hash/impl {
    # 1 read arguments
    local hlen=
    while [[ $1 == -* ]]; do
      local arg="$1"; shift
      case "$arg" in
      (-v)  _var="$1"; shift ;;
      (-v*) _var="${arg:2}"  ;;
      (-l)  hlen="$1"; shift ;;
      (-l*) hlen="${arg:2}"  ;;
      (*)   break ;;
      esac
    done

    # 2. text to char array
    local text="$*"
    local tlen="${#text}"
    (((!hlen||hlen>tlen)&&(hlen=tlen)))
    local i data
    data=()
    for((i=0;i<tlen;i++)); do
      mwg_char.get "${text:i:1}"
      ((data[i%hlen]+=mwg_char))
    done

    # 3. base64 encoding
    local i _j _s quartet buff
    buff=()
    for((i=0;i<hlen;i+=3)); do
      ((_s=data[i]<<16&0xFF0000|data[i+1]<<8&0xFF00|data[i+2]&0xFF))

      quartet=
      for((_j=3;_j>=0;_j--));do
        if ((i+_j>hlen)); then
          quartet="=$quartet"
        else
          quartet="${mwg_base64_table:_s%64:1}$quartet"
        fi
        ((_s/=64))
      done

      buff[${#buff[@]}]="$quartet"
    done

    IFS= eval '_ret="${buff[*]}"'
  }

  function mcxx.hash {
    local _var= _ret
    mcxx.hash/impl "$@"
    if [[ $_var ]]; then
      eval "$_var=\"\$_ret\""
    else
      echo "$_ret"
    fi
  }
else
  function mcxx.hash {
    local _var _len
    while [[ $1 == -* ]]; do
      local arg="$1"; shift
      case "$arg" in
      (-v)  _var="$1"; shift ;;
      (-v*) _var="${arg:2}"  ;;
      (-v)  _len="$1"; shift ;;
      (-v*) _len="${arg:2}"  ;;
      (*)   break ;;
      esac
    done

    local _ret="$(echo -n "$*"|md5sum)"
    _ret="${_ret//[   -]}"

    if [[ $_var ]]; then
      eval "$_var=\"\$_ret\""
    else
      echo "$_ret"
    fi
  }
fi

#------------------------------------------------------------------------------
# simple check

comp_test() {
  fdlog.print_title "$*"
  $CXXDIR/cxx -c -xc++ - -o tmp.o "${CompilerOptions[@]}" 1>&$fdlog 2>&$fdlog
  r=$?

  rm -f tmp.o tmp.obj
  return $r
}

# \env[in] param_cachename
# \env[in] param_log_title
# \env[in] param_msg_title
# \env[in] param_cmd_code
comp_test_cached() {
  local cache="$CACHEDIR/$param_cachename.stamp"
  local result=''

  local message_head='  checking'

  if test -e "$cache"; then
    if test -s "$cache"; then
      result='+'
      echo "$message_head $param_msg_title ... ${m_ok:-$msg_ok} (cached)"
    else
      echo "$message_head $param_msg_title ... ${m_ng:-$msg_invalid} (cached)"
    fi
  else
    echo -n "$message_head $param_msg_title ... "
    if $param_cmd_code | comp_test "$param_log_title"; then
      result='+'
      echo "${m_ok:-$msg_ok}"
      echo -n '+' > "$cache"
    else
      echo "${m_ng:-$msg_invalid}"
      :>"$cache"
      {
        echo "compiler options: ${CompilerOptions[@]}"
        $param_cmd_code | sed 's/^/| /'
      } >&$fdlog
    fi
  fi

  test -n "$result"
}

#------------------------------------------------------------------------------
# header

test_header.code() {
  echo "#include <$header>"
}

## @var[in] title
test_header_cached () {
  local header="$1"

  local SL='/'
  local name="${header//$SL/%}"
  local param_cachename="H+$name"
  local param_log_title="test_header $header"
  local param_msg_title="(H) $t_sgr35${title:-#include <$header>}$t_sgr0"
  local param_cmd_code=test_header.code
  local m_ng="$msg_missing"
  comp_test_cached
}

function H {
  # read arguments
  local header= dname= title=
  while (($#)); do
    local arg="$1"
    shift
    case "$arg" in
    (-o?*) dname="${arg:2}"   ;;
    (-o)   dname="$1"; shift  ;;
    (-t?*) title="${arg:2}"  ;;
    (-t)   title="$1"; shift ;;
    (*)
      if [[ ! $header ]]; then
        header="$arg"
      elif [[ ! $dname ]]; then
        dname="$arg"
      else
        echoe "H: ignored argument '$arg'."
      fi ;;
    esac
  done

  if [[ ! $header ]]; then
    echoe 'H: no header is specified.'
    return 1
  fi

  if [[ $dname ]]; then
    dname="${dname//[^0-9a-zA-Z/_]}"
  else
    mwg.uppercase.set dname "MWGCONF_HEADER_${header//[^0-9a-zA-Z]/_}"
  fi

  local r=''
  test_header_cached "$header" && r=1
  fdout.define "$dname" "$r"
  eval "$dname=$r"
  test -n "$r"
}

#------------------------------------------------------------------------------
# macro

test_macro.code() {
  for h in $headers; do
    echo "#include <$h>"
  done
  cat <<EOF
int main(){
#ifdef $macro
  return 0;
#else
  __choke__ /* macro is not defined! */
#endif
}
EOF
}

test_macro_cached () {
  local name="$1"
  local headers="$2"
  local macro="$3"

  local enc_head; mwg.base64.set enc_head $headers
  local param_cachename="M-$enc_head-$macro"
  local param_log_title="test_macro $macro"
  local param_msg_title="(M) $t_sgr35#define $macro$t_sgr0"
  local param_cmd_code=test_macro.code
  local m_ng="$msg_missing"
  comp_test_cached
}

function M {
  local def_name; mwg.uppercase.set def_name "MWGCONF_${1//[^0-9a-zA-Z]/_}"
  local headers="$2"
  local macro="$3"

  local r=''
  test_macro_cached "$@" && r=1
  fdout.define "$def_name" "$r"
  eval "$def_name=$r"
  test -n "$r"
}

#------------------------------------------------------------------------------
# expr

test_expression.code() {
  local h
  for h in "${headers[@]}"; do
    echo "#include <$h>"
  done
  echo "void f(){$expression;}"
}

## @var[in] title
## @var[in] headers=(...)
## @var[in] expression
test_expression_cached () {
  local enc_head enc_expr
  mcxx.hash -venc_head -l64 "${headers[*]}"
  mcxx.hash -venc_expr -l64 "$expression"

  local param_cachename="X-$enc_head-$enc_expr"
  local param_log_title="test_expression $header $expression"
  local param_msg_title="(X) $t_sgr35$title$t_sgr0"
  local param_cmd_code=test_expression.code
  comp_test_cached
}

function X {
  # read arguments
  local dname= expression= title=
  local fAbsoluteName= fSetName= fSetHeader=
  local -a headers
  headers=()
  while (($#)); do
    local arg="$1"
    shift
    case "$arg" in
    (-o?*) fAbsoluteName=1 fSetName=1 dname="${arg:2}"   ;;
    (-o)   fAbsoluteName=1 fSetName=1 dname="$1"; shift  ;;
    (-t?*) title="${arg:2}"  ;;
    (-t)   title="$1"; shift ;;
    (-h?*) fSetHeader=1 headers+=("${arg:2}")  ;;
    (-h*)  fSetHeader=1 headers+=("$1"); shift ;;
    (*)
      if [[ ! $fSetName ]]; then
        fSetName=1 dname="$arg"
      elif [[ ! $fSetHeader ]]; then
        fSetHeader=1 headers+=($arg)
      elif [[ ! $expression ]]; then
        expression="$arg"
      else
        echoe "X: ignored argument '$arg'."
      fi ;;
    esac
  done

  : "${title:="${dname:-"$expression"}"}"

  if [[ ! $dname || $dname == - ]]; then
    dname=
  elif [[ ! $fAbsoluteName ]]; then
    mwg.uppercase.set dname "${dname//[^0-9a-zA-Z]/_}"
    [[ "$dname" =~ ^MWGCONF_ ]] || dname="MWGCONF_HAS_$dname"
  else
    dname="${dname//[^0-9a-zA-Z]/_}"
  fi

  if [[ ! $expression ]]; then
    echoe 'X: expression is not specified!'
    return 1
  fi

  local r=
  test_expression_cached && r=1
  if [[ $dname ]]; then
    fdout.define "$dname" "$r"
    eval "$dname=$r"
  fi
  test -n "$r"
}

#------------------------------------------------------------------------------
# source

test_source.code() {
  local h
  for h in "${headers[@]}"; do
    echo "#include <$h>"
  done
  echo "$source"
}

## @var[in] title
## @var[in] headers=(...)
## @var[in] source
test_source_cached() {
  local enc_head enc_expr
  mcxx.hash -venc_head -l64 "${headers[*]}"
  mcxx.hash -venc_expr -l64 "$source"

  local param_cachename="S-$enc_head-$enc_expr"
  local param_log_title="test_source $headers $source"
  local param_msg_title="(S) $t_sgr35${title}$t_sgr0"
  local param_cmd_code=test_source.code
  comp_test_cached
}

function S {
  # read arguments
  local dname= source= title=
  local fAbsoluteName= fSetName= fSetHeader=
  local -a headers
  headers=()
  while (($#)); do
    local arg="$1"
    shift
    case "$arg" in
    (-o?*) fAbsoluteName=1 fSetName=1 dname="${arg:2}"   ;;
    (-o)   fAbsoluteName=1 fSetName=1 dname="$1"; shift  ;;
    (-t?*) title="${arg:2}"  ;;
    (-t)   title="$1"; shift ;;
    (-h?*) fSetHeader=1 headers+=("${arg:2}")  ;;
    (-h*)  fSetHeader=1 headers+=("$1"); shift ;;
    (*)
      if [[ ! $fSetName ]]; then
        fSetName=1 dname="$arg"
      elif [[ ! $fSetHeader ]]; then
        fSetHeader=1 headers+=($arg)
      elif [[ ! $source ]]; then
        source="$arg"
      else
        echoe "X: ignored argument '$arg'."
      fi ;;
    esac
  done

  : "${title:="${dname:-"$source"}"}"

  if [[ ! $fAbsoluteName ]]; then
    mwg.uppercase.set dname "${dname//[^0-9a-zA-Z]/_}"
    [[ "$dname" =~ ^MWGCONF_ ]] || dname="MWGCONF_$dname"
  else
    dname="${dname//[^0-9a-zA-Z]/_}"
  fi

  if [[ ! $source ]]; then
    echoe 'X: source is not specified!'
    return 1
  fi

  local r=''
  test_source_cached && r=1
  if [[ $dname ]]; then
    fdout.define "$dname" "$r"
    eval "$dname=$r"
  fi
  test -n "$r"
}

#------------------------------------------------------------------------------
# test named

# test_named.code() {
#   for h in $headers; do
#     echo "#include <$h>"
#   done
#   echo "$source"
# }

# test_source_cached() {
#   local name="$1"
#   local headers="$2"
#   local source="$3"

#   local enc_head; mwg.base64.set enc_head $headers
#   local enc_expr; mwg.base64.set enc_expr "$source"

#   local param_cachename="S-$enc_head-$enc_expr"
#   local param_log_title="test_source $headers $source"
#   local param_msg_title="test_source $t_sgr35$name$t_sgr0"
#   local param_cmd_code=test_source.code
#   comp_test_cached
# }

# function N {
#   local name="$1"
#   local def_name; mwg.uppercase.set def_name "MWGCONF_${1//[^0-9a-zA-Z]/_}"
#   local headers="$2"
#   local source="$3"

#   local r=''
#   test_source_cached "$@" && r=1
#   if test ${#name} -gt 0; then
#     fdout.define "$def_name" "$r"
#     eval "$def_name=$r"
#   fi
#   test -n "$r"
# }

#------------------------------------------------------------------------------
# execute

# ※ ./ をつけないと /usr/bin の中のコマンドなどを source してしまう。
test -z "${fname_input##/*}" || fname_input="./$fname_input"

source "$fname_input"
if [[ $fname_output_flag_part ]]; then
  mv -f "$fname_output.part" "$fname_output"
fi
