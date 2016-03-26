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

[[ $mcxx_verbose ]] && echo ar rc "$@" '&&' ranlib "$1" >&2
ar rc "$@" && ranlib "$1"
