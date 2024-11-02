module InstructionCache(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [31:0]          read_addr,
  intput                      is_reading,

  output wire [31:0]          read_data,
);


endmodule