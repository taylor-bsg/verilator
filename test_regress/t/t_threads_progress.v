// DESCRIPTION: Verilator: Verilog Test module
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Michael Bedford Taylor
// SPDX-License-Identifier: CC0-1.0

module t (
  input logic clk,
  input logic rst,
  input int unsigned seed,
  output int unsigned result[8]
);
  function automatic int unsigned mix(input int unsigned a, b);
    int unsigned x;
    x = a ^ b;
    for (int j = 0; j < 24; ++j)
      x = ((x << 5) | (x >> 27)) * 32'h9e3779b9 + b + 32'(j);
    return x;
  endfunction

  for (genvar i = 0; i < 8; ++i) begin : lanes
    int unsigned next_value;
    always_comb next_value = mix(result[i], result[(i + 1) % 8] ^ seed);
    always @(posedge clk)
      if (rst) result[i] <= seed ^ (32'h1234567 * (i + 1));
      else result[i] <= next_value;
  end
endmodule
