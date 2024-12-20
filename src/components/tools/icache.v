module InstructionCache(
        input  wire                 clk_in,			// system clock signal
        input  wire                 rst_in,			// reset signal
        input  wire	                rdy_in,	        // ready signal, pause cpu when low
        input  wire                 flush_pipline,

        input  wire [31:0]          read_addr,
        input  wire                 is_reading,

        output wire [31:0]          ins_data, // the data should be collected immediately when is_ready is high
        output wire [31:0]          predicted_resulting_PC,
        output wire [ 6:0]          opcode,
        output wire [ 2:0]          funct3,
        output wire [ 6:0]          funct7,
        output wire [31:0]          imm_val,
        output wire [ 5:0]          shamt_val,
        output wire [ 4:0]          rs1,
        output wire [ 4:0]          rs2,
        output wire [ 4:0]          rd,
        output wire                 is_compressed_ins,
        output wire                 is_jalr,
        output wire                 is_ready,
        output wire                 icache_available,

        input  wire [31:0]          ins_fetched_from_memory_adaptor,
        input  wire                 insfetch_task_done, // this signal should occur exactly 1 cycle every time.
        output wire                 request_ins_from_memory_adaptor,
        output wire [31:0]          insaddr_to_be_fetched_from_memory_adaptor
    );
    // Input: This module will not process request during working, also it will store previously fetched instructions
    // Output: This module will only provide output in one cycle, so the result should be collected immediately when is_ready is high.

    wire currently_have_task = (!task_conducting) && is_reading;
    wire [31:0] addr = currently_have_task ? read_addr : insaddr_to_be_fetched;
    wire [ICACHE_SIZE_BITS - 1:0] addr_index = addr[ICACHE_SIZE_BITS:1];
    wire no_need_to_fetch = (cached_ins_addr[addr_index] == addr);
    assign is_ready = no_need_to_fetch && (currently_have_task || task_conducting);
    assign request_ins_from_memory_adaptor = currently_have_task && (!no_need_to_fetch);
    assign insaddr_to_be_fetched_from_memory_adaptor = addr;
    assign icache_available = task_conducting ? 1'b0 : 1'b1;

    reg [31:0] cached_ins_data [ICACHE_SIZE - 1:0];
    reg [31:0] cached_ins_addr [ICACHE_SIZE - 1:0];
    reg [31:0] cached_predicted_resulting_PC [ICACHE_SIZE - 1:0];
    reg [ 6:0] cached_opcode [ICACHE_SIZE - 1:0];
    reg [ 2:0] cached_funct3 [ICACHE_SIZE - 1:0];
    reg [ 6:0] cached_funct7 [ICACHE_SIZE - 1:0];
    reg [31:0] cached_imm_val [ICACHE_SIZE - 1:0];
    reg [ 5:0] cached_shamt_val [ICACHE_SIZE - 1:0];
    reg [ 4:0] cached_rs1 [ICACHE_SIZE - 1:0];
    reg [ 4:0] cached_rs2 [ICACHE_SIZE - 1:0];
    reg [ 4:0] cached_rd [ICACHE_SIZE - 1:0];
    reg cached_is_compressed_ins [ICACHE_SIZE - 1:0];
    reg cached_is_jalr [ICACHE_SIZE - 1:0];
    assign ins_data = cached_ins_data[addr_index];
    assign predicted_resulting_PC = cached_predicted_resulting_PC[addr_index];
    assign opcode = cached_opcode[addr_index];
    assign funct3 = cached_funct3[addr_index];
    assign funct7 = cached_funct7[addr_index];
    assign imm_val = cached_imm_val[addr_index];
    assign shamt_val = cached_shamt_val[addr_index];
    assign rs1 = cached_rs1[addr_index];
    assign rs2 = cached_rs2[addr_index];
    assign rd = cached_rd[addr_index];
    assign is_compressed_ins = cached_is_compressed_ins[addr_index];
    assign is_jalr = cached_is_jalr[addr_index];

    wire dc_decoding_done;
    wire [6:0] dc_opcode;
    wire [2:0] dc_funct3;
    wire [6:0] dc_funct7;
    wire [31:0] dc_imm_val;
    wire [5:0] dc_shamt_val;
    wire [4:0] dc_rs1;
    wire [4:0] dc_rs2;
    wire [4:0] dc_rd;
    wire [31:0] dc_offset;
    wire dc_is_jalr;
    wire dc_is_compressed_ins;
    Decoder decoder(
                .clk_in(clk_in),
                .rst_in(rst_in),
                .rdy_in(rdy_in),
                .decoding_done(dc_decoding_done),
                .opcode(dc_opcode),
                .funct3(dc_funct3),
                .funct7(dc_funct7),
                .imm_val(dc_imm_val),
                .shamt_val(dc_shamt_val),
                .rs1(dc_rs1),
                .rs2(dc_rs2),
                .rd(dc_rd),
                .offset(dc_offset),
                .is_jalr(dc_is_jalr),
                .is_compressed_ins(dc_is_compressed_ins),
                .have_decoding_task(insfetch_task_done),
                .ins(ins_fetched_from_memory_adaptor)
            );

    reg        task_conducting;
    reg [31:0] insaddr_to_be_fetched;

    always @(posedge clk_in) begin : icache_main_working_block
        integer i;
        if (rst_in) begin
            task_conducting <= 1'b0;
            for (i = 0; i < ICACHE_SIZE; i = i + 1) begin
                cached_ins_addr[i] <= 32'hffffffff;
            end
        end
        else if (!rdy_in) begin
        end
        else begin
            if (flush_pipline) begin
                task_conducting <= 1'b0;
            end
            else if (task_conducting) begin
                if (insfetch_task_done) begin
                    cached_ins_data[addr_index] <= ins_fetched_from_memory_adaptor;
                end
                if (dc_decoding_done) begin
                    cached_ins_addr[addr_index] <= insaddr_to_be_fetched;
                    cached_predicted_resulting_PC[addr_index] <= addr + dc_offset;
                    cached_opcode[addr_index] <= dc_opcode;
                    cached_funct3[addr_index] <= dc_funct3;
                    cached_funct7[addr_index] <= dc_funct7;
                    cached_imm_val[addr_index] <= dc_imm_val;
                    cached_shamt_val[addr_index] <= dc_shamt_val;
                    cached_rs1[addr_index] <= dc_rs1;
                    cached_rs2[addr_index] <= dc_rs2;
                    cached_rd[addr_index] <= dc_rd;
                    cached_is_compressed_ins[addr_index] <= dc_is_compressed_ins;
                    cached_is_jalr[addr_index] <= dc_is_jalr;
                end
                if (is_ready) begin
                    task_conducting <= 1'b0;
                end
            end
            else if (request_ins_from_memory_adaptor) begin
                task_conducting <= 1'b1;
                insaddr_to_be_fetched <= read_addr;
            end
        end
    end
endmodule
