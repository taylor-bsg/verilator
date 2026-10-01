// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d: %m got=%0d exp=%0d (%s !== %s)\n", `__FILE__, `__LINE__, (gotv), (expv), `"gotv`", `"expv`"); `stop; end while (0);
// verilog_format: on

typedef logic signed [6:0] signed_t;
typedef struct packed {
  logic [3:0] high;
  logic signed [2:0] low;
} fields_a_t;
typedef struct packed {
  logic signed [2:0] low;
  logic [3:0] high;
} fields_b_t;

module t (
    input clk
);
  int cycles = 0;
  checked #(
      .ID(1),
      .DEFAULTS(1)
  ) c0 (
      .*
  );
  checked #(.ID(2)) c1 (.*);
  checked #(.ID(3)) c2 (.*);  // Same library, independent state and input.
  checked #(
      .ID(4),
      .K(4)
  ) c3 (
      .*
  );
  checked #(
      .ID(5),
      .T(logic [6:0])
  ) c4 (
      .*
  );  // Same width, different signedness.
  checked #(
      .ID(6),
      .T(logic signed [14:0]),
      .U(logic [30:0])
  ) c5 (
      .*
  );
  checked #(
      .ID(7),
      .T(logic signed [32:0]),
      .U(logic [6:0])
  ) c6 (
      .*
  );
  checked #(
      .ID(8),
      .T(signed_t)
  ) c7 (
      .*
  );
  checked #(
      .ID(9),
      .R(2.5),
      .TAG("different,tag"),
      .BIG(65'h123456789abcdef01)
  ) c8 (
      .*
  );
  checked #(
      .ID(10),
      .K(-17),
      .T(logic [30:0]),
      .U(logic [32:0])
  ) c9 (
      .*
  );
  checked #(
      .ID(11),
      .T(fields_a_t),
      .FIELDS(1)
  ) c10 (
      .*
  );
  checked #(
      .ID(12),
      .T(fields_b_t),
      .FIELDS(1)
  ) c11 (
      .*
  );
  longint a0, a1;
  type_only #(
      .T(logic signed [6:0])
  ) type0 (
      .clk,
      .data(cycles),
      .out(a0)
  );
  type_only #(
      .T(logic [6:0])
  ) type1 (
      .clk,
      .data(cycles),
      .out(a1)
  );
  int v0, v1, plain_out;
  value_only value0 (
      .clk,
      .data(cycles),
      .out(v0)
  );
  value_only #(
      .K(3)
  ) value1 (
      .clk,
      .data(cycles),
      .out(v1)
  );
  plain plain0 (
      .clk,
      .data(cycles),
      .out(plain_out)
  );
  int bv, bt, ot;
  branch_value #(
      .K(9)
  ) b0 (
      .clk,
      .data(cycles),
      .out(bv)
  );
  branch_type #(
      .T(signed_t)
  ) b1 (
      .clk,
      .data(cycles),
      .out(bt)
  );
  outer #(
      .T(logic [14:0])
  ) b2 (
      .clk,
      .data(cycles),
      .out(ot)
  );
  always @(negedge clk) begin
    if (cycles > 0) begin
      `checkd(a0, longint'(7'(7'(cycles) >>> 1)));
      `checkd(a1, longint'($unsigned(7'(7'(cycles) >> 1))));
      `checkd(v0, cycles + 3);
      `checkd(v1, cycles + 3);
      `checkd(plain_out, cycles + 1);
      `checkd(bv, cycles + 9);
      `checkd(bt, cycles + 7);
      `checkd(ot, 2 * cycles + 24);
    end
    cycles <= cycles + 1;
    if (cycles == 150) begin
`ifdef VERILATOR
      // Archives or DPI declarations alone cannot satisfy this check. Each library
      // instance constructs a model, including repeated and nested instances.
      int model_threads;
      model_threads = $c("Verilated::threadContextp()->threadsInModels()");
      `checkd(model_threads, `ROOT_THREADS + 30);
`endif
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end
endmodule

// The reference runs outside the leaf library, using a masked 64-bit accumulator
// and explicit sign extension. Each repeated instance gets different inputs.
module checked #(
    parameter type T = logic signed [6:0],
    U = logic [14:0],
    parameter int K = 3,
    ID = 1,
    parameter real R = 1.25,
    parameter string TAG = "a,b'\\z",
    parameter logic [64:0] BIG = 65'h1ffffffffffffffff,
    parameter bit DEFAULTS = 0,
    FIELDS = 0
) (
    input clk
);
  int cycle = 0;
  int data;
  bit reset, enable;
  longint a, b;
  longint unsigned ref_a = 0, ref_b = 0;
  localparam longint unsigned MASK_A = (64'd1 << $bits(T)) - 1;
  localparam longint unsigned MASK_B = (64'd1 << $bits(U)) - 1;
  localparam int STEP = K + $rtoi(R * 4) + TAG.len() + int'(BIG >> 64);
  assign data = (cycle * 37 + ID * 101) ^ (cycle << (ID % 7));
  assign reset = (cycle % (17 + ID)) == 0;
  assign enable = (cycle % (3 + ID)) != 1;
  if (DEFAULTS) begin
    leaf dut (
        .clk,
        .data,
        .reset,
        .enable,
        .a,
        .b
    );
  end
  else begin
    leaf #(
        .T(T),
        .U(U),
        .K(K),
        .R(R),
        .TAG(TAG),
        .BIG(BIG),
        .FIELDS(FIELDS)
    ) dut (
        .clk,
        .data,
        .reset,
        .enable,
        .a,
        .b
    );
  end
  always @(posedge clk) begin
    if (reset) begin
      ref_a <= MASK_A;
      ref_b <= 0;
    end
    else if (enable) begin
      ref_a <= (ref_a + 64'(data) + 64'(STEP)) & MASK_A;
      ref_b <= (ref_b ^ (64'(data) << 1)) & MASK_B;
    end
  end
  if (FIELDS) begin
    T fields;
    assign fields = T'(ref_a);
    always @(negedge clk) `checkd(a, longint'(fields.low));
  end
  else begin
    longint extended;
    assign extended = (T'(-1) < T'(0)) && ref_a[$bits(
        T
    )-1] ? longint'(ref_a | ~MASK_A) : longint'(ref_a);
    always @(negedge clk) `checkd(a, extended >>> 1);
  end
  always @(negedge clk) begin
    `checkd(b, longint'(ref_b));
    cycle <= cycle + 1;
  end
endmodule

module leaf #(
    parameter type T = logic signed [6:0],
    U = logic [$bits(T)+7:0],
    parameter int K = 3,
    parameter real R = 1.25,
    parameter string TAG = "a,b'\\z",
    parameter logic [64:0] BIG = 65'h1ffffffffffffffff,
    parameter bit FIELDS = 0
) (
    input clk,
    reset,
    enable,
    input int data,
    output longint a,
    b
);
  /*verilator hier_block*/
  T acc;
  U other;
  always @(posedge clk) begin
    if (reset) begin
      acc <= T'(-1);
      other <= U'(0);
    end
    else if (enable) begin
      acc <= T'(acc + T'(data + K + $rtoi(R * 4) + TAG.len() + int'(BIG >> 64)));
      other <= other ^ U'(data << 1);
    end
  end
  if (FIELDS) assign a = longint'(acc.low);
  else assign a = longint'(T'(acc >>> 1));
  assign b = longint'($unsigned(other));
endmodule

module type_only #(
    parameter type T = logic [6:0]
) (
    input clk,
    input int data,
    output longint out
);
  /*verilator hier_block*/
  T state;
  always @(posedge clk) state <= T'(data);
  assign out = longint'(T'(state >>> 1));
endmodule

module value_only #(
    parameter int K = 3
) (
    input clk,
    input int data,
    output int out
);
  /*verilator hier_block*/
  always @(posedge clk) out <= data + K;
endmodule

module plain (
    input clk,
    input int data,
    output int out
);
  /*verilator hier_block*/
  always @(posedge clk) out <= data + 1;
endmodule

// This intermediate child has no type file but consumes type libraries.
module branch_value #(
    parameter int K = 9
) (
    input clk,
    input int data,
    output int out
);
  /*verilator hier_block*/
  checked #(
      .ID(13),
      .K(K)
  ) c0 (
      .*
  );
  checked #(
      .ID(14),
      .K(K),
      .T(logic [6:0])
  ) c1 (
      .*
  );
  always @(posedge clk) out <= data + K;
endmodule

// The file must apply only to this top, despite the reused formal name T.
module branch_type #(
    parameter type T = logic [4:0]
) (
    input clk,
    input int data,
    output int out
);
  /*verilator hier_block*/
  checked #(
      .ID(15),
      .T(T)
  ) c0 (
      .*
  );
  checked #(
      .ID(16),
      .T(T),
      .K(4)
  ) c1 (
      .*
  );
  always @(posedge clk) out <= data + $bits(T);
endmodule

module outer #(
    parameter type T = logic [4:0]
) (
    input clk,
    input int data,
    output int out
);
  /*verilator hier_block*/
  int a, b;
  branch_value #(
      .K(9)
  ) b0 (
      .clk,
      .data,
      .out(a)
  );
  branch_type #(
      .T(T)
  ) b1 (
      .clk,
      .data,
      .out(b)
  );
  assign out = a + b;
endmodule
