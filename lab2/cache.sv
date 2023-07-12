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

module cache (
  input wire[`ADDR1_BUS_SIZE-1:0] A1, 
  output wire[`ADDR2_BUS_SIZE-1:0] A2,
  inout wire[`DATA1_BUS_SIZE-1:0] D1,
  inout wire[`DATA2_BUS_SIZE-1:0] D2,
  inout wire[`CTR1_BUS_SIZE-1:0] C1,
  inout wire[`CTR2_BUS_SIZE-1:0] C2,  
  input wire CLK,
  input wire C_DUMP,
  input wire RESET,
  input wire STATS
  );
  reg[`ADDR2_BUS_SIZE-1:0] A2_out = 'bz;
  reg[`DATA1_BUS_SIZE-1:0] D1_ = 'bz;
  reg[`CTR1_BUS_SIZE-1:0] C1_ = 'bz;
  reg[`DATA2_BUS_SIZE-1:0] D2_ = 'bz;
  reg[`CTR2_BUS_SIZE-1:0] C2_ = 0;
  assign A2 = A2_out;
  assign D1 = D1_;
  assign D2 = D2_;
  assign C1 = C1_;
  assign C2 = C2_;


  reg[`DATA1_BUS_SIZE-1:0] save_data1;
  reg[`DATA1_BUS_SIZE-1:0] save_data2;
  reg[`CTR1_BUS_SIZE-1:0] save_c1;
  reg[`CACHE_TAG_SIZE*2-1:0] Cache_Set[0:`CACHE_SETS_COUNT-1];
  reg[7:0] Cache[0:`CACHE_SIZE-1];
  reg valid[0:`CACHE_LINE_COUNT-1];
  reg dirty[0:`CACHE_LINE_COUNT-1];
  int cache_miss = 0;
  int cache_hit = 0;
  integer SEED = 225526;
  integer fd;
  int h;
  int a1;
  int offset = 0;
  int set = 0;
  int tag = 0;
  int tags_line[0:`CACHE_WAY - 1];
  int idx = 0;
  int pos;
  int flag;

  initial begin
    for (int i = 0; i < `CACHE_LINE_COUNT; i++) Cache_Set[i] = 0;
    for (int i = 0; i < `CACHE_SIZE; i++) Cache[i] = 0;
  end

  task automatic get_set(int A);
    set = A % (1 << `CACHE_SET_SIZE);
  endtask

  task automatic get_offset(int A);
    offset = A % (1 << `CACHE_OFFSET_SIZE);
  endtask

  task automatic get_tag(int A);
    tag = A >> `CACHE_SET_SIZE;
  endtask

  task automatic get_tags_from_set(int set1);
    tags_line[0] = Cache_Set[set1] % (1 << `CACHE_TAG_SIZE);
    tags_line[1] = Cache_Set[set1] >> `CACHE_TAG_SIZE;
  endtask

  always @(posedge RESET) begin
    reset();
  end

  always @(posedge C_DUMP) begin
    // $display("cache_hit: %d, cache_miss1: %d, cache_miss2: %d", cache_hit, cache_miss1, cache_miss2);
    dump();
  end

  always @(posedge STATS) begin
    $display("cache_hit: %0d, cache_miss: %0d", cache_hit, cache_miss);
  end
  
  task automatic swap(int idx);
    reg[`CACHE_TAG_SIZE-1:0] first_tag = Cache_Set[idx] % (1 << `CACHE_TAG_SIZE);
    Cache_Set[idx] >>= `CACHE_TAG_SIZE;
    Cache_Set[idx] = Cache_Set[idx] + (first_tag << `CACHE_TAG_SIZE);
    h = valid[idx * `CACHE_WAY];
    valid[idx * `CACHE_WAY] = valid[idx * `CACHE_WAY + 1];
    valid[idx * `CACHE_WAY + 1] = h;
    h =  dirty[idx * `CACHE_WAY];
    dirty[idx * `CACHE_WAY] = dirty[idx * `CACHE_WAY + 1];
    dirty[idx * `CACHE_WAY + 1] = h;
    for (int i = 0; i < `CACHE_LINE_SIZE; i++) begin
      reg[7:0] t = Cache[idx * `CACHE_WAY * `CACHE_LINE_SIZE + i];
      Cache[idx * `CACHE_WAY * `CACHE_LINE_SIZE + i] = Cache[idx * `CACHE_WAY * `CACHE_LINE_SIZE + i + `CACHE_LINE_SIZE];
      Cache[idx * `CACHE_WAY * `CACHE_LINE_SIZE + i + `CACHE_LINE_SIZE] = t;
    end
  endtask

  always @(posedge CLK && (C1 === 1 || C1 === 2 || C1 === 3 || C1 === 4 || C1 === 5 || C1 === 6 || C1 === 7)) begin
    if (C1 === 4) begin
      a1 = A1;
      invalid(a1);
      wait_(1);
      C2_ = 0;
      C1_ = 3'b111;
      wait_(1);
      C1_ = 'bz;
    end else begin
      save_c1 = C1;
      a1 = A1;
      save_data1 = D1;
      get_set(a1);
      get_tag(a1);
      get_tags_from_set(set);
      flag = 0;
      for (int i = 0; i < `CACHE_WAY; i++) begin
          if (tags_line[i] === tag && valid[set * `CACHE_WAY + i] === 1 && flag == 0) begin
              flag = 1;
              cache_hit++;
              wait_(1);
              save_data2 = D1;
              get_offset(A1);
              C1_ = 0;
              idx = (set * `CACHE_WAY + i) * `CACHE_LINE_SIZE + offset;
              if (save_c1 > 0 && save_c1 < 4) begin
                wait_(5);
                C1_ = `CTR1_BUS_SIZE'b111;
                if (save_c1 === 1) begin
                  D1_ = Cache[idx];
                end else if (save_c1 === 2) begin
                  D1_ = (Cache[idx + 1] << 8) + Cache[idx];
                end else if (save_c1 === 3) begin
                  D1_ = (Cache[idx + 3] << 8) + Cache[idx + 2];
                  wait_(1);
                  D1_ = (Cache[idx + 1] << 8) + Cache[idx];
                end
                if (i == 1) swap(set);
                wait_(1);
                C1_ = 'bz;
                D1_ = 'bz;
              end
              if (save_c1 > 4 && save_c1 < 8) begin
                dirty[set * `CACHE_WAY + i] = 1;
                if (save_c1 === 5) begin
                  Cache[idx] = save_data1 % (1 << 8);
                end else if (save_c1 === 6) begin
                  Cache[idx] = save_data1 % (1 << 8);
                  Cache[idx + 1] = save_data1 >> 8;
                end else if (save_c1 === 7) begin
                  Cache[idx] = save_data2 % (1 << 8);
                  Cache[idx + 1] = save_data2 >> 8;
                  Cache[idx + 2] = save_data1 % (1 << 8);
                  Cache[idx + 3] = save_data1 >> 8;
                end
                if (i == 1) begin swap(set); end
                wait_(5);
                C1_ = `CTR1_BUS_SIZE'b111;
                wait_(1);
                C1_ = 'bz;
              end
          end
      end
      if (flag == 0) begin
        cache_miss++;
        wait_(1);
        get_offset(A1);
        save_data2 = D1;
        C1_ = 0;
        wait_(3);
        if (dirty[set * `CACHE_WAY + 1] === 1 && valid[set * `CACHE_WAY + 1] === 1) begin
          invalid((tags_line[1] << `CACHE_SET_SIZE) + set);
          wait_(1);
        end
        read_mem(a1);
        read_from_mem(a1);
        answer_for_CPU(a1);
      end
    end
  end

  task automatic read_from_mem(int A);
    wait(C2 === 1);
    get_set(A);
    get_tag(A);
    swap(set);
    Cache_Set[set] = ((Cache_Set[set] >> 8) << 8) + tag;
    valid[set * `CACHE_WAY] = 1;
    dirty[set * `CACHE_WAY] = 0;
    for (int i = 7; i >= 0; i--) begin
      Cache[set * `CACHE_LINE_SIZE * `CACHE_WAY + i * 2] = D2 % (1 << 8);
      Cache[set * `CACHE_LINE_SIZE * `CACHE_WAY + i * 2 + 1] = (D2 >> 8);
      wait_(1);
    end
  endtask

  task automatic answer_for_CPU(int A);
    get_set(A);
    get_tag(A);
    idx = set * `CACHE_WAY * `CACHE_LINE_SIZE + offset;
    if (save_c1 === 1) begin
      dirty[set * `CACHE_WAY] = 0;
      C1_ = `CTR1_BUS_SIZE'b111;
      D1_ = Cache[idx];
    end else if (save_c1 === 2) begin
      dirty[set * `CACHE_WAY] = 0;
      C1_ = `CTR1_BUS_SIZE'b111;
      D1_ = (Cache[idx + 1] << 8) + Cache[idx];
    end else if (save_c1 === 3) begin
      dirty[set * `CACHE_WAY] = 0;
      C1_ = `CTR1_BUS_SIZE'b111;
      D1_ = (Cache[idx + 3] << 8) + Cache[idx + 2];
      wait_(1);
      D1_ = (Cache[idx + 1] << 8) + Cache[idx];
    end
    if (save_c1 === 5) begin
      dirty[set * `CACHE_WAY] = 1;
      Cache[idx] = save_data1 % (1 << 8);
    end else if (save_c1 === 6) begin
      dirty[set * `CACHE_WAY] = 1;
      Cache[idx] = save_data1 % (1 << 8);
      Cache[idx + 1] = save_data1 >> 8;
    end else if (save_c1 === 7) begin
      dirty[set * `CACHE_WAY] = 1;
      Cache[idx] = save_data2 % (1 << 8);
      Cache[idx + 1] = save_data2 >> 8;
      Cache[idx + 2] = save_data1 % (1 << 8);
      Cache[idx + 3] = save_data1 >> 8;
    end
    C1_ = `CTR1_BUS_SIZE'b111;
    wait_(1);
    D1_ = 'bz;
    C1_ = 'bz;
  endtask

  task automatic invalid(int A);
    get_set(A);
    get_tag(A);
    get_tags_from_set(set);
    if (tags_line[0] === tag) begin
        if (dirty[set * `CACHE_WAY] == 1 && valid[set * `CACHE_WAY] == 1) begin write_mem(A, 0); @(posedge C2); end
        valid[set * `CACHE_WAY] = 0;
        swap(set);
    end else if (tags_line[1] === tag) begin
        if (dirty[set * `CACHE_WAY + 1] == 1 && valid[set * `CACHE_WAY + 1] == 1) begin write_mem(A, 1); @(posedge C2); end
        valid[set * `CACHE_WAY + 1] = 0;
    end
  endtask

  task automatic read_mem(int A);
    A2_out = A;
    C2_ = `CTR2_BUS_SIZE'b10;
    wait_(1);
    A2_out = 'bz;
    C2_ = 'bz;
  endtask

  task automatic write_mem(int A, int tag_in_set);
    get_set(A);
    A2_out = A;
    C2_ = `CTR2_BUS_SIZE'b11;
    pos = (set * `CACHE_WAY + tag_in_set) * `CACHE_LINE_SIZE;
    for (int i = 7; i >= 0; i--) begin
        D2_ = (Cache[pos + i * 2 + 1] << 8) + Cache[pos + i * 2];
        wait_(1);
        A2_out = 'bz;
    end
    D2_ = 'bz;
    C2_ = 'bz;
  endtask

  task automatic reset();
    for (int i = 0; i < `CACHE_LINE_COUNT; i++) begin
      valid[i] = 0;
    end
  endtask

  task automatic wait_(int time_);
    for (int i = 0; i < time_; i++) begin
      @(posedge CLK);
    end
  endtask

  task automatic dump();
    fd = $fopen("output.txt", "w");
    for (int i = 0; i < `CACHE_LINE_COUNT; i++) begin
      $fdisplay(fd, "%0d", i);
      if (i % 2 == 0) $fdisplay(fd, "%b", (Cache_Set[i/2] % (1 << `CACHE_TAG_SIZE)));
      else $fdisplay(fd, "%b", (Cache_Set[i/2] >> `CACHE_TAG_SIZE));
      $fdisplay(fd, "Valid: %b", valid[i]);
      $fdisplay(fd, "Dirty: %b", dirty[i]);
      for (int j = 0; j < `CACHE_LINE_SIZE; j++)
        $fdisplay(fd, Cache[i * `CACHE_LINE_SIZE + j]);
    end
    $fclose(fd);
  endtask
endmodule