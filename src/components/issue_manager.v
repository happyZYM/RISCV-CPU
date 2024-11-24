module InstructionCache(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [31:0]          read_addr,
  input  wire                 is_reading,

  output wire [31:0]          read_data,
  output wire                 is_ready,

  input  wire [31:0]          ins_fetched_from_memory_adaptor,
  input  wire [ 2:0]          status_of_memory_adaptor,
  input  wire                 insfetch_task_accepted,
  output wire                 request_ins_from_memory_adaptor,
  output wire [31:0]          insaddr_to_be_fetched_from_memory_adaptor
);

// This cache is based on Tree-PLRU, and the size is 64(ins) * 32(bit/ins)
reg [31:0] cached_ins_addr [63:0];
reg [31:0] cached_ins_data [63:0];
reg switch0;
reg [1:0] switch1;
reg [3:0] switch2;
reg [7:0] switch3;
reg [15:0] switch4;
reg [31:0] switch5;
wire [31:0] query_addr = read_addr;
wire cache_hit;
wire [5:0] cache_hit_index;
reg [2:0] status;
reg is_ready_reg;
assign is_ready = is_ready_reg;

genvar cached_ins_data_init_i;
generate
  for (cached_ins_data_init_i = 0; cached_ins_data_init_i < 64; cached_ins_data_init_i = cached_ins_data_init_i + 1)
    begin
      always @(posedge clk_in)
        begin
          if (rst_in)
            begin
              cached_ins_addr[cached_ins_data_init_i] <= 32'b11111111111111111111111111111111;
              cached_ins_data[cached_ins_data_init_i] <= 32'b0;
            end
          else if (!rdy_in)
            begin
            end
          else
            begin
            end
        end
    end
endgenerate

// TODO: during synthesis, this may need to be mannually edited to reduce latency
assign cache_hit = (cached_ins_addr[0] == query_addr)
                 ||(cached_ins_addr[1] == query_addr)
                 ||(cached_ins_addr[2] == query_addr)
                 ||(cached_ins_addr[3] == query_addr)
                 ||(cached_ins_addr[4] == query_addr)
                 ||(cached_ins_addr[5] == query_addr)
                 ||(cached_ins_addr[6] == query_addr)
                 ||(cached_ins_addr[7] == query_addr)
                 ||(cached_ins_addr[8] == query_addr)
                 ||(cached_ins_addr[9] == query_addr)
                 ||(cached_ins_addr[10] == query_addr)
                 ||(cached_ins_addr[11] == query_addr)
                 ||(cached_ins_addr[12] == query_addr)
                 ||(cached_ins_addr[13] == query_addr)
                 ||(cached_ins_addr[14] == query_addr)
                 ||(cached_ins_addr[15] == query_addr)
                 ||(cached_ins_addr[16] == query_addr)
                 ||(cached_ins_addr[17] == query_addr)
                 ||(cached_ins_addr[18] == query_addr)
                 ||(cached_ins_addr[19] == query_addr)
                 ||(cached_ins_addr[20] == query_addr)
                 ||(cached_ins_addr[21] == query_addr)
                 ||(cached_ins_addr[22] == query_addr)
                 ||(cached_ins_addr[23] == query_addr)
                 ||(cached_ins_addr[24] == query_addr)
                 ||(cached_ins_addr[25] == query_addr)
                 ||(cached_ins_addr[26] == query_addr)
                 ||(cached_ins_addr[27] == query_addr)
                 ||(cached_ins_addr[28] == query_addr)
                 ||(cached_ins_addr[29] == query_addr)
                 ||(cached_ins_addr[30] == query_addr)
                 ||(cached_ins_addr[31] == query_addr)
                 ||(cached_ins_addr[32] == query_addr)
                 ||(cached_ins_addr[33] == query_addr)
                 ||(cached_ins_addr[34] == query_addr)
                 ||(cached_ins_addr[35] == query_addr)
                 ||(cached_ins_addr[36] == query_addr)
                 ||(cached_ins_addr[37] == query_addr)
                 ||(cached_ins_addr[38] == query_addr)
                 ||(cached_ins_addr[39] == query_addr)
                 ||(cached_ins_addr[40] == query_addr)
                 ||(cached_ins_addr[41] == query_addr)
                 ||(cached_ins_addr[42] == query_addr)
                 ||(cached_ins_addr[43] == query_addr)
                 ||(cached_ins_addr[44] == query_addr)
                 ||(cached_ins_addr[45] == query_addr)
                 ||(cached_ins_addr[46] == query_addr)
                 ||(cached_ins_addr[47] == query_addr)
                 ||(cached_ins_addr[48] == query_addr)
                 ||(cached_ins_addr[49] == query_addr)
                 ||(cached_ins_addr[50] == query_addr)
                 ||(cached_ins_addr[51] == query_addr)
                 ||(cached_ins_addr[52] == query_addr)
                 ||(cached_ins_addr[53] == query_addr)
                 ||(cached_ins_addr[54] == query_addr)
                 ||(cached_ins_addr[55] == query_addr)
                 ||(cached_ins_addr[56] == query_addr)
                 ||(cached_ins_addr[57] == query_addr)
                 ||(cached_ins_addr[58] == query_addr)
                 ||(cached_ins_addr[59] == query_addr)
                 ||(cached_ins_addr[60] == query_addr)
                 ||(cached_ins_addr[61] == query_addr)
                 ||(cached_ins_addr[62] == query_addr)
                 ||(cached_ins_addr[63] == query_addr);
assign cache_hit_index = (cached_ins_addr[0] == query_addr ? 0 : 0)
                        |(cached_ins_addr[1] == query_addr ? 1 : 0)
                        |(cached_ins_addr[2] == query_addr ? 2 : 0)
                        |(cached_ins_addr[3] == query_addr ? 3 : 0)
                        |(cached_ins_addr[4] == query_addr ? 4 : 0)
                        |(cached_ins_addr[5] == query_addr ? 5 : 0)
                        |(cached_ins_addr[6] == query_addr ? 6 : 0)
                        |(cached_ins_addr[7] == query_addr ? 7 : 0)
                        |(cached_ins_addr[8] == query_addr ? 8 : 0)
                        |(cached_ins_addr[9] == query_addr ? 9 : 0)
                        |(cached_ins_addr[10] == query_addr ? 10 : 0)
                        |(cached_ins_addr[11] == query_addr ? 11 : 0)
                        |(cached_ins_addr[12] == query_addr ? 12 : 0)
                        |(cached_ins_addr[13] == query_addr ? 13 : 0)
                        |(cached_ins_addr[14] == query_addr ? 14 : 0)
                        |(cached_ins_addr[15] == query_addr ? 15 : 0)
                        |(cached_ins_addr[16] == query_addr ? 16 : 0)
                        |(cached_ins_addr[17] == query_addr ? 17 : 0)
                        |(cached_ins_addr[18] == query_addr ? 18 : 0)
                        |(cached_ins_addr[19] == query_addr ? 19 : 0)
                        |(cached_ins_addr[20] == query_addr ? 20 : 0)
                        |(cached_ins_addr[21] == query_addr ? 21 : 0)
                        |(cached_ins_addr[22] == query_addr ? 22 : 0)
                        |(cached_ins_addr[23] == query_addr ? 23 : 0)
                        |(cached_ins_addr[24] == query_addr ? 24 : 0)
                        |(cached_ins_addr[25] == query_addr ? 25 : 0)
                        |(cached_ins_addr[26] == query_addr ? 26 : 0)
                        |(cached_ins_addr[27] == query_addr ? 27 : 0)
                        |(cached_ins_addr[28] == query_addr ? 28 : 0)
                        |(cached_ins_addr[29] == query_addr ? 29 : 0)
                        |(cached_ins_addr[30] == query_addr ? 30 : 0)
                        |(cached_ins_addr[31] == query_addr ? 31 : 0)
                        |(cached_ins_addr[32] == query_addr ? 32 : 0)
                        |(cached_ins_addr[33] == query_addr ? 33 : 0)
                        |(cached_ins_addr[34] == query_addr ? 34 : 0)
                        |(cached_ins_addr[35] == query_addr ? 35 : 0)
                        |(cached_ins_addr[36] == query_addr ? 36 : 0)
                        |(cached_ins_addr[37] == query_addr ? 37 : 0)
                        |(cached_ins_addr[38] == query_addr ? 38 : 0)
                        |(cached_ins_addr[39] == query_addr ? 39 : 0)
                        |(cached_ins_addr[40] == query_addr ? 40 : 0)
                        |(cached_ins_addr[41] == query_addr ? 41 : 0)
                        |(cached_ins_addr[42] == query_addr ? 42 : 0)
                        |(cached_ins_addr[43] == query_addr ? 43 : 0)
                        |(cached_ins_addr[44] == query_addr ? 44 : 0)
                        |(cached_ins_addr[45] == query_addr ? 45 : 0)
                        |(cached_ins_addr[46] == query_addr ? 46 : 0)
                        |(cached_ins_addr[47] == query_addr ? 47 : 0)
                        |(cached_ins_addr[48] == query_addr ? 48 : 0)
                        |(cached_ins_addr[49] == query_addr ? 49 : 0)
                        |(cached_ins_addr[50] == query_addr ? 50 : 0)
                        |(cached_ins_addr[51] == query_addr ? 51 : 0)
                        |(cached_ins_addr[52] == query_addr ? 52 : 0)
                        |(cached_ins_addr[53] == query_addr ? 53 : 0)
                        |(cached_ins_addr[54] == query_addr ? 54 : 0)
                        |(cached_ins_addr[55] == query_addr ? 55 : 0)
                        |(cached_ins_addr[56] == query_addr ? 56 : 0)
                        |(cached_ins_addr[57] == query_addr ? 57 : 0)
                        |(cached_ins_addr[58] == query_addr ? 58 : 0)
                        |(cached_ins_addr[59] == query_addr ? 59 : 0)
                        |(cached_ins_addr[60] == query_addr ? 60 : 0)
                        |(cached_ins_addr[61] == query_addr ? 61 : 0)
                        |(cached_ins_addr[62] == query_addr ? 62 : 0)
                        |(cached_ins_addr[63] == query_addr ? 63 : 0);

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        switch0 <= 1'b0;
        switch1 <= 2'b00;
        switch2 <= 4'b0000;
        switch3 <= 8'b00000000;
        switch4 <= 16'b0000000000000000;
        switch5 <= 32'b00000000000000000000000000000000;
        status <= 3'b000;
        is_ready_reg <= 1'b0;
      end
    else if (!rdy_in)
      begin
      end
    else
      begin
        if (status == 0)
          begin
            if (is_reading)
              begin
                if (cache_hit)
                  begin
                    is_ready_reg <= 1'b1;
                  end
                else
                  begin
                    is_ready_reg <= 1'b0;
                  end
              end
          end
      end
  end

endmodule

module Decoder(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [31:0]          ins,

  output wire [ 6:0]          opcode,
  output wire [ 2:0]          funct3,
  output wire [ 6:0]          funct7,
  output wire [31:0]          imm_val,
  output wire [ 5:0]          shamt_val,
  output wire [ 4:0]          rs1,
  output wire [ 4:0]          rs2,
  output wire [ 4:0]          rd
); // decode and translate compressed instruction
  wire is_compressed = (ins[1:0] == 2'b11);
  wire [ 6:0] opcode_normal;
  wire [ 2:0] funct3_normal;
  wire [ 6:0] funct7_normal;
  wire [31:0] imm_val_normal;
  wire [ 5:0] shamt_val_normal;
  wire [ 4:0] rs1_normal;
  wire [ 4:0] rs2_normal;
  wire [ 4:0] rd_normal;
  wire [ 6:0] opcode_compressed;
  wire [ 2:0] funct3_compressed;
  wire [ 6:0] funct7_compressed;
  wire [31:0] imm_val_compressed;
  wire [ 5:0] shamt_val_compressed;
  wire [ 4:0] rs1_compressed;
  wire [ 4:0] rs2_compressed;
  wire [ 4:0] rd_compressed;
  assign opcode = is_compressed ? opcode_compressed : opcode_normal;
  assign funct3 = is_compressed ? funct3_compressed : funct3_normal;
  assign funct7 = is_compressed ? funct7_compressed : funct7_normal;
  assign imm_val = is_compressed ? imm_val_compressed : imm_val_normal;
  assign shamt_val = is_compressed ? shamt_val_compressed : shamt_val_normal;
  assign rs1 = is_compressed ? rs1_compressed : rs1_normal;
  assign rs2 = is_compressed ? rs2_compressed : rs2_normal;
  assign rd = is_compressed ? rd_compressed : rd_normal;
  // TODO: decode normal instruction
// Decode normal (32-bit) instruction based on opcode
assign opcode_normal = ins[6:0];

// Initialize funct3_normal and funct7_normal based on opcode
assign funct3_normal = 
    (opcode_normal == 7'b0110011 || // R-type
     opcode_normal == 7'b0010011 || // I-type
     opcode_normal == 7'b0000011 || // I-type Load
     opcode_normal == 7'b1100111 || // I-type JALR
     opcode_normal == 7'b1100111 || // I-type SYSTEM
     opcode_normal == 7'b0010111 || // U-type AUIPC
     opcode_normal == 7'b0110111 || // U-type LUI
     opcode_normal == 7'b1101111 || // J-type JAL
     opcode_normal == 7'b1100011)   // B-type Branch
    ? ins[14:12] 
    : 3'b000;

// funct7_normal 仅在 R-type 和部分 I-type 指令中有效
assign funct7_normal = 
    (opcode_normal == 7'b0110011 || // R-type
     (opcode_normal == 7'b0010011 && (ins[14:12] == 3'b101))) // I-type shift
    ? ins[31:25]
    : 7'b0000000;

// 立即数的解码根据指令类型不同而不同
wire [31:0] imm_i_type = {{20{ins[31]}}, ins[31:20]};
wire [31:0] imm_s_type = {{20{ins[31]}}, ins[31:25], ins[11:7]};
wire [31:0] imm_b_type = {{19{ins[31]}}, ins[31], ins[7], ins[30:25], ins[11:8], 1'b0};
wire [31:0] imm_u_type = {ins[31:12], 12'b0};
wire [31:0] imm_j_type = {{11{ins[31]}}, ins[31], ins[19:12], ins[20], ins[30:21], 1'b0};

// 选择立即数
assign imm_val_normal = 
    (opcode_normal == 7'b0010011 || // I-type
     opcode_normal == 7'b0000011 || 
     opcode_normal == 7'b1100111)
    ? imm_i_type :
    (opcode_normal == 7'b0100011) // S-type
    ? imm_s_type :
    (opcode_normal == 7'b1100011) // B-type
    ? imm_b_type :
    (opcode_normal == 7'b0110111 || // U-type
     opcode_normal == 7'b0010111)
    ? imm_u_type :
    (opcode_normal == 7'b1101111) // J-type
    ? imm_j_type :
    32'b0;

// 移位量仅在某些指令中有效
assign shamt_val_normal = 
    (opcode_normal == 7'b0010011 && ins[14:12] == 3'b101) || // I-type shift
    (opcode_normal == 7'b0110011 && (ins[14:12] == 3'b001 || ins[14:12] == 3'b101))
    ? ins[25:20]
    : 6'b000000;

// 寄存器解码
assign rd_normal = 
    (opcode_normal == 7'b0110011 || // R-type
     opcode_normal == 7'b0010011 || // I-type
     opcode_normal == 7'b0000011 || // I-type Load
     opcode_normal == 7'b1100111 || // I-type JALR
     opcode_normal == 7'b0010111 || // U-type AUIPC
     opcode_normal == 7'b0110111 || // U-type LUI
     opcode_normal == 7'b1101111)   // J-type JAL
    ? ins[11:7]
    : 5'b00000;

assign rs1_normal = 
    (opcode_normal == 7'b0110011 || // R-type
     opcode_normal == 7'b0010011 || // I-type
     opcode_normal == 7'b0000011 || // I-type Load
     opcode_normal == 7'b1100111 || // I-type JALR
     opcode_normal == 7'b1100011)   // B-type Branch
    ? ins[19:15]
    : 5'b00000;

assign rs2_normal = 
    (opcode_normal == 7'b0110011 || // R-type
     opcode_normal == 7'b0100011 || // S-type
     opcode_normal == 7'b1100011)   // B-type Branch
    ? ins[24:20]
    : 5'b00000;

  // TODO: decode compressed instruction

endmodule

module IssueManager(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire                 flush_pipline,

  input  wire                 jalr_just_done,
  input  wire [31:0]          jalr_resulting_PC,

  output wire                 is_issueing,
  output wire [31:0]          issue_PC,
  output wire [31:0]          full_ins,
  output wire [ 6:0]          opcode,
  output wire [ 2:0]          funct3,
  output wire [ 6:0]          funct7,
  output wire [31:0]          imm_val,
  output wire [ 5:0]          shamt_val,
  output wire [ 4:0]          rs1,
  output wire [ 4:0]          rs2,
  output wire [ 4:0]          rd,

  input  wire [31:0]          ins_fetched_from_memory_adaptor,
  input  wire [ 1:0]          status_of_memory_adaptor,
  output wire                 request_ins_from_memory_adaptor,
  output wire [31:0]          insaddr_to_be_fetched_from_memory_adaptor
);

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
      
      end
    else if (!rdy_in)
      begin
      
      end
    else
      begin
      
      end
  end

endmodule