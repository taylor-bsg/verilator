// Differential test #2: multi-instance BinToOneHot decoders and BreakCycles
// (false combinational loops through bit slices).

module bth (
    input clk,
    input [6:0] idx,
    input [127:0] data,
    output logic [127:0] onehot,
    output logic [7:0] q
);
  /* verilator no_inline_module */
  // 128 compares of the same index -> BinToOneHot decoder table
  for (genvar i = 0; i < 128; ++i) begin : g
    assign onehot[i] = (idx == 7'(i)) & data[i];
  end
  always_ff @(posedge clk) q <= q ^ {7'd0, |onehot} ^ {1'b0, idx};
endmodule

module cyc (
    input [63:0] ra,
    input [63:0] rb,
    output [63:0] sig
);
  /* verilator no_inline_module */
  /* verilator lint_off UNOPTFLAT */
  wire [2:0] gray_sel;
  assign gray_sel = ra[2:0] ^ 3'(gray_sel[2:1]);
  wire [2:0] concat_mid;
  assign concat_mid[0] = |concat_mid[2:1];
  assign concat_mid[2:1] = {ra[2], ~ra[2]};
  wire [7:0] zx;
  assign zx[0] = ra[3];
  assign zx[3:1] = 3'(zx[0]);
  assign zx[4] = zx[1];
  assign zx[6:5] = zx[2:1];
  assign zx[7] = zx[3];
  wire [13:0] shiftr;
  assign shiftr = {shiftr[6:5], shiftr[7:6], shiftr[5:4], shiftr[3:0] >> 2, ra[3:0]};
  wire [9:0] shiftr2_a;
  wire [9:0] shiftr2_b = shiftr2_a >> 2;
  assign shiftr2_a = {ra[1:0], shiftr2_b[9:2]};
  wire [1:0] shiftr_var;
  assign shiftr_var = ra[1:0] ^ ({1'b0, shiftr_var[1]} >> rb[0]);
  wire [4:0] sx;
  assign sx = 5'(signed'({ra[0], sx[3:2]}));
  wire [2:0] and_c;
  assign and_c = ra[2:0] & 3'(and_c[2:1]);
  /* verilator lint_on UNOPTFLAT */
  assign sig = {16'd0, gray_sel, concat_mid, zx, shiftr, shiftr2_a, shiftr_var, sx, and_c} ^ rb;
endmodule

module t;
  bit clk = 0;
  logic [127:0] lfsr = 128'hdeadbeef_01234567_89abcdef_cafef00d;
  logic [63:0] acc = 0;
  int cycle = 0;
  localparam int N = 8;
  wire [63:0] sigs[N];
  for (genvar n = 0; n < N; ++n) begin : g
    wire [127:0] onehot;
    wire [7:0] q;
    wire [6:0] idx = (n == 5) ? 7'd42 : lfsr[n+:7];
    wire [127:0] data = (n % 3 == 2) ? {128{1'b1}} : {lfsr[63:0], lfsr[127:64]} ^ {128{n[0]}};
    bth b (
        .clk,
        .idx,
        .data,
        .onehot,
        .q
    );
    wire [63:0] csig;
    wire [63:0] ra = (n == 6) ? 64'h0 : (lfsr[127:64] >> n) ^ lfsr[63:0];
    cyc c (
        .ra,
        .rb(lfsr[n+:64]),
        .sig(csig)
    );
    assign sigs[n] = onehot[63:0] ^ onehot[127:64] ^ {56'd0, q} ^ csig;
  end
  always #1 clk = ~clk;
  always @(posedge clk) begin
    logic [63:0] x;
    x = 0;
    for (int i = 0; i < N; ++i) x = {x[62:0], x[63]} ^ sigs[i];
    acc <= {acc[62:0], acc[63]} ^ x;
    lfsr <= {lfsr[126:0], lfsr[127] ^ lfsr[125] ^ lfsr[100] ^ lfsr[98]};
    $display("%0d %x %x", cycle, x, acc);
    cycle <= cycle + 1;
    if (cycle == 400) begin
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end
endmodule
