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
    // output control
    reg [31:0] current_PC;
    reg is_waiting_for_jalr;

    wire ins_ready;
    wire icache_available;
    wire jalr_just_occured;
    wire ins_decoding_is_jalr;
    assign jalr_just_occured = ic_is_jalr && ins_ready;

    wire try_fetch = (~is_waiting_for_jalr) & issue_space_available & icache_available;
    wire [31:0] ic_ins_data;
    wire [31:0] ic_predicted_resulting_PC;
    wire [ 6:0] ic_opcode;
    wire [ 2:0] ic_funct3;
    wire [ 6:0] ic_funct7;
    wire [31:0] ic_imm_val;
    wire [ 5:0] ic_shamt_val;
    wire [ 4:0] ic_rs1;
    wire [ 4:0] ic_rs2;
    wire [ 4:0] ic_rd;
    wire        ic_is_compressed_ins;
    wire        ic_is_jalr;
    InstructionCache icache(
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
                         .ins_data(ic_ins_data),
                         .predicted_resulting_PC(ic_predicted_resulting_PC),
                         .opcode(ic_opcode),
                         .funct3(ic_funct3),
                         .funct7(ic_funct7),
                         .imm_val(ic_imm_val),
                         .shamt_val(ic_shamt_val),
                         .rs1(ic_rs1),
                         .rs2(ic_rs2),
                         .rd(ic_rd),
                         .is_compressed_ins(ic_is_compressed_ins),
                         .is_jalr(ic_is_jalr)
                     );

    assign is_issueing = ins_ready;
    assign issue_PC = current_PC;
    assign predicted_resulting_PC = ic_predicted_resulting_PC;
    assign full_ins = ic_ins_data;
    assign opcode = ic_opcode;
    assign funct3 = ic_funct3;
    assign funct7 = ic_funct7;
    assign imm_val = ic_imm_val;
    assign shamt_val = ic_shamt_val;
    assign rs1 = ic_rs1;
    assign rs2 = ic_rs2;
    assign rd = ic_rd;
    assign is_compressed_ins = ic_is_compressed_ins;

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
            else if (ins_ready) begin
                current_PC <= ic_predicted_resulting_PC;
                is_waiting_for_jalr <= jalr_just_occured;
            end
        end
    end

endmodule
