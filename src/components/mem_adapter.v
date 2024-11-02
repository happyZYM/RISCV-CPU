module MemAdapter(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	input  wire                 io_buffer_full, // 1 if uart buffer is full

  output wire [2:0]           adapter_state,

  input  wire                 try_start_prefetch_task,
  input  wire [31:0]          prefetch_addr,
  output wire                 prefetch_task_accepted,
  output wire                 prefetch_task_done,
  output wire [31:0]          prefetch_ins_full,

  input wire                  have_mem_access_task,
  input wire [31:0]           mem_access_addr,
  input wire                  mem_access_rw,
  input wire [31:0]           mem_access_data,
  output wire                 mem_access_task_accepted,
  output wire                 mem_access_task_done,
  output wire [31:0]          mem_access_data_out
);


endmodule