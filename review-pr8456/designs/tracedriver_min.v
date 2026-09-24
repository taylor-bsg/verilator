module t (input [63:0] rand_a, output [7:0] out);
  /* verilator lint_off UNOPTFLAT */
  wire logic [7:0] arr [2];
  assign arr[0][3:0] = rand_a[3:0];
  assign arr[0][7:6] = rand_a[7:6];  // bits [5:4] never driven, keeps the splice
  assign arr[1] = {arr[0][7:6], 2'b00, arr[0][3:0]} + 8'd1;
  assign out = arr[1];
endmodule
