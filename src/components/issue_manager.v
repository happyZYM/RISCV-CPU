module IssueManager(
        input  wire                 clk_in,// system clock signal
        input  wire                 rst_in,// reset signal
        input  wire                 rdy_in,// ready signal, pause cpu when low

        input  wire                 flush_pipline,
        input  wire [31:0]          reset_PC_to,
        input  wire                 jalr_just_done,
        input  wire [31:0]          jalr_resulting_PC,
        input  wire                 issue_space_available,

        output wire                 is_issueing, // The issued instruction should be immediately processed by CSU
        output wire [31:0]          issue_PC,
        output wire [31:0]          predicted_resulting_PC,
        output wire [31:0]          full_ins,
        output wire [ 6:0]          opcode,
        output wire [ 2:0]          funct3,
        output wire [ 6:0]          funct7,
        output wire [31:0]          imm_val,
        output wire [ 5:0]          shamt_val,
        output wire [ 4:0]          rs1,
        output wire [ 4:0]          rs2,
        output wire [ 4:0]          rd,
        output wire                 is_compressed_ins,

        input  wire [31:0]          ins_fetched_from_memory_adaptor,
        input  wire                 insfetch_task_done,
        output wire                 request_ins_from_memory_adaptor,
        output wire [31:0]          insaddr_to_be_fetched_from_memory_adaptor
    );

    wire [31:0]  current_ins_offset;
    reg [31:0] current_PC;
    reg is_waiting_for_jalr;
    wire [31:0] ins_data;

    wire ins_ready;
    wire icache_available;
    wire jalr_just_occured;
    wire ins_decoding_is_jalr;
    assign jalr_just_occured = ins_decoding_is_jalr && is_issueing;
    Decoder decoder(
                .clk_in(clk_in),
                .rst_in(rst_in),
                .rdy_in(rdy_in),
                .ins(ins_data),
                .opcode(opcode),
                .funct3(funct3),
                .funct7(funct7),
                .imm_val(imm_val),
                .shamt_val(shamt_val),
                .rs1(rs1),
                .rs2(rs2),
                .rd(rd),
                .offset(current_ins_offset),
                .is_jalr(ins_decoding_is_jalr),
                .is_compressed_ins(is_compressed_ins)
            );
    
    assign full_ins = ins_data;

    wire try_fetch = (~is_waiting_for_jalr) & issue_space_available & icache_available;
    InstructionCache cache(
                         .clk_in(clk_in),
                         .rst_in(rst_in),
                         .rdy_in(rdy_in),
                         .flush_pipline(flush_pipline),
                         .ins_fetched_from_memory_adaptor(ins_fetched_from_memory_adaptor),
                         .insfetch_task_done(insfetch_task_done),
                         .request_ins_from_memory_adaptor(request_ins_from_memory_adaptor),
                         .insaddr_to_be_fetched_from_memory_adaptor(insaddr_to_be_fetched_from_memory_adaptor),
                         .is_reading(try_fetch),
                         .read_addr(current_PC),
                         .is_ready(ins_ready),
                         .icache_available(icache_available),
                         .read_data(ins_data)
                     );

    assign is_issueing = ins_ready;
    assign issue_PC = current_PC;
    assign predicted_resulting_PC = current_PC + current_ins_offset;

    always @(posedge clk_in) begin
        if (rst_in) begin
            current_PC <= 32'h0;
            is_waiting_for_jalr <= 1'b0;
        end
        else if (!rdy_in) begin
        end
        else begin
            if (flush_pipline) begin
                current_PC <= reset_PC_to;
                is_waiting_for_jalr <= 1'b0;
            end
            else if (jalr_just_done && is_waiting_for_jalr) begin
                current_PC <= jalr_resulting_PC;
                is_waiting_for_jalr <= 1'b0;
            end
            else if (is_issueing) begin
                current_PC <= predicted_resulting_PC;
                is_waiting_for_jalr <= jalr_just_occured;
            end
        end
    end

endmodule
