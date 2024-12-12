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
    wire [31:0]          alu_alu_res;
    wire                 alu_alu_rdy;
    wire [ 2:0]          alu_res_ins_id;
    wire [31:0]          alu_completed_alu_resulting_PC;

    wire                 csu_is_executing;
    wire                 csu_executing_ins_type;
    wire [ 2:0]          csu_exec_ins_id;
    wire [ 6:0]          csu_exec_opcode;
    wire [ 2:0]          csu_exec_funct3;
    wire [ 6:0]          csu_exec_funct7;
    wire [31:0]          csu_exec_imm_val;
    wire [ 5:0]          csu_exec_shamt_val;
    wire [31:0]          csu_exec_rs1;
    wire [31:0]          csu_exec_rs2;
    wire [ 4:0]          csu_exec_rd;
    wire [31:0]          csu_exec_PC;
    wire                 csu_flush_pipline;

    wire                 im_is_issueing;
    wire [31:0]          im_issue_PC;
    wire [31:0]          im_full_ins;
    wire [ 6:0]          im_opcode;
    wire [ 2:0]          im_funct3;
    wire [ 6:0]          im_funct7;
    wire [31:0]          im_imm_val;
    wire [ 5:0]          im_shamt_val;
    wire [ 4:0]          im_rs1;
    wire [ 4:0]          im_rs2;
    wire [ 4:0]          im_rd;
    wire                 im_request_ins_from_memory_adaptor;
    wire [31:0]          im_insaddr_to_be_fetched_from_memory_adaptor;

    wire [ 7:0]          ma_mem_dout;
    wire [31:0]          ma_mem_a;
    wire                 ma_mem_wr;
    wire [2:0]           ma_adapter_state;
    wire                 ma_insfetch_task_accepted;
    wire                 ma_insfetch_task_done;
    wire [31:0]          ma_insfetch_ins_full;
    wire                 ma_mem_access_task_accepted;
    wire                 ma_mem_access_task_done;
    wire [31:0]          ma_mem_access_data_out;

    wire [31:0]          mo_alu_res;
    wire                 mo_alu_rdy;
    wire [ 2:0]          mo_res_ins_id;
    wire [31:0]          mo_completed_alu_resulting_PC;

    wire [31:0]          rf_data_out;

    Alu alu(
            .clk_in(clk_in),
            .rst_in(rst_in),
            .rdy_in(rdy_in),
            .flush_pipline(csu_flush_pipline),
            .have_ins(csu_is_executing),
            .ins_id(csu_exec_ins_id),
            .rs1_val(csu_exec_rs1),
            .rs2_val(csu_exec_rs2),
            .imm_val(csu_exec_imm_val),
            .shamt_val(csu_exec_shamt_val),
            .opcode(csu_exec_opcode),
            .funct3(csu_exec_funct3),
            .funct7(csu_exec_funct7),
            .request_PC(csu_exec_PC),
            .alu_res(alu_alu_res),
            .alu_rdy(alu_alu_rdy),
            .res_ins_id(alu_res_ins_id),
            .completed_alu_resulting_PC(alu_completed_alu_resulting_PC)
        );

    CentralScheduleUnit csu(
                            .clk_in(clk_in),
                            .rst_in(rst_in),
                            .rdy_in(rdy_in),
                            .ins_just_issued(im_is_issueing),
                            .issue_PC(im_issue_PC),
                            .ins_issued(im_full_ins),
                            .issue_opcode(im_opcode),
                            .issue_funct3(im_funct3),
                            .issue_funct7(im_funct7),
                            .issue_imm_val(im_imm_val),
                            .issue_shamt_val(im_shamt_val),
                            .issue_rs1(im_rs1),
                            .issue_rs2(im_rs2),
                            .issue_rd(im_rd),
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
                            .flush_pipline(csu_flush_pipline)
                        );

    IssueManager im(
                     .clk_in(clk_in),
                     .rst_in(rst_in),
                     .rdy_in(rdy_in),
                     .flush_pipline(csu_flush_pipline),
                     .is_issueing(im_is_issueing),
                     .issue_PC(im_issue_PC),
                     .full_ins(im_full_ins),
                     .opcode(im_opcode),
                     .funct3(im_funct3),
                     .funct7(im_funct7),
                     .imm_val(im_imm_val),
                     .shamt_val(im_shamt_val),
                     .rs1(im_rs1),
                     .rs2(im_rs2),
                     .rd(im_rd),
                     .request_ins_from_memory_adaptor(im_request_ins_from_memory_adaptor),
                     .insaddr_to_be_fetched_from_memory_adaptor(im_insaddr_to_be_fetched_from_memory_adaptor),
                     .ins_fetched_from_memory_adaptor(ma_insfetch_ins_full),
                     .insfetch_task_done(ma_insfetch_task_done)
                 );

    MemAdapter ma(
                   .clk_in(clk_in),
                   .rst_in(rst_in),
                   .rdy_in(rdy_in),
                   .flush_pipline(csu_flush_pipline),
                   .mem_din(mem_din),
                   .mem_dout(ma_mem_dout),
                   .mem_a(ma_mem_a),
                   .mem_wr(ma_mem_wr),
                   .io_buffer_full(io_buffer_full),
                   .try_start_insfetch_task(im_request_ins_from_memory_adaptor),
                   .insfetch_addr(im_insaddr_to_be_fetched_from_memory_adaptor),
                   .insfetch_task_done(ma_insfetch_task_done),
                   .insfetch_ins_full(ma_insfetch_ins_full),
                   .have_mem_access_task(csu_is_executing),
                   .mem_access_addr(csu_exec_PC),
                   .mem_access_rw(csu_executing_ins_type),
                   .mem_access_data(csu_exec_rs2),
                   .mem_access_task_done(ma_mem_access_task_done),
                   .mem_access_data_out(ma_mem_access_data_out)
               );

    MemOperator mo(
                    .clk_in(clk_in),
                    .rst_in(rst_in),
                    .rdy_in(rdy_in),
                    .flush_pipline(csu_flush_pipline),
                    .have_ins(csu_is_executing),
                    .ins_id(csu_exec_ins_id),
                    .rs1_val(csu_exec_rs1),
                    .rs2_val(csu_exec_rs2),
                    .imm_val(csu_exec_imm_val),
                    .shamt_val(csu_exec_shamt_val),
                    .opcode(csu_exec_opcode),
                    .funct3(csu_exec_funct3),
                    .funct7(csu_exec_funct7),
                    .request_PC(csu_exec_PC),
                    // .alu_res(mo_alu_res),
                    // .alu_rdy(mo_alu_rdy),
                    .res_ins_id(mo_res_ins_id)
                    // .completed_alu_resulting_PC(mo_completed_alu_resulting_PC)
                );

    RegisterFile rf(
                     .clk_in(clk_in),
                     .rst_in(rst_in),
                     .rdy_in(rdy_in),
                     .flush_pipline(csu_flush_pipline)
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
