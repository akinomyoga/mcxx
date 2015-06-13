#!/bin/bash

shopt -s extglob
source_if() { test -e "$1" && source "$@" >/dev/null; }
mkd () { test -d "$1" || mkdir -p "$1"; }

function get_script_directory {
  if test "x$1" == x-v; then
    local _fscr="$3"
    test -h "$_fscr" && _fscr="$(PATH=/bin:/usr/bin readlink -f "$_fscr")"

    local _dir="${_fscr%/*}"
    test "$_dir" == "$_fscr" && _dir="$MWGDIR/mcxx" # 既定値

    eval "$2=\"\$_dir\""
  else
    local _value
    get_script_directory -v _value "$1"
    echo -n "$_value"
  fi
}

# MWGDIR/CXXDIR
if test -n "$MWGDIR" -o ! -d "$MWGDIR"; then
  test -d $HOME/.mwg && MWGDIR=$HOME/.mwg
fi
export MWGDIR

get_script_directory -v CXXDIR "$0"
export CXXDIR

#------------------------------------------------------------------------------

mcxx_version=20110
mcxx_version_string="mcxx-2.1.10"

# read +argument
mcxx_arg=
if test "x${1:0:1}" == x+; then
  mcxx_arg="x${1:1}"
  shift
elif test "x$1" == xmwg; then
  mcxx_arg="x$2"
  shift 2
fi

if test -n "$mcxx_arg"; then
  case "$mcxx_arg" in
  (xhelp)
    source "$CXXDIR/cxx_help.sh"
    exit ;;
  (xversion)
    if test -n "$1"; then
      test $mcxx_version -ge "$1"
    else
      echo "$mcxx_version_string"
    fi
    exit ;;
  (xprefix)
    if test $# -eq 0; then
      source "$CXXDIR/cxx_pref-get.sh"
      echo -n "$CXXPREFIX"
    else
      "$CXXDIR/cxx_pref.sh" "$@"
    fi
    exit ;;
  (xconfig|xtraits) # xtraits obsoleted
    source "$CXXDIR/cxx_pref-get.sh"
    if [[ "$1" == clean ]]; then
      rm -f "$CXXDIR2/cxx_conf"/*.stamp
      exit 0
    else
      source "$CXXDIR/cxx_conf.sh" "$@"
    fi
    exit ;;
  (xmake)
    source "$CXXDIR/cxx_make.sh" "$@"
    exit ;;
  (xget|xparam) # xparam obsoleted
    source "$CXXDIR/cxx_pref-get.sh"
    case "$1" in
    cxxdir)
      echo "$CXXDIR"
      exit ;;
    env-source)
      echo "$CXXDIR2/config.src"
      exit ;;
    input-charset)
      if test -f "$CXXDIR2/input-charset.txt"; then
        cat "$CXXDIR2/input-charset.txt"
      elif test -n "$SYSTEMROOT" -a -n "$PROGRAMFILES" -a -n "${CXXPREFIX/*-cygwin-*/}"; then
        # windows
        echo -n cp932
      else
        echo -n utf-8
      fi
      exit ;;
    paths)
      source_if "$CXXDIR/local/m/common.src"
      source "$CXXDIR2/config.src" cxx

      echo "PATH='$PATH'"
      test -n "$LIBRARY_PATH" && echo "LIBRARY_PATH='$LIBRARY_PATH'"
      test -n "$C_INCLUDE_PATH" && echo "C_INCLUDE_PATH='$C_INCLUDE_PATH'"
      test -n "$CPLUS_INCLUDE_PATH" && echo "CPLUS_INCLUDE_PATH='$CPLUS_INCLUDE_PATH'"
      test -n "$INCLUDE" && echo "INCLUDE='$INCLUDE'"
      test -n "$LIB" && echo "LIB='$LIB'"
      test -n "$LIBPATH" && echo "LIBPATH='$LIBPATH'"
      exit 0 ;;
    *)
      echo "unknown parameter name '$1'" >&2
      exit 1 ;;
    esac ;;
  (*)
    echo "unknown command '+${mcxx_arg:1}'" >/dev/stderr
    exit 1 ;;
  esac
fi

# obsoleted function
if test "x$1" == x--mwg-cxxprefix -o "x$1" == x--mwg-get-cxxprefix; then
  source "$CXXDIR/cxx_pref-get.sh"
  echo "$CXXPREFIX"
  exit
fi

# CXXPREFIX/CXXDIR2
source "$CXXDIR/cxx_pref-get.sh"

FLAGS=''
if test "x$1" == x-futf8; then
  shift
  CXX_ENCODING=utf-8
else
  if test -z "$CXX_ENCODING"; then
    if test -n "SYSTEMROOT" -a -n "$PROGRAM_FILES"; then
      # windows
      CXX_ENCODING=CP932
    else
      CXX_ENCODING=utf-8
    fi
  fi
fi

#------------------------------------------------------------------------------

if test ! -s "$CXXDIR2/config.src"; then
  echo "$0: settings for '$CXXPREFIX' is not found" >/dev/stderr
  exit 1
fi
source "$CXXDIR2/config.src" cxx
#↑内部で更に "$CXXDIR/local/m/common.src" が source される @2013-10-25

test "$#" -eq 0 && FLAGS=''

case "${0##*/}" in
@(cc|?cc)*)
    $CC $FLAGS "$@"
    ;;
*)
    #echo $CXX $FLAGS "$@"
    $CXX $FLAGS "$@"
    ;;
esac
