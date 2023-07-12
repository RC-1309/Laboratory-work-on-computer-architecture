`define CACHE_WAY 2
`define CACHE_TAG_SIZE 10
`define CACHE_LINE_SIZE 16
`define CACHE_LINE_COUNT 64
`define MEM_SIZE (1 << 19)
`define CACHE_SIZE (1 << 10)
`define CACHE_SETS_COUNT 32
`define CACHE_SET_SIZE 5
`define CACHE_OFFSET_SIZE 4
`define CACHE_ADDR_SIZE 19
`define ADDR1_BUS_SIZE 15
`define ADDR2_BUS_SIZE 15
`define DATA1_BUS_SIZE 16
`define DATA2_BUS_SIZE 16
`define CTR1_BUS_SIZE 3
`define CTR2_BUS_SIZE 2
`define M 64
`define N 60
`define K 32

`include "MemCTR.sv"
`include "cache.sv"
`include "CPU.sv"

module test #(parameter _SEED = 225526);
  integer SEED = _SEED;
  byte mem[0:`MEM_SIZE-1];
  integer i = 0;
  initial begin
    for (i = 0; i < `MEM_SIZE; i += 1) begin
      mem[i] = $random(SEED)>>16;
    end
  end
endmodule

module testbench;
  int count = 0;
  reg clk = 0;
  reg c_dum = 0;
  reg m_dum = 0;
  reg res = 0;
  wire STATS;
  wire C_DUM;
  wire M_DUM;
  wire RES;
  wire CLK;
  wire[`ADDR1_BUS_SIZE-1:0] A1;
  wire[`DATA1_BUS_SIZE-1:0] D1;
  wire[`CTR1_BUS_SIZE-1:0] C1;
  wire[`ADDR2_BUS_SIZE-1:0] A2;
  wire[`DATA2_BUS_SIZE-1:0] D2;
  wire[`CTR2_BUS_SIZE-1:0] C2;
  assign CLK = clk;
  assign C_DUM = c_dum;
  assign M_DUM = m_dum;
  assign RES = res;

  CPU cpu(.A1(A1), .D1(D1), .C1(C1), .CLK(CLK), .STATS(STATS));

  cache CACHE(.A1(A1), .A2(A2), .C1(C1), .C2(C2), .D1(D1), .D2(D2), .CLK(CLK), .C_DUMP(C_DUM), .RESET(RES), .STATS(STATS));
  
  MemCTR MEM(.A2(A2), .D2(D2), .C2(C2), .CLK(CLK), .M_DUMP(M_DUM), .RESET(RES));

  always #1 clk = ~clk;

  initial begin
    res = 1;
    #1;
    res = 0;
  end
  
  always @(posedge CLK) begin
    count++;
  end
endmodule