#!/bin/bash

#------------------------------------------------------------------------------
# utils

function source_if { test -e "$1" && source "$@" >&2; }
function mkd { test -d "$1" || mkdir -p "$1"; }
function mcxx/util/readfile {
  IFS= read -r -d '' "$1" < "$2"
  eval "$1=\"\${$1%\$'\n'}\""
}

# from mshex/functions/hdirname.sh

# readlink -f
function hdirname/readlink {
  local path="$1"
  case "$OSTYPE" in
  (cygwin|linux-gnu)
    # 少なくとも cygwin, GNU/Linux では readlink -f が使える
    PATH=/bin:/usr/bin readlink -f "$path" ;;
  (darwin*|*)
    # Mac OSX には readlink -f がない。
    local PWD="$PWD" OLDPWD="$OLDPWD"
    while [[ -h $path ]]; do
      local link="$(PATH=/bin:/usr/bin readlink "$path" || true)"
      [[ $link ]] || break

      if [[ $link = /* || $path != */* ]]; then
        # * $link ~ 絶対パス の時
        # * $link ~ 相対パス かつ ( $path が現在のディレクトリにある ) の時
        path="$link"
      else
        local dir="${path%/*}"
        path="${dir%/}/$link"
      fi
    done
    echo -n "$path" ;;
  esac
}

## @fn hdirname/impl file defaultValue
## @param[in] file
## @param[in] defaultValue
## @var[out] _ret
function hdirname {
  if [[ $1 == -v ]]; then
    # hdirname -v var file defaultValue
    eval '
      '$2'="$3"
      [[ -h ${'$2'} ]] && '$2'=$(hdirname/readlink "${'$2'}")

      if [[ ${'$2'} == */* ]]; then
        '$2'="${'$2'%/*}"
        : "${'$2':=/}"
      else
        '$2'="${4-$PWD}"
      fi
    '
  elif [[ $1 == -v* ]]; then
    hdirname -v "${1:2}" "${@:2}"
  else
    local ret
    hdirname -v ret "$@"
    echo -n "$ret"
  fi
}

#------------------------------------------------------------------------------
# script directory

shopt -s extglob

# MWGDIR/CXXDIR
if [[ ! $MWGDIR || ! -d $MWGDIR ]]; then
  [[ -d $HOME/.mwg ]] && MWGDIR="$HOME/.mwg"
fi
export MWGDIR

hdirname -v CXXDIR "${BASH_SOURCE:-$0}" "$MWGDIR/share/mcxx"
export CXXDIR

#------------------------------------------------------------------------------

function CXXPREFIX.initialize {
  source "$CXXDIR/cxx_pref-get.sh"
  function CXXPREFIX.initialize { :; }
}
function CXX_ENCODING.initialize {
  CXXPREFIX.initialize

  if [[ -f $CXXDIR2/input-charset.txt ]]; then
    CXX_ENCODING=
    mcxx/util/readfile CXX_ENCODING "$CXXDIR2/input-charset.txt"
    [[ $CXX_ENCODING ]] && return
  fi

  if [[ $SYSTEMROOT && $PROGRAMFILES && $CXXPREFIX != *-cygwin-* ]]; then
    # windows
    CXX_ENCODING=cp932
    # CXX_ENCODING=CP932
  else
    CXX_ENCODING=utf-8
  fi

  function CXX_ENCODING.initialize { :; }
}
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
      CXXPREFIX.initialize
      echo -n "$CXXPREFIX"
    else
      source "$CXXDIR/cxx_pref.sh" "$@"
    fi
    exit ;;
  (config|traits) # xtraits obsoleted
    CXXPREFIX.initialize
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
    case "$1" in
    (cxxdir)
      echo "$CXXDIR"
      exit ;;
    (env-source)
      CXXPREFIX.initialize
      echo "$CXXDIR2/config.src"
      exit ;;
    (input-charset)
      CXX_ENCODING.initialize
      echo "$CXX_ENCODING"
      exit ;;
    (paths)
      CXXPREFIX.initialize
      source "$CXXDIR2/config.src" cxx
      echo "PATH='$PATH'"
      test -n "$LIBRARY_PATH" && echo "LIBRARY_PATH='$LIBRARY_PATH'"
      test -n "$C_INCLUDE_PATH" && echo "C_INCLUDE_PATH='$C_INCLUDE_PATH'"
      test -n "$CPLUS_INCLUDE_PATH" && echo "CPLUS_INCLUDE_PATH='$CPLUS_INCLUDE_PATH'"
      test -n "$INCLUDE" && echo "INCLUDE='$INCLUDE'"
      test -n "$LIB" && echo "LIB='$LIB'"
      test -n "$LIBPATH" && echo "LIBPATH='$LIBPATH'" ;;
    (--eval)
      CXXPREFIX.initialize
      CXX_ENCODING.initialize
      source "$CXXDIR2/config.src" cxx

      declare result
      IFS= eval "result=(${@:2})"
      echo "${result[*]}" ;;
    (*)
      echo "unknown parameter name '$1'" >&2
      exit 1 ;;
    esac
    exit 0 ;;
  (*)
    echo "unknown command '+$mcxx_arg'" >&2
    exit 1 ;;
  esac
fi

# obsoleted function
if [[ $1 == --mwg-cxxprefix || $1 == --mwg-get-cxxprefix ]]; then
  CXXPREFIX.initialize
  echo -n "$CXXPREFIX"
  exit
fi

# CXXPREFIX/CXXDIR2
CXXPREFIX.initialize

FLAGS=''
if [[ $1 == -futf8 ]]; then
  shift
  CXX_ENCODING=utf-8
else
  if [[ ! $CXX_ENCODING ]]; then
    CXX_ENCODING.initialize
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
