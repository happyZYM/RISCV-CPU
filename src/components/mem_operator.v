module MemOperator(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire                 have_ins,
  input  wire [ 4:0]          ins_id,
  input  wire [31:0]          addr,
  input  wire [31:0]          data,
  input  wire [ 6:0]          opcode,
  input  wire [ 2:0]          funct3,
  input  wire [ 6:0]          funct7,

  output wire [31:0]          alu_res,
  output wire                 alu_rdy,
  output wire [ 4:0]          res_ins_id
);


endmodule