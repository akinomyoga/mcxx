#!/bin/bash

source "$CXXDIR/ext/mydoc1" <<EOF
cxx (MCXX) 1.0
Copyright (C) 2011-2013 Koichi Murase <murase@nt.phys.s.u-tokyo.ac.jp>.

[*usage*]

$ cxx [_[compiler_arguments...]_]
.compiles a target using the default compiler

$ CXXKEY=[_key_] cxx [_[compiler_arguments...]_]
.compiles a target using the compiler specified by [_key_]

$ cxx +[_mcxx_command_] [_arguments..._]
.executes [_mcxx_command_] with the specified arguments

list of [*mcxx_command*]

.cxx +[*help*]
..show this help
.
.cxx +[*config*] [[_options_]...] [_listfiles_]...
..create cxx_conf.h from [_listfile_].
..Each line in a [_listfile_] corresponds to an item to check.
..A line in a [_listfile_] takes one of the following forms:
.
..# P [_line_]
...Output [_line_] to mwg_conf.h.
...
..# D [_MACRO_] [[_value_]]
...Define or undefine the specified macro.
...-[_MACRO_] = the name of the macro to be defined.
...-[_value_] = the value of the macro. If this is omitted, the macro will be undefined.
...
..# H [_foobar.h_] [[_MWGCONF_HEADER_FOOBAR_H_]]
...Test if the specified headers are available or not.
...-[_foobar.h_] = include file to check its existence
...-[_MWGCONF_HEADER_FOOBAR_H_]
....= macro defined when [_foobar.h_] exists.
....The default value is "MWGCONF_HEADER_[_FOOBAR_H_]".
...
..# M [_name_] [_headers_] [_macro_]
...Test if the specified macro is defined or not.
...- [_name_] = name of the test.
...- [_headers_] = headers to include separated with spaces.
...- [_macro_] = macro name to test.
...MWGCONF_[_NAME_] will be defined when the expression is valid.
...
..# X [_name_] [_headers_] [_expression_]
...Test if the expression is valid or not.
...- [_name_] = name of the test.
...- [_headers_] = headers to include separated with spaces.
...- [_expression_] = expression to test.
...MWGCONF_HAS_[_NAME_] will be defined when the expression is valid.
...
..# S [_name_] [_headers_] [_source_]
...Test if the code is valid or not.
...- [_name_] = name of the test.
...- [_headers_] = headers to include separated with spaces.
...- [_source_] = C++ source code to test.
...MWGCONF_[_NAME_] will be defined when the expression is valid.
..
..Options
...[*-o FILE*]     specify output file (default: generated from \${listfiles[0]%.*})

.cxx +[*prefix*]
.cxx +[*prefix*] get
..prints the cxxprefix of the default compiler

.cxx +[*prefix*] list
..prints the list of the registered pairs of CXXKEY and CXXPREFIX.

.CXX=[_/bin/c++-compiler_] CC=[_/bin/c-compiler_] cxx +[*prefix*] add
..registers a CXXKEY and CXXPREFIX pair for the specified compilers

.cxx +[*prefix*] auto
..automatically detects compilers and registers

.cxx +[*prefix*] remove [_key/prefix_]
.cxx +[*prefix*] set-default [_key/prefix_]
.cxx +[*prefix*] set-key [_key/prefix_] [_newkey_]

.cxx +[*get*] [_varname_]
..retrieve the value of the [_varname_]:
.- cxxdir
.- env-source
.- input-charset
.- paths

EOF
