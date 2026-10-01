// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

module t;
  Missing #(.N(1)) missing ();
  Wrong #(.N(1)) wrong ();
endmodule

module Missing #(
    parameter int N = 0
);
endmodule

module Wrong #(
    parameter int N = 0
);
endmodule

// Stand-ins for parsed generated wrappers. The metadata must be rejected before
// producing a model, even though both requested wrapper modules exist.
module Missing_lib;
endmodule

module Wrong_lib;
endmodule
