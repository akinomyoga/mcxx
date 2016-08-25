#!/bin/bash

version=2.1
: ${MWGDIR:=$HOME/.mwg}
: ${PREFIX:=$MWGDIR}

share_directory=$PREFIX/share/mcxx
local_directory=$PREFIX/share/mcxx/local

function echo-eval {
  local expanded="$*"
  local a b
  b='\' a='\\'; expanded=${expanded//$b/$a}
  b='`' a='\`'; expanded=${expanded//$b/$a}
  b='"' a='\"'; expanded=${expanded//$b/$a}
  b='"' a='\"'; expanded=${expanded//$b/$a}
  echo "$expanded"

  eval "$*"
}

if test "$PWD" != "$share_directory"; then
  echo-eval 'mkdir -p "$share_directory"'
  echo-eval 'cp -r ./* "$share_directory/"'
fi

function ln_versioned {
  local fpath_src="$share_directory/$1"
  local fname_dst="${2:-$1}"
  local fname_ver="${2:-$1}-$version"
  local fpath_dst="$PREFIX/bin/$fname_dst"
  local fpath_ver="$PREFIX/bin/$fname_ver"

  # .mwg/hoge-version
  echo-eval 'ln -sf "$fpath_src" "$fpath_ver"'

  # .mwg/hoge
  if [[ ! -f $fpath_dst || $fpath_dst -ot $fpath_src ]]; then
    echo-eval 'ln -sf "$fname_ver" "$fpath_dst"'
  fi
}

mkdir -p "$PREFIX/bin"
ln_versioned cxx   mcxx
ln_versioned cxx   mcc
ln_versioned cxxar mcxxar
type cxx   &>/dev/null || ln_versioned cxx   cxx
type cc    &>/dev/null || ln_versioned cxx   cc
type cxxar &>/dev/null || ln_versioned cxxar cxxar

if [[ ! -f $local_directory/prefix/key+default.stamp ]]; then
  "$share_directory/cxx" +prefix auto
fi
