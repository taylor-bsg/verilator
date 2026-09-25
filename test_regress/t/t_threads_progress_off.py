#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap

test.scenarios('vltmt')
test.top_filename = 't/t_threads_progress.v'
test.compile(make_top_shell=False,
             make_main=False,
             threads=2,
             verilator_flags2=['--cc --no-threads-progress --exe', 't/t_threads_progress.cpp'])
test.execute()
test.passes()
