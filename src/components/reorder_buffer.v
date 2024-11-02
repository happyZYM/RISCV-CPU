module ReorderedBuffer(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low
  
  input  wire                 flush_pipline,
  input  wire                 ins_just_issued,
  input  wire [31:0]          ins_issued,

  output wire                 need_write_to_regfile,
  output wire [ 4:0]          reg_id,
  output wire [31:0]          data,
);

endmodule