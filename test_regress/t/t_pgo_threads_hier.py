#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2025 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap

import shutil

test.scenarios('vltmt')
test.top_filename = "t/t_hier_block_perf.v"
cycles = 100
test.sim_time = cycles * 10 + 1000

threads = 2
config_file = test.t_dir + "/" + test.name + ".vlt"
flags = [config_file, "--hierarchical", "-Wno-UNOPTFLAT", "-DSIM_CYCLES=" + str(cycles)]

test.compile(v_flags2=["--prof-pgo"] + flags, threads=threads)

# Exported ports must retain source order regardless of internal field layout.
ports = test.file_grep(test.obj_dir + '/VTest/Test.sv', r'(?s)module Test \((.*?)\);')
if ports:
    names = [port.split()[-1] for port in ports[0].split(',')]
    if names != ['rdata', 'rdata2', 'clk', 'we', 'sel', 'wdata']:
        test.error('Exported module port order differs from source: ' + str(names))

test.execute(all_run_flags=[
    "+verilator+prof+exec+start+0",
    " +verilator+prof+exec+file+/dev/null",
    " +verilator+prof+vlt+file+" + test.obj_dir + "/profile.vlt"])  # yapf:disable

test.file_grep(test.obj_dir + "/profile.vlt", r'profile_data -model "VTest"')
test.file_grep(test.obj_dir + "/profile.vlt", r'profile_data -model "VCheck"')
test.file_grep(test.obj_dir + "/profile.vlt", r'profile_data -model "VCoreHier"')
test.file_grep(test.obj_dir + "/profile.vlt", r'profile_data -model "V' + test.name + '"')

# Check for cost rollovers
test.file_grep_not(test.obj_dir + "/profile.vlt", r'.*cost 64\'d\d{18}.*')

# PGO changes field layout, but must preserve the exported DPI interface.
wrappers = [
    test.obj_dir + '/' + name
    for name in ('VTest/Test.sv', 'VCheck/Check.sv', 'VCoreHier/CoreHier.sv')
]
for filename in wrappers:
    shutil.copyfile(filename, filename + '.before_pgo')

# Differentiate results
test.name = test.name + "_optimized"
test.compile(
    # Intentionally no --prof-pgo here to make sure profile data can be read in
    # without it (that is: --prof-pgo has no effect on profile_data hash names)
    v_flags2=[test.obj_dir + "/profile.vlt"] + flags,
    threads=threads)

test.execute()

for filename in wrappers:
    test.files_identical(filename, filename + '.before_pgo')

test.passes()
