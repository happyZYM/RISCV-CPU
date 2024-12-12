module MemAdapter(
        input  wire                 clk_in,			// system clock signal
        input  wire                 rst_in,			// reset signal
        input  wire					        rdy_in,			// ready signal, pause cpu when low

        input  wire                 flush_pipline,

        input  wire [ 7:0]          mem_din,		// data input bus
        output wire [ 7:0]          mem_dout,		// data output bus
        output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
        output wire                 mem_wr,			// write/read signal (1 for write)
        input  wire                 io_buffer_full, // 1 if uart buffer is full

        input  wire                 try_start_insfetch_task,
        input  wire [31:0]          insfetch_addr,
        output wire                 insfetch_task_done,
        output wire [31:0]          insfetch_ins_full,

        input wire                  have_mem_access_task,
        input wire [31:0]           mem_access_addr,
        input wire                  mem_access_rw,
        input wire [1:0]            mem_access_size, // 00 -> 1 byte, 01 -> 2 bytes, 10 -> 4 bytes, 11 -> 8 bytes
        input wire [31:0]           mem_access_data,
        output wire                 mem_access_task_done,
        output wire [31:0]          mem_access_data_out
    );


endmodule
