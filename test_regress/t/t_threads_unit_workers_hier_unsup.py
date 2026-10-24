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
test.top_filename = "t/t_threads_unit.v"
test.clean_objs()
test.write_wholefile(
    test.obj_dir + "/workers.vlt", '''`verilator_config
threads_unit -module "tile" -workers 4->2: { 0 0 1 1 }
''')
test.compile(verilator_flags2=[
    test.obj_dir + "/workers.vlt", "--hierarchical", "+define+TEST_VLT",
    "+define+TEST_HIERARCHICAL"
],
             threads=2,
             fails='any',
             expect_filename=test.golden_filename)
test.passes()
