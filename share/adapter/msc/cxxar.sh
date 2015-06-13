#!/bin/bash

ICONV="iconv -f cp932 -t utf-8"
#local ICONV="nkf -Sw"

search_object_file () {
  local file="$1"
  case "${file##*.}" in
  o)
      local file2="${file%.o}.obj"
      if test -f "$file2"; then
        echo "$file2"
      else
        echo "$file"
      fi
      ;;
  a)
      local file2="${file%.a}.lib"
      local file3="${file2#lib}"
      if test -f "$file3"; then
        echo "$file3"
      elif test -f "$file2"; then
        echo "$file2"
      else
        echo "$file"
      fi
      ;;
  *)
      echo "$file"
      ;;
  esac
}

force_link () {
  # to calm makefile
  local src="$1"
  local dst="$2" # must be same directory
  test "$src" == "$dst" && return
  test -h "$dst" && return
  test -e "$dst" && /bin/rm "$dst"
  ln -s "${src##*/}" "$dst"
}

create_libname () {
  local lib="${1%.a}"
  if test "$lib" == "${lib%/*}"; then
    echo "${lib#lib}.lib"
  else
    local dir="${lib%/*}"
    local lib="${lib##*/}"
    echo "$dir/${lib#lib}.lib"
  fi
}

#------------------------------------------------------------------------------

command_create_library () {
  local req="$1"                        # "hoge/libhoge.a"
  local dst="$(create_libname "$req")"  # "hoge/hoge.lib"
  shift
  local -a objs
  for file in "$@"; do
    objs[${#objs[@]}]="$(cygpath -w "$(search_object_file "$file")")"
  done

  force_link "$dst" "$req"
  local dstw="$(cygpath -w "$dst")"
  echo lib /OUT:"$dstw" "${objs[@]}"
  lib /OUT:"$dstw" "${objs[@]}" \
    1> >($ICONV            ) \
    2> >($ICONV>/dev/stderr)
}

command_copy_library () {
  local src_="$1"
  local src="$(create_libname "$src_")"
  local dst_="$2"
  local dst="$(create_libname "$dst_")"

  cp -p "$src" "$dst"
  force_link "$dst" "$dst_"
}

#------------------------------------------------------------------------------
usage_and_exit () {
  echo "usage: $0 NAME [objectfiles...]" > /dev/stderr
  echo "  the target library is libNAME.a or NAME.lib" > /dev/stderr
  echo "usage: $0 --cp [libsrc.a] [libdst.a]" > /dev/stderr
  echo "  copies a library" > /dev/stderr
  exit 1
}

if test $# -eq 0; then
  usage_and_exit
fi

if test "x$1" == "x--cp"; then
  shift
  if test $# -ne 2; then
    usage_and_exit
  fi

  command_copy_library "$@"
else
  command_create_library "$@"
fi
