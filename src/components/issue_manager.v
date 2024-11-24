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

  output wire [31:0]          read_data,
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