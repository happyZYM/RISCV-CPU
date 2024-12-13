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
        output wire                 exec_is_compressed_ins,

        input wire [31:0]           alu_res,
        input wire                  alu_rdy,
        input wire [ 2:0]           alu_res_ins_id,
        input wire [31:0]           alu_completed_alu_resulting_PC, // for branch prediction check

        input wire [31:0]           mo_res,
        input wire                  mo_rdy,
        input wire [ 2:0]           mo_res_ins_id,
        input wire [31:0]           mo_completed_mo_resulting_PC, // for branch prediction check

        output  wire [ 4:0]         rf_rs1_reg_id,
        input wire [31:0]           rf_rs1_val,
        output  wire [ 4:0]         rf_rs2_reg_id,
        input wire [31:0]           rf_rs2_val,
        output  wire                rf_is_writing_rd,
        output  wire [ 4:0]         rf_rd_reg_id,
        output  wire [31:0]         rf_rd_val
    ); // This module act as ROB, Reserve Station and Load/Store Buffer
    // output control
    reg flush_pipline_out;


    // internal data
    reg [7:0] ins_count_in_csu;
    assign issue_space_available = (ins_count_in_csu < 8);

    reg reg_writen[31:0];
    reg [2:0] reg_depends_on [31:0];
    reg [7:0] memrw_ins_count;
    reg [2:0] previous_memrw_ins_id;

    reg [2:0] csu_head;
    reg [2:0] csu_tail;
    reg [7:0] ins_state [7:0]; // 0 -> empty, 1-> recorded
    reg [31:0] ins_full [7:0]; // for debug, no need for real cpu
    reg [31:0] ins_PC [7:0]; // for debug, no need for real cpu
    reg [31:0] ins_predicted_resulting_PC [7:0];
    reg ins_rs1_depend_on [7:0][7:0];
    reg ins_rs1_dependency_satified [7:0];
    reg ins_rs2_depend_on [7:0][7:0];
    reg ins_rs2_dependency_satified [7:0];
    reg ins_memrw_depend_on [7:0][7:0];
    reg ins_memrw_dependency_satified [7:0];

    reg [6:0] ins_opcode [7:0];
    reg [2:0] ins_funct3 [7:0];
    reg [6:0] ins_funct7 [7:0];
    reg [31:0] ins_imm_val [7:0];
    reg [ 5:0] ins_shamt_val [7:0];
    reg [ 4:0] ins_rs1 [7:0];
    reg [31:0] ins_rs1_val [7:0];
    reg [ 4:0] ins_rs2 [7:0];
    reg [31:0] ins_rs2_val [7:0];
    reg [ 4:0] ins_rd [7:0];
    reg [31:0] ins_rd_val [7:0];
    reg ins_is_compressed_ins [7:0];

    task initialize_internal_state;
        begin
            flush_pipline_out <= 1'b0;
            ins_count_in_csu <= 8'd0;
            reg_writen[0] <= 1'b0;
            reg_writen[1] <= 1'b0;
            reg_writen[2] <= 1'b0;
            reg_writen[3] <= 1'b0;
            reg_writen[4] <= 1'b0;
            reg_writen[5] <= 1'b0;
            reg_writen[6] <= 1'b0;
            reg_writen[7] <= 1'b0;
            reg_writen[8] <= 1'b0;
            reg_writen[9] <= 1'b0;
            reg_writen[10] <= 1'b0;
            reg_writen[11] <= 1'b0;
            reg_writen[12] <= 1'b0;
            reg_writen[13] <= 1'b0;
            reg_writen[14] <= 1'b0;
            reg_writen[15] <= 1'b0;
            reg_writen[16] <= 1'b0;
            reg_writen[17] <= 1'b0;
            reg_writen[18] <= 1'b0;
            reg_writen[19] <= 1'b0;
            reg_writen[20] <= 1'b0;
            reg_writen[21] <= 1'b0;
            reg_writen[22] <= 1'b0;
            reg_writen[23] <= 1'b0;
            reg_writen[24] <= 1'b0;
            reg_writen[25] <= 1'b0;
            reg_writen[26] <= 1'b0;
            reg_writen[27] <= 1'b0;
            reg_writen[28] <= 1'b0;
            reg_writen[29] <= 1'b0;
            reg_writen[30] <= 1'b0;
            reg_writen[31] <= 1'b0;
            reg_depends_on[0] <= 3'b000;
            reg_depends_on[1] <= 3'b000;
            reg_depends_on[2] <= 3'b000;
            reg_depends_on[3] <= 3'b000;
            reg_depends_on[4] <= 3'b000;
            reg_depends_on[5] <= 3'b000;
            reg_depends_on[6] <= 3'b000;
            reg_depends_on[7] <= 3'b000;
            reg_depends_on[8] <= 3'b000;
            reg_depends_on[9] <= 3'b000;
            reg_depends_on[10] <= 3'b000;
            reg_depends_on[11] <= 3'b000;
            reg_depends_on[12] <= 3'b000;
            reg_depends_on[13] <= 3'b000;
            reg_depends_on[14] <= 3'b000;
            reg_depends_on[15] <= 3'b000;
            reg_depends_on[16] <= 3'b000;
            reg_depends_on[17] <= 3'b000;
            reg_depends_on[18] <= 3'b000;
            reg_depends_on[19] <= 3'b000;
            reg_depends_on[20] <= 3'b000;
            reg_depends_on[21] <= 3'b000;
            reg_depends_on[22] <= 3'b000;
            reg_depends_on[23] <= 3'b000;
            reg_depends_on[24] <= 3'b000;
            reg_depends_on[25] <= 3'b000;
            reg_depends_on[26] <= 3'b000;
            reg_depends_on[27] <= 3'b000;
            reg_depends_on[28] <= 3'b000;
            reg_depends_on[29] <= 3'b000;
            reg_depends_on[30] <= 3'b000;
            reg_depends_on[31] <= 3'b000;
            memrw_ins_count <= 8'd0;
            previous_memrw_ins_id <= 3'b000;
            csu_head <= 3'b000;
            csu_tail <= 3'b000;
            ins_state[0] <= 8'd0;
            ins_state[1] <= 8'd0;
            ins_state[2] <= 8'd0;
            ins_state[3] <= 8'd0;
            ins_state[4] <= 8'd0;
            ins_state[5] <= 8'd0;
            ins_state[6] <= 8'd0;
            ins_state[7] <= 8'd0;
            ins_full[0] <= 32'b0;
            ins_full[1] <= 32'b0;
            ins_full[2] <= 32'b0;
            ins_full[3] <= 32'b0;
            ins_full[4] <= 32'b0;
            ins_full[5] <= 32'b0;
            ins_full[6] <= 32'b0;
            ins_full[7] <= 32'b0;
            ins_PC[0] <= 32'b0;
            ins_PC[1] <= 32'b0;
            ins_PC[2] <= 32'b0;
            ins_PC[3] <= 32'b0;
            ins_PC[4] <= 32'b0;
            ins_PC[5] <= 32'b0;
            ins_PC[6] <= 32'b0;
            ins_PC[7] <= 32'b0;
            ins_predicted_resulting_PC[0] <= 32'b0;
            ins_predicted_resulting_PC[1] <= 32'b0;
            ins_predicted_resulting_PC[2] <= 32'b0;
            ins_predicted_resulting_PC[3] <= 32'b0;
            ins_predicted_resulting_PC[4] <= 32'b0;
            ins_predicted_resulting_PC[5] <= 32'b0;
            ins_predicted_resulting_PC[6] <= 32'b0;
            ins_predicted_resulting_PC[7] <= 32'b0;
            ins_rs1_depend_on[0][0] <= 1'b0;
            ins_rs1_depend_on[0][1] <= 1'b0;
            ins_rs1_depend_on[0][2] <= 1'b0;
            ins_rs1_depend_on[0][3] <= 1'b0;
            ins_rs1_depend_on[0][4] <= 1'b0;
            ins_rs1_depend_on[0][5] <= 1'b0;
            ins_rs1_depend_on[0][6] <= 1'b0;
            ins_rs1_depend_on[0][7] <= 1'b0;
            ins_rs1_depend_on[1][0] <= 1'b0;
            ins_rs1_depend_on[1][1] <= 1'b0;
            ins_rs1_depend_on[1][2] <= 1'b0;
            ins_rs1_depend_on[1][3] <= 1'b0;
            ins_rs1_depend_on[1][4] <= 1'b0;
            ins_rs1_depend_on[1][5] <= 1'b0;
            ins_rs1_depend_on[1][6] <= 1'b0;
            ins_rs1_depend_on[1][7] <= 1'b0;
            ins_rs1_depend_on[2][0] <= 1'b0;
            ins_rs1_depend_on[2][1] <= 1'b0;
            ins_rs1_depend_on[2][2] <= 1'b0;
            ins_rs1_depend_on[2][3] <= 1'b0;
            ins_rs1_depend_on[2][4] <= 1'b0;
            ins_rs1_depend_on[2][5] <= 1'b0;
            ins_rs1_depend_on[2][6] <= 1'b0;
            ins_rs1_depend_on[2][7] <= 1'b0;
            ins_rs1_depend_on[3][0] <= 1'b0;
            ins_rs1_depend_on[3][1] <= 1'b0;
            ins_rs1_depend_on[3][2] <= 1'b0;
            ins_rs1_depend_on[3][3] <= 1'b0;
            ins_rs1_depend_on[3][4] <= 1'b0;
            ins_rs1_depend_on[3][5] <= 1'b0;
            ins_rs1_depend_on[3][6] <= 1'b0;
            ins_rs1_depend_on[3][7] <= 1'b0;
            ins_rs1_depend_on[4][0] <= 1'b0;
            ins_rs1_depend_on[4][1] <= 1'b0;
            ins_rs1_depend_on[4][2] <= 1'b0;
            ins_rs1_depend_on[4][3] <= 1'b0;
            ins_rs1_depend_on[4][4] <= 1'b0;
            ins_rs1_depend_on[4][5] <= 1'b0;
            ins_rs1_depend_on[4][6] <= 1'b0;
            ins_rs1_depend_on[4][7] <= 1'b0;
            ins_rs1_depend_on[5][0] <= 1'b0;
            ins_rs1_depend_on[5][1] <= 1'b0;
            ins_rs1_depend_on[5][2] <= 1'b0;
            ins_rs1_depend_on[5][3] <= 1'b0;
            ins_rs1_depend_on[5][4] <= 1'b0;
            ins_rs1_depend_on[5][5] <= 1'b0;
            ins_rs1_depend_on[5][6] <= 1'b0;
            ins_rs1_depend_on[5][7] <= 1'b0;
            ins_rs1_depend_on[6][0] <= 1'b0;
            ins_rs1_depend_on[6][1] <= 1'b0;
            ins_rs1_depend_on[6][2] <= 1'b0;
            ins_rs1_depend_on[6][3] <= 1'b0;
            ins_rs1_depend_on[6][4] <= 1'b0;
            ins_rs1_depend_on[6][5] <= 1'b0;
            ins_rs1_depend_on[6][6] <= 1'b0;
            ins_rs1_depend_on[6][7] <= 1'b0;
            ins_rs1_depend_on[7][0] <= 1'b0;
            ins_rs1_depend_on[7][1] <= 1'b0;
            ins_rs1_depend_on[7][2] <= 1'b0;
            ins_rs1_depend_on[7][3] <= 1'b0;
            ins_rs1_depend_on[7][4] <= 1'b0;
            ins_rs1_depend_on[7][5] <= 1'b0;
            ins_rs1_depend_on[7][6] <= 1'b0;
            ins_rs1_depend_on[7][7] <= 1'b0;
            ins_rs1_dependency_satified[0] <= 1'b0;
            ins_rs1_dependency_satified[1] <= 1'b0;
            ins_rs1_dependency_satified[2] <= 1'b0;
            ins_rs1_dependency_satified[3] <= 1'b0;
            ins_rs1_dependency_satified[4] <= 1'b0;
            ins_rs1_dependency_satified[5] <= 1'b0;
            ins_rs1_dependency_satified[6] <= 1'b0;
            ins_rs1_dependency_satified[7] <= 1'b0;
            ins_rs2_depend_on[0][0] <= 1'b0;
            ins_rs2_depend_on[0][1] <= 1'b0;
            ins_rs2_depend_on[0][2] <= 1'b0;
            ins_rs2_depend_on[0][3] <= 1'b0;
            ins_rs2_depend_on[0][4] <= 1'b0;
            ins_rs2_depend_on[0][5] <= 1'b0;
            ins_rs2_depend_on[0][6] <= 1'b0;
            ins_rs2_depend_on[0][7] <= 1'b0;
            ins_rs2_depend_on[1][0] <= 1'b0;
            ins_rs2_depend_on[1][1] <= 1'b0;
            ins_rs2_depend_on[1][2] <= 1'b0;
            ins_rs2_depend_on[1][3] <= 1'b0;
            ins_rs2_depend_on[1][4] <= 1'b0;
            ins_rs2_depend_on[1][5] <= 1'b0;
            ins_rs2_depend_on[1][6] <= 1'b0;
            ins_rs2_depend_on[1][7] <= 1'b0;
            ins_rs2_depend_on[2][0] <= 1'b0;
            ins_rs2_depend_on[2][1] <= 1'b0;
            ins_rs2_depend_on[2][2] <= 1'b0;
            ins_rs2_depend_on[2][3] <= 1'b0;
            ins_rs2_depend_on[2][4] <= 1'b0;
            ins_rs2_depend_on[2][5] <= 1'b0;
            ins_rs2_depend_on[2][6] <= 1'b0;
            ins_rs2_depend_on[2][7] <= 1'b0;
            ins_rs2_depend_on[3][0] <= 1'b0;
            ins_rs2_depend_on[3][1] <= 1'b0;
            ins_rs2_depend_on[3][2] <= 1'b0;
            ins_rs2_depend_on[3][3] <= 1'b0;
            ins_rs2_depend_on[3][4] <= 1'b0;
            ins_rs2_depend_on[3][5] <= 1'b0;
            ins_rs2_depend_on[3][6] <= 1'b0;
            ins_rs2_depend_on[3][7] <= 1'b0;
            ins_rs2_depend_on[4][0] <= 1'b0;
            ins_rs2_depend_on[4][1] <= 1'b0;
            ins_rs2_depend_on[4][2] <= 1'b0;
            ins_rs2_depend_on[4][3] <= 1'b0;
            ins_rs2_depend_on[4][4] <= 1'b0;
            ins_rs2_depend_on[4][5] <= 1'b0;
            ins_rs2_depend_on[4][6] <= 1'b0;
            ins_rs2_depend_on[4][7] <= 1'b0;
            ins_rs2_depend_on[5][0] <= 1'b0;
            ins_rs2_depend_on[5][1] <= 1'b0;
            ins_rs2_depend_on[5][2] <= 1'b0;
            ins_rs2_depend_on[5][3] <= 1'b0;
            ins_rs2_depend_on[5][4] <= 1'b0;
            ins_rs2_depend_on[5][5] <= 1'b0;
            ins_rs2_depend_on[5][6] <= 1'b0;
            ins_rs2_depend_on[5][7] <= 1'b0;
            ins_rs2_depend_on[6][0] <= 1'b0;
            ins_rs2_depend_on[6][1] <= 1'b0;
            ins_rs2_depend_on[6][2] <= 1'b0;
            ins_rs2_depend_on[6][3] <= 1'b0;
            ins_rs2_depend_on[6][4] <= 1'b0;
            ins_rs2_depend_on[6][5] <= 1'b0;
            ins_rs2_depend_on[6][6] <= 1'b0;
            ins_rs2_depend_on[6][7] <= 1'b0;
            ins_rs2_depend_on[7][0] <= 1'b0;
            ins_rs2_depend_on[7][1] <= 1'b0;
            ins_rs2_depend_on[7][2] <= 1'b0;
            ins_rs2_depend_on[7][3] <= 1'b0;
            ins_rs2_depend_on[7][4] <= 1'b0;
            ins_rs2_depend_on[7][5] <= 1'b0;
            ins_rs2_depend_on[7][6] <= 1'b0;
            ins_rs2_depend_on[7][7] <= 1'b0;
            ins_rs2_dependency_satified[0] <= 1'b0;
            ins_rs2_dependency_satified[1] <= 1'b0;
            ins_rs2_dependency_satified[2] <= 1'b0;
            ins_rs2_dependency_satified[3] <= 1'b0;
            ins_rs2_dependency_satified[4] <= 1'b0;
            ins_rs2_dependency_satified[5] <= 1'b0;
            ins_rs2_dependency_satified[6] <= 1'b0;
            ins_rs2_dependency_satified[7] <= 1'b0;
            ins_memrw_depend_on[0][0] <= 1'b0;
            ins_memrw_depend_on[0][1] <= 1'b0;
            ins_memrw_depend_on[0][2] <= 1'b0;
            ins_memrw_depend_on[0][3] <= 1'b0;
            ins_memrw_depend_on[0][4] <= 1'b0;
            ins_memrw_depend_on[0][5] <= 1'b0;
            ins_memrw_depend_on[0][6] <= 1'b0;
            ins_memrw_depend_on[0][7] <= 1'b0;
            ins_memrw_depend_on[1][0] <= 1'b0;
            ins_memrw_depend_on[1][1] <= 1'b0;
            ins_memrw_depend_on[1][2] <= 1'b0;
            ins_memrw_depend_on[1][3] <= 1'b0;
            ins_memrw_depend_on[1][4] <= 1'b0;
            ins_memrw_depend_on[1][5] <= 1'b0;
            ins_memrw_depend_on[1][6] <= 1'b0;
            ins_memrw_depend_on[1][7] <= 1'b0;
            ins_memrw_depend_on[2][0] <= 1'b0;
            ins_memrw_depend_on[2][1] <= 1'b0;
            ins_memrw_depend_on[2][2] <= 1'b0;
            ins_memrw_depend_on[2][3] <= 1'b0;
            ins_memrw_depend_on[2][4] <= 1'b0;
            ins_memrw_depend_on[2][5] <= 1'b0;
            ins_memrw_depend_on[2][6] <= 1'b0;
            ins_memrw_depend_on[2][7] <= 1'b0;
            ins_memrw_depend_on[3][0] <= 1'b0;
            ins_memrw_depend_on[3][1] <= 1'b0;
            ins_memrw_depend_on[3][2] <= 1'b0;
            ins_memrw_depend_on[3][3] <= 1'b0;
            ins_memrw_depend_on[3][4] <= 1'b0;
            ins_memrw_depend_on[3][5] <= 1'b0;
            ins_memrw_depend_on[3][6] <= 1'b0;
            ins_memrw_depend_on[3][7] <= 1'b0;
            ins_memrw_depend_on[4][0] <= 1'b0;
            ins_memrw_depend_on[4][1] <= 1'b0;
            ins_memrw_depend_on[4][2] <= 1'b0;
            ins_memrw_depend_on[4][3] <= 1'b0;
            ins_memrw_depend_on[4][4] <= 1'b0;
            ins_memrw_depend_on[4][5] <= 1'b0;
            ins_memrw_depend_on[4][6] <= 1'b0;
            ins_memrw_depend_on[4][7] <= 1'b0;
            ins_memrw_depend_on[5][0] <= 1'b0;
            ins_memrw_depend_on[5][1] <= 1'b0;
            ins_memrw_depend_on[5][2] <= 1'b0;
            ins_memrw_depend_on[5][3] <= 1'b0;
            ins_memrw_depend_on[5][4] <= 1'b0;
            ins_memrw_depend_on[5][5] <= 1'b0;
            ins_memrw_depend_on[5][6] <= 1'b0;
            ins_memrw_depend_on[5][7] <= 1'b0;
            ins_memrw_depend_on[6][0] <= 1'b0;
            ins_memrw_depend_on[6][1] <= 1'b0;
            ins_memrw_depend_on[6][2] <= 1'b0;
            ins_memrw_depend_on[6][3] <= 1'b0;
            ins_memrw_depend_on[6][4] <= 1'b0;
            ins_memrw_depend_on[6][5] <= 1'b0;
            ins_memrw_depend_on[6][6] <= 1'b0;
            ins_memrw_depend_on[6][7] <= 1'b0;
            ins_memrw_depend_on[7][0] <= 1'b0;
            ins_memrw_depend_on[7][1] <= 1'b0;
            ins_memrw_depend_on[7][2] <= 1'b0;
            ins_memrw_depend_on[7][3] <= 1'b0;
            ins_memrw_depend_on[7][4] <= 1'b0;
            ins_memrw_depend_on[7][5] <= 1'b0;
            ins_memrw_depend_on[7][6] <= 1'b0;
            ins_memrw_depend_on[7][7] <= 1'b0;
            ins_memrw_dependency_satified[0] <= 1'b0;
            ins_memrw_dependency_satified[1] <= 1'b0;
            ins_memrw_dependency_satified[2] <= 1'b0;
            ins_memrw_dependency_satified[3] <= 1'b0;
            ins_memrw_dependency_satified[4] <= 1'b0;
            ins_memrw_dependency_satified[5] <= 1'b0;
            ins_memrw_dependency_satified[6] <= 1'b0;
            ins_memrw_dependency_satified[7] <= 1'b0;
            ins_opcode[0] <= 7'b0;
            ins_opcode[1] <= 7'b0;
            ins_opcode[2] <= 7'b0;
            ins_opcode[3] <= 7'b0;
            ins_opcode[4] <= 7'b0;
            ins_opcode[5] <= 7'b0;
            ins_opcode[6] <= 7'b0;
            ins_opcode[7] <= 7'b0;
            ins_funct3[0] <= 3'b0;
            ins_funct3[1] <= 3'b0;
            ins_funct3[2] <= 3'b0;
            ins_funct3[3] <= 3'b0;
            ins_funct3[4] <= 3'b0;
            ins_funct3[5] <= 3'b0;
            ins_funct3[6] <= 3'b0;
            ins_funct3[7] <= 3'b0;
            ins_funct7[0] <= 7'b0;
            ins_funct7[1] <= 7'b0;
            ins_funct7[2] <= 7'b0;
            ins_funct7[3] <= 7'b0;
            ins_funct7[4] <= 7'b0;
            ins_funct7[5] <= 7'b0;
            ins_funct7[6] <= 7'b0;
            ins_funct7[7] <= 7'b0;
            ins_imm_val[0] <= 32'b0;
            ins_imm_val[1] <= 32'b0;
            ins_imm_val[2] <= 32'b0;
            ins_imm_val[3] <= 32'b0;
            ins_imm_val[4] <= 32'b0;
            ins_imm_val[5] <= 32'b0;
            ins_imm_val[6] <= 32'b0;
            ins_imm_val[7] <= 32'b0;
            ins_shamt_val[0] <= 6'b0;
            ins_shamt_val[1] <= 6'b0;
            ins_shamt_val[2] <= 6'b0;
            ins_shamt_val[3] <= 6'b0;
            ins_shamt_val[4] <= 6'b0;
            ins_shamt_val[5] <= 6'b0;
            ins_shamt_val[6] <= 6'b0;
            ins_shamt_val[7] <= 6'b0;
            ins_rs1[0] <= 5'b0;
            ins_rs1[1] <= 5'b0;
            ins_rs1[2] <= 5'b0;
            ins_rs1[3] <= 5'b0;
            ins_rs1[4] <= 5'b0;
            ins_rs1[5] <= 5'b0;
            ins_rs1[6] <= 5'b0;
            ins_rs1[7] <= 5'b0;
            ins_rs1_val[0] <= 32'b0;
            ins_rs1_val[1] <= 32'b0;
            ins_rs1_val[2] <= 32'b0;
            ins_rs1_val[3] <= 32'b0;
            ins_rs1_val[4] <= 32'b0;
            ins_rs1_val[5] <= 32'b0;
            ins_rs1_val[6] <= 32'b0;
            ins_rs1_val[7] <= 32'b0;
            ins_rs2[0] <= 5'b0;
            ins_rs2[1] <= 5'b0;
            ins_rs2[2] <= 5'b0;
            ins_rs2[3] <= 5'b0;
            ins_rs2[4] <= 5'b0;
            ins_rs2[5] <= 5'b0;
            ins_rs2[6] <= 5'b0;
            ins_rs2[7] <= 5'b0;
            ins_rs2_val[0] <= 32'b0;
            ins_rs2_val[1] <= 32'b0;
            ins_rs2_val[2] <= 32'b0;
            ins_rs2_val[3] <= 32'b0;
            ins_rs2_val[4] <= 32'b0;
            ins_rs2_val[5] <= 32'b0;
            ins_rs2_val[6] <= 32'b0;
            ins_rs2_val[7] <= 32'b0;
            ins_rd[0] <= 5'b0;
            ins_rd[1] <= 5'b0;
            ins_rd[2] <= 5'b0;
            ins_rd[3] <= 5'b0;
            ins_rd[4] <= 5'b0;
            ins_rd[5] <= 5'b0;
            ins_rd[6] <= 5'b0;
            ins_rd[7] <= 5'b0;
            ins_rd_val[0] <= 32'b0;
            ins_rd_val[1] <= 32'b0;
            ins_rd_val[2] <= 32'b0;
            ins_rd_val[3] <= 32'b0;
            ins_rd_val[4] <= 32'b0;
            ins_rd_val[5] <= 32'b0;
            ins_rd_val[6] <= 32'b0;
            ins_rd_val[7] <= 32'b0;
            ins_is_compressed_ins[0] <= 1'b0;
            ins_is_compressed_ins[1] <= 1'b0;
            ins_is_compressed_ins[2] <= 1'b0;
            ins_is_compressed_ins[3] <= 1'b0;
            ins_is_compressed_ins[4] <= 1'b0;
            ins_is_compressed_ins[5] <= 1'b0;
            ins_is_compressed_ins[6] <= 1'b0;
            ins_is_compressed_ins[7] <= 1'b0;
        end
    endtask

    always @(*) begin
    end

    always @(posedge clk_in) begin
        if (rst_in) begin
            initialize_internal_state;
        end
        else if (!rdy_in) begin
        end
        else begin
            if (flush_pipline_out) begin
                initialize_internal_state;
            end
        end
    end
endmodule
