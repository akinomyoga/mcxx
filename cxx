#!/bin/bash

shopt -s extglob
source_if() { test -e "$1" && source "$@" >&2; }
mkd () { test -d "$1" || mkdir -p "$1"; }

function get_script_directory {
  if test "x$1" == x-v; then
    local _fscr="$3"
    [[ -h "$_fscr" ]] && _fscr="$(PATH=/bin:/usr/bin readlink -f "$_fscr")"

    local _dir
    if [[ $_fscr == */* ]]; then
      _dir="${_fscr%/*}"
    elif [[ -s $_fscr ]]; then
      _dir=.
    else
      _dir="$MWGDIR/mcxx" # 既定値
    fi

    eval "$2=\"\$_dir\""
  else
    local _value
    get_script_directory -v _value "$1"
    echo -n "$_value"
  fi
}

# MWGDIR/CXXDIR
if [[ ! $MWGDIR || ! -d $MWGDIR ]]; then
  [[ -d $HOME/.mwg ]] && MWGDIR="$HOME"/.mwg
fi
export MWGDIR

get_script_directory -v CXXDIR "${BASH_SOURCE:-$0}"
export CXXDIR

#------------------------------------------------------------------------------

mcxx_version=20111
mcxx_version_string="mcxx-2.1.11"

# read +argument
mcxx_arg_set=
mcxx_arg=
if [[ $1 == +?* ]]; then
  mcxx_arg="${1:1}"
  mcxx_arg_set=1
  shift
elif [[ $1 == mwg ]]; then
  mcxx_arg="$2"
  mcxx_arg_set=1
  shift 2
fi

if [[ $mcxx_arg_set ]]; then
  case "$mcxx_arg" in
  (help)
    source "$CXXDIR/cxx_help.sh"
    exit ;;
  (version)
    if [[ $1 ]]; then
      [[ $mcxx_version -ge $1 ]]
    else
      echo "$mcxx_version_string"
    fi
    exit ;;
  (prefix)
    if [[ $# -eq 0 || $1 == get ]]; then
      source "$CXXDIR/cxx_pref-get.sh"
      echo -n "$CXXPREFIX"
    else
      source "$CXXDIR/cxx_pref.sh" "$@"
    fi
    exit ;;
  (config|traits) # xtraits obsoleted
    source "$CXXDIR/cxx_pref-get.sh"
    if [[ "$1" == clean ]]; then
      rm -f "$CXXDIR2/cxx_conf"/*.stamp
      exit 0
    else
      source "$CXXDIR/cxx_conf.sh" "$@"
    fi
    exit ;;
  (make)
    source "$CXXDIR/cxx_make.sh" "$@"
    exit ;;
  (get|param) # xparam obsoleted
    source "$CXXDIR/cxx_pref-get.sh"
    case "$1" in
    (cxxdir)
      echo "$CXXDIR"
      exit ;;
    (env-source)
      echo "$CXXDIR2/config.src"
      exit ;;
    (input-charset)
      if [[ -f $CXXDIR2/input-charset.txt ]]; then
        cat "$CXXDIR2/input-charset.txt"
      elif [[ $SYSTEMROOT && $PROGRAMFILES && ${CXXPREFIX/*-cygwin-*/} ]]; then
        # windows
        echo -n cp932
      else
        echo -n utf-8
      fi
      exit ;;
    (paths)
      source "$CXXDIR2/config.src" cxx

      echo "PATH='$PATH'"
      test -n "$LIBRARY_PATH" && echo "LIBRARY_PATH='$LIBRARY_PATH'"
      test -n "$C_INCLUDE_PATH" && echo "C_INCLUDE_PATH='$C_INCLUDE_PATH'"
      test -n "$CPLUS_INCLUDE_PATH" && echo "CPLUS_INCLUDE_PATH='$CPLUS_INCLUDE_PATH'"
      test -n "$INCLUDE" && echo "INCLUDE='$INCLUDE'"
      test -n "$LIB" && echo "LIB='$LIB'"
      test -n "$LIBPATH" && echo "LIBPATH='$LIBPATH'"
      exit 0 ;;
    (*)
      echo "unknown parameter name '$1'" >&2
      exit 1 ;;
    esac ;;
  (*)
    echo "unknown command '+$mcxx_arg'" >&2
    exit 1 ;;
  esac
fi

# obsoleted function
if [[ $1 == --mwg-cxxprefix || $1 == --mwg-get-cxxprefix ]]; then
  source "$CXXDIR/cxx_pref-get.sh"
  echo "$CXXPREFIX"
  exit
fi

# CXXPREFIX/CXXDIR2
source "$CXXDIR/cxx_pref-get.sh"

FLAGS=''
if [[ $1 == -futf8 ]]; then
  shift
  CXX_ENCODING=utf-8
else
  if [[ ! $CXX_ENCODING ]]; then
    if [[ $OSTYPE == cygwin || $SYSTEMROOT && $PROGRAM_FILES ]]; then
      # windows
      CXX_ENCODING=CP932
    else
      CXX_ENCODING=utf-8
    fi
  fi
fi

#------------------------------------------------------------------------------

if [[ ! -s $CXXDIR2/config.src ]]; then
  echo "$0: settings for '$CXXPREFIX' is not found" >&2
  exit 1
fi
source "$CXXDIR2/config.src" cxx
#↑内部で更に "$CXXDIR/local/m/common.src" が source される @2013-10-25

[[ $# -eq 0 ]] && FLAGS=''

case "${0##*/}" in
(cc*|?cc*)
    $CC $FLAGS "$@"
    ;;
*)
    #echo $CXX $FLAGS "$@"
    $CXX $FLAGS "$@"
    ;;
esac
