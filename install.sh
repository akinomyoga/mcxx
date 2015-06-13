#!/bin/bash

version=2.1
: ${MWGDIR:=$HOME/.mwg}

function echo-eval {
  eval "echo \"$@\""
  eval "$@"
}

if test "$PWD" != "$MWGDIR/mcxx"; then
  echo-eval 'mkdir -p "$MWGDIR/mcxx"'
  echo-eval 'cp -r ./* "$MWGDIR/mcxx/"'
fi

function ln_versioned {
  local fpath_src="$MWGDIR/mcxx/$1"
  local fname_dst="${2:-$1}"
  local fname_ver="${2:-$1}-$version"
  local fpath_dst="$MWGDIR/bin/$fname_dst"
  local fpath_ver="$MWGDIR/bin/$fname_ver"

  # .mwg/hoge-version
  if test -f "$fpath_ver" -o -h "$fpath_ver"; then
    echo-eval 'rm -f "$fpath_ver"'
  fi
  echo-eval 'ln -s "$fpath_src" "$fpath_ver"'

  # .mwg/hoge
  if test ! -f "$fpath_dst" -o "$fpath_dst" -ot "$fpath_src"; then
    if test -f "$fpath_dst" -o -h "$fpath_dst"; then
      echo-eval 'rm -f "$fpath_dst"'
    fi
    echo-eval 'ln -s "$fname_ver" "$fpath_dst"'
  fi
}

mkdir -p "$MWGDIR/bin"
ln_versioned cxx   mcxx
ln_versioned cxx   mcc
ln_versioned cxxar mcxxar
type cxx   &>/dev/null || ln_versioned cxx   cxx
type cc    &>/dev/null || ln_versioned cxx   cc
type cxxar &>/dev/null || ln_versioned cxxar cxxar

if test ! -f "$MWGDIR/mcxx/local/prefix/key+default.stamp"; then
  "$MWGDIR/mcxx/cxx" +prefix auto
fi
