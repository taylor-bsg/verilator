// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

interface channel;
  bit data;
endinterface

typedef int wildcard_t [*];
typedef virtual channel channel_t;

module t;
  leaf #(.T(wildcard_t)) wildcard_array ();
  leaf #(.T(channel_t)) virtual_interface ();
endmodule

module leaf #(
    parameter type T = int
);
  /*verilator hier_block*/
  T state;
endmodule
