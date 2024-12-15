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
    // internal data
    reg [7:0] ins_count_in_csu;
    assign issue_space_available = (ins_count_in_csu < CSU_SIZE);

    reg reg_writen[31:0];
    reg [CSU_SIZE_BITS - 1:0] reg_depends_on [31:0];
    reg [7:0] memrw_ins_count;
    reg [CSU_SIZE_BITS - 1:0] previous_memrw_ins_id;

    reg [CSU_SIZE_BITS - 1:0] csu_head;
    reg [CSU_SIZE_BITS - 1:0] csu_tail;
    reg [7:0] ins_state [CSU_SIZE - 1:0]; // 0 -> empty, 1-> recorded, 2 -> in execution, 3 -> done
    reg [31:0] ins_full [CSU_SIZE - 1:0]; // for debug, no need for real cpu
    reg [31:0] ins_PC [CSU_SIZE - 1:0]; // for debug, no need for real cpu
    reg [31:0] ins_predicted_resulting_PC [CSU_SIZE - 1:0];
    reg [CSU_SIZE_BITS - 1:0] ins_rs1_depend_on [CSU_SIZE - 1:0];
    reg ins_rs1_dependency_satified [CSU_SIZE - 1:0];
    reg [CSU_SIZE_BITS - 1:0] ins_rs2_depend_on [CSU_SIZE - 1:0];
    reg ins_rs2_dependency_satified [CSU_SIZE - 1:0];
    reg [CSU_SIZE_BITS - 1:0] ins_memrw_depend_on [CSU_SIZE - 1:0];
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
    reg [31:0] ins_actual_resulting_PC [CSU_SIZE - 1:0];

    wire need_commit = (ins_count_in_csu > 0) && (ins_state[csu_head] == 3);
    assign rf_is_writing_rd = need_commit;
    assign rf_rd_reg_id = ins_rd[csu_head];
    assign rf_rd_val = ins_rd_val[csu_head];
    wire prediction_failed = (need_commit && (ins_actual_resulting_PC[csu_head] != ins_predicted_resulting_PC[csu_head]));
    assign flush_pipline = prediction_failed;
    assign reset_PC_to = ins_actual_resulting_PC[csu_head];

    assign rf_rs1_reg_id = issue_rs1;
    assign rf_rs2_reg_id = issue_rs2;

    wire is_mem_read [CSU_SIZE - 1 : 0];
    genvar i;
    generate
        for (i = 0; i < CSU_SIZE; i = i + 1) begin
            assign is_mem_read[i] = (ins_opcode[i] == 7'b0000011);
        end
    endgenerate

    wire is_mem_write [CSU_SIZE - 1 : 0];
    generate
        for (i = 0; i < CSU_SIZE; i = i + 1) begin
            assign is_mem_write[i] = (ins_opcode[i] == 7'b0100011);
        end
    endgenerate

    wire ready_for_exec [CSU_SIZE - 1 : 0];
    generate
        for (i = 0; i < CSU_SIZE; i = i + 1) begin
            assign ready_for_exec[i] = (ins_state[i] == 1)
                   && ins_rs1_dependency_satified[i]
                   && ins_rs2_dependency_satified[i]
                   && ins_memrw_dependency_satified[i]
                   && ((!is_mem_write[i]) || i == csu_head);
        end
    endgenerate

    wire have_ins_to_exec__ [CSU_SIZE - 1 : 0];
    wire [CSU_SIZE_BITS - 1:0] ins_to_exec_id__ [CSU_SIZE - 1 : 0];

    generate
        for (i = HALF_CSU_SIZE; i < CSU_SIZE; i = i + 1) begin
            assign have_ins_to_exec__[i] = ready_for_exec[i];
            assign ins_to_exec_id__[i] = ready_for_exec[i] ? i : 0;
        end
        for (i = 1; i < HALF_CSU_SIZE; i = i + 1) begin
            assign have_ins_to_exec__[i] = ready_for_exec[i] || have_ins_to_exec__[i<<1] || have_ins_to_exec__[(i<<1)|1];
            assign ins_to_exec_id__[i] = ready_for_exec[i] ? i :
                   have_ins_to_exec__[i<<1] ? ins_to_exec_id__[i<<1] : ins_to_exec_id__[(i<<1)|1];
        end
        assign have_ins_to_exec__[0] = ready_for_exec[0] || have_ins_to_exec__[1];
        assign ins_to_exec_id__[0] = ready_for_exec[0] ? 0 : ins_to_exec_id__[1];
    endgenerate

    wire have_ins_to_exec = have_ins_to_exec__[0];
    wire [CSU_SIZE_BITS - 1:0] ins_to_exec_id = ins_to_exec_id__[0];
    wire ins_to_exec_is_memrw = is_mem_read[ins_to_exec_id] || is_mem_write[ins_to_exec_id];
    wire can_submit_for_exec = have_ins_to_exec && ((!is_executing_reg) || current_exec_just_done);

    reg                                is_executing_reg;
    assign is_executing = is_executing_reg;
    reg                                executing_ins_type_reg; // 0 for alu and 1 for memory operator
    assign executing_ins_type = executing_ins_type_reg;
    reg [CSU_SIZE_BITS - 1:0]          exec_ins_id_reg;
    assign exec_ins_id = exec_ins_id_reg;
    reg [ 6:0]                         exec_opcode_reg;
    assign exec_opcode = exec_opcode_reg;
    reg [ 2:0]                         exec_funct3_reg;
    assign exec_funct3 = exec_funct3_reg;
    reg [ 6:0]                         exec_funct7_reg;
    assign exec_funct7 = exec_funct7_reg;
    reg [31:0]                         exec_imm_val_reg;
    assign exec_imm_val = exec_imm_val_reg;
    reg [ 5:0]                         exec_shamt_val_reg;
    assign exec_shamt_val = exec_shamt_val_reg;
    reg [31:0]                         exec_rs1_reg;
    assign exec_rs1 = exec_rs1_reg;
    reg [31:0]                         exec_rs2_reg;
    assign exec_rs2 = exec_rs2_reg;
    reg [ 4:0]                         exec_rd_reg;
    assign exec_rd = exec_rd_reg;
    reg [31:0]                         exec_PC_reg;
    assign exec_PC = exec_PC_reg;
    reg                                exec_is_compressed_ins_reg;
    assign exec_is_compressed_ins = exec_is_compressed_ins_reg;

    wire current_exec_just_done = is_executing_reg && (executing_ins_type_reg ? mo_rdy : alu_rdy);
    wire [CSU_SIZE_BITS - 1:0] just_done_ins_id = executing_ins_type_reg ? mo_res_ins_id : alu_res_ins_id;
    wire [31:0] just_done_res = executing_ins_type_reg ? mo_res : alu_res;
    wire [31:0] just_done_completed_resulting_PC = executing_ins_type_reg ? mo_completed_mo_resulting_PC : alu_completed_alu_resulting_PC;

    task initialize_internal_state;
        begin
            integer i;
            integer j;
            ins_count_in_csu <= 8'd0;
            for (i = 0; i < 32; i = i + 1) begin
                reg_writen[i] <= 1'b0;
                reg_depends_on[i] <= 0;
            end
            memrw_ins_count <= 8'd0;
            previous_memrw_ins_id <= 0;
            csu_head <= 0;
            csu_tail <= 0;
            for (i = 0; i < CSU_SIZE; i = i + 1) begin
                ins_state[i] <= 8'd0;
                ins_full[i] <= 32'b0;
                ins_PC[i] <= 32'b0;
                ins_predicted_resulting_PC[i] <= 32'b0;
                ins_rs1_depend_on[i] <= 0;
                ins_rs2_depend_on[i] <= 0;
                ins_memrw_depend_on[i] <= 0;
                ins_rs1_dependency_satified[i] <= 0;
                ins_rs2_dependency_satified[i] <= 0;
                ins_memrw_dependency_satified[i] <= 0;
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
            is_executing_reg <= 0;
        end
    endtask

    always @(posedge clk_in) begin
        reg [CSU_SIZE_BITS - 1:0] csu_head_tmp;
        reg [CSU_SIZE_BITS - 1:0] csu_tail_tmp;
        reg [7:0] ins_count_in_csu_tmp;
        reg [7:0] memrw_ins_count_tmp;
        integer i;
        integer j;
        if (rst_in) begin
            initialize_internal_state;
        end
        else if (!rdy_in) begin
        end
        else begin
            if (flush_pipline) begin
                initialize_internal_state;
            end
            else begin
                csu_head_tmp = csu_head;
                csu_tail_tmp = csu_tail;
                ins_count_in_csu_tmp = ins_count_in_csu;
                memrw_ins_count_tmp = memrw_ins_count;
                if (need_commit) begin
                    ins_count_in_csu_tmp = ins_count_in_csu_tmp - 1;
                    csu_head_tmp = csu_head_tmp + 1;
                    ins_state[csu_head] <= 8'd0;
                    if (reg_writen[ins_rd[csu_head]] && reg_depends_on[ins_rd[csu_head]] == csu_head && !(ins_just_issued && issue_rd == ins_rd[csu_head])) begin
                        reg_writen[ins_rd[csu_head]] <= 1'b0;
                        reg_depends_on[ins_rd[csu_head]] <= 0;
                    end
                    if (is_mem_read[csu_head] || is_mem_write[csu_head]) begin
                        memrw_ins_count_tmp = memrw_ins_count_tmp - 1;
                    end
                end
                if (ins_just_issued) begin
                    ins_count_in_csu_tmp = ins_count_in_csu_tmp + 1;
                    csu_tail_tmp = csu_tail_tmp + 1;
                    ins_state[csu_tail] <= 8'd1;
                    ins_full[csu_tail] <= ins_issued;
                    ins_PC[csu_tail] <= issue_PC;
                    ins_predicted_resulting_PC[csu_tail] <= issue_predicted_resulting_PC;
                    ins_opcode[csu_tail] <= issue_opcode;
                    ins_funct3[csu_tail] <= issue_funct3;
                    ins_funct7[csu_tail] <= issue_funct7;
                    ins_imm_val[csu_tail] <= issue_imm_val;
                    ins_shamt_val[csu_tail] <= issue_shamt_val;
                    ins_rs1[csu_tail] <= issue_rs1;
                    ins_rs2[csu_tail] <= issue_rs2;
                    ins_rd[csu_tail] <= issue_rd;
                    ins_rd_val[csu_tail] <= 32'b0;
                    ins_is_compressed_ins[csu_tail] <= issue_is_compressed_ins;
                    if (current_exec_just_done && reg_writen[issue_rs1] && reg_depends_on[issue_rs1] == just_done_ins_id) begin
                        ins_rs1_dependency_satified[csu_tail] <= 1;
                        ins_rs1_val[csu_tail] <= just_done_res;
                    end
                    else begin
                        ins_rs1_val[csu_tail] <= reg_writen[issue_rs1] ? ins_rd_val[reg_depends_on[issue_rs1]] : rf_rs1_val;
                        ins_rs1_dependency_satified[csu_tail] <= reg_writen[issue_rs1] ? ins_state[reg_depends_on[issue_rs1]] == 3 : 1'b1;
                    end
                    if (current_exec_just_done && reg_writen[issue_rs2] && reg_depends_on[issue_rs2] == just_done_ins_id) begin
                        ins_rs2_dependency_satified[csu_tail] <= 1;
                        ins_rs2_val[csu_tail] <= just_done_res;
                    end
                    else begin
                        ins_rs2_val[csu_tail] <= reg_writen[issue_rs2] ? ins_rd_val[reg_depends_on[issue_rs2]] : rf_rs2_val;
                        ins_rs2_dependency_satified[csu_tail] <= reg_writen[issue_rs2] ? ins_state[reg_depends_on[issue_rs2]] == 3 : 1'b1;
                    end
                    reg_writen[issue_rd] <= 1'b1;
                    reg_depends_on[issue_rd] <= csu_tail;
                    ins_rs1_depend_on[csu_tail] <= (reg_writen[issue_rs1] ? reg_depends_on[issue_rs1] : 0);
                    ins_rs2_depend_on[csu_tail] <= (reg_writen[issue_rs2] ? reg_depends_on[issue_rs2] : 0);
                    if (issue_opcode == 7'b0000011 || issue_opcode == 7'b0100011) begin
                        if (memrw_ins_count == 0) begin
                            ins_memrw_dependency_satified[csu_tail] <= 1'b1;
                        end
                        else begin
                            ins_memrw_dependency_satified[csu_tail] <= (ins_state[previous_memrw_ins_id] == 3);
                            ins_memrw_depend_on[csu_tail] <= previous_memrw_ins_id;
                        end
                        memrw_ins_count_tmp = memrw_ins_count_tmp + 1;
                        previous_memrw_ins_id <= csu_tail;
                    end
                    else begin
                        ins_memrw_dependency_satified[csu_tail] <= 1'b1;
                    end
                end
                if (can_submit_for_exec) begin
                    ins_state[ins_to_exec_id] <= 2;
                    is_executing_reg <= 1;
                    executing_ins_type_reg <= ins_to_exec_is_memrw;
                    exec_ins_id_reg <= ins_to_exec_id;
                    exec_opcode_reg <= ins_opcode[ins_to_exec_id];
                    exec_funct3_reg <= ins_funct3[ins_to_exec_id];
                    exec_funct7_reg <= ins_funct7[ins_to_exec_id];
                    exec_imm_val_reg <= ins_imm_val[ins_to_exec_id];
                    exec_shamt_val_reg <= ins_shamt_val[ins_to_exec_id];
                    exec_rs1_reg <= ins_rs1_val[ins_to_exec_id];
                    exec_rs2_reg <= ins_rs2_val[ins_to_exec_id];
                    exec_rd_reg <= ins_rd[ins_to_exec_id];
                    exec_PC_reg <= ins_PC[ins_to_exec_id];
                    exec_is_compressed_ins_reg <= ins_is_compressed_ins[ins_to_exec_id];
                end
                if (current_exec_just_done) begin
                    if (!can_submit_for_exec) begin
                        is_executing_reg <= 0;
                    end
                    ins_state[just_done_ins_id] <= 3;
                    ins_rd_val[just_done_ins_id] <= just_done_res;
                    ins_actual_resulting_PC[just_done_ins_id] <= just_done_completed_resulting_PC;
                    for (i = 0; i < CSU_SIZE; i = i + 1) begin
                        if (ins_state[i] == 1 && !ins_rs1_dependency_satified[i] && ins_rs1_depend_on[i] == just_done_ins_id) begin
                            ins_rs1_dependency_satified[i] <= 1'b1;
                            ins_rs1_val[i] <= just_done_res;
                        end
                        if (ins_state[i] == 1 && !ins_rs2_dependency_satified[i] && ins_rs2_depend_on[i] == just_done_ins_id) begin
                            ins_rs2_dependency_satified[i] <= 1'b1;
                            ins_rs2_val[i] <= just_done_res;
                        end
                        if (ins_state[i] == 1 && !ins_memrw_dependency_satified[i] && ins_memrw_depend_on[i] == just_done_ins_id) begin
                            ins_memrw_dependency_satified[i] <= 1'b1;
                        end
                    end
                end
                csu_head <= csu_head_tmp;
                csu_tail <= csu_tail_tmp;
                ins_count_in_csu <= ins_count_in_csu_tmp;
                memrw_ins_count <= memrw_ins_count_tmp;
            end
        end
    end
endmodule
