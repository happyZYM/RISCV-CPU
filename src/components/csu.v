module RegUseCal(
        input  wire [ 6:0]          opcode,
        input  wire [ 2:0]          funct3,
        input  wire [ 6:0]          funct7,

        output wire                 is_rs1_used,
        output wire                 is_rs2_used,
        output wire                 is_rd_used
    );

endmodule

module CentralScheduleUnit(
        input  wire                 clk_in,			// system clock signal
        input  wire                 rst_in,			// reset signal
        input  wire					        rdy_in,			// ready signal, pause cpu when low

        input  wire                 ins_just_issued,
        input  wire [31:0]          issue_PC,
        input  wire [31:0]          issue_predicted_resulting_PC,
        input  wire [31:0]          ins_issued,
        input  wire [ 6:0]          issue_opcode,
        input  wire [ 2:0]          issue_funct3,
        input  wire [ 6:0]          issue_funct7,
        input  wire [31:0]          issue_imm_val,
        input  wire [ 5:0]          issue_shamt_val,
        input  wire [ 4:0]          issue_rs1,
        input  wire [ 4:0]          issue_rs2,
        input  wire [ 4:0]          issue_rd,
        input  wire                 issue_is_compressed_ins,

        output wire                 is_executing,
        output wire                 executing_ins_type, // 0 for alu and 1 for memory operator
        output wire [ 2:0]          exec_ins_id,
        output wire [ 6:0]          exec_opcode,
        output wire [ 2:0]          exec_funct3,
        output wire [ 6:0]          exec_funct7,
        output wire [31:0]          exec_imm_val,
        output wire [ 5:0]          exec_shamt_val,
        output wire [31:0]          exec_rs1,
        output wire [31:0]          exec_rs2,
        output wire [ 4:0]          exec_rd,
        output wire [31:0]          exec_PC,

        output wire                 flush_pipline
    );

endmodule
