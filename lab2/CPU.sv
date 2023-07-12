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

module CPU (
  output wire[`ADDR1_BUS_SIZE-1:0] A1, 
  inout wire[`DATA1_BUS_SIZE-1:0] D1,
  inout wire[`CTR1_BUS_SIZE-1:0] C1,
  input wire CLK,
  output wire STATS
  );
  reg[`ADDR1_BUS_SIZE-1:0] A1_out = 'bz;
  reg[`DATA1_BUS_SIZE-1:0] D1_ = 'bz;
  reg[`CTR1_BUS_SIZE-1:0] C1_ = 3'b0;
  reg stats = 0;
  assign STATS = stats;
  assign A1 = A1_out;
  assign D1 = D1_;
  assign C1 = C1_;
  reg[`DATA1_BUS_SIZE * 2 - 1 : 0] reg_a;
  reg[`DATA1_BUS_SIZE * 2 - 1 : 0] reg_b;
  reg[`DATA1_BUS_SIZE * 2 - 1 : 0] reg_c;
  reg[`DATA1_BUS_SIZE - 1 : 0] reg_d;
  int pa = 0;
  int command = 0;
  int s;
  int pb;
  int pc = `M * `K + `K * `N * 2;
  int addr_a;
  int addr_b;
  int addr_c;
  int a, b, c;
  int all_tic = 0;
  int tacts = 0;
  int fd = $fopen("input.txt", "w");

  task automatic wait_(int time_);
    for (int i = 0; i < time_; i++) begin
      @(posedge CLK);
    end
  endtask

  function int get_addr(int m, int k, int n);
    if (m == 0) return k * `K + n;
    if (m == 1) return `M * `K + 2 * (k * `N + n);
    return `M * `K + `K * `N * 2 + 4 * (k * `N + n);
  endfunction

  always @(posedge CLK && 1) tacts++;

  always @(posedge CLK) begin
    $display("MAIN------------------------------------------------------------------------------------------------------------");
    C1_ = 0;
    wait_(2);
    pa = 0;
    pc = `M * `K + `K * `N * 2;
    wait_(1); // int y = 0;
    for (int y = 0; y < `M; y++) begin
      wait_(1); // int x = 0;
      for (int x = 0; x < `N; x++) begin
        pb = `M * `K;
        s = 0;
        wait_(2);
        wait_(1); // int k = 0;
        for (int k = 0; k < `K; k++) begin
          read(pa + k, 1);
          all_tic++;
          answer_from();
          all_tic++;
          wait_(1);
          read(pb + x * 2, 2);
          answer_from();
          a = reg_a;
          b = reg_b;
          s += a * b;
          wait_(8);
          pb += `N * 2;
          wait_(1); // new iteration
        end
        addr_c = get_addr(2, y, x);
        reg_c = s;
        all_tic++;
        write(pc + x * 4, 7);
        answer_from();
        wait_(1);
        wait_(1); // new iteration
      end
      pa += `K;
      pc += `N * 4;
      wait_(2);
      if (y % 10 == 0) begin
        $display(y, tacts);
        stats = 1;
      end
      wait_(1); // new iteration
      stats = 0;
    end
    $display("Time: %0d", tacts);
    stats = 1;
    wait_(1);
    for (int y = 0; y < `M; y++) begin
      for (int x = 0; x < `N; x++) begin
        addr_c = get_addr(2, y, x);
        read(addr_c, 3);
        answer_from();
        $fdisplay(fd, "%d", reg_c);
        wait_(1);
      end
    end
    $fclose(fd);
    $finish;
  end

  task automatic inval(int A);
    C1_ = 4;
    A1_out = A >> `CACHE_OFFSET_SIZE;
    wait_(1);
    C1_ = 'bz;
    A1_out = 'bz;
    wait(C1 === 7);
    C1_ = 0;
  endtask

  task automatic answer_from();
    wait(C1 === 7);
    if (command == 1) begin
      reg_a = D1;
    end else if (command == 2) begin
      reg_b = D1;
    end else if (command == 3) begin
      reg_c = D1;
      wait_(1);
      reg_c <<= 16;
      reg_c = D1 + reg_c;
    end
    C1_ = 0;
    command = 0;
  endtask

  task write(int A, int cc);
    C1_ = cc;
    command = cc;
    A1_out = A >> `CACHE_OFFSET_SIZE;
    if (cc === 5) begin
      D1_ = reg_a % (1 << 8);
      wait_(1);
      A1_out = A % (1 << `CACHE_OFFSET_SIZE);
    end else if (cc === 6) begin
      reg_d = reg_b;
      D1_ = reg_b;
      wait_(1);
      A1_out = A % (1 << `CACHE_OFFSET_SIZE);
    end else if (cc === 7) begin
      reg_d = reg_c >> `DATA1_BUS_SIZE; 
      D1_ = reg_d;
      wait_(1);
      A1_out = A % (1 << `CACHE_OFFSET_SIZE);
      reg_d = reg_c % (1 << `DATA1_BUS_SIZE);
      D1_ = reg_d;
    end
    wait_(1);
    D1_ = 'bz;
    C1_ = 'bz;
    A1_out = 'bz;
  endtask

  task read(int A, int cc);
    C1_ = cc;
    command = cc;
    A1_out = A >> `CACHE_OFFSET_SIZE;
    wait_(1);
    A1_out = A % (1 << `CACHE_OFFSET_SIZE);
    wait_(1);
    C1_ = 'bz;
    A1_out = 'bz;
  endtask
endmodule