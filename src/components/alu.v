module Alu(
        input  wire                 clk_in,			// system clock signal
        input  wire                 rst_in,			// reset signal
        input  wire					        rdy_in,			// ready signal, pause cpu when low

        input  wire                 flush_pipline,

        input  wire                 have_ins,
        input  wire [ 2:0]          ins_id,
        input  wire [31:0]          rs1_val,
        input  wire [31:0]          rs2_val,
        input  wire [31:0]          imm_val,
        input  wire [ 5:0]          shamt_val,
        input  wire [ 6:0]          opcode,
        input  wire [ 2:0]          funct3,
        input  wire [ 6:0]          funct7,
        input  wire [31:0]          request_PC,
        input  wire                 is_compressed_ins,

        output wire [31:0]          alu_res,
        output wire                 alu_rdy,
        output wire [ 2:0]          res_ins_id,
        output wire [31:0]          completed_alu_resulting_PC, // for branch prediction check
        output wire                 alu_available
    );
    wire [ 2:0] ins_length = (is_compressed_ins ? 16'd2 : 16'd4);
    reg [31:0] alu_res_reg;
    reg        alu_rdy_reg;
    reg [ 2:0] res_ins_id_reg;
    reg [31:0] completed_alu_resulting_PC_reg;
    assign alu_available = 1'b1; // currently alu is always available
    assign alu_res = alu_res_reg;
    assign alu_rdy = alu_rdy_reg;
    assign res_ins_id = res_ins_id_reg;
    assign completed_alu_resulting_PC = completed_alu_resulting_PC_reg;
    always @(posedge clk_in) begin
        if (rst_in) begin
            alu_rdy_reg <= 1'b0;
            alu_res_reg <= 32'b0;
            completed_alu_resulting_PC_reg <= 32'b0;
        end
        else if (!rdy_in) begin
            alu_rdy_reg <= 1'b0;
        end
        else begin
            alu_rdy_reg <= have_ins;
            res_ins_id_reg <= ins_id;

            case ({funct7, funct3, opcode})
                // LUI
                17'b0000000_000_0110111: begin
                    alu_res_reg <= imm_val;
                    completed_alu_resulting_PC_reg <= request_PC + ins_length;
                end

                // AUIPC
                17'b0000000_000_0010111: begin
                    alu_res_reg <= request_PC + imm_val;
                    completed_alu_resulting_PC_reg <= request_PC + ins_length;
                end

                // JAL
                17'b0000000_000_1101111: begin
                    alu_res_reg <= request_PC + ins_length;
                    completed_alu_resulting_PC_reg <= request_PC + imm_val;
                end

                // JALR
                17'b0000000_000_1100111: begin
                    alu_res_reg <= request_PC + ins_length;
                    completed_alu_resulting_PC_reg <= (rs1_val + imm_val) & ~32'b1;
                end

                // Branch instructions
                17'b0000000_000_1100011: begin // BEQ
                    completed_alu_resulting_PC_reg <= (rs1_val == rs2_val) ? request_PC + imm_val : request_PC + ins_length;
                end
                17'b0000000_001_1100011: begin // BNE
                    completed_alu_resulting_PC_reg <= (rs1_val != rs2_val) ? request_PC + imm_val : request_PC + ins_length;
                end
                17'b0000000_100_1100011: begin // BLT
                    completed_alu_resulting_PC_reg <= ($signed(rs1_val) < $signed(rs2_val)) ? request_PC + imm_val : request_PC + ins_length;
                end
                17'b0000000_101_1100011: begin // BGE
                    completed_alu_resulting_PC_reg <= ($signed(rs1_val) >= $signed(rs2_val)) ? request_PC + imm_val : request_PC + ins_length;
                end
                17'b0000000_110_1100011: begin // BLTU
                    completed_alu_resulting_PC_reg <= (rs1_val < rs2_val) ? request_PC + imm_val : request_PC + ins_length;
                end
                17'b0000000_111_1100011: begin // BGEU
                    completed_alu_resulting_PC_reg <= (rs1_val >= rs2_val) ? request_PC + imm_val : request_PC + ins_length;
                end

                // I-type ALU operations
                17'b0000000_000_0010011: begin // ADDI
                    alu_res_reg <= rs1_val + imm_val;
                    completed_alu_resulting_PC_reg <= request_PC + ins_length;
                end
                17'b0000000_010_0010011: begin // SLTI
                    alu_res_reg <= ($signed(rs1_val) < $signed(imm_val)) ? 32'd1 : 32'd0;
                    completed_alu_resulting_PC_reg <= request_PC + ins_length;
                end
                17'b0000000_011_0010011: begin // SLTIU
                    alu_res_reg <= (rs1_val < imm_val) ? 32'd1 : 32'd0;
                    completed_alu_resulting_PC_reg <= request_PC + ins_length;
                end
                17'b0000000_100_0010011: begin // XORI
                    alu_res_reg <= rs1_val ^ imm_val;
                    completed_alu_resulting_PC_reg <= request_PC + ins_length;
                end
                17'b0000000_110_0010011: begin // ORI
                    alu_res_reg <= rs1_val | imm_val;
                    completed_alu_resulting_PC_reg <= request_PC + ins_length;
                end
                17'b0000000_111_0010011: begin // ANDI
                    alu_res_reg <= rs1_val & imm_val;
                    completed_alu_resulting_PC_reg <= request_PC + ins_length;
                end

                // Shift operations
                17'b0000000_001_0010011: begin // SLLI
                    alu_res_reg <= rs1_val << shamt_val;
                    completed_alu_resulting_PC_reg <= request_PC + ins_length;
                end
                17'b0000000_101_0010011: begin // SRLI
                    alu_res_reg <= rs1_val >> shamt_val;
                    completed_alu_resulting_PC_reg <= request_PC + ins_length;
                end
                17'b0100000_101_0010011: begin // SRAI
                    alu_res_reg <= $signed(rs1_val) >>> shamt_val;
                    completed_alu_resulting_PC_reg <= request_PC + ins_length;
                end

                // R-type ALU operations
                17'b0000000_000_0110011: begin // ADD
                    alu_res_reg <= rs1_val + rs2_val;
                    completed_alu_resulting_PC_reg <= request_PC + ins_length;
                end
                17'b0100000_000_0110011: begin // SUB
                    alu_res_reg <= rs1_val - rs2_val;
                    completed_alu_resulting_PC_reg <= request_PC + ins_length;
                end
                17'b0000000_001_0110011: begin // SLL
                    alu_res_reg <= rs1_val << (rs2_val[4:0]);
                    completed_alu_resulting_PC_reg <= request_PC + ins_length;
                end
                17'b0000000_010_0110011: begin // SLT
                    alu_res_reg <= ($signed(rs1_val) < $signed(rs2_val)) ? 32'd1 : 32'd0;
                    completed_alu_resulting_PC_reg <= request_PC + ins_length;
                end
                17'b0000000_011_0110011: begin // SLTU
                    alu_res_reg <= (rs1_val < rs2_val) ? 32'd1 : 32'd0;
                    completed_alu_resulting_PC_reg <= request_PC + ins_length;
                end
                17'b0000000_100_0110011: begin // XOR
                    alu_res_reg <= rs1_val ^ rs2_val;
                    completed_alu_resulting_PC_reg <= request_PC + ins_length;
                end
                17'b0000000_101_0110011: begin // SRL
                    alu_res_reg <= rs1_val >> (rs2_val[4:0]);
                    completed_alu_resulting_PC_reg <= request_PC + ins_length;
                end
                17'b0100000_101_0110011: begin // SRA
                    alu_res_reg <= $signed(rs1_val) >>> (rs2_val[4:0]);
                    completed_alu_resulting_PC_reg <= request_PC + ins_length;
                end
                17'b0000000_110_0110011: begin // OR
                    alu_res_reg <= rs1_val | rs2_val;
                    completed_alu_resulting_PC_reg <= request_PC + ins_length;
                end
                17'b0000000_111_0110011: begin // AND
                    alu_res_reg <= rs1_val & rs2_val;
                    completed_alu_resulting_PC_reg <= request_PC + ins_length;
                end
            endcase
        end
    end

endmodule
