module ReserveStation(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire                 flush_pipline,
  input  wire                 ins_just_issued,
  input  wire [31:0]          ins_issued,

  output wire [ 6:0]          opcode,
  output wire [ 2:0]          funct3,
  output wire [ 6:0]          funct7,
  output wire [ 4:0]          ins_id,
  output wire                 alu_task_ready,
  output wire                 mem_task_ready,
);

endmodule