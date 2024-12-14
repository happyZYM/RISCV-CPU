module MemOperator(
        input  wire                 clk_in,			// system clock signal
        input  wire                 rst_in,			// reset signal
        input  wire                 rdy_in,         // ready signal, pause cpu when low

        input  wire                 flush_pipline,

        input  wire                 have_ins,
        input  wire [CSU_SIZE_BITS - 1:0]          ins_id,
        input  wire [31:0]          rs1_val,
        input  wire [31:0]          rs2_val,
        input  wire [31:0]          imm_val,
        input  wire [ 5:0]          shamt_val,
        input  wire [ 6:0]          opcode,
        input  wire [ 2:0]          funct3,
        input  wire [ 6:0]          funct7,
        input  wire [31:0]          request_PC,
        input  wire                 is_compressed_ins,

        output wire [31:0]          mo_res,
        output wire                 mo_rdy,
        output wire [CSU_SIZE_BITS - 1:0]          res_ins_id,
        output wire [31:0]          completed_mo_resulting_PC, // for branch prediction check

        output wire                 ma_have_mem_access_task,
        output wire [31:0]          ma_mem_access_addr,
        output wire                 ma_mem_access_rw, // 0 for read, 1 for write
        output wire [1:0]           ma_mem_access_size, // 00 -> 1 byte, 01 -> 2 bytes, 10 -> 4 bytes, 11 -> 8 bytes
        output wire [31:0]          ma_mem_access_data,
        input wire                  ma_mem_access_task_done,
        input wire [31:0]           ma_mem_access_data_out,
        output wire                 mo_available
    );

    assign mo_rdy = ma_mem_access_task_done;
    wire is_sb = (opcode == 7'b0100011) && (funct3 == 3'b000);
    wire is_sh = (opcode == 7'b0100011) && (funct3 == 3'b001);
    wire is_sw = (opcode == 7'b0100011) && (funct3 == 3'b010);
    wire is_lb = (opcode == 7'b0000011) && (funct3 == 3'b000);
    wire is_lbu = (opcode == 7'b0000011) && (funct3 == 3'b100);
    wire is_lh = (opcode == 7'b0000011) && (funct3 == 3'b001);
    wire is_lhu = (opcode == 7'b0000011) && (funct3 == 3'b101);
    wire is_lw = (opcode == 7'b0000011) && (funct3 == 3'b010);
    wire [31:0] lb_out = {{24{ma_mem_access_data_out[7]}}, ma_mem_access_data_out[7:0]};
    wire [31:0] lbu_out = {{24{1'b0}}, ma_mem_access_data_out[7:0]};
    wire [31:0] lh_out = {{16{ma_mem_access_data_out[15]}}, ma_mem_access_data_out[15:0]};
    wire [31:0] lhu_out = {{16{1'b0}}, ma_mem_access_data_out[15:0]};
    wire [31:0] lw_out = ma_mem_access_data_out;
    assign mo_res = (is_lb) ? lb_out : (is_lbu) ? lbu_out : (is_lh) ? lh_out : (is_lhu) ? lhu_out : (is_lw) ? lw_out : 32'b0;
    assign res_ins_id = ins_id;
    assign completed_mo_resulting_PC = request_PC + (is_compressed_ins ? 2 : 4);

    assign ma_have_mem_access_task = have_ins;
    assign ma_mem_access_size = funct3[1:0];
    assign ma_mem_access_addr = rs1_val + imm_val;
    assign ma_mem_access_rw = (is_sb || is_sh || is_sw) ? 1 : 0;
    assign ma_mem_access_data = rs2_val;

endmodule
