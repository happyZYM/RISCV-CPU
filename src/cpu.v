// RISCV32 CPU top module
// port modification allowed for debugging purposes

module cpu(
        input  wire                 clk_in,			// system clock signal
        input  wire                 rst_in,			// reset signal
        input  wire					        rdy_in,			// ready signal, pause cpu when low

        input  wire [ 7:0]          mem_din,		// data input bus
        output wire [ 7:0]          mem_dout,		// data output bus
        output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
        output wire                 mem_wr,			// write/read signal (1 for write)

        input  wire                 io_buffer_full, // 1 if uart buffer is full

        output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
    );

    // output wires of sub modules
    wire im_is_issueing;
    wire [31:0] im_issue_PC;
    wire [31:0] im_predicted_resulting_PC;
    wire [31:0] im_full_ins;
    wire [ 6:0] im_opcode;
    wire [ 2:0] im_funct3;
    wire [ 6:0] im_funct7;
    wire [31:0] im_imm_val;
    wire [ 5:0] im_shamt_val;
    wire [ 4:0] im_rs1;
    wire [ 4:0] im_rs2;
    wire [ 4:0] im_rd;
    wire im_is_compressed_ins;
    wire im_request_ins_from_memory_adaptor;
    wire [31:0] im_insaddr_to_be_fetched_from_memory_adaptor;

    wire                 ma_insfetch_task_done;
    wire [31:0]          ma_insfetch_ins_full;
    wire                 ma_mem_access_task_done;
    wire [31:0]          ma_mem_access_data_out;

    wire [31:0] rf_rs1_val;
    wire [31:0] rf_rs2_val;

    wire csu_flush_pipline;
    wire [31:0] csu_reset_PC_to;
    wire csu_issue_space_available;
    wire csu_is_executing;
    wire csu_executing_ins_type;
    wire [CSU_SIZE_BITS - 1:0] csu_exec_ins_id;
    wire [ 6:0] csu_exec_opcode;
    wire [ 2:0] csu_exec_funct3;
    wire [ 6:0] csu_exec_funct7;
    wire [31:0] csu_exec_imm_val;
    wire [ 5:0] csu_exec_shamt_val;
    wire [31:0] csu_exec_rs1;
    wire [31:0] csu_exec_rs2;
    wire [ 4:0] csu_exec_rd;
    wire [31:0] csu_exec_PC;
    wire csu_exec_is_compressed_ins;
    wire [ 4:0] csu_rf_rs1_reg_id;
    wire [ 4:0] csu_rf_rs2_reg_id;
    wire csu_rf_is_writing_rd;
    wire [ 4:0] csu_rf_rd_reg_id;
    wire [31:0] csu_rf_rd_val;

    wire [31:0] alu_alu_res;
    wire alu_alu_rdy;
    wire [CSU_SIZE_BITS - 1:0] alu_res_ins_id;
    wire [31:0] alu_completed_alu_resulting_PC;
    wire alu_jalr_just_done;
    wire [31:0] alu_jalr_resulting_PC;

    wire [31:0] mo_mo_res;
    wire mo_mo_rdy;
    wire [CSU_SIZE_BITS - 1:0] mo_res_ins_id;
    wire [31:0] mo_completed_mo_resulting_PC;
    wire                 mo_ma_have_mem_access_task;
    wire [31:0]          mo_ma_mem_access_addr;
    wire                 mo_ma_mem_access_rw;
    wire [1:0]           mo_ma_mem_access_size;
    wire [31:0]          mo_ma_mem_access_data;

    IssueManager im(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),
        .flush_pipline(csu_flush_pipline),
        .reset_PC_to(csu_reset_PC_to),
        .jalr_just_done(alu_jalr_just_done),
        .jalr_resulting_PC(alu_jalr_resulting_PC),
        .issue_space_available(csu_issue_space_available),
        .is_issueing(im_is_issueing),
        .issue_PC(im_issue_PC),
        .predicted_resulting_PC(im_predicted_resulting_PC),
        .full_ins(im_full_ins),
        .opcode(im_opcode),
        .funct3(im_funct3),
        .funct7(im_funct7),
        .imm_val(im_imm_val),
        .shamt_val(im_shamt_val),
        .rs1(im_rs1),
        .rs2(im_rs2),
        .rd(im_rd),
        .is_compressed_ins(im_is_compressed_ins),
        .ins_fetched_from_memory_adaptor(ma_insfetch_ins_full),
        .insfetch_task_done(ma_insfetch_task_done),
        .request_ins_from_memory_adaptor(im_request_ins_from_memory_adaptor),
        .insaddr_to_be_fetched_from_memory_adaptor(im_insaddr_to_be_fetched_from_memory_adaptor)
    );

    MemAdapter ma(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),
        .flush_pipline(csu_flush_pipline),
        .mem_din(mem_din),
        .mem_dout(mem_dout),
        .mem_a(mem_a),
        .mem_wr(mem_wr),
        .io_buffer_full(io_buffer_full),
        .try_start_insfetch_task(im_request_ins_from_memory_adaptor),
        .insfetch_addr(im_insaddr_to_be_fetched_from_memory_adaptor),
        .insfetch_task_done(ma_insfetch_task_done),
        .insfetch_ins_full(ma_insfetch_ins_full),
        .have_mem_access_task(mo_ma_have_mem_access_task),
        .mem_access_addr(mo_ma_mem_access_addr),
        .mem_access_rw(mo_ma_mem_access_rw),
        .mem_access_size(mo_ma_mem_access_size),
        .mem_access_data(mo_ma_mem_access_data),
        .mem_access_task_done(ma_mem_access_task_done),
        .mem_access_data_out(ma_mem_access_data_out)
    );

    RegisterFile rf(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),
        .flush_pipline(csu_flush_pipline),
        .rs1_reg_id(csu_rf_rs1_reg_id),
        .rs1_val(rf_rs1_val),
        .rs2_reg_id(csu_rf_rs2_reg_id),
        .rs2_val(rf_rs2_val),
        .is_writing_rd(csu_rf_is_writing_rd),
        .rd_reg_id(csu_rf_rd_reg_id),
        .rd_val(csu_rf_rd_val)
    );

    CentralScheduleUnit csu(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),
        .flush_pipline(csu_flush_pipline),
        .reset_PC_to(csu_reset_PC_to),
        .ins_just_issued(im_is_issueing),
        .issue_PC(im_issue_PC),
        .issue_predicted_resulting_PC(im_predicted_resulting_PC),
        .ins_issued(im_full_ins),
        .issue_opcode(im_opcode),
        .issue_funct3(im_funct3),
        .issue_funct7(im_funct7),
        .issue_imm_val(im_imm_val),
        .issue_shamt_val(im_shamt_val),
        .issue_rs1(im_rs1),
        .issue_rs2(im_rs2),
        .issue_rd(im_rd),
        .issue_is_compressed_ins(im_is_compressed_ins),
        .issue_space_available(csu_issue_space_available),
        .is_executing(csu_is_executing),
        .executing_ins_type(csu_executing_ins_type),
        .exec_ins_id(csu_exec_ins_id),
        .exec_opcode(csu_exec_opcode),
        .exec_funct3(csu_exec_funct3),
        .exec_funct7(csu_exec_funct7),
        .exec_imm_val(csu_exec_imm_val),
        .exec_shamt_val(csu_exec_shamt_val),
        .exec_rs1(csu_exec_rs1),
        .exec_rs2(csu_exec_rs2),
        .exec_rd(csu_exec_rd),
        .exec_PC(csu_exec_PC),
        .exec_is_compressed_ins(csu_exec_is_compressed_ins),
        .alu_res(alu_alu_res),
        .alu_rdy(alu_alu_rdy),
        .alu_res_ins_id(alu_res_ins_id),
        .alu_completed_alu_resulting_PC(alu_completed_alu_resulting_PC),
        .mo_res(mo_mo_res),
        .mo_rdy(mo_mo_rdy),
        .mo_res_ins_id(mo_res_ins_id),
        .mo_completed_mo_resulting_PC(mo_completed_mo_resulting_PC),
        .rf_rs1_reg_id(csu_rf_rs1_reg_id),
        .rf_rs1_val(rf_rs1_val),
        .rf_rs2_reg_id(csu_rf_rs2_reg_id),
        .rf_rs2_val(rf_rs2_val),
        .rf_is_writing_rd(csu_rf_is_writing_rd),
        .rf_rd_reg_id(csu_rf_rd_reg_id),
        .rf_rd_val(csu_rf_rd_val)
    );

    Alu alu(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),
        .flush_pipline(csu_flush_pipline),
        .have_ins(csu_is_executing && (csu_executing_ins_type == 0)),
        .ins_id(csu_exec_ins_id),
        .rs1_val(csu_exec_rs1),
        .rs2_val(csu_exec_rs2),
        .imm_val(csu_exec_imm_val),
        .shamt_val(csu_exec_shamt_val),
        .opcode(csu_exec_opcode),
        .funct3(csu_exec_funct3),
        .funct7(csu_exec_funct7),
        .request_PC(csu_exec_PC),
        .is_compressed_ins(csu_exec_is_compressed_ins),
        .alu_res(alu_alu_res),
        .alu_rdy(alu_alu_rdy),
        .res_ins_id(alu_res_ins_id),
        .completed_alu_resulting_PC(alu_completed_alu_resulting_PC),
        .jalr_just_done(alu_jalr_just_done),
        .jalr_resulting_PC(alu_jalr_resulting_PC)
    );

    MemOperator mo(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),
        .flush_pipline(csu_flush_pipline),
        .have_ins(csu_is_executing && (csu_executing_ins_type == 1)),
        .ins_id(csu_exec_ins_id),
        .rs1_val(csu_exec_rs1),
        .rs2_val(csu_exec_rs2),
        .imm_val(csu_exec_imm_val),
        .shamt_val(csu_exec_shamt_val),
        .opcode(csu_exec_opcode),
        .funct3(csu_exec_funct3),
        .funct7(csu_exec_funct7),
        .request_PC(csu_exec_PC),
        .is_compressed_ins(csu_exec_is_compressed_ins),
        .mo_res(mo_mo_res),
        .mo_rdy(mo_mo_rdy),
        .res_ins_id(mo_res_ins_id),
        .completed_mo_resulting_PC(mo_completed_mo_resulting_PC),
        .ma_have_mem_access_task(mo_ma_have_mem_access_task),
        .ma_mem_access_addr(mo_ma_mem_access_addr),
        .ma_mem_access_rw(mo_ma_mem_access_rw),
        .ma_mem_access_size(mo_ma_mem_access_size),
        .ma_mem_access_data(mo_ma_mem_access_data),
        .ma_mem_access_task_done(ma_mem_access_task_done),
        .ma_mem_access_data_out(ma_mem_access_data_out)
    );

    // Specifications:
    // - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
    // - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
    // - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
    // - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
    // - 0x30000 read: read a byte from input
    // - 0x30000 write: write a byte to output (write 0x00 is ignored)
    // - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
    // - 0x30004 write: indicates program stop (will output '\0' through uart tx)

    always @(posedge clk_in) begin
        if (rst_in) begin
        end
        else if (!rdy_in) begin
        end
        else begin

        end
    end

endmodule
