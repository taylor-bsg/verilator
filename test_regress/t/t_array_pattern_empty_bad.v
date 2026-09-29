// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Michael Bedford Taylor
// SPDX-License-Identifier: CC0-1.0

module t;
  typedef struct packed {logic a;} s_t;
  typedef struct {
    int a;
    int b;
  } us_t;

  int v[2] = '{};
  s_t s = '{};
  logic [3:0] w = '{};
  us_t us = '{};
  us_t usa = '{a: 1};
endmodule
