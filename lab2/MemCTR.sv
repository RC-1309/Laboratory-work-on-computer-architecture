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

module MemCTR (
  input wire[`ADDR2_BUS_SIZE-1:0] A2, 
  inout wire[`DATA2_BUS_SIZE-1:0] D2,
  inout wire[`CTR2_BUS_SIZE-1:0] C2,
  input wire CLK,
  input wire M_DUMP,
  input wire RESET
  );
  reg[`DATA2_BUS_SIZE-1:0] D2_ = 'bz;
  reg[`CTR2_BUS_SIZE-1:0] C2_ = 'bz;
  assign D2 = D2_;
  assign C2 = C2_;
  reg[7:0] mem[0:`MEM_SIZE-1];
  integer SEED = 225526;
  int fd;
  int a2;

  always @(posedge RESET) begin
    reset();
  end

  always @(posedge M_DUMP) begin
    dump();
  end

  always @(posedge CLK && C2 === 2) begin
    a2 = A2;
    C2_ = 0;
    wait_(100);
    C2_ = 1;
    for (int i = 7; i >= 0; i--) begin
      D2_ = mem[a2 * `CACHE_LINE_SIZE + i * 2] + (mem[a2 * `CACHE_LINE_SIZE + i * 2 + 1] << 8);
      wait_(1);
    end
    D2_ = 'bz;
    C2_ = 'bz;
  end

  always @(posedge CLK && C2 === 3) begin
    a2 = A2;
    for (int i = 7; i >= 0; i--) begin
      mem[a2 * `CACHE_LINE_SIZE + i * 2] = D2 % (1 << 8);
      mem[a2 * `CACHE_LINE_SIZE + i * 2 + 1] = D2 >> 8;
      wait_(1);
    end
    C2_ = 0;
    wait_(92);
    C2_ = 1;
    wait_(1);
    C2_ = 'bz;
  end

  task automatic reset();
    for (int i = 0; i < `MEM_SIZE; i++) begin
      mem[i] = $random(SEED)>>16;
    end
  endtask

  task automatic wait_(int time_);
    for (int i = 0; i < time_; i++) begin
      @(posedge CLK);
    end
  endtask

  task automatic dump();
    fd = $fopen("output.txt", "w");
    for (int i = 0; i < `MEM_SIZE; i++)
      $fdisplay(fd, "%b", mem[i]);
    $fclose(fd);
  endtask

endmodule