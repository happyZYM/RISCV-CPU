module RegisterFile(
        input  wire                 clk_in,			// system clock signal
        input  wire                 rst_in,			// reset signal
        input  wire					        rdy_in,			// ready signal, pause cpu when low

        input  wire                 flush_pipline,

        input  wire                 have_task,
        input  wire [ 4:0]          reg_id,
        input  wire                 rw,
        input  wire [31:0]          data_in,

        output wire [31:0]          data_out
    );

endmodule
