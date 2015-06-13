#!/bin/bash

if test "x$1" == "x--cp"; then
  shift
  if test $# -ne 2; then
    echo "usage: $0 --cp <src.a> <dst.a>" > /dev/stderr
    echo "  the target library is libNAME.a or NAME.lib" > /dev/stderr
    exit 1
  fi

  cp -p "$1" "$2"
  exit
fi

declare -a objs
for file in "$@"; do
  objs[${#objs[@]}]="$(cygpath -w "$file")"
done

#echo ar cru "${objs[@]}" '&&' ranlib "${objs[0]}"
ar cru "${objs[@]}" && ranlib "${objs[0]}"
