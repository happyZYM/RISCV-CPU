module RegisterFile(
        input  wire                 clk_in,			// system clock signal
        input  wire                 rst_in,			// reset signal
        input  wire					        rdy_in,			// ready signal, pause cpu when low

        input  wire                 flush_pipline,

        input  wire [ 4:0]          rs1_reg_id,
        output wire [31:0]          rs1_val,

        input  wire [ 4:0]          rs2_reg_id,
        output wire [31:0]          rs2_val,

        input  wire                 is_writing_rd,
        input  wire [ 4:0]          rd_reg_id,
        input  wire [31:0]          rd_val
    );
    reg [31:0] reg_file [31:0];

    assign rs1_val = (rs1_reg_id == 0) ? 0 : reg_file[rs1_reg_id];
    assign rs2_val = (rs2_reg_id == 0) ? 0 : reg_file[rs2_reg_id];

    always @(posedge clk_in) begin
        integer i;
        if (rst_in) begin
            for (i = 0; i < 32; i = i + 1) begin
                reg_file[i] <= 32'h0;
            end
        end
        else if (!rdy_in) begin
        end
        else begin
            // warning, currently don't support immediate forward, so if read and write to the same reg happen in the same cycle,
            // the result is the old value
            if (is_writing_rd && rd_reg_id != 0) begin
                reg_file[rd_reg_id] <= rd_val;
            end
        end
    end

endmodule
