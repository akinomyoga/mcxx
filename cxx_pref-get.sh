#!/bin/bash

dirpref="$CXXDIR/local/prefix"

function CXXPREFIX.initialize {
  # read .cxxkey
  if [[ ! $CXXKEY ]]; then
    local dir="${PWD%/}"
    while
      if [[ -f $dir/.cxxkey ]]; then
        CXXKEY=$(< "$dir/.cxxkey")
        break
      fi

      [[ $dir ]] && dir="${dir%/*}"
    do :; done
  fi

  : ${CXXKEY:=default}

  if [[ ! -s $dirpref/key+$CXXKEY.stamp ]]; then
    {
      printf "cxx: The key CXXKEY=%q is not registered.\n" "$CXXKEY"
      keys=("$dirpref"/key+*.stamp)
      if ((${#keys[@]})); then
        keys=("${keys[@]%%.stamp}")
        keys=("${keys[@]##*/key+}")
        IFS= eval 'keys="${keys[*]/#/, }"'
        echo "cxx: Specify one of the keys: ${keys:2}."
      else
        echo "cxx: There are no registered keys."
        echo "  Consider adding keys using \`cxx +prefix add <compiler>' or \`cxx +prefix auto'."
      fi
    } >&2
    exit 1
  fi

  export CXXPREFIX=$(< "$dirpref/key+$CXXKEY.stamp")
  export CXXDIR2="$CXXDIR/local/m/$CXXPREFIX"
}

CXXPREFIX.initialize
