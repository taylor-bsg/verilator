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

# Keep the path outside the group visible to the partitioner.
test.compile(
    verilator_flags2=["--stats", "-fno-dfg", "-fno-gate", "-CFLAGS", "-DVL_THREADS_SERIAL_COST=0"],
    threads=2)

test.execute()

# Separate ready source logic from logic awaiting an external group entry.
# The feedback instance must also split across the path leaving and re-entering it.
test.file_grep(test.stats, r'MTask graph, threads_group parts\s+(\d+)', 4)

test.passes()
