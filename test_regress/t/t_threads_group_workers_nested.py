#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap

test.scenarios('vltmt')
test.top_filename = "t/t_threads_group.v"
test.write_wholefile(
    test.obj_dir + "/workers.vlt", '''`verilator_config
threads_group -module "tile" -workers 4->2: { 0 0 1 1 }
threads_group -module "acc" -workers 4->2: { 1 1 0 0 }
threads_group -module "hazard_group" -workers 2->2: { 0 1 }
threads_group -module "chk" -workers 1->2: { 1 }
''')
test.compile(verilator_flags2=[
    test.obj_dir + "/workers.vlt", "--stats", "-fno-dfg", "-CFLAGS", "-DVL_THREADS_SERIAL_COST=0"
],
             threads=2)
test.execute()
test.file_grep(test.stats, r'MTask graph, explicitly placed units\s+(\d+)', 11)
test.passes()
