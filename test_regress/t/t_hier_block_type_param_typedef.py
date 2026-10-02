#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2024 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap
import hier_block_check

test.scenarios('simulator')

# Stale wrappers or call sites from another compiler must not satisfy the checks.
test.clean_objs()
test.compile(verilator_flags2=['--hierarchical'])

test.execute()

if test.vlt:
    hier_block_check.check_libraries(test)

test.passes()
