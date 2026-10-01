// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d: %m got=%0d exp=%0d (%s !== %s)\n", `__FILE__, `__LINE__, (gotv), (expv), `"gotv`", `"expv`"); `stop; end while (0);
// verilog_format: on

package alpha;
  typedef struct packed {logic [6:0] value;} record_t;
  typedef enum logic [2:0] {
    ZERO = 0,
    ONE = 1,
    FIVE = 5
  } enum_t;
endpackage
package beta;
  typedef struct packed {logic [6:0] value;} record_t;
  typedef enum logic [2:0] {
    ZERO = 0,
    ONE = 1,
    FIVE = 5
  } enum_t;
endpackage
package \escaped.package ;
  typedef struct packed {logic [6:0] value;} \escaped.record ;
endpackage
typedef struct packed {logic [6:0] value;} unit_record_t;
typedef enum logic [2:0] {
  UNIT_ZERO = 0,
  UNIT_ONE = 1,
  UNIT_FIVE = 5
} unit_enum_t;

module t (
    input clk
);
  int cycles = 0;
  int data[10], result[10], names[10];
  bit same_type[10];
  localparam int CODES[10] = '{11, 11, 22, 12, 32, 44, 55, 66, 45, 72};
  nominal #(
      .T(alpha::record_t),
      .U(alpha::record_t)
  ) child0 (
      .clk,
      .data(data[0]),
      .result(result[0]),
      .names(names[0]),
      .same_type(same_type[0])
  );
  nominal #(
      .T(alpha::record_t),
      .U(alpha::record_t)
  ) child1 (
      .clk,
      .data(data[1]),
      .result(result[1]),
      .names(names[1]),
      .same_type(same_type[1])
  );
  nominal #(
      .T(beta::record_t),
      .U(beta::record_t)
  ) child2 (
      .clk,
      .data(data[2]),
      .result(result[2]),
      .names(names[2]),
      .same_type(same_type[2])
  );
  nominal #(
      .T(alpha::record_t),
      .U(beta::record_t)
  ) child3 (
      .clk,
      .data(data[3]),
      .result(result[3]),
      .names(names[3]),
      .same_type(same_type[3])
  );
  nominal #(
      .T(unit_record_t),
      .U(beta::record_t)
  ) child4 (
      .clk,
      .data(data[4]),
      .result(result[4]),
      .names(names[4]),
      .same_type(same_type[4])
  );
  nominal #(
      .T(alpha::enum_t),
      .U(alpha::enum_t)
  ) child5 (
      .clk,
      .data(data[5]),
      .result(result[5]),
      .names(names[5]),
      .same_type(same_type[5])
  );
  nominal #(
      .T(beta::enum_t),
      .U(beta::enum_t)
  ) child6 (
      .clk,
      .data(data[6]),
      .result(result[6]),
      .names(names[6]),
      .same_type(same_type[6])
  );
  nominal #(
      .T(unit_enum_t),
      .U(unit_enum_t)
  ) child7 (
      .clk,
      .data(data[7]),
      .result(result[7]),
      .names(names[7]),
      .same_type(same_type[7])
  );
  nominal #(
      .T(alpha::enum_t),
      .U(beta::enum_t)
  ) child8 (
      .clk,
      .data(data[8]),
      .result(result[8]),
      .names(names[8]),
      .same_type(same_type[8])
  );
  nominal #(
      .T(\escaped.package ::\escaped.record ),
      .U(beta::record_t)
  ) child9 (
      .clk,
      .data(data[9]),
      .result(result[9]),
      .names(names[9]),
      .same_type(same_type[9])
  );
  for (genvar i = 0; i < 10; ++i) begin
    nominal_checked #(
        .CODE(CODES[i]),
        .ID(i + 1),
        .MASK(i < 5 || i == 9 ? 127 : 7)
    ) check (
        .clk,
        .data(data[i]),
        .result(result[i]),
        .names(names[i]),
        .same_type(same_type[i])
    );
  end
  always @(negedge clk) begin
    cycles <= cycles + 1;
    if (cycles == 100) begin
`ifdef VERILATOR
`ifdef ROOT_THREADS
      int model_threads;
      model_threads = $c("Verilated::threadContextp()->threadsInModels()");
      `checkd(model_threads, `ROOT_THREADS + 10);
`endif
`endif
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end
endmodule

// Only T and U cross the hierarchy boundary. CODE and ID remain in the parent,
// so equal-shaped nominal types cannot be distinguished by value parameters.
module nominal_checked #(
    parameter int CODE = 0,
    ID = 0,
    MASK = 127
) (
    input clk,
    output int data,
    input int result,
    names,
    input bit same_type
);
  int cycles = 0;
  int ref_t = 0, ref_u = 0;
  assign data = 7 * cycles + 13 * ID;
  always @(posedge clk) begin
    cycles <= cycles + 1;
    ref_t <= (ref_t + data) & MASK;
    ref_u <= (ref_u + data + 3) & MASK;
  end
  always @(negedge clk) begin
    `checkd(names, CODE);
    `checkd(same_type, CODE/ 10 == CODE % 10);
    `checkd(result, ref_t + ref_u);
  end
endmodule

module nominal #(
    parameter type T = logic [6:0],
    U = T
) (
    input clk,
    input int data,
    output int result,
    names,
    output bit same_type
);
  /*verilator hier_block*/
  T state_t = T'(0);
  U state_u = U'(0);
  function automatic int name_code(input string type_name);
    if (type_name == $typename(alpha::record_t)) return 1;
    if (type_name == $typename(beta::record_t)) return 2;
    if (type_name == $typename(unit_record_t)) return 3;
    if (type_name == $typename(alpha::enum_t)) return 4;
    if (type_name == $typename(beta::enum_t)) return 5;
    if (type_name == $typename(unit_enum_t)) return 6;
    if (type_name == $typename(\escaped.package ::\escaped.record )) return 7;
    return 0;
  endfunction
  assign names = 10 * name_code($typename(T)) + name_code($typename(U));
  assign same_type = $typename(T) == $typename(U);
  assign result = int'($unsigned(state_t)) + int'($unsigned(state_u));
  always @(posedge clk) begin
    state_t <= T'(int'($unsigned(state_t)) + data);
    state_u <= U'(int'($unsigned(state_u)) + data + 3);
  end
endmodule
