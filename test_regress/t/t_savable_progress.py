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
test.top_filename = 't/t_savable.v'

test.compile(v_flags2=['--savable', '--threads-progress', '--stats'], threads=2, save_time=500)

test.execute(check_finished=False, all_run_flags=['+save_time=500'])

if not os.path.exists(test.obj_dir + "/saved.vltsv"):
    test.error("Saved.vltsv not created")

test.execute(all_run_flags=['+save_restore=1'])

test.file_grep(test.glob_one(test.obj_dir + '/*___024root.h'), r'VlMTaskProgress')
test.passes()
