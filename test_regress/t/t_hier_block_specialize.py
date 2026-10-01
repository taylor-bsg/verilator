#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap
import hier_block_check

test.scenarios('vlt_all')
test.sim_time = 2000
test.top_filename = 't/t_hier_block_specialize.v'
threads = 2 if test.vltmt else 1
test.compile(verilator_flags2=['--hierarchical', '-DROOT_THREADS=' + str(threads)],
             threads=threads)
test.execute()
hier_block_check.check_libraries(test)
test.passes()
