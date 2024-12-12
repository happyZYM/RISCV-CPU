module MemOperator(
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

        output wire [31:0]          mo_res,
        output wire                 mo_rdy,
        output wire [ 2:0]          res_ins_id,
        output wire [31:0]          completed_mo_resulting_PC // for branch prediction check
    );


endmodule
