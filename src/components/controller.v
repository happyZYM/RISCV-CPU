module Controller(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  output wire                 flush_pipline,
  output wire [31:0]          nxt_PC,
  output wire                 is_issuing,
  output wire [31:0]          prefetch_PC,
  output wire                 is_prefetching
);
  reg [31:0] PC;
endmodule