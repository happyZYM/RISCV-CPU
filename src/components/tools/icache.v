module InstructionCache(
        input  wire                 clk_in,			// system clock signal
        input  wire                 rst_in,			// reset signal
        input  wire	                rdy_in,	        // ready signal, pause cpu when low
        input  wire                 flush_pipline,

        input  wire [31:0]          read_addr,
        input  wire                 is_reading,

        output wire [31:0]          read_data, // the data should be collected immediately when is_ready is high
        output wire                 is_ready,
        output wire                 icache_available,

        input  wire [31:0]          ins_fetched_from_memory_adaptor,
        input  wire                 insfetch_task_done, // this signal should occur exactly 1 cycle every time.
        output wire                 request_ins_from_memory_adaptor,
        output wire [31:0]          insaddr_to_be_fetched_from_memory_adaptor
    );
    // Input: This module will not process request during working, also it will store previously fetched instructions
    // Output: This module will only provide output in one cycle, so the result should be collected immediately when is_ready is high.

    wire currently_have_task = (!fetch_conducting) && is_reading;
    wire [31:0] addr = currently_have_task ? read_addr : insaddr_to_be_fetched;
    wire no_need_to_fetch = (cached_ins_addr[addr[ICACHE_SIZE_BITS:1]] == addr);
    assign is_ready = no_need_to_fetch ? is_reading : insfetch_task_done;
    assign read_data = no_need_to_fetch ? cached_ins_data[addr[ICACHE_SIZE_BITS:1]] : ins_fetched_from_memory_adaptor;
    assign request_ins_from_memory_adaptor = currently_have_task && (!no_need_to_fetch);
    assign insaddr_to_be_fetched_from_memory_adaptor = addr;
    assign icache_available = fetch_conducting ? 1'b0 : 1'b1;

    reg [31:0] cached_ins_data [ICACHE_SIZE - 1:0];
    reg [31:0] cached_ins_addr [ICACHE_SIZE - 1:0];
    reg        fetch_conducting;
    reg [31:0] insaddr_to_be_fetched;

    genvar i;
    generate
        for (i = 0; i < ICACHE_SIZE; i = i + 1) begin : gen_loop
            always @(posedge clk_in) begin
                if (rst_in) begin
                    // set cached_ins_addr to 0xffffffff
                    cached_ins_addr[i] <= 32'hffffffff;
                end
            end
        end
    endgenerate

    always @(posedge clk_in) begin
        if (rst_in) begin
            fetch_conducting <= 1'b0;
        end
        else if (!rdy_in) begin
        end
        else begin
            if (flush_pipline) begin
                fetch_conducting <= 1'b0;
            end
            else if (fetch_conducting) begin
                if (insfetch_task_done) begin
                    fetch_conducting <= 1'b0;
                    cached_ins_data[insaddr_to_be_fetched[8:1]] <= ins_fetched_from_memory_adaptor;
                    cached_ins_addr[insaddr_to_be_fetched[8:1]] <= insaddr_to_be_fetched;
                end
            end
            else if (request_ins_from_memory_adaptor) begin
                if (!insfetch_task_done) begin
                    fetch_conducting <= 1'b1;
                    insaddr_to_be_fetched <= read_addr;
                end
                else begin
                    cached_ins_data[read_addr[8:1]] <= ins_fetched_from_memory_adaptor;
                    cached_ins_addr[read_addr[8:1]] <= read_addr;
                end
            end
        end
    end
endmodule