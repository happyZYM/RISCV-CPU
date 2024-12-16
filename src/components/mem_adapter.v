module MemAdapter(
        input  wire                 clk_in, // system clock signal
        input  wire                 rst_in, // reset signal
        input  wire                 rdy_in, // ready signal, pause cpu when low

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
        input wire                  mem_access_rw, // 0 for read, 1 for write
        input wire [1:0]            mem_access_size, // 00 -> 1 byte, 01 -> 2 bytes, 10 -> 4 bytes, 11 -> 8 bytes
        input wire [31:0]           mem_access_data,
        output wire                 mem_access_task_done,
        output wire [31:0]          mem_access_data_out
    );

    // prioirty: mem access > ins fetch

    wire new_mo_task = mo_task_state == 0 && have_mem_access_task;
    wire mo_task_pending = (mo_task_state == 1) || new_mo_task;
    wire mo_task_running = (mo_task_state[7:1] != 7'b0000000);
    wire [31:0] mo_mem_a_control = mo_task_state == 2 ? mo_task_addr :
         mo_task_state == 3 ? mo_task_addr + 1 :
         mo_task_state == 4 ? mo_task_addr + 2 :
         mo_task_state == 5 ? mo_task_addr + 3 : 32'h0;
    assign mem_dout = mo_task_state == 2 ? mo_data_to_write[7:0] :
           mo_task_state == 3 ? mo_data_to_write[15:8] :
           mo_task_state == 4 ? mo_data_to_write[23:16] :
           mo_task_state == 5 ? mo_data_to_write[31:24] : 8'b0;
    wire can_write = (mem_a[17:16]!=2'b11) || (~io_buffer_full);
    wire mo_last_task_ok = (mo_task_rw == 0) || can_write;
    reg [7:0] mo_task_state;
    reg mo_task_rw;
    reg [31:0] mo_task_addr;
    reg [31:0] mo_data_to_write;
    reg [1:0] mo_data_size;
    wire is_lb = (mo_task_rw == 0) && (mo_data_size == 2'b00);
    wire is_lh = (mo_task_rw == 0) && (mo_data_size == 2'b01);
    wire is_lw = (mo_task_rw == 0) && (mo_data_size == 2'b10);
    wire is_sb = (mo_task_rw == 1) && (mo_data_size == 2'b00);
    wire is_sh = (mo_task_rw == 1) && (mo_data_size == 2'b01);
    wire is_sw = (mo_task_rw == 1) && (mo_data_size == 2'b10);
    reg [7:0] mo_read_byte0_stored;
    reg [7:0] mo_read_byte1_stored;
    reg [7:0] mo_read_byte2_stored;
    wire [7:0] mo_read_byte0 = is_lb ? mem_din : mo_read_byte0_stored;
    wire [7:0] mo_read_byte1 = is_lb ? 8'b0 : is_lh ? mem_din : mo_read_byte1_stored;
    wire [7:0] mo_read_byte2 = is_lw ? mo_read_byte2_stored : 8'b0;
    wire [7:0] mo_read_byte3 = is_lw ? mem_din : 8'b0;
    assign mem_access_data_out = {mo_read_byte3, mo_read_byte2, mo_read_byte1, mo_read_byte0};
    assign mem_access_task_done = (is_lw || is_sw) ? mo_task_state == 7'b0000101 :
           (is_lh || is_sh) ? mo_task_state == 7'b0000011 :
           (is_lb || is_sb) ? mo_task_state == 7'b0000010 : 0;

    wire new_ifetch_task = ifetch_task_state == 0 && try_start_insfetch_task;
    wire ifetch_task_pending = (ifetch_task_state == 1) || new_ifetch_task;
    wire [31:0] ifetch_mem_a_control = ifetch_task_state == 2 ? ifetch_task_addr :
         ifetch_task_state == 3 ? ifetch_task_addr + 1 :
         ifetch_task_state == 4 ? ifetch_task_addr + 2 :
         ifetch_task_state == 5 ? ifetch_task_addr + 3 : 32'h0;
    wire ifetch_task_running = (ifetch_task_state[7:1] != 7'b0000000);
    reg [7:0] ifetch_task_state; // 0 -> idle, 1 -> pending
    reg [31:0] ifetch_task_addr;
    wire is_compressed_ins = (ifetch_task_state >= 3) && (ifetch_read_byte0_stored[1:0] != 2'b11);
    reg [7:0] ifetch_read_byte0_stored;
    reg [7:0] ifetch_read_byte1_stored;
    reg [7:0] ifetch_read_byte2_stored;
    wire [7:0] ifetch_read_byte0 = ifetch_read_byte0_stored;
    wire [7:0] ifetch_read_byte1 = is_compressed_ins ? mem_din : ifetch_read_byte1_stored;
    wire [7:0] ifetch_read_byte2 = is_compressed_ins ? 8'b0 : ifetch_read_byte2_stored;
    wire [7:0] ifetch_read_byte3 = is_compressed_ins ? 8'b0 : mem_din;
    assign insfetch_ins_full = {ifetch_read_byte3, ifetch_read_byte2, ifetch_read_byte1, ifetch_read_byte0};
    assign insfetch_task_done = is_compressed_ins ? ifetch_task_state == 7'b0000011 : ifetch_task_state == 7'b0000101;

    wire no_task_running = (ifetch_task_state[7:1] == 7'b0000000) && (mo_task_state[7:1] == 7'b0000000);
    wire launch_mo_task = no_task_running && mo_task_pending;
    wire launch_ifetch_task = no_task_running && ifetch_task_pending && (!mo_task_pending);
    assign mem_a = mo_task_running ? mo_mem_a_control : ifetch_task_running ? ifetch_mem_a_control : 32'h0;
    assign mem_wr = mo_task_running ? (mo_task_rw && can_write) : 1'b0;

    always @(posedge clk_in) begin
        if (rst_in) begin
            ifetch_task_state <= 8'b0;
            mo_task_state <= 8'b0;
        end
        else if (!rdy_in) begin
        end
        else begin
            if (flush_pipline) begin
                ifetch_task_state <= 8'b0;
                mo_task_state <= 8'b0;
            end
            else begin
                if (new_mo_task) begin
                    mo_task_rw <= mem_access_rw;
                    mo_task_addr <= mem_access_addr;
                    mo_data_to_write <= mem_access_data;
                    mo_data_size <= mem_access_size;
                end
                if (new_ifetch_task) begin
                    ifetch_task_addr <= insfetch_addr;
                end

                if (launch_mo_task) begin
                    mo_task_state <= 8'b00000010;
                end
                else if (new_mo_task) begin
                    mo_task_state <= 8'b00000001;
                end
                if (mo_task_state == 8'b00000010 && mo_last_task_ok) begin
                    if (mo_data_size == 0) begin
                        mo_task_state <= 8'b00000000;
                    end
                    else begin
                        mo_task_state <= 8'b00000011;
                        mo_read_byte0_stored <= mem_din;
                    end
                end
                if (mo_task_state == 8'b00000011 && mo_last_task_ok) begin
                    if (mo_data_size == 2'b01) begin
                        mo_task_state <= 8'b00000000;
                    end
                    else begin
                        mo_task_state <= 8'b00000100;
                        mo_read_byte1_stored <= mem_din;
                    end
                end
                if (mo_task_state == 8'b00000100 && mo_last_task_ok) begin
                    mo_task_state <= 8'b00000101;
                    mo_read_byte2_stored <= mem_din;
                end
                if (mo_task_state == 8'b00000101 && mo_last_task_ok) begin
                    mo_task_state <= 8'b00000000;
                end

                if (launch_ifetch_task) begin
                    ifetch_task_state <= 8'b00000010;
                end
                else if (new_ifetch_task) begin
                    ifetch_task_state <= 8'b00000001;
                end
                if (ifetch_task_state == 8'b00000010) begin
                    ifetch_task_state <= 8'b00000011;
                    ifetch_read_byte0_stored <= mem_din;
                end
                if (ifetch_task_state == 8'b00000011) begin
                    if (insfetch_task_done) begin
                        ifetch_task_state <= 8'b00000000;
                    end
                    else begin
                        ifetch_task_state <= 8'b00000100;
                        ifetch_read_byte1_stored <= mem_din;
                    end
                end
                if (ifetch_task_state == 8'b00000100) begin
                    ifetch_task_state <= 8'b00000101;
                    ifetch_read_byte2_stored <= mem_din;
                end
                if (ifetch_task_state == 8'b00000101) begin
                    ifetch_task_state <= 8'b00000000;
                end
            end
        end
    end

endmodule
