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
    reg                 is_issueing_reg;
    assign is_issueing = is_issueing_reg;
    reg [31:0]          issue_PC_reg;
    assign issue_PC = issue_PC_reg;
    reg [31:0]          predicted_resulting_PC_reg;
    assign predicted_resulting_PC = predicted_resulting_PC_reg;
    reg [31:0]          full_ins_reg;
    assign full_ins = full_ins_reg;
    reg [ 6:0]          opcode_reg;
    assign opcode = opcode_reg;
    reg [ 2:0]          funct3_reg;
    assign funct3 = funct3_reg;
    reg [ 6:0]          funct7_reg;
    assign funct7 = funct7_reg;
    reg [31:0]          imm_val_reg;
    assign imm_val = imm_val_reg;
    reg [ 5:0]          shamt_val_reg;
    assign shamt_val = shamt_val_reg;
    reg [ 4:0]          rs1_reg;
    assign rs1 = rs1_reg;
    reg [ 4:0]          rs2_reg;
    assign rs2 = rs2_reg;
    reg [ 4:0]          rd_reg;
    assign rd = rd_reg;
    reg                 is_compressed_ins_reg;
    assign is_compressed_ins = is_compressed_ins_reg;
    wire                 is_issueing_tmp;
    wire [31:0]          issue_PC_tmp;
    wire [31:0]          predicted_resulting_PC_tmp;
    wire [31:0]          full_ins_tmp;
    wire [ 6:0]          opcode_tmp;
    wire [ 2:0]          funct3_tmp;
    wire [ 6:0]          funct7_tmp;
    wire [31:0]          imm_val_tmp;
    wire [ 5:0]          shamt_val_tmp;
    wire [ 4:0]          rs1_tmp;
    wire [ 4:0]          rs2_tmp;
    wire [ 4:0]          rd_tmp;
    wire                 is_compressed_ins_tmp;

    wire [31:0]  current_ins_offset;
    reg [31:0] current_PC;
    reg is_waiting_for_jalr;
    wire [31:0] ins_data;

    wire ins_ready;
    wire icache_available;
    wire jalr_just_occured;
    wire ins_decoding_is_jalr;
    assign jalr_just_occured = ins_decoding_is_jalr && ins_ready;
    Decoder decoder(
                .clk_in(clk_in),
                .rst_in(rst_in),
                .rdy_in(rdy_in),
                .ins(ins_data),
                .opcode(opcode_tmp),
                .funct3(funct3_tmp),
                .funct7(funct7_tmp),
                .imm_val(imm_val_tmp),
                .shamt_val(shamt_val_tmp),
                .rs1(rs1_tmp),
                .rs2(rs2_tmp),
                .rd(rd_tmp),
                .offset(current_ins_offset),
                .is_jalr(ins_decoding_is_jalr),
                .is_compressed_ins(is_compressed_ins_tmp)
            );

    assign full_ins_tmp = ins_data;

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

    assign is_issueing_tmp = ins_ready;
    assign issue_PC_tmp = current_PC;
    assign predicted_resulting_PC_tmp = current_PC + current_ins_offset;

    always @(posedge clk_in) begin
        if (rst_in) begin
            current_PC <= 32'h0;
            is_waiting_for_jalr <= 1'b0;
        end
        else if (!rdy_in) begin
        end
        else begin
            is_issueing_reg <= flush_pipline ? 0 : is_issueing_tmp;
            issue_PC_reg <= issue_PC_tmp;
            predicted_resulting_PC_reg <= predicted_resulting_PC_tmp;
            full_ins_reg <= full_ins_tmp;
            opcode_reg <= opcode_tmp;
            funct3_reg <= funct3_tmp;
            funct7_reg <= funct7_tmp;
            imm_val_reg <= imm_val_tmp;
            shamt_val_reg <= shamt_val_tmp;
            rs1_reg <= rs1_tmp;
            rs2_reg <= rs2_tmp;
            rd_reg <= rd_tmp;
            is_compressed_ins_reg <= is_compressed_ins_tmp;
            if (flush_pipline) begin
                current_PC <= reset_PC_to;
                is_waiting_for_jalr <= 1'b0;
            end
            else if (jalr_just_done && is_waiting_for_jalr) begin
                current_PC <= jalr_resulting_PC;
                is_waiting_for_jalr <= 1'b0;
            end
            else if (ins_ready) begin
                current_PC <= predicted_resulting_PC_tmp;
                is_waiting_for_jalr <= jalr_just_occured;
            end
        end
    end

endmodule
