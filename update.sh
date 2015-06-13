#!/bin/bash

#------------------------------------------------------------------------------
# version up from 2.0 to 2.1

# local
test -d local || mkdir -p local

# local/prefix
if test -d cxx_pref; then
  mv cxx_pref local/prefix
fi

function modify_cxxdir2_content {
  local cxxdir2="$1"
  local fconf="$cxxdir2/config.src"

  if grep -q '^source_if .\+/loadlib\.src\b' "$fconf"; then
    # merge gccflags, loadlib to common.src
    echo "sed -i ... $fconf (replacing 'source gccflags.src/loadlib.src' with 'source common.src')"
    sed -i '
      /^source_if .\+\/gccflags\.src\b/d
      /^source_if .\+\/loadlib\.src\b/s_\(/local\)\?/m/loadlib\.src_/local/m/common.src_
    ' "$fconf"
  fi

  if grep -q '^[[:space:]]*C\(C\|XX\)=.*/cxx-cl.sh' "$fconf"; then
    # modify i686-win-vc-*
    echo "sed -i ... $fconf (modifying the place of cxx-cl.sh to share/adapter/msc/cxx.sh)"
    sed -i '
      /^[[:space:]]*C\(C\|XX\)=/s#cxx-cl.sh#share/adapter/msc/cxx.sh#
    ' "$fconf"
  fi

  if test -h "$cxxdir2/cxxar"; then
    local link="$(readlink "$cxxdir2/cxxar")"

    local newlink=
    if [[ "$link" =~ \bcxxar-vc\.sh$ ]]; then
      newlink=share/adapter/msc/cxxar.sh
    elif [[ "$link" =~ \bcxxar-mingw\.sh$ ]]; then
      newlink=share/adapter/mingw/cxxar.sh
    fi
    echo "link=$link newlink=$newlink"

    if test -n "$newlink"; then
      echo "ln -s $newlink ${cxxdir2#$CXXDIR}/cxxar"
      rm -f "$cxxdir2/cxxar"
      ln -s "$CXXDIR/$newlink" "$cxxdir2/cxxar"
    fi
  fi
}

# local/m
if test -d m; then
  mv m local/m

  # local/m/*/config.src
  for file in local/m/*/config.src; do
    test -f "$file" || continue
    modify_cxxdir2_content "${file%/config.src}"
  done
  
  # local/m/common.src
  fcom=local/m/common.src
  
  f1=local/m/gccflags.src
  if test -s "$f1"; then
    echo "$f1: combined to $fcom"
    cat "$f1" >> "$fcom" && rm "$f1"
  fi
  
  f2=local/m/loadlib.src
  if test -s "$f2"; then
    echo "$f2: combined to $fcom"
    cat "$f2" >> "$fcom" && rm "$f2"
  fi
  
  if test ! -s "$fcom"; then
    cat share/m.new/common.src >> "$fcom"
  fi
fi

#test
for file in local/m/*/config.src; do
  test -f "$file" || continue
  modify_cxxdir2_content "${file%/config.src}"
done
