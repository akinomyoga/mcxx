#!/bin/bash

# to be sourced from cxx
if [[ ! -d $CXXDIR ]]; then
  echo "mcxx/cxx_pref.sh: \$CXXDIR ($CXXDIR) is not a directory." >&2
  exit 1
fi

source "$CXXDIR/ext/echox" --color=auto
mwg_echox_prog="mcxx($CXXDIR) +prefix"

mkd () { test -d "$1" || mkdir -p "$1"; }
ends_with () { test "${1%$2}" != "$1"; }
is_windows() { test -n "$SYSTEMROOT" -a -n "$PROGRAMFILES"; }

dirpref="$CXXDIR/local/prefix"
mkd "$dirpref"

#==============================================================================
#  cxx +prefix add
#  cxx +prefix auto
#------------------------------------------------------------------------------

generate_cxxprefix () {
  export CXX
  ret=$(

    # check if it is vc
    local rex_msc_path='/Microsoft Visual Studio ([1-9][.0-9]*)/VC/bin/cl(.exe)?$'
    if [[ "$CXX" =~ $rex_msc_path ]]; then
      case "${BASH_REMATCH[1]}" in
      (9.0)  echo -n i686-win-vc-msc15 ; exit ;;
      (10.0) echo -n i686-win-vc-msc16 ; exit ;;
      esac
    fi

    "$CXX" --version 2>&1 | gawk '
      BEGIN{
        plat=ENVIRON["PLATFORM"];
        sub(/pc-cygwin/,"cygwin",plat);
      }
      /^[^[:space:]]+ \([^\)]*\) ([[:digit:]]+)\.([[:digit:]]+)\.([[:digit:]]+)/{
        if(match($0,/[^[:space:]]+ \(([^\)]*)\) ([[:digit:]]+)\.([[:digit:]]+)\.([[:digit:]]+)/,dict)>0){
          if(dict[1] ~ /^GCC\y/)
            gcc="gcc";
          else if(dict[1] ~ /^ICC\y/)
            gcc="icc";
          else if(dict[1] ~ /(^(TDM|tdm)\y)|\yMinGW-builds\y/){
            sub(/\ycygwin\y/,"win",plat);
            gcc="mingw";
          }else
            gcc=""

          if(gcc!=""){
            printf("%s-%s-%d.%d.%d",plat,gcc,dict[2],dict[3],dict[4]);
            comp++;
            exit;
          }
        }
      }
      /Microsoft ?\(R\) 32-bit C\/C\+\+ Optimizing Compiler Version/{
        if(match($0,/Version ([[:digit:]]+)\.([[:digit:]]+)/,dict)>0){
          printf("i686-win-vc-msc%d",dict[1]);
          comp++;
          exit;
        }
      }
      /^clang version ([[:digit:]]+)\.([[:digit:]]+)/{
        if(match($0,/^clang version ([[:digit:]]+)\.([[:digit:]]+)/,dict)>0){
          printf("%s-clang-%d.%d",plat,dict[1],dict[2]);
          comp++;
          exit;
        }
      }
      END{
        if(comp==0){
          CXX=ENVIRON["CXX"];
          sub(/^.+\//,"",CXX);
          sub(/\.exe$/,"",CXX);
          printf("%s-%s",plat,CXX);
        }
      }
    '
  )

  if is_windows && test -z "${ret##*-cygwin-gcc-*}"; then
    # test if it is mingw

    local ftmp="$(cygpath -w $CXXDIR/tmp.o)"
    if cat <<EOF | "$CXX" -xc - -c -o$ftmp &>/dev/null; then
#ifndef __MINGW32__
__choke__
#endif
EOF
      ret="${ret/-cygwin-gcc-/-win-mingw-}"
    fi
    rm -f "$ftmp"
  fi

  echo $ret
}

declare -a adapters=()
function adapters.initialize {
  ((${#adapters[@]})) && return
  
  # gcc は default でもあるので最後にする必要がある。
  adapters=(msc mingw gcc)

  local adp
  for adp in "${adapters[@]}"; do
    # ※全て source した後に中の関数を実行する必要がある。
    #   内部で互いに関数などを融通している為。
    source "$CXXDIR/share/adapter/$adp/prefix.sh"
  done
}

function cmd.prefix/add {
  local mwg_echox_prog='mcxx +prefix add'

  local a_quiet=
  local a_default=
  local a_key=
  local regex
  local compiler_pairs
  local flagTargetSpecified flagError
  compiler_pairs=()
  while (($#)); do
    local arg="$1"
    shift
    case "$arg" in
    (-q) a_quiet=1 ;;
    (-d) a_default=1 ;;
    (-k) a_key="$1"; shift ;;
    (-k*) a_key="${arg:2}" ;;
    (--help)
      local help
      read -rd '' help <<EOF
mcxx +prefix add

USAGE: mcxx +prefix add [options] compiler-spec

options

  -q     quiet mode

  -d     set this compiler as the default one

  -k KEY specify the key for this compiler

compiler-spec

  CXX:CC
      Specify the compiler pair, e.g. /bin/g++:/bin/gcc

  CC
  CXX
      Specify one of the c/c++ compiler, e.g. /bin/g++.
      The c/c++ compiler not specified will be guessed using the specified one.
      If the c compiler cannot be guessed or found, the operation will fail.

  DIR
      Specify the directory that contains the compilers.
      The following compiler pairs will be checked in order.

      - DIR/g++:DIR/gcc
      - DIR/bin/g++:DIR/bin/gcc

EOF
      echo "$help"
      return 0 ;;
    (*)
      flagTargetSpecified=1

      # コンパイラのペア CXX:CC を指定した場合
      if regex='^([^:]+):([^:]+)$' && [[ $arg =~ $regex ]]; then
        local cxx="${BASH_REMATCH[1]}"
        local cc="${BASH_REMATCH[2]}"
        if [[ -x $cxx && -x $cc ]]; then
          compiler_pairs+=("$cxx:$cc")
          continue
        fi
      fi

      # コンパイラのディレクトリを指定した場合
      if [[ -d $arg ]]; then

        if [[ -x $arg/gcc && -x $arg/g++ ]]; then
          compiler_pairs+=("$arg/g++:$arg/gcc")
          continue
        elif [[ -x $arg/bin/gcc && -x $arg/bin/g++ ]]; then
          compiler_pairs+=("$arg/bin/g++:$arg/bin/gcc")
          continue
        fi

        echoe "$arg (directory): C/C++ Compiler pair not found!"
        flagError=1
      fi

      # コンパイラ C/C++ どちらかを指定した場合
      if [[ -x $arg ]]; then
        # compiler?
        if regex='(^|/|-)g(cc|\+\+)([^/]*)$' && [[ $arg =~ $regex ]]; then
          # gcc/g++ の場合
          local suffix="${BASH_REMATCH[3]}"
          local compiler_base="${arg::${#arg}-3-${#suffix}}"
          local cxx="${compiler_base}g++$suffix"
          local cc="${compiler_base}gcc$suffix"
          if [[ -x $cxx && -x $cc ]]; then
            compiler_pairs+=("$cxx:$cc")
            continue
          else
            if [[ ! -x $cxx ]]; then
              echoe "$arg: Corresponding C++ compiler not found!"
            else
              echoe "$arg: Corresponding C compiler not found!"
            fi
            flagError=1
            continue
          fi
        fi

        echoe "unrecognized compiler \`$arg'!"
        flagError=1
      else
        echoe "unknown argument \`$arg'!"
        flagError=1
      fi ;;
    esac
  done

  # 引数が何も指定されなかった場合は環境変数 CXX, CC から読み取りを試みる
  if [[ ! $flagTargetSpecified ]]; then
    if [[ -x $CXX && -x $CC ]]; then
      compiler_pairs+=("$CXX:$CC")
    else
      flagError=1
      if [[ ! $CXX ]]; then
        echoe "environmental variable CXX is not set"
      elif [[ ! -x $CXX ]]; then
        echoe "compiler CXX=$CXX not found!"
      fi

      if [[ ! $CC ]]; then
        echoe "environmental variable CC is not set"
      elif [[ ! -x $CC ]]; then
        echoe "compiler CC=$CC not found!"
      fi
    fi
  fi

  [[ ! $flagError ]] || return 1

  local pair pair2
  for pair in "${compiler_pairs[@]}"; do
    IFS=: eval "pair2=(\$pair)"
    CXX="${pair2[0]}" CC="${pair2[1]}" cmd.prefix/add/register_pair
  done
}

## @var[in] CXX
## @var[in] CC
## @var[in] a_quiet
## @var[in] a_default
function cmd.prefix/add/register_pair {
  #----------------------------------------------------------------------------
  # Read settings
  #----------------------------------------------------------------------------
  if test -z "$CXX" -o -z "$CC"; then
    test -z "$CXX" && echoe "environmental variable CXX is not set"
    test -z "$CC" && echoe "environmental variable CC is not set"
    return 1
  fi

  local name="${1:-${CXX##*/}}"
  echom "adding compiler: [35m$name[m ($CXX)"
  echox_push
  echom "CXX=$CXX"
  echom "CC=$CC"

  #----------------------------------------------------------------------------
  # Determine CXXKEY and CXXPREFIX
  #----------------------------------------------------------------------------
  PLATFORM.initialize

  prefix="$(generate_cxxprefix)"
  default_prefix="$prefix"
  i=1; while test -s "$dirpref/prefix+$prefix.stamp"; do
    prefix="$default_prefix+$((i++))"
  done
  if test -z "$a_quiet"; then
    while echor prefix "CXXPREFIX=" "$prefix";do
      test ! -s "$dirpref/prefix+$prefix.stamp" && break
      echoe "specified cxxprefix is already used!"
    done
  fi

  # determine key
  local key= keyGenerated=
  # (1) specified in option
  if [[ $a_key ]]; then
    if [[ ! -s $dirpref/key+$a_key.stamp ]]; then
      key="$a_key"
    else
      echoe "the specified key '$a_key' is already used."
    fi
  fi
  # (2) simple numbers
  if [[ ! $key ]]; then
    local regex
    if regex='-gcc-([0-9]\.[0-9]\.[0-9])$' && [[ $default_prefix =~ $regex ]]; then
      key="g${BASH_REMATCH[1]//./}" keyGenerated=1
    elif regex='-clang-([0-9]\.[0-9])$' && [[ $default_prefix =~ $regex ]]; then
      key="l${BASH_REMATCH[1]//./}" keyGenerated=1
    elif regex='-icc-([0-9]+)[.0-9]*$' && [[ $default_prefix =~ $regex ]]; then
      key="i${BASH_REMATCH[1]}" keyGenerated=1
    fi
  fi
  # (3) simple numbers
  if [[ ! $key ]]; then
    key=1 keyGenerated=1
    while [[ -s $dirpref/key+$key.stamp ]]; do
      let key++
    done
  fi
  # (4) ask via terminal
  if [[ $keyGenerated && -t 0 && ! $a_quiet ]]; then
    while echor key "CXXKEY=" "$key"; do
      [[ ! -s $dirpref/key+$key.stamp ]] && break
      echoe "specified cxxkey is already used!"
    done
  fi

  #----------------------------------------------------------------------------
  # Confirm
  #----------------------------------------------------------------------------
  # kakunin
  echox_push
  echom "CXXPREFIX=$prefix"
  echom "CXXKEY=$key"
  echom "CXX=$CXX"
  echom "CC=$CC"
  echox_pop
  if test -z "$a_quiet"; then
    while :;do
      echor result "would you like to add the above setting (y/n)"
      if test "$result" == 'y'; then
        break
      elif test "$result" == 'n'; then
        echox_pop
        return
      fi
    done
  fi

  #----------------------------------------------------------------------------
  # Write settings
  #----------------------------------------------------------------------------
  # CXXDIR/local/prefix
  mkd "$dirpref"
  echo -n "$prefix" > "$dirpref/key+$key.stamp"
  echo -n "$key" > "$dirpref/prefix+$prefix.stamp"
  if test -n "$a_default"; then
    local key_default_file="$dirpref/key+default.stamp"
    test -e "$key_default_file" && rm -f "$key_default_file"
    ln -s "key+$key.stamp" "$key_default_file"
  fi

  # CXXDIR/local/m
  test ! -d "$CXXDIR/local/m" && cp -pr "$CXXDIR/share/m.new" "$CXXDIR/local/m"

  local cxxdir2="$CXXDIR/local/m/$prefix"
  mkd "$cxxdir2"

  adapters.initialize

  local adp r=0 CXXPREFIX="$prefix"
  for adp in "${adapters[@]}"; do
    # 関数 $adp.create-config
    #   $adp.create-config CXXDIR2
    # \env   [in]  CXXDIR    mcxx インストールディレクトリを指定します。
    # \env   [in]  CXXPREFIX 設定の名称を指定します。
    # \env   [in]  CXX       使用する C++ コンパイラを指定します。
    # \env   [in]  CC        使用する C コンパイラを指定します。
    # \param [in]  CXXDIR2   構成情報を初期化するディレクトリを指定します。
    # \return[out] ?         終了状態を返します。
    #   0 = 正常終了
    #   1 = 構成情報の初期化に失敗
    #   2 = この adp で担当するコンパイラではない

    "$adp.create-config" "$cxxdir2"; r=$?
    ((r==2)) && continue

    # when error has occured
    ((r)) && echoe "failed to generate the config directory $cxxdir2"

    break
  done

  # CXXDIR/local/m/cxxprefix/cxxpair.txt
  if [[ ! $CXXPAIR ]]; then
    local CXX_=$(readlink -f "$CXX")
    local CC_=$(readlink -f "$CC")
    if msc/is_cygwin; then
      CXX_="${CXX_%.exe}"
      CC_="${CC_%.exe}"
    fi
    CXXPAIR="$CXX_:$CC_"
  fi
  echo -n $CXXPAIR > "$cxxdir2"/cxxpair.txt

  echox_pop

  return $r
}

function PLATFORM.initialize {
  if test -z "$PLATFORM"; then
    export PLATFORM="$(source $CXXDIR/cxx_pref-guess.src)"
  fi
}

# cxxpair: すでに登録されている CXX:CC の pair を管理

cxxpairs=()
function cxxpair.load {
  ((${#cxxpairs[@]})) && return

  local pref count=0
  for pref in "$dirpref"/prefix+*.stamp; do
    [[ -f $pref ]] || continue
    ((count++))
    local prefix="${pref#$dirpref/prefix+}"
    prefix="${prefix%.stamp}"
    local fcxxpair="$CXXDIR/local/m/$prefix/cxxpair.txt"
    if [[ -s $fcxxpair ]]; then
      cxxpairs+=("$(< $fcxxpair)")
    fi
  done

  if ((count&&!${#cxxpairs[@]})); then
    cxxpair.update
  fi
}
function cxxpair.registered {
  cxxpair.load

  local cxxpair
  for cxxpair in "${cxxpairs[@]}"; do
    [[ $cxxpair == "$1" ]] && return
  done
  return 1
}
function cxxpair.update {
  local pref
  for pref in "$dirpref"/prefix+*.stamp; do
    [[ -f $pref ]] || continue
    local prefix="${pref#$dirpref/prefix+}"
    prefix="${prefix%.stamp}"
    local dst="$CXXDIR/local/m/$prefix/cxxpair.txt"
    [[ -s $dst ]] && continue

    (
      function source_if { [[ -s "$1" ]] && source "$@"; }
      source "$CXXDIR/local/m/$prefix/config.src" cxx
      acxx=($CXX) acc=($CC)
      echo -n "$acxx:$acc" > "$dst"
    )
    cxxpairs+=("$(< $dst)")
  done
}

function cmd.prefix/auto () {
  local mwg_echox_prog='mcxx +prefix auto'

  PLATFORM.initialize
  adapters.initialize

  # COMPILERS
  #   一番先頭に来るのが default になるので順番は重要
  local -a COMPILERS=()
  gcc.detect-compilers
  msc.detect-compilers
  
  local line fields
  for line in "${COMPILERS[@]}"; do
    IFS=: eval 'fields=($line)'
    local CXXPAIR="${fields[2]:-${fields[0]}}:${fields[3]:-${fields[1]}}"
    if cxxpair.registered "$CXXPAIR"; then
      echom "skip: compiler pair '$CXXPAIR' already registered." >&2
      continue
    fi

    local CXX="${fields[0]}"
    local CC="${fields[1]}"
    cmd.prefix/add "$@"

    if test ! -e "$dirpref/key+default.stamp"; then
      # default として登録
      local prefs=("$dirpref"/prefix+*.stamp)
      local pref0="${prefs[0]}"
      pref0="${pref0##*/prefix+}"
      pref0="${pref0%.stamp}"
      if test -n "$pref0" -a "$pref0" != '*'; then
        cmd.prefix/set-default "$pref0"
      fi
    fi
  done
}

#==============================================================================
#  cxx +prefix remove
#  cxx +prefix set-default
#  cxx +prefix set-key
#------------------------------------------------------------------------------

function get_cxxpair_fromKeyOrPrefix {
  local arg1="$1"

  CXXKEY= CXXPREFIX=
  if test -f "$dirpref/key+$1.stamp"; then
    CXXKEY="$1"
    CXXPREFIX=$(cat "$dirpref/key+$CXXKEY.stamp" 2>&1)
    if test "$CXXKEY" == default; then
      CXXKEY=$(cat "$dirpref/prefix+$CXXPREFIX.stamp" 2>&1)
    fi
  elif test -f "$dirpref/prefix+$1.stamp"; then
    CXXPREFIX="$1"
    CXXKEY=$(cat "$dirpref/prefix+$CXXPREFIX.stamp" 2>&1)
  fi

  if test -z "$CXXKEY" -o -z "$CXXPREFIX"; then
    echoe "the specified key/prefix '$arg1' is invalid!"
    return 1
  fi
}

cmd.prefix/remove() {
  local mwg_echox_prog='mcxx +prefix remove'

  # check argument $1
  if test -z "$1"; then
    echoe "key nor prefix is specified"
    echoi "usage: cxx mwg prefix remove <key/prefix>"
    return 1
  elif test "$1" == default; then
    echoe "default key cannot be removed!"
    return 1
  fi

  local CXXKEY= CXXPREFIX=
  get_cxxpair_fromKeyOrPrefix "$1" || return 1

  # check if the prefix is not the default prefix.
  if test -f "$dirpref/key+default.stamp"; then
    local DEFPREFIX=$(cat "$dirpref/key+default.stamp")
    if test "$CXXPREFIX" == "$DEFPREFIX"; then
      echoe "default setting, $CXXKEY ($CXXPREFIX), cannot be removed!"
      return 1
    fi
  fi

  while :;do
    echor result "would you like to remove the settings for $CXXKEY ($CXXPREFIX) (y/n)"
    if test "$result" == 'y'; then
      break
    elif test "$result" == 'n'; then
      return
    fi
  done

  rm -f "$dirpref/key+$CXXKEY.stamp"
  rm -f "$dirpref/prefix+$CXXPREFIX.stamp"
}

cmd.prefix/set-default() {
  local mwg_echox_prog='mcxx +prefix set-default'

  # check argument $1
  if test -z "$1"; then
    echoe "key nor prefix is specified"
    echom "usage: mcxx mwg prefix set-default <key/prefix>"
    return 1
  elif test "$1" == default; then
    echoe "default key cannot be set as default!"
    return 1
  fi

  local CXXKEY= CXXPREFIX=
  get_cxxpair_fromKeyOrPrefix "$1" || return 1

  local fstamp_default="$dirpref/key+default.stamp"
  if test -f "$fstamp_default"; then
    # check if the prefix is not yet the default prefix.
    local DEFPREFIX=$(cat "$fstamp_default")
    if test "$CXXPREFIX" == "$DEFPREFIX"; then
      echoe "the setting, $CXXKEY ($CXXPREFIX), is already default!"
      return 1
    fi

    rm "$fstamp_default"
  elif test -h "$fstamp_default"; then
    # dangling symbolic link
    rm "$fstamp_default"
  fi

  ln -s "key+$CXXKEY.stamp" "$fstamp_default"
}

function cmd.prefix/set-key {
  local mwg_echox_prog='mcxx +prefix set-key'

  if test -z "$1"; then
    echoe "a key nor a prefix is specified"
    echom "usage: mcxx mwg prefix set-key <oldkey/prefix> newkey"
    return 1
  elif test -z "$2"; then
    echoe "a new key is not specified"
    echom "usage: mcxx mwg prefix set-key <oldkey/prefix> newkey"
    return 1
  elif test -f "$dirpref/key+$2.stamp"; then
    echoe "the specified new key '$2' is already used"
    return 1
  fi

  local CXXKEY= CXXPREFIX=
  get_cxxpair_fromKeyOrPrefix "$1" || return 1

  # check if is default setting
  local fkdef="$dirpref/key+default.stamp"
  if test -f "$fkdef"; then
    if test "$CXXPREFIX" == "$(cat "$fkdef")"; then
      local is_default=1
    fi
  fi

  local NEWKEY="$2"

  mv "$dirpref/key+$CXXKEY.stamp" "$dirpref/key+$NEWKEY.stamp"
  echo -n "$NEWKEY" > "$dirpref/prefix+$CXXPREFIX.stamp"

  if test -n "$is_default"; then
    cmd.prefix/set-default "$NEWKEY"
  fi
}

#==============================================================================
#  get_cxxprefix
#------------------------------------------------------------------------------

get_cxxprefix() {
  source "$CXXDIR/cxx_pref-get.sh"
  echo -n "$CXXPREFIX"
}

show_cxxprefix_nocache() {
  local fstamp_default="$dirpref/key+default.stamp"
  if test -f "$fstamp_default"; then
    local DEFPREFIX=$(cat "$fstamp_default")
  fi

  local pref
  for pref in "$dirpref"/prefix+*.stamp; do
    local prefix="${pref#$dirpref/prefix+}"; prefix="${prefix%.stamp}"
    local key="$(cat "$pref")"

    local flag='-'
    [[ "$prefix" == "$DEFPREFIX" ]] && flag='*'

    printf "%s %-10s %s %s\n" "$flag" "$key" "$prefix"
  done
}

show_cxxprefix() {
  local cache="$dirpref/show_cxxprefix.cache"
  local pref
  for pref in "$dirpref" "$dirpref"/{prefix,key}+*.stamp; do
    if test -e "$pref" -a "$cache" -ot "$pref"; then
      show_cxxprefix_nocache | tee "$cache"
      return
    fi
  done
  cat "$cache"
}

function cmd.prefix/help {
  local bold=$'\e[1m=\e[m'
  local ul=$'\e[4m=\e[m'
  local cyan=$'\e[36m=\e[39m'
  ifold -i -s -w 80 <<EOF
usage: cxx +prefix ${cyan/=/OPERATION} [${cyan/=/ARGUMENTS}...]

${cyan/=/OPERATION}

  ${bold/=/help}
    shows this help.

  ${bold/=/add} [options..]
    manually adds settings to use the specified compiler. \
the compilers are specified through the environmental variables ${cyan/=/CC} and ${cyan/=/CXX}. \
${cyan/=/CC} specifies the c compiler and ${cyan/=/CXX} specifies the c++ compiler.
      
    ${bold/=/-q}  do not ask for confirmation.

  ${bold/=/auto} [options..]
    Automatically searches and registers compilers in the system. \
The same options with the ${bold/=/add} operation is supported.

  ${bold/=/remove} ${ul/=/key/prefix}
    removes the settings of the specified compiler

  ${bold/=/set-default} ${ul/=/key/prefix}
    sets the specified setting to the default setting.

  ${bold/=/set-key} ${ul/=/key/prefix} ${ul/=/newkey}
    resets the key for the specified settings.

  ${bold/=/list}
    prints the list of registered compilers

  ${bold/=/get}
    prints the ${cyan/=/CXXPREFIX} of the current settings

  ${bold/=/dbg-generate_cxxprefix} (for internal use)

EOF
}

case "x$1" in
(xlist)
  show_cxxprefix ;;
(xget)
  get_cxxprefix ;;
(xdbg-generate_cxxprefix)
  PLATFORM.initialize
  generate_cxxprefix ;;
(xremove)
  shift
  cmd.prefix/remove "$@"
  ;;
(xset-default)
  shift
  cmd.prefix/set-default "$@"
  ;;
(*)
  declare cmd="cmd.prefix/$1"
  if declare -f "$cmd" &>/dev/null; then
    shift
    "$cmd" "$@"
  else
    echom "usage: $0 list|auto|add|get|set-default|remove|set-key|dbg-generate_cxxprefix"
  fi ;;
esac
