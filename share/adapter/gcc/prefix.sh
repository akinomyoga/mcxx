#!/bin/bash
# to be sourced from mcxx/cxx_pref.sh

# include guard
declare -f gcc.initialized &>/dev/null && return
function gcc.initialized { echo; }

#------------------------------------------------------------------------------
# detect-compilers

gcc/search-compiler-from-path () {
  local m_cxx="$1"
  local m_cc="$2"

  local CXX="$(type -p "$1" 2>/dev/null)"
  test -z "$CXX" && return 1

  local CC="$(type -p "$2" 2>/dev/null)"
  test -z "$CC" && CC="$CXX"

  COMPILERS+=("$CXX:$CC")
}

function gcc.detect-compilers {
  # icc (Intel C/C++ Compiler): icpc
  gcc/search-compiler-from-path icpc icc

  # gcc (GNU Compiler Collection): g++*
  local CXX
  while read CXX; do
    [[ "$CXX" =~ ~$ ]] && continue # skip backup files
    gcc/search-compiler-from-path "$CXX" "gcc${CXX#g++}"
  done < <(compgen -c g++ | sort -u)

  # g++ を含むコマンドを全て列挙する方法... *-g++
  # IFS=: eval 'find $PATH -maxdepth 1 -name \*-g++\* 2>/dev/null | sort -u'

  # clang
  gcc/search-compiler-from-path clang++ clang

  # xlc (IBM XL C/C++) gcc-like interface
  gcc/search-compiler-from-path gxlc++ gxlc
  #gcc/search-compiler-from-path xlc++ xlc
}

#------------------------------------------------------------------------------
# create-config

## 関数 gcc/get_cxxstdspec
##   gcc/get_cxxstdspec -v var CXXPREFIX
##   コンパイラに渡す -std=... 引数を生成します。
function gcc/generate_cxxstdspec {
  if test "x$1" == x-v -a -n "$2"; then
    # $1 = -v
    # $2 = var
    # $3 = CXXPREFIX

    eval "$2="
    if [[ "$3" =~ -(gcc|mingw)- ]]; then
      local _version=$(echo "$3" | awk '{
        if(match($0,/-([0-9]+)(\.([0-9]+)(\.([0-9]+))?)?$/,capt)>=0){
          print capt[1]*10000+capt[3]*100+capt[5]
        }else{
          print 0
        }
      }')

      if ((_version>=40700)); then
        eval "$2=' -std=gnu++11'"
      elif ((_version>=40300)); then
        eval "$2=' -std=gnu++0x'"
      fi
    fi
  else
    local _value
    gcc/get_cxxstdspec -v _value "$1"
    echo "$_value"
  fi
}

function gcc/PATH.canonicalize {
  local _var=PATH _F=:
  while test $# -gt 0; do
    case "$1" in
    (-v)  test -n "$2" && _var="$2"; shift 2 ;;
    (-v*) _var="${1:2}";             shift   ;;
    (-F)  test -n "$2" && _F="$2";   shift 2 ;;
    (-F*) _F="${1:2}";               shift   ;;
    (*)
      echo "unknown argument '$1'" >&2
      return 1 ;;
    esac
  done

  test "x$1" == x-v -a -n "$2" && _var="$2"

  IFS="$_F" eval "local _paths=(\$$_var)"
  test -z "${_paths[*]}" && return

  local result=
  local _path
  for _path in "${_paths[@]}"; do
    test -z "$_path" -o -n "$result" -a -z "${result/*:$_path:*/}" && continue
    result+=":$_path:"
  done

  result="${result#:}"
  result="${result%:}"
  result="${result//::/$_F}"
  eval "$_var=\"\$result\""
  return
}

# CXXDIR CXX; gcc.create_cofig CXXDIR2
function gcc.create-config {
  # check compiler
  # = all compiler (その他)
  echom 'compiler type = default (gcc)'

  local mwg_echox_prog='mcxx+prefix(gcc.create-config)'
  local CXXDIR2="${1%/}"
  if test ! -d "$CXXDIR2"; then
    echoe 'specified directory does not exist'
    echom "usage $0 \$CXXDIR/local/m/\$CXXPREFIX"
    return 1
  fi

  #--------------------------------------------------------
  # cxx_name

  local cxx_name=${CXX##*/}
  cxx_name="${cxx_name%.exe}"
  local cc_name=${CC##*/}
  cc_name="${cc_name%.exe}"

  # cxx_stdspec
  local cxx_stdspec
  gcc/generate_cxxstdspec -v cxx_stdspec "$CXXPREFIX"

  #--------------------------------------------------------
  # read environental variables

  if test -n "$LIBRARY_PATH"; then
    gcc/PATH.canonicalize -v LIBRARY_PATH
    source_line_library_path="export LIBRARY_PATH=\"\$LIBRARY_PATH\${LIBRARY_PATH:+:}$LIBRARY_PATH\""
  else
    source_line_library_path="# export LIBRARY_PATH='/usr/lib:/lib/gcc/$PLATFORM/${default_prefix##*-}'"
  fi

  if test -n "$INCLUDE_PATH"; then
    gcc/PATH.canonicalize -v INCLUDE_PATH
    source_line_include_path="export INCLUDE_PATH=\"\$INCLUDE_PATH\${INCLUDE_PATH:+:}$INCLUDE_PATH\""
  else
    source_line_include_path="# export INCLUDE_PATH"
  fi

  if test -n "$C_INCLUDE_PATH"; then
    gcc/PATH.canonicalize -v C_INCLUDE_PATH
    source_line_c_include_path="export C_INCLUDE_PATH=\"\$C_INCLUDE_PATH\${C_INCLUDE_PATH:+:}$C_INCLUDE_PATH\""
  else
    source_line_c_include_path="# export C_INCLUDE_PATH='/usr/include:/lib/gcc/$PLATFORM/${default_prefix##*-}/include'"
  fi

  if test -n "$CPLUS_INCLUDE_PATH"; then
    gcc/PATH.canonicalize -v CPLUS_INCLUDE_PATH
    source_line_cplus_include_path="export CPLUS_INCLUDE_PATH=\"\$CPLUS_INCLUDE_PATH\${CPLUS_INCLUDE_PATH:+:}$CPLUS_INCLUDE_PATH\""
  else
    source_line_cplus_include_path="# export CPLUS_INCLUDE_PATH='/usr/include:/lib/gcc/$PLATFORM/${default_prefix##*-}/include/c++'"
  fi

  if test -n "$FLAGS"; then
    source_line_flags_path="export FLAGS=\"\$FLAGS\${FLAGS:+ }$FLAGS\""
  else
    source_line_flags_path="# export FLAGS"
  fi

  if test -n "$CFLAGS"; then
    source_line_cflags_path="export CFLAGS=\"\$CFLAGS\${CFLAGS:+ }$CFLAGS\""
  else
    source_line_cflags_path="# export CFLAGS='-Wall'"
  fi

  if test -n "$CXXFLAGS"; then
    source_line_cxxflags_path="export CXXFLAGS=\"\$CXXFLAGS\${CXXFLAGS:+ }$CXXFLAGS\""
  else
    source_line_cxxflags_path="# export CXXFLAGS='-Wall'"
  fi

  #--------------------------------------------------------
  # create config.src

  cat <<EOF >"$CXXDIR2/config.src"
# -*- mode:sh -*-

# export PATH="\$PATH"
$source_line_library_path
$source_line_include_path
$source_line_c_include_path
$source_line_cplus_include_path
$source_line_flags_path
$source_line_cflags_path
$source_line_cxxflags_path

source_if() { test -e "\$1" && source "\$@" >/dev/null; }
source_if "\${CXXDIR:-\$HOME/.mwg/mcxx}/local/m/common.src" gcc

if test "x\$1" == xcxx; then
  CXX='$CXX$stdxxspec'
  CC='$CC'
elif test "x\$1" == xenv; then
  # alias $cxx_name="$CXX \$FLAGS \$CXXFLAGS$stdxxspec"
  # alias $cc_name="$CC \$FLAGS \$CFLAGS"
  echo '.... setup $CXXPREFIX'
fi
EOF

}
