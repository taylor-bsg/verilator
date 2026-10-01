#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test hierarchical library checks
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import re


def check_libraries(test):
    """Require creation and execution calls for each planned library.

    Discover symbols from wrappers rather than hard-coding generated names.
    Each block has its own output directory immediately below the parent.
    """
    sources = test.glob_some(test.obj_dir + '/*.cpp') + test.glob_some(test.obj_dir + '/*/*.cpp')
    wrappers = test.glob_some(test.obj_dir + '/*/*.sv')
    for wrapper in wrappers:
        text = test.file_contents(wrapper)
        symbols = re.findall(
            r'function\s+\w+\s+(\w+_protectlib_(?:create|combo_update|seq_update))\s*\(', text)
        if not symbols:
            test.error('No library entry points in ' + wrapper)
        for symbol in symbols:
            test.file_grep_any(sources, r'=\s*' + re.escape(symbol) + r'\(')
