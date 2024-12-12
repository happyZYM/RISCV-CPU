module Decoder(
        input  wire                 clk_in,			// system clock signal
        input  wire                 rst_in,			// reset signal
        input  wire	                rdy_in,	        // ready signal, pause cpu when low

        input  wire [31:0]          ins,

        output wire [ 6:0]          opcode,
        output wire [ 2:0]          funct3,
        output wire [ 6:0]          funct7,
        output wire [31:0]          imm_val,
        output wire [ 5:0]          shamt_val,
        output wire [ 4:0]          rs1,
        output wire [ 4:0]          rs2,
        output wire [ 4:0]          rd,
        output wire [31:0]          offset,
        output wire                 is_jalr,
        output wire                 is_compressed_ins
    ); // decode and translate compressed instruction
    wire is_compressed = (ins[1:0] != 2'b11);
    assign is_compressed_ins = is_compressed;
    wire [ 6:0] opcode_normal;
    wire [ 2:0] funct3_normal;
    wire [ 6:0] funct7_normal;
    wire [31:0] imm_val_normal;
    wire [ 5:0] shamt_val_normal;
    wire [ 4:0] rs1_normal;
    wire [ 4:0] rs2_normal;
    wire [ 4:0] rd_normal;
    wire is_jalr_normal;
    wire [31:0] offset_normal;
    wire [ 6:0] opcode_compressed;
    wire [ 2:0] funct3_compressed;
    wire [ 6:0] funct7_compressed;
    wire [31:0] imm_val_compressed;
    wire [ 5:0] shamt_val_compressed;
    wire [ 4:0] rs1_compressed;
    wire [ 4:0] rs2_compressed;
    wire [ 4:0] rd_compressed;
    wire is_jalr_compressed;
    wire [31:0] offset_compressed;
    assign opcode = is_compressed ? opcode_compressed : opcode_normal;
    assign funct3 = is_compressed ? funct3_compressed : funct3_normal;
    assign funct7 = is_compressed ? funct7_compressed : funct7_normal;
    assign imm_val = is_compressed ? imm_val_compressed : imm_val_normal;
    assign shamt_val = is_compressed ? shamt_val_compressed : shamt_val_normal;
    assign rs1 = is_compressed ? rs1_compressed : rs1_normal;
    assign rs2 = is_compressed ? rs2_compressed : rs2_normal;
    assign rd = is_compressed ? rd_compressed : rd_normal;
    assign is_jalr = is_compressed ? is_jalr_compressed : is_jalr_normal;
    assign offset = is_compressed ? offset_compressed : offset_normal;

    assign is_jalr_normal = (opcode_normal == 7'b1100111) ? 1'b1 : 1'b0;
    wire is_branch_normal = (opcode_normal == 7'b1100011);
    wire [31:0] predicted_offset_if_branch_normal = (imm_val_normal[31] == 1'b1 ? imm_val_normal : 4);
    wire is_jal_normal = (opcode_normal == 7'b1101111);
    assign offset_normal = is_jal_normal ? imm_val_normal : (is_branch_normal ? predicted_offset_if_branch_normal : 4);

    // Decode normal (32-bit) instruction based on opcode
    assign opcode_normal = ins[6:0];

    // Initialize funct3_normal and funct7_normal based on opcode
    wire is_r_type_normal = (opcode_normal == 7'b0110011);
    wire is_i_type_normal = (opcode_normal == 7'b0010011 || opcode_normal == 7'b0000011 || opcode_normal == 7'b1100111);
    wire is_s_type_normal = (opcode_normal == 7'b0100011);
    wire is_b_type_normal = (opcode_normal == 7'b1100011);
    wire is_u_type_normal = (opcode_normal == 7'b0110111 || opcode_normal == 7'b0010111);
    wire is_j_type_normal = (opcode_normal == 7'b1101111);
    assign funct3_normal =
           (is_r_type_normal ||
            is_i_type_normal ||
            is_s_type_normal ||
            is_b_type_normal)
           ? ins[14:12]
           : 3'b000;

    // funct7_normal 仅在 R-type 和部分 I-type 指令中有效
    assign funct7_normal =
           (is_r_type_normal || // R-type
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
           (is_i_type_normal)
           ? imm_i_type
           : (is_s_type_normal)
           ? imm_s_type
           : (is_b_type_normal)
           ? imm_b_type
           : (is_u_type_normal)
           ? imm_u_type
           : (is_j_type_normal)
           ? imm_j_type
           : 32'b0;

    // 移位量仅在某些指令中有效
    assign shamt_val_normal =
           (opcode_normal == 7'b0010011 && (ins[14:12] == 3'b101 || ins[14:12] == 3'b001))
           ? ins[25:20]
           : 6'b000000;

    // 寄存器解码
    assign rd_normal =
           (is_r_type_normal ||
            is_i_type_normal ||
            is_u_type_normal ||
            is_j_type_normal)
           ? ins[11:7]
           : 5'b00000;

    assign rs1_normal =
           (is_r_type_normal ||
            is_i_type_normal ||
            is_s_type_normal ||
            is_b_type_normal)
           ? ins[19:15]
           : 5'b00000;

    assign rs2_normal =
           (is_r_type_normal ||
            is_s_type_normal ||
            is_b_type_normal)
           ? ins[24:20]
           : 5'b00000;

    C_Translator translator(
                     .ins(ins),
                     .opcode_compressed(opcode_compressed),
                     .funct3_compressed(funct3_compressed),
                     .funct7_compressed(funct7_compressed),
                     .imm_val_compressed(imm_val_compressed),
                     .shamt_val_compressed(shamt_val_compressed),
                     .rs1_compressed(rs1_compressed),
                     .rs2_compressed(rs2_compressed),
                     .rd_compressed(rd_compressed),
                     .offset_compressed(offset_compressed),
                     .is_jalr_compressed(is_jalr_compressed)
                 );
endmodule
