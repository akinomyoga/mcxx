#!/bin/bash

# @env[in] mcxx_gxx: actual path of the compiler
# @env[in] mcxx_verbose

mcxx_bash=$((${BASH_VERSINFO[0]}*10000+${BASH_VERSINFO[1]}*100+${BASH_VERSINFO[2]}))

args=()
if ((mcxx_bash>=30100)); then
  function args.push { args+=("$@"); }
else
  function args.push { args=("${args[@]}" "$@"); }
fi

arg_input=
function process-input {
  [[ -f $1 && ! $arg_input ]] && arg_input="$1"
  args.push "$1"
}

arg_compile=
function process-option:-c {
  arg_compile=1
  args.push -c
}

arg_output=
function process-option:-o {
  arg_output="$1"
  args.push -o "$1"
}

# -MT filename/-MQ filename は gcc-2.95 では使えない様だ。
dep_target_sed=
function process-option:-MT {
  local file="$1" a b
  a='/' b='\/'; file="${file//$a/$b}"
  dep_target_sed="1s/^[^:]*:/$file :/"
}
function process-option:-MQ {
  local file="$1" a b
  a='#' b='\#'; file="${file//$a/$b}"
  a='$' b='$$'; file="${file//$a/$b}"
  a=' ' b='\ '; file="${file//$a/$b}"
  process-option:-MT "$file"
}

dep_output_set=
dep_output=
function process-option:-MF {
  dep_output_set=1
  dep_output="$1"
}

function read-arguments {
  while (($#)); do
    local arg="$1"
    shift
    case "$arg" in
    (-o)   process-option:-o "$1"; shift ;;
    (-o*)  process-option:-o "${arg#-o}" ;;
    (-MF)  process-option:-MF "$1"; shift ;;
    (-MF*) process-option:-MF "${arg#-MF}" ;;
    (-MT)  process-option:-MT "$1"; shift ;;
    (-MT*) process-option:-MT "${arg#-MT}" ;;
    (-MQ)  process-option:-MQ "$1"; shift ;;
    (-MQ*) process-option:-MQ "${arg#-MQ}" ;;
    (-[ILDUulxAzB]|-M[FT]|-Xlinker|-Xpreprocessor)
      args.push "$arg" "$1"
      shift 1 ;;
    (-c)   process-option:-c ;;
    (-*)   args.push "$arg" ;;
    (*)    process-input "$arg" ;;
    esac
  done
}

read-arguments "$@"

[[ $mcxx_verbose ]] && echo "$mcxx_gxx" "${args[@]}" >&2
"$mcxx_gxx" "${args[@]}"
exit=$?

# 出力ファイルの予想位置
if [[ ! $arg_output ]]; then
  if [[ $arg_compile ]]; then
    if [[ $arg_input ]]; then
      arg_output="${arg_input%.*}.o"
    else
      arg_output=
    fi
  else
    arg_output=a.out
  fi
fi

# 依存関係 *.d の予想位置
if [[ $arg_output == *.o ]]; then
  dep_output_tmp="${arg_output%.o}.d"
elif [[ -f $arg_input ]]; then
  dep_output_tmp="${arg_input%.*}.d"
else
  dep_output_tmp="a.d"
fi

# -MF -MT の処理
if [[ -f $dep_output_tmp ]]; then
  if [[ $dep_output_set && $dep_output_tmp != $dep_output ]]; then
    mv -f "$dep_output_tmp" "$dep_output"
  else
    dep_output="$dep_output_tmp"
  fi
  if [[ $dep_target_sed ]]; then
    sed -e "$dep_target_sed" "$dep_output" > "$dep_output.tmp" &&
      mv -- "$dep_output.tmp" "$dep_output"
  fi
fi

exit "$exit"
