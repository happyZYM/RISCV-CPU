module CentralScheduleUnit(
        input  wire                 clk_in, // system clock signal
        input  wire                 rst_in, // reset signal
        input  wire	                rdy_in, // ready signal, pause cpu when low

        output wire                 flush_pipline,
        output wire [31:0]          reset_PC_to,

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
        output wire                 issue_space_available,

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

        input wire [31:0]           alu_res,
        input wire                  alu_rdy,
        input wire [ 2:0]           alu_res_ins_id,
        input wire [31:0]           alu_completed_alu_resulting_PC, // for branch prediction check

        input wire [31:0]           mo_res,
        input wire                  mo_rdy,
        input wire [ 2:0]           mo_res_ins_id,
        input wire [31:0]           mo_completed_mo_resulting_PC, // for branch prediction check

        output  wire [ 4:0]         rs1_reg_id,
        input wire [31:0]           rs1_val,
        output  wire [ 4:0]         rs2_reg_id,
        input wire [31:0]           rs2_val,
        output  wire                is_writing_rd,
        output  wire [ 4:0]         rd_reg_id,
        output  wire [31:0]         rd_val
    );

    reg [7:0] ins_count_in_csu;
    assign issue_space_available = (ins_count_in_csu < 8);

    reg reg_writen[31:0];
    reg [2:0] reg_depends_on [31:0];

    reg [2:0] csu_head;
    reg [2:0] csu_tail;
    reg [7:0] ins_state [7:0];

endmodule
