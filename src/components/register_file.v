module RegisterFile(
        input  wire                 clk_in,			// system clock signal
        input  wire                 rst_in,			// reset signal
        input  wire					        rdy_in,			// ready signal, pause cpu when low

        input  wire                 flush_pipline,

        input  wire                 is_reading_rs1,
        input  wire [ 4:0]          rs1_reg_id,
        output wire [31:0]          rs1_val,

        input  wire                 is_reading_rs2,
        input  wire [ 4:0]          rs2_reg_id,
        output wire [31:0]          rs2_val,

        input  wire                 is_writing_rd,
        input  wire [ 4:0]          rd_reg_id,
        input  wire [31:0]          rd_val
    );
    reg [31:0] reg_file [31:0];

    reg [31:0] rs1_val_reg;
    assign rs1_val = rs1_val_reg;
    reg [31:0] rs2_val_reg;
    assign rs2_val = rs2_val_reg;

    always @(posedge clk_in) begin
        if (rst_in) begin
        end
        else if (!rdy_in) begin
        end
        else begin
            // warning, currently don't support immediate forward, so if read and write to the same reg happen in the same cycle, 
            // the result is the old value
            if (is_reading_rs1) begin
                if (rs1_reg_id != 0) begin
                    rs1_val_reg <= reg_file[rs1_reg_id];
                end
                else begin
                    rs1_val_reg <= 32'b0;
                end
            end
            if (is_reading_rs2) begin
                if (rs2_reg_id != 0) begin
                    rs2_val_reg <= reg_file[rs2_reg_id];
                end
                else begin
                    rs2_val_reg <= 32'b0;
                end
            end
            if (is_writing_rd) begin
                if (rd_reg_id != 0) begin
                    reg_file[rd_reg_id] <= rd_val;
                end
            end
        end
    end

endmodule
