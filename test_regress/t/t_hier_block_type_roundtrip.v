// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d: %m got=%0d exp=%0d (%s !== %s)\n", `__FILE__, `__LINE__, (gotv), (expv), `"gotv`", `"expv`"); `stop; end while (0);
// verilog_format: on

typedef struct packed signed {logic [6:0] bits;} signed_struct_t;
typedef struct packed unsigned {logic [6:0] bits;} unsigned_struct_t;
typedef logic [6:0] two_t[2];
typedef logic [6:0] three_t[3];
typedef logic [6:0] ascending_t[1:3];
typedef logic [6:0] descending_t[3:1];
typedef int dynamic_t[];
typedef int queue_t[$:3];
typedef int associative_t[string];

module t (
    input clk
);
  int cycle = 0;
  checked_scalar #(
      .T(byte unsigned),
      .W(8),
      .ID(1)
  ) a0 (
      .*
  );
  checked_scalar #(
      .T(shortint unsigned),
      .W(16),
      .ID(2)
  ) a1 (
      .*
  );
  checked_scalar #(
      .T(int unsigned),
      .W(32),
      .ID(3)
  ) a2 (
      .*
  );
  checked_scalar #(
      .T(longint unsigned),
      .W(64),
      .ID(4)
  ) a3 (
      .*
  );
  checked_scalar #(
      .T(integer unsigned),
      .W(32),
      .ID(5)
  ) a4 (
      .*
  );
  checked_scalar #(
      .T(int signed),
      .W(32),
      .SIGNED(1),
      .ID(6)
  ) a5 (
      .*
  );
  checked_scalar #(
      .T(signed_struct_t),
      .W(7),
      .SIGNED(1),
      .ID(7)
  ) s0 (
      .*
  );
  checked_scalar #(
      .T(unsigned_struct_t),
      .W(7),
      .ID(8)
  ) s1 (
      .*
  );
  checked_scalar #(
      .T(signed_struct_t),
      .W(7),
      .SIGNED(1),
      .ID(9)
  ) s2 (
      .*
  );
  checked_scalar #(
      .T(logic [2:0][6:0]),
      .W(21),
      .ID(10)
  ) p0 (
      .*
  );
  checked_array #(
      .T(two_t),
      .HI(1),
      .ID(11)
  ) u0 (
      .*
  );
  checked_array #(
      .T(three_t),
      .HI(2),
      .ID(12)
  ) u1 (
      .*
  );
  checked_array #(
      .T(ascending_t),
      .LO(1),
      .HI(3),
      .ID(13)
  ) u2 (
      .*
  );
  checked_array #(
      .T(descending_t),
      .LO(1),
      .HI(3),
      .ID(14)
  ) u3 (
      .*
  );
  int names[6];
  int name_reference[6] = '{default: 0};
  localparam string N0 = $typename(
      dynamic_t
  ), N1 = $typename(
      queue_t
  ), N2 = $typename(
      associative_t
  ), N3 = $typename(
      real
  ), N4 = $typename(
      string
  ), N5 = $typename(
      chandle
  );
  localparam int NAME_LENGTHS[6] = '{N0.len(), N1.len(), N2.len(), N3.len(), N4.len(), N5.len()};
  name_leaf #(
      .T(dynamic_t)
  ) n0 (
      .clk,
      .data(cycle),
      .out(names[0])
  );
  name_leaf #(
      .T(queue_t)
  ) n1 (
      .clk,
      .data(cycle),
      .out(names[1])
  );
  name_leaf #(
      .T(associative_t)
  ) n2 (
      .clk,
      .data(cycle),
      .out(names[2])
  );
  name_leaf #(
      .T(real)
  ) n3 (
      .clk,
      .data(cycle),
      .out(names[3])
  );
  name_leaf #(
      .T(string)
  ) n4 (
      .clk,
      .data(cycle),
      .out(names[4])
  );
  name_leaf #(
      .T(chandle)
  ) n5 (
      .clk,
      .data(cycle),
      .out(names[5])
  );
  always @(posedge clk) begin
    foreach (name_reference[i]) name_reference[i] <= name_reference[i] + cycle + NAME_LENGTHS[i];
  end
  always @(negedge clk) begin
    foreach (names[i]) `checkd(names[i], name_reference[i]);
    cycle <= cycle + 1;
    if (cycle == 150) begin
`ifdef VERILATOR
      int model_threads;
      model_threads = $c("Verilated::threadContextp()->threadsInModels()");
      `checkd(model_threads, `ROOT_THREADS + 20);
`endif
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end
endmodule

module name_leaf #(
    parameter type T = int
) (
    input clk,
    input int data,
    output int out
);
  /*verilator hier_block*/
  localparam string NAME = $typename(T);
  int state = 0;
  always @(posedge clk) state <= state + data + NAME.len();
  assign out = state;
endmodule

module checked_scalar #(
    parameter type T = int unsigned,
    parameter int W = 32,
    ID = 1,
    parameter bit SIGNED = 0
) (
    input clk
);
  int cycle = 0;
  logic reset, enable;
  longint unsigned data, reference = 0;
  longint signed out, expected;
  localparam longint unsigned MASK = 64'hffffffffffffffff >> (64 - W);
  assign data = (64'h8000000000000000 >> (64 - W)) | (64'(cycle * 177 + ID * 43));
  assign reset = cycle % (19 + ID) == 0;
  assign enable = cycle % (3 + ID) != 1;
  scalar_leaf #(.T(T)) dut (.*);
  always @(posedge clk) begin
    if (reset) reference <= MASK;
    else if (enable) reference <= (reference + data) & MASK;
  end
  assign expected = SIGNED && reference[W-1]
                    ? longint'(reference | ~MASK) >>> 1 : longint'(reference >> 1);
  always @(negedge clk) begin
    `checkd(out, expected);
    cycle <= cycle + 1;
  end
endmodule

module scalar_leaf #(
    parameter type T = int unsigned
) (
    input clk,
    reset,
    enable,
    input longint unsigned data,
    output longint signed out
);
  /*verilator hier_block*/
  T state;
  always @(posedge clk) begin
    if (reset) state <= T'('1);
    else if (enable) state <= T'(state + T'(data));
  end
  assign out = longint'(T'(state >>> 1));
endmodule

module checked_array #(
    parameter type T = two_t,
    parameter int LO = 0,
    HI = 1,
    ID = 1
) (
    input clk
);
  int cycle = 0;
  int data, out, expected;
  int reference[LO:HI];
  logic reset, enable;
  assign data = cycle * 37 + ID * 53;
  assign reset = cycle % (19 + ID) == 0;
  assign enable = cycle % (3 + ID) != 1;
  array_leaf #(.T(T)) dut (.*);
  always @(posedge clk) begin
    foreach (reference[i]) begin
      if (reset) reference[i] <= (i * 19 + 3) & 127;
      else if (enable) reference[i] <= (reference[i] + data + i) & 127;
    end
  end
  always_comb begin
    expected = 0;
    foreach (reference[i]) expected += reference[i] * (i + 1);
  end
  always @(negedge clk) begin
    `checkd(out, expected);
    cycle <= cycle + 1;
  end
endmodule

module array_leaf #(
    parameter type T = two_t
) (
    input clk,
    reset,
    enable,
    input int data,
    output int out
);
  /*verilator hier_block*/
  T state;
  always @(posedge clk) begin
    foreach (state[i]) begin
      if (reset) state[i] <= 7'(i * 19 + 3);
      else if (enable) state[i] <= 7'(int'(state[i]) + data + i);
    end
  end
  always_comb begin
    out = 0;
    foreach (state[i]) out += int'(state[i]) * (i + 1);
  end
endmodule
