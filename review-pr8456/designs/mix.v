// Differential test: many instances of modules that create every kind of DFG
// temporary (Regularize CSE temps, Synthesize branch/join/unpack temps,
// BinToOneHot tables). Some instances get constant-tied inputs, so different
// instances of the same module end up with different temporary sets.
// Prints a running signature every cycle; base and PR logs must match.

module leaf #(
    parameter int W = 16,
    parameter bit MODE = 0
) (
    input clk,
    input [W-1:0] a,
    input [W-1:0] b,
    input [W-1:0] c,
    input [3:0] sel,
    input [2:0] idx,
    output logic [W-1:0] y0,
    output logic [W-1:0] y1,
    output logic [W-1:0] y2,
    output logic [7:0] oh,
    output logic [W-1:0] q
);
  /* verilator no_inline_module */
  // Regularize: common subexpressions used multiple times
  wire [W-1:0] s = a + b;
  wire [W-1:0] t = a ^ c;
  assign y0 = ((s ^ c) + (s & t)) ^ ((t | s) - (s ^ t));

  // Synthesize: branches, joins, partial assignments
  always_comb begin
    y1 = '0;
    if (sel[0]) y1 = a - b;
    else if (sel[1]) y1 = b ^ c;
    else y1 = s;
    if (sel[2]) y1[W/2-1:0] = y1[W/2-1:0] + t[W/2-1:0];
    if (sel[3]) y1[W-1] = ~y1[W-1];
  end

  // Unpack: concatenated LHS with compound RHS
  logic [W/2-1:0] hi, lo;
  always_comb {hi, lo} = (a * b) + (c ^ s);
  assign y2 = {lo, hi} ^ {hi, lo};

  // BinToOneHot: many compares of the same index against constants
  always_comb begin
    case (idx)
      3'd0: oh = a[7:0];
      3'd1: oh = b[7:0];
      3'd2: oh = c[7:0];
      3'd3: oh = s[7:0];
      3'd4: oh = t[7:0];
      3'd5: oh = a[7:0] ^ b[7:0];
      3'd6: oh = b[7:0] + c[7:0];
      default: oh = 8'h5a;
    endcase
  end

  // State on both edges
  always_ff @(posedge clk) q <= MODE ? (y0 ^ y1 ^ q) : (y2 + q + {{(W - 8) {1'b0}}, oh});
endmodule

module mid #(
    parameter int W = 16
) (
    input clk,
    input [W-1:0] a,
    input [W-1:0] b,
    input [W-1:0] c,
    input [3:0] sel,
    input [2:0] idx,
    output [W-1:0] sig
);
  /* verilator no_inline_module */
  wire [W-1:0] y0a, y1a, y2a, qa, y0b, y1b, y2b, qb;
  wire [7:0] oha, ohb;
  leaf #(
      .W(W),
      .MODE(0)
  ) la (
      .clk,
      .a,
      .b,
      .c,
      .sel,
      .idx,
      .y0(y0a),
      .y1(y1a),
      .y2(y2a),
      .oh(oha),
      .q(qa)
  );
  // Second instance fed from the first one's outputs: cross-instance dataflow
  leaf #(
      .W(W),
      .MODE(1)
  ) lb (
      .clk,
      .a(y0a),
      .b(y1a ^ b),
      .c(qa),
      .sel(sel ^ 4'h5),
      .idx(idx + 3'd1),
      .y0(y0b),
      .y1(y1b),
      .y2(y2b),
      .oh(ohb),
      .q(qb)
  );
  assign sig = y0a ^ y1a ^ y2a ^ qa ^ y0b ^ y1b ^ y2b ^ qb ^ {{(W - 8) {1'b0}}, oha ^ ohb};
endmodule

module t;
  bit clk = 0;
  logic [127:0] lfsr = 128'h0123456789abcdef_fedcba9876543210;
  logic [63:0] sig_acc = 0;
  int cycle = 0;

  localparam int N = 12;
  wire [63:0] sigs[N];

  for (genvar n = 0; n < N; ++n) begin : g
    localparam int W = (n % 3 == 0) ? 16 : (n % 3 == 1) ? 40 : 64;
    wire [W-1:0] a = W'(lfsr >> n);
    wire [W-1:0] b = W'(lfsr >> (2 * n + 7));
    // Every fourth instance gets a constant 'c' and constant 'sel' bits, so
    // DFG can fold away different logic in different instances of 'mid'.
    wire [W-1:0] c = (n % 4 == 3) ? '0 : W'(lfsr >> (3 * n + 11));
    wire [3:0] sel = (n % 4 == 2) ? 4'b0100 : lfsr[n+:4];
    wire [2:0] idx = (n % 5 == 1) ? 3'd3 : lfsr[2*n+:3];
    wire [W-1:0] sig;
    mid #(.W(W)) m (
        .clk,
        .a,
        .b,
        .c,
        .sel,
        .idx,
        .sig
    );
    assign sigs[n] = 64'(sig);
  end

  always #1 clk = ~clk;

  always @(posedge clk) begin
    logic [63:0] x;
    x = 0;
    for (int i = 0; i < N; ++i) x = {x[62:0], x[63]} ^ sigs[i];
    sig_acc <= {sig_acc[62:0], sig_acc[63]} ^ x;
    lfsr <= {lfsr[126:0], lfsr[127] ^ lfsr[125] ^ lfsr[100] ^ lfsr[98]};
    $display("%0d %x %x", cycle, x, sig_acc);
    cycle <= cycle + 1;
    if (cycle == 400) begin
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end
endmodule
