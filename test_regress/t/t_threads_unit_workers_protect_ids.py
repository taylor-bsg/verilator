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
test.top_filename = "t/t_threads_unit_workers.v"

test.compile(verilator_flags2=[
    "t/t_threads_unit_workers.vlt", "--threads-unit-list", "--protect-ids", "-CFLAGS",
    "-DVL_THREADS_SERIAL_COST=0"
],
             threads=2)
test.execute()
listing = test.obj_dir + "/" + test.vm_prefix + "__threads_units.txt"
test.file_grep_not(listing, r'worker_tile|t\.g\[')
test.file_grep_count(listing, r'^"\S+"\t\d+\t[01]\t"\S+"$', 16)
test.passes()
