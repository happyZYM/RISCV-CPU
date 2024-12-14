module CentralScheduleUnit(
        input  wire                                clk_in, // system clock signal
        input  wire                                rst_in, // reset signal
        input  wire	                               rdy_in, // ready signal, pause cpu when low

        output wire                                flush_pipline,
        output wire [31:0]                         reset_PC_to,

        input  wire                                ins_just_issued,
        input  wire [31:0]                         issue_PC,
        input  wire [31:0]                         issue_predicted_resulting_PC,
        input  wire [31:0]                         ins_issued,
        input  wire [ 6:0]                         issue_opcode,
        input  wire [ 2:0]                         issue_funct3,
        input  wire [ 6:0]                         issue_funct7,
        input  wire [31:0]                         issue_imm_val,
        input  wire [ 5:0]                         issue_shamt_val,
        input  wire [ 4:0]                         issue_rs1,
        input  wire [ 4:0]                         issue_rs2,
        input  wire [ 4:0]                         issue_rd,
        input  wire                                issue_is_compressed_ins,
        output wire                                issue_space_available,

        output wire                                is_executing,
        output wire                                executing_ins_type, // 0 for alu and 1 for memory operator
        output wire [CSU_SIZE_BITS - 1:0]          exec_ins_id,
        output wire [ 6:0]                         exec_opcode,
        output wire [ 2:0]                         exec_funct3,
        output wire [ 6:0]                         exec_funct7,
        output wire [31:0]                         exec_imm_val,
        output wire [ 5:0]                         exec_shamt_val,
        output wire [31:0]                         exec_rs1,
        output wire [31:0]                         exec_rs2,
        output wire [ 4:0]                         exec_rd,
        output wire [31:0]                         exec_PC,
        output wire                                exec_is_compressed_ins,

        input wire [31:0]                          alu_res,
        input wire                                 alu_rdy,
        input wire [CSU_SIZE_BITS - 1:0]           alu_res_ins_id,
        input wire [31:0]                          alu_completed_alu_resulting_PC, // for branch prediction check

        input wire [31:0]                          mo_res,
        input wire                                 mo_rdy,
        input wire [CSU_SIZE_BITS - 1:0]           mo_res_ins_id,
        input wire [31:0]                          mo_completed_mo_resulting_PC, // for branch prediction check

        output  wire [ 4:0]                        rf_rs1_reg_id,
        input wire [31:0]                          rf_rs1_val,
        output  wire [ 4:0]                        rf_rs2_reg_id,
        input wire [31:0]                          rf_rs2_val,
        output  wire                               rf_is_writing_rd,
        output  wire [ 4:0]                        rf_rd_reg_id,
        output  wire [31:0]                        rf_rd_val
    ); // This module act as ROB, Reserve Station and Load/Store Buffer
    // output control
    reg flush_pipline_out;


    // internal data
    reg [7:0] ins_count_in_csu;
    assign issue_space_available = (ins_count_in_csu < 8);

    reg reg_writen[31:0];
    reg [CSU_SIZE_BITS - 1:0] reg_depends_on [31:0];
    reg [7:0] memrw_ins_count;
    reg [CSU_SIZE_BITS - 1:0] previous_memrw_ins_id;

    reg [CSU_SIZE_BITS - 1:0] csu_head;
    reg [CSU_SIZE_BITS - 1:0] csu_tail;
    reg [7:0] ins_state [CSU_SIZE - 1:0]; // 0 -> empty, 1-> recorded
    reg [31:0] ins_full [CSU_SIZE - 1:0]; // for debug, no need for real cpu
    reg [31:0] ins_PC [CSU_SIZE - 1:0]; // for debug, no need for real cpu
    reg [31:0] ins_predicted_resulting_PC [CSU_SIZE - 1:0];
    reg ins_rs1_depend_on [CSU_SIZE - 1:0][CSU_SIZE - 1:0];
    reg ins_rs1_dependency_satified [CSU_SIZE - 1:0];
    reg ins_rs2_depend_on [CSU_SIZE - 1:0][CSU_SIZE - 1:0];
    reg ins_rs2_dependency_satified [CSU_SIZE - 1:0];
    reg ins_memrw_depend_on [CSU_SIZE - 1:0][CSU_SIZE - 1:0];
    reg ins_memrw_dependency_satified [CSU_SIZE - 1:0];

    reg [6:0] ins_opcode [CSU_SIZE - 1:0];
    reg [2:0] ins_funct3 [CSU_SIZE - 1:0];
    reg [6:0] ins_funct7 [CSU_SIZE - 1:0];
    reg [31:0] ins_imm_val [CSU_SIZE - 1:0];
    reg [ 5:0] ins_shamt_val [CSU_SIZE - 1:0];
    reg [ 4:0] ins_rs1 [CSU_SIZE - 1:0];
    reg [31:0] ins_rs1_val [CSU_SIZE - 1:0];
    reg [ 4:0] ins_rs2 [CSU_SIZE - 1:0];
    reg [31:0] ins_rs2_val [CSU_SIZE - 1:0];
    reg [ 4:0] ins_rd [CSU_SIZE - 1:0];
    reg [31:0] ins_rd_val [CSU_SIZE - 1:0];
    reg ins_is_compressed_ins [CSU_SIZE - 1:0];

    task initialize_internal_state;
        begin
            integer i;
            integer j;
            flush_pipline_out <= 1'b0;
            ins_count_in_csu <= 8'd0;
            for (i = 0; i < 32; i = i + 1) begin
                reg_writen[i] <= 1'b0;
                reg_depends_on[i] <= 3'b000;
            end
            memrw_ins_count <= 8'd0;
            previous_memrw_ins_id <= 3'b000;
            csu_head <= 3'b000;
            csu_tail <= 3'b000;
            for (i = 0; i < CSU_SIZE; i = i + 1) begin
                ins_state[i] <= 8'd0;
                ins_full[i] <= 32'b0;
                ins_PC[i] <= 32'b0;
                ins_predicted_resulting_PC[i] <= 32'b0;
                for (j = 0; j < CSU_SIZE; j = j + 1) begin
                    ins_rs1_depend_on[i][j] <= 1'b0;
                    ins_rs2_depend_on[i][j] <= 1'b0;
                    ins_memrw_depend_on[i][j] <= 1'b0;
                end
                ins_rs1_dependency_satified[i] <= 1'b0;
                ins_rs2_dependency_satified[i] <= 1'b0;
                ins_memrw_dependency_satified[i] <= 1'b0;
                ins_opcode[i] <= 7'b0;
                ins_funct3[i] <= 3'b0;
                ins_funct7[i] <= 7'b0;
                ins_imm_val[i] <= 32'b0;
                ins_shamt_val[i] <= 6'b0;
                ins_rs1[i] <= 5'b0;
                ins_rs1_val[i] <= 32'b0;
                ins_rs2[i] <= 5'b0;
                ins_rs2_val[i] <= 32'b0;
                ins_rd[i] <= 5'b0;
                ins_rd_val[i] <= 32'b0;
                ins_is_compressed_ins[i] <= 1'b0;
            end
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
