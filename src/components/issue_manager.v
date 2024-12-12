module InstructionCache(
        input  wire                 clk_in,			// system clock signal
        input  wire                 rst_in,			// reset signal
        input  wire	                rdy_in,	        // ready signal, pause cpu when low
        input  wire                 flush_pipline,

        input  wire [31:0]          read_addr,
        input  wire                 is_reading,

        output wire [31:0]          read_data,
        output wire                 is_ready,

        input  wire [31:0]          ins_fetched_from_memory_adaptor,
        input  wire                 insfetch_task_done,
        output wire                 request_ins_from_memory_adaptor,
        output wire [31:0]          insaddr_to_be_fetched_from_memory_adaptor
    );

    reg [31:0] read_data_reg;
    assign read_data = read_data_reg;
    reg        is_ready_reg;
    assign is_ready = is_ready_reg;
    reg        request_ins_from_memory_adaptor_reg;
    assign request_ins_from_memory_adaptor = request_ins_from_memory_adaptor_reg;
    reg [31:0] insaddr_to_be_fetched_from_memory_adaptor_reg;
    assign insaddr_to_be_fetched_from_memory_adaptor = insaddr_to_be_fetched_from_memory_adaptor_reg;

    reg [31:0] cached_ins_data [255:0];
    reg [31:0] cached_ins_addr [255:0];
    reg        fetch_conducting;
    reg [31:0] insaddr_to_be_fetched;

    genvar i;
    generate
        for (i = 0; i < 256; i = i + 1) begin : gen_loop
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
            request_ins_from_memory_adaptor_reg <= 1'b0;
            is_ready_reg <= 1'b1;
        end
        else if (!rdy_in) begin
        end
        else begin
            if (flush_pipline) begin
                fetch_conducting <= 1'b0;
                request_ins_from_memory_adaptor_reg <= 1'b0;
                is_ready_reg <= 1'b1;
            end
            else if (fetch_conducting) begin
                request_ins_from_memory_adaptor_reg <= 1'b0; // the request only last for one cycle, so the memory adaptor should store the request itself
                if (insfetch_task_done) begin
                    cached_ins_addr[insaddr_to_be_fetched[8:1] & 8'b11111111] <= insaddr_to_be_fetched;
                    cached_ins_data[insaddr_to_be_fetched[8:1] & 8'b11111111] <= ins_fetched_from_memory_adaptor;
                    fetch_conducting <= 1'b0;
                    is_ready_reg <= 1'b1;
                    read_data_reg <= ins_fetched_from_memory_adaptor;
                end
            end
            else if (is_reading) begin
                if (cached_ins_addr[read_addr[8:1] & 8'b11111111] == read_addr) begin
                    is_ready_reg <= 1'b1;
                    read_data_reg <= cached_ins_data[read_addr[8:1] & 8'b11111111];
                    fetch_conducting <= 1'b0;
                    request_ins_from_memory_adaptor_reg <= 1'b0;
                end
                else begin
                    is_ready_reg <= 1'b0;
                    fetch_conducting <= 1'b1;
                    request_ins_from_memory_adaptor_reg <= 1'b1;
                    insaddr_to_be_fetched_from_memory_adaptor_reg <= read_addr;
                    insaddr_to_be_fetched <= read_addr;
                end
            end
        end
    end
endmodule

module Decoder(
        input  wire                 clk_in,			// system clock signal
        input  wire                 rst_in,			// reset signal
        input  wire	                rdy_in,	        // ready signal, pause cpu when low

        input  wire [31:0]          ins,

        output wire [ 6:0]          opcode,
        output wire [ 2:0]          funct3,
        output wire [ 6:0]          funct7,
        output wire [31:0]          imm_val,
        output wire [ 5:0]          shamt_val,
        output wire [ 4:0]          rs1,
        output wire [ 4:0]          rs2,
        output wire [ 4:0]          rd,
        output wire [31:0]          offset,
        output wire                 is_jalr,
        output wire                 is_compressed_ins
    ); // decode and translate compressed instruction
    wire is_compressed = (ins[1:0] != 2'b11);
    assign is_compressed_ins = is_compressed;
    wire [ 6:0] opcode_normal;
    wire [ 2:0] funct3_normal;
    wire [ 6:0] funct7_normal;
    wire [31:0] imm_val_normal;
    wire [ 5:0] shamt_val_normal;
    wire [ 4:0] rs1_normal;
    wire [ 4:0] rs2_normal;
    wire [ 4:0] rd_normal;
    wire is_jalr_normal;
    wire [31:0] offset_normal;
    wire [ 6:0] opcode_compressed;
    wire [ 2:0] funct3_compressed;
    wire [ 6:0] funct7_compressed;
    wire [31:0] imm_val_compressed;
    wire [ 5:0] shamt_val_compressed;
    wire [ 4:0] rs1_compressed;
    wire [ 4:0] rs2_compressed;
    wire [ 4:0] rd_compressed;
    wire is_jalr_compressed;
    wire [31:0] offset_compressed;
    assign opcode = is_compressed ? opcode_compressed : opcode_normal;
    assign funct3 = is_compressed ? funct3_compressed : funct3_normal;
    assign funct7 = is_compressed ? funct7_compressed : funct7_normal;
    assign imm_val = is_compressed ? imm_val_compressed : imm_val_normal;
    assign shamt_val = is_compressed ? shamt_val_compressed : shamt_val_normal;
    assign rs1 = is_compressed ? rs1_compressed : rs1_normal;
    assign rs2 = is_compressed ? rs2_compressed : rs2_normal;
    assign rd = is_compressed ? rd_compressed : rd_normal;
    assign is_jalr = is_compressed ? is_jalr_compressed : is_jalr_normal;
    assign offset = is_compressed ? offset_compressed : offset_normal;

    assign is_jalr_normal = (opcode_normal == 7'b1100111) ? 1'b1 : 1'b0;
    wire is_branch_normal = (opcode_normal == 7'b1100011);
    wire [31:0] predicted_offset_if_branch_normal = (imm_val_normal[31] == 1'b1 ? imm_val_normal : 4);
    wire is_jal_normal = (opcode_normal == 7'b1101111);
    assign offset_normal = is_jal_normal ? imm_val_normal : (is_branch_normal ? predicted_offset_if_branch_normal : 4);

    // Decode normal (32-bit) instruction based on opcode
    assign opcode_normal = ins[6:0];

    // Initialize funct3_normal and funct7_normal based on opcode
    wire is_r_type_normal = (opcode_normal == 7'b0110011);
    wire is_i_type_normal = (opcode_normal == 7'b0010011 || opcode_normal == 7'b0000011 || opcode_normal == 7'b1100111);
    wire is_s_type_normal = (opcode_normal == 7'b0100011);
    wire is_b_type_normal = (opcode_normal == 7'b1100011);
    wire is_u_type_normal = (opcode_normal == 7'b0110111 || opcode_normal == 7'b0010111);
    wire is_j_type_normal = (opcode_normal == 7'b1101111);
    assign funct3_normal =
           (is_r_type_normal ||
            is_i_type_normal ||
            is_s_type_normal ||
            is_b_type_normal)
           ? ins[14:12]
           : 3'b000;

    // funct7_normal 仅在 R-type 和部分 I-type 指令中有效
    assign funct7_normal =
           (is_r_type_normal || // R-type
            (opcode_normal == 7'b0010011 && (ins[14:12] == 3'b101))) // I-type shift
           ? ins[31:25]
           : 7'b0000000;

    // 立即数的解码根据指令类型不同而不同
    wire [31:0] imm_i_type = {{20{ins[31]}}, ins[31:20]};
    wire [31:0] imm_s_type = {{20{ins[31]}}, ins[31:25], ins[11:7]};
    wire [31:0] imm_b_type = {{19{ins[31]}}, ins[31], ins[7], ins[30:25], ins[11:8], 1'b0};
    wire [31:0] imm_u_type = {ins[31:12], 12'b0};
    wire [31:0] imm_j_type = {{11{ins[31]}}, ins[31], ins[19:12], ins[20], ins[30:21], 1'b0};

    // 选择立即数
    assign imm_val_normal =
           (is_i_type_normal)
           ? imm_i_type
           : (is_s_type_normal)
           ? imm_s_type
           : (is_b_type_normal)
           ? imm_b_type
           : (is_u_type_normal)
           ? imm_u_type
           : (is_j_type_normal)
           ? imm_j_type
           : 32'b0;

    // 移位量仅在某些指令中有效
    assign shamt_val_normal =
           (opcode_normal == 7'b0010011 && (ins[14:12] == 3'b101 || ins[14:12] == 3'b001))
           ? ins[25:20]
           : 6'b000000;

    // 寄存器解码
    assign rd_normal =
           (is_r_type_normal ||
            is_i_type_normal ||
            is_u_type_normal ||
            is_j_type_normal)
           ? ins[11:7]
           : 5'b00000;

    assign rs1_normal =
           (is_r_type_normal ||
            is_i_type_normal ||
            is_s_type_normal ||
            is_b_type_normal)
           ? ins[19:15]
           : 5'b00000;

    assign rs2_normal =
           (is_r_type_normal ||
            is_s_type_normal ||
            is_b_type_normal)
           ? ins[24:20]
           : 5'b00000;

    // TODO: decode compressed instruction
    // compressed instructions supported: `c.addi`，`c.jal`，`c.li`，`c.addi16sp`，`c.lui`，`c.srli`，`c.srai`，`c.andi`，`c.sub`，`c.xor`，`c.or`，`c.and`，`c.j`，`c.beqz`，`c.bnez`，`c.addi4spn`，`c.lw`，`c.sw`，`c.slli`，`c.jr`，`c.mv`，`c.jalr`，`c.add`，`c.lwsp`，`c.swsp`
    wire [1:0] c_op = ins[1:0];
    wire [2:0] c_funct3 = ins[15:13];
    wire is_c_add = (c_op == 2'b10 && c_funct3 == 3'b100 && ins[12] == 1'b1 && ins[11:7] != 5'b00000 && ins[6:2] != 5'b00000);
    wire is_c_addi = (c_op == 2'b01 && c_funct3 == 3'b000);
    wire is_c_addi16sp = (c_op == 2'b01 && c_funct3 == 3'b011 && ins[11:7] == 5'b00010);
    wire is_c_addi4spn = (c_op == 2'b00 && c_funct3 == 3'b000);
    wire is_c_and = (c_op == 2'b01 && c_funct3 == 3'b100 && ins[11:10] == 2'b11 && ins[6:5] == 2'b11);
    wire is_c_andi = (c_op == 2'b01 && c_funct3 == 3'b100 && ins[11:10] == 2'b10);
    wire is_c_beqz = (c_op == 2'b01 && c_funct3 == 3'b110);
    wire is_c_bnez = (c_op == 2'b01 && c_funct3 == 3'b111);
    wire is_c_j = (c_op == 2'b01 && c_funct3 == 3'b101);
    wire is_c_jal = (c_op == 2'b01 && c_funct3 == 3'b001);
    wire is_c_jalr = (c_op == 2'b10 && c_funct3 == 3'b100 && ins[12] == 1'b1 && ins[11:7] != 5'b00000 && ins[6:2] == 5'b00000);
    wire is_c_jr = (c_op == 2'b10 && c_funct3 == 3'b100 && ins[12] == 1'b0 && ins[11:7] != 5'b00000 && ins[6:2] == 5'b00000);
    wire is_c_li = (c_op == 2'b01 && c_funct3 == 3'b010);
    wire is_c_lui = (c_op == 2'b01 && c_funct3 == 3'b011 && ins[11:7] != 5'b00010);
    wire is_c_lw = (c_op == 2'b00 && c_funct3 == 3'b010);
    wire is_c_lwsp = (c_op == 2'b10 && c_funct3 == 3'b010);
    wire is_c_mv = (c_op == 2'b10 && c_funct3 == 3'b100 && ins[12] == 1'b0 && ins[11:7] != 5'b00000 && ins[6:2] != 5'b00000);
    wire is_c_or = (c_op == 2'b01 && c_funct3 == 3'b100 && ins[11:10] == 2'b11 && ins[6:5] == 2'b10);
    wire is_c_slli = (c_op == 2'b10 && c_funct3 == 3'b000);
    wire is_c_srai = (c_op == 2'b01 && c_funct3 == 3'b100 && ins[11:10] == 2'b01);
    wire is_c_srli = (c_op == 2'b01 && c_funct3 == 3'b100 && ins[11:10] == 2'b00);
    wire is_c_sub = (c_op == 2'b01 && c_funct3 == 3'b100 && ins[11:10] == 2'b11 && ins[6:5] == 2'b00);
    wire is_c_sw = (c_op == 2'b00 && c_funct3 == 3'b110);
    wire is_c_swsp = (c_op == 2'b10 && c_funct3 == 3'b110);
    wire is_c_xor = (c_op == 2'b01 && c_funct3 == 3'b100 && ins[11:10] == 2'b11 && ins[6:5] == 2'b01);

    // translate compressed instruction
    wire [ 6:0] opcode_compressed_c_add = 7'b0110011;
    wire [ 2:0] funct3_compressed_c_add = 3'b000;
    wire [ 6:0] funct7_compressed_c_add = 7'b0000000;
    wire [31:0] imm_val_compressed_c_add = 32'b0;
    wire [ 5:0] shamt_val_compressed_c_add = 6'b000000;
    wire [ 4:0] rs1_compressed_c_add = ins[6:2];
    wire [ 4:0] rs2_compressed_c_add = ins[11:7];
    wire [ 4:0] rd_compressed_c_add = ins[11:7];
    wire is_jalr_compressed_c_add = 1'b0;
    wire [31:0] offset_compressed_c_add = 2;

    wire [ 6:0] opcode_compressed_c_addi = 7'b0010011;
    wire [ 2:0] funct3_compressed_c_addi = 3'b000;
    wire [ 6:0] funct7_compressed_c_addi = 7'b0000000;
    wire [31:0] imm_val_compressed_c_addi = {{26{ins[12]}}, ins[12], ins[6:2]};
    wire [ 5:0] shamt_val_compressed_c_addi = 6'b000000;
    wire [ 4:0] rs1_compressed_c_addi = ins[11:7];
    wire [ 4:0] rs2_compressed_c_addi = 5'b00000;
    wire [ 4:0] rd_compressed_c_addi = ins[11:7];
    wire is_jalr_compressed_c_addi = 1'b0;
    wire [31:0] offset_compressed_c_addi = 2;

    wire [ 6:0] opcode_compressed_c_addi16sp = 7'b0010011;
    wire [ 2:0] funct3_compressed_c_addi16sp = 3'b000;
    wire [ 6:0] funct7_compressed_c_addi16sp = 7'b0000000;
    wire [31:0] imm_val_compressed_c_addi16sp = {{22{ins[12]}}, ins[12], ins[4:3], ins[5], ins[2], ins[6], 4'b0000};
    wire [ 5:0] shamt_val_compressed_c_addi16sp = 6'b000000;
    wire [ 4:0] rs1_compressed_c_addi16sp = 5'b00010;
    wire [ 4:0] rs2_compressed_c_addi16sp = 5'b00000;
    wire [ 4:0] rd_compressed_c_addi16sp = 5'b00010;
    wire is_jalr_compressed_c_addi16sp = 1'b0;
    wire [31:0] offset_compressed_c_addi16sp = 2;

    wire [ 6:0] opcode_compressed_c_addi4spn = 7'b0010011;
    wire [ 2:0] funct3_compressed_c_addi4spn = 3'b000;
    wire [ 6:0] funct7_compressed_c_addi4spn = 7'b0000000;
    wire [31:0] imm_val_compressed_c_addi4spn = {22'b0, ins[10:7], ins[12:11], ins[5], ins[6], 2'b00};
    wire [ 5:0] shamt_val_compressed_c_addi4spn = 6'b000000;
    wire [ 4:0] rs1_compressed_c_addi4spn = 5'b00010;
    wire [ 4:0] rs2_compressed_c_addi4spn = 5'b00000;
    wire [ 4:0] rd_compressed_c_addi4spn = 5'b01000 | ins[4:2];
    wire is_jalr_compressed_c_addi4spn = 1'b0;
    wire [31:0] offset_compressed_c_addi4spn = 2;

    wire [ 6:0] opcode_compressed_c_and = 7'b0110011;
    wire [ 2:0] funct3_compressed_c_and = 3'b111;
    wire [ 6:0] funct7_compressed_c_and = 7'b0000000;
    wire [31:0] imm_val_compressed_c_and = 32'b0;
    wire [ 5:0] shamt_val_compressed_c_and = 6'b000000;
    wire [ 4:0] rs1_compressed_c_and = 5'b01000 | ins[9:7];
    wire [ 4:0] rs2_compressed_c_and = 5'b01000 | ins[4:2];
    wire [ 4:0] rd_compressed_c_and = 5'b01000 | ins[9:7];
    wire is_jalr_compressed_c_and = 1'b0;
    wire [31:0] offset_compressed_c_and = 2;

    wire [ 6:0] opcode_compressed_c_andi = 7'b0010011;
    wire [ 2:0] funct3_compressed_c_andi = 3'b111;
    wire [ 6:0] funct7_compressed_c_andi = 7'b0000000;
    wire [31:0] imm_val_compressed_c_andi = {{26{ins[12]}}, ins[12], ins[6:2]};
    wire [ 5:0] shamt_val_compressed_c_andi = 6'b000000;
    wire [ 4:0] rs1_compressed_c_andi = 5'b01000 | ins[9:7];
    wire [ 4:0] rs2_compressed_c_andi = 5'b00000;
    wire [ 4:0] rd_compressed_c_andi = 5'b01000 | ins[9:7];
    wire is_jalr_compressed_c_andi = 1'b0;
    wire [31:0] offset_compressed_c_andi = 2;

    wire [ 6:0] opcode_compressed_c_beqz = 7'b1100011;
    wire [ 2:0] funct3_compressed_c_beqz = 3'b000;
    wire [ 6:0] funct7_compressed_c_beqz = 7'b0000000;
    wire [31:0] imm_val_compressed_c_beqz = {{23{ins[12]}}, ins[12], ins[6:5], ins[2], ins[11:10], ins[4:3], 1'b0};
    wire [ 5:0] shamt_val_compressed_c_beqz = 6'b000000;
    wire [ 4:0] rs1_compressed_c_beqz = 5'b01000 | ins[9:7];
    wire [ 4:0] rs2_compressed_c_beqz = 5'b00000;
    wire [ 4:0] rd_compressed_c_beqz = 5'b00000;
    wire is_jalr_compressed_c_beqz = 1'b0;
    wire [31:0] offset_compressed_c_beqz = (imm_val_compressed_c_beqz[31] == 1'b1 ? imm_val_compressed_c_beqz : 2);

    wire [ 6:0] opcode_compressed_c_bnez = 7'b1100011;
    wire [ 2:0] funct3_compressed_c_bnez = 3'b001;
    wire [ 6:0] funct7_compressed_c_bnez = 7'b0000000;
    wire [31:0] imm_val_compressed_c_bnez = {{23{ins[12]}}, ins[12], ins[6:5], ins[2], ins[11:10], ins[4:3], 1'b0};
    wire [ 5:0] shamt_val_compressed_c_bnez = 6'b000000;
    wire [ 4:0] rs1_compressed_c_bnez = 5'b01000 | ins[9:7];
    wire [ 4:0] rs2_compressed_c_bnez = 5'b00000;
    wire [ 4:0] rd_compressed_c_bnez = 5'b00000;
    wire is_jalr_compressed_c_bnez = 1'b0;
    wire [31:0] offset_compressed_c_bnez = (imm_val_compressed_c_bnez[31] == 1'b1 ? imm_val_compressed_c_bnez : 2);

    wire [ 6:0] opcode_compressed_c_j = 7'b1101111;
    wire [ 2:0] funct3_compressed_c_j = 3'b000;
    wire [ 6:0] funct7_compressed_c_j = 7'b0000000;
    wire [31:0] imm_val_compressed_c_j = {{20{ins[12]}}, ins[12], ins[8], ins[10:9], ins[6], ins[7], ins[2], ins[11], ins[5:3], 1'b0};
    wire [ 5:0] shamt_val_compressed_c_j = 6'b000000;
    wire [ 4:0] rs1_compressed_c_j = 5'b00000;
    wire [ 4:0] rs2_compressed_c_j = 5'b00000;
    wire [ 4:0] rd_compressed_c_j = 5'b00000;
    wire is_jalr_compressed_c_j = 1'b0;
    wire [31:0] offset_compressed_c_j = imm_val_compressed_c_j;

    wire [ 6:0] opcode_compressed_c_jal = 7'b1101111;
    wire [ 2:0] funct3_compressed_c_jal = 3'b000;
    wire [ 6:0] funct7_compressed_c_jal = 7'b0000000;
    wire [31:0] imm_val_compressed_c_jal = {{20{ins[12]}}, ins[12], ins[8], ins[10:9], ins[6], ins[7], ins[2], ins[11], ins[5:3], 1'b0};
    wire [ 5:0] shamt_val_compressed_c_jal = 6'b000000;
    wire [ 4:0] rs1_compressed_c_jal = 5'b00000;
    wire [ 4:0] rs2_compressed_c_jal = 5'b00000;
    wire [ 4:0] rd_compressed_c_jal = 5'b00001;
    wire is_jalr_compressed_c_jal = 1'b0;
    wire [31:0] offset_compressed_c_jal = imm_val_compressed_c_jal;

    wire [ 6:0] opcode_compressed_c_jalr = 7'b1100111;
    wire [ 2:0] funct3_compressed_c_jalr = 3'b000;
    wire [ 6:0] funct7_compressed_c_jalr = 7'b0000000;
    wire [31:0] imm_val_compressed_c_jalr = 32'b0;
    wire [ 5:0] shamt_val_compressed_c_jalr = 6'b000000;
    wire [ 4:0] rs1_compressed_c_jalr = ins[11:7];
    wire [ 4:0] rs2_compressed_c_jalr = 5'b00000;
    wire [ 4:0] rd_compressed_c_jalr = 5'b00001;
    wire is_jalr_compressed_c_jalr = 1'b1;
    wire [31:0] offset_compressed_c_jalr = 0;

    wire [ 6:0] opcode_compressed_c_jr = 7'b1100111;
    wire [ 2:0] funct3_compressed_c_jr = 3'b000;
    wire [ 6:0] funct7_compressed_c_jr = 7'b0000000;
    wire [31:0] imm_val_compressed_c_jr = 32'b0;
    wire [ 5:0] shamt_val_compressed_c_jr = 6'b000000;
    wire [ 4:0] rs1_compressed_c_jr = ins[11:7];
    wire [ 4:0] rs2_compressed_c_jr = 5'b00000;
    wire [ 4:0] rd_compressed_c_jr = 5'b00000;
    wire is_jalr_compressed_c_jr = 1'b1;
    wire [31:0] offset_compressed_c_jr = 0;

    wire [ 6:0] opcode_compressed_c_li = 7'b0010011;
    wire [ 2:0] funct3_compressed_c_li = 3'b000;
    wire [ 6:0] funct7_compressed_c_li = 7'b0000000;
    wire [31:0] imm_val_compressed_c_li = {{26{ins[12]}}, ins[12], ins[6:2]};
    wire [ 5:0] shamt_val_compressed_c_li = 6'b000000;
    wire [ 4:0] rs1_compressed_c_li = 5'b00000;
    wire [ 4:0] rs2_compressed_c_li = 5'b00000;
    wire [ 4:0] rd_compressed_c_li = ins[11:7];
    wire is_jalr_compressed_c_li = 1'b0;
    wire [31:0] offset_compressed_c_li = 2;

    wire [ 6:0] opcode_compressed_c_lui = 7'b0110111;
    wire [ 2:0] funct3_compressed_c_lui = 3'b000;
    wire [ 6:0] funct7_compressed_c_lui = 7'b0000000;
    wire [31:0] imm_val_compressed_c_lui = {{14{ins[12]}}, ins[12], ins[6:2], 12'b0};
    wire [ 5:0] shamt_val_compressed_c_lui = 6'b000000;
    wire [ 4:0] rs1_compressed_c_lui = 5'b00000;
    wire [ 4:0] rs2_compressed_c_lui = 5'b00000;
    wire [ 4:0] rd_compressed_c_lui = ins[11:7];
    wire is_jalr_compressed_c_lui = 1'b0;
    wire [31:0] offset_compressed_c_lui = 2;

    wire [ 6:0] opcode_compressed_c_lw = 7'b0000011;
    wire [ 2:0] funct3_compressed_c_lw = 3'b010;
    wire [ 6:0] funct7_compressed_c_lw = 7'b0000000;
    wire [31:0] imm_val_compressed_c_lw = {25'b0, ins[5], ins[12:10], ins[6], 2'b00};
    wire [ 5:0] shamt_val_compressed_c_lw = 6'b000000;
    wire [ 4:0] rs1_compressed_c_lw = 5'b01000 | ins[9:7];
    wire [ 4:0] rs2_compressed_c_lw = 5'b00000;
    wire [ 4:0] rd_compressed_c_lw = 5'b01000 | ins[4:2];
    wire is_jalr_compressed_c_lw = 1'b0;
    wire [31:0] offset_compressed_c_lw = 2;

    wire [ 6:0] opcode_compressed_c_lwsp = 7'b0000011;
    wire [ 2:0] funct3_compressed_c_lwsp = 3'b010;
    wire [ 6:0] funct7_compressed_c_lwsp = 7'b0000000;
    wire [31:0] imm_val_compressed_c_lwsp = {24'b0, ins[3:2], ins[12], ins[6:4], 2'b00};
    wire [ 5:0] shamt_val_compressed_c_lwsp = 6'b000000;
    wire [ 4:0] rs1_compressed_c_lwsp = 5'b00010;
    wire [ 4:0] rs2_compressed_c_lwsp = 5'b00000;
    wire [ 4:0] rd_compressed_c_lwsp = ins[11:7];
    wire is_jalr_compressed_c_lwsp = 1'b0;
    wire [31:0] offset_compressed_c_lwsp = 2;

    wire [ 6:0] opcode_compressed_c_mv = 7'b0010011;
    wire [ 2:0] funct3_compressed_c_mv = 3'b000;
    wire [ 6:0] funct7_compressed_c_mv = 7'b0000000;
    wire [31:0] imm_val_compressed_c_mv = 32'b0;
    wire [ 5:0] shamt_val_compressed_c_mv = 6'b000000;
    wire [ 4:0] rs1_compressed_c_mv = ins[6:2];
    wire [ 4:0] rs2_compressed_c_mv = 5'b00000;
    wire [ 4:0] rd_compressed_c_mv = ins[11:7];
    wire is_jalr_compressed_c_mv = 1'b0;
    wire [31:0] offset_compressed_c_mv = 2;

    wire [ 6:0] opcode_compressed_c_or = 7'b0110011;
    wire [ 2:0] funct3_compressed_c_or = 3'b110;
    wire [ 6:0] funct7_compressed_c_or = 7'b0000000;
    wire [31:0] imm_val_compressed_c_or = 32'b0;
    wire [ 5:0] shamt_val_compressed_c_or = 6'b000000;
    wire [ 4:0] rs1_compressed_c_or = 5'b01000 | ins[9:7];
    wire [ 4:0] rs2_compressed_c_or = 5'b01000 | ins[4:2];
    wire [ 4:0] rd_compressed_c_or = 5'b01000 | ins[9:7];
    wire is_jalr_compressed_c_or = 1'b0;
    wire [31:0] offset_compressed_c_or = 2;

    wire [ 6:0] opcode_compressed_c_slli = 7'b0010011;
    wire [ 2:0] funct3_compressed_c_slli = 3'b001;
    wire [ 6:0] funct7_compressed_c_slli = 7'b0000000;
    wire [31:0] imm_val_compressed_c_slli = 32'b0;
    wire [ 5:0] shamt_val_compressed_c_slli = {ins[12], ins[6:2]};
    wire [ 4:0] rs1_compressed_c_slli = ins[11:7];
    wire [ 4:0] rs2_compressed_c_slli = 5'b00000;
    wire [ 4:0] rd_compressed_c_slli = ins[11:7];
    wire is_jalr_compressed_c_slli = 1'b0;
    wire [31:0] offset_compressed_c_slli = 2;

    wire [ 6:0] opcode_compressed_c_srai = 7'b0010011;
    wire [ 2:0] funct3_compressed_c_srai = 3'b101;
    wire [ 6:0] funct7_compressed_c_srai = 7'b0100000;
    wire [31:0] imm_val_compressed_c_srai = 32'b0;
    wire [ 5:0] shamt_val_compressed_c_srai = {ins[12], ins[6:2]};
    wire [ 4:0] rs1_compressed_c_srai = 5'b01000 | ins[9:7];
    wire [ 4:0] rs2_compressed_c_srai = 5'b00000;
    wire [ 4:0] rd_compressed_c_srai = 5'b01000 | ins[9:7];
    wire is_jalr_compressed_c_srai = 1'b0;
    wire [31:0] offset_compressed_c_srai = 2;

    wire [ 6:0] opcode_compressed_c_srli = 7'b0010011;
    wire [ 2:0] funct3_compressed_c_srli = 3'b101;
    wire [ 6:0] funct7_compressed_c_srli = 7'b0000000;
    wire [31:0] imm_val_compressed_c_srli = 32'b0;
    wire [ 5:0] shamt_val_compressed_c_srli = {ins[12], ins[6:2]};
    wire [ 4:0] rs1_compressed_c_srli = 5'b01000 | ins[9:7];
    wire [ 4:0] rs2_compressed_c_srli = 5'b00000;
    wire [ 4:0] rd_compressed_c_srli = 5'b01000 | ins[9:7];
    wire is_jalr_compressed_c_srli = 1'b0;
    wire [31:0] offset_compressed_c_srli = 2;

    wire [ 6:0] opcode_compressed_c_sub = 7'b0110011;
    wire [ 2:0] funct3_compressed_c_sub = 3'b000;
    wire [ 6:0] funct7_compressed_c_sub = 7'b0100000;
    wire [31:0] imm_val_compressed_c_sub = 32'b0;
    wire [ 5:0] shamt_val_compressed_c_sub = 6'b000000;
    wire [ 4:0] rs1_compressed_c_sub = 5'b01000 | ins[9:7];
    wire [ 4:0] rs2_compressed_c_sub = 5'b01000 | ins[4:2];
    wire [ 4:0] rd_compressed_c_sub = 5'b01000 | ins[9:7];
    wire is_jalr_compressed_c_sub = 1'b0;
    wire [31:0] offset_compressed_c_sub = 2;

    wire [ 6:0] opcode_compressed_c_sw = 7'b0100011;
    wire [ 2:0] funct3_compressed_c_sw = 3'b010;
    wire [ 6:0] funct7_compressed_c_sw = 7'b0000000;
    wire [31:0] imm_val_compressed_c_sw = {25'b0, ins[5], ins[12:10], ins[6], 2'b00};
    wire [ 5:0] shamt_val_compressed_c_sw = 6'b000000;
    wire [ 4:0] rs1_compressed_c_sw = 5'b01000 | ins[9:7];
    wire [ 4:0] rs2_compressed_c_sw = 5'b01000 | ins[4:2];
    wire [ 4:0] rd_compressed_c_sw = 5'b00000;
    wire is_jalr_compressed_c_sw = 1'b0;
    wire [31:0] offset_compressed_c_sw = 2;

    wire [ 6:0] opcode_compressed_c_swsp = 7'b0100011;
    wire [ 2:0] funct3_compressed_c_swsp = 3'b010;
    wire [ 6:0] funct7_compressed_c_swsp = 7'b0000000;
    wire [31:0] imm_val_compressed_c_swsp = {24'b0, ins[8:7], ins[12:9], 2'b00};
    wire [ 5:0] shamt_val_compressed_c_swsp = 6'b000000;
    wire [ 4:0] rs1_compressed_c_swsp = 5'b00010;
    wire [ 4:0] rs2_compressed_c_swsp = ins[6:2];
    wire [ 4:0] rd_compressed_c_swsp = 5'b00000;
    wire is_jalr_compressed_c_swsp = 1'b0;
    wire [31:0] offset_compressed_c_swsp = 2;

    wire [ 6:0] opcode_compressed_c_xor = 7'b0110011;
    wire [ 2:0] funct3_compressed_c_xor = 3'b100;
    wire [ 6:0] funct7_compressed_c_xor = 7'b0000000;
    wire [31:0] imm_val_compressed_c_xor = 32'b0;
    wire [ 5:0] shamt_val_compressed_c_xor = 6'b000000;
    wire [ 4:0] rs1_compressed_c_xor = 5'b01000 | ins[9:7];
    wire [ 4:0] rs2_compressed_c_xor = 5'b01000 | ins[4:2];
    wire [ 4:0] rd_compressed_c_xor = 5'b01000 | ins[9:7];
    wire is_jalr_compressed_c_xor = 1'b0;
    wire [31:0] offset_compressed_c_xor = 2;

    assign opcode_compressed = (is_c_add ? opcode_compressed_c_add :
                                (is_c_addi ? opcode_compressed_c_addi :
                                 (is_c_addi16sp ? opcode_compressed_c_addi16sp :
                                  (is_c_addi4spn ? opcode_compressed_c_addi4spn :
                                   (is_c_and ? opcode_compressed_c_and :
                                    (is_c_andi ? opcode_compressed_c_andi :
                                     (is_c_beqz ? opcode_compressed_c_beqz :
                                      (is_c_bnez ? opcode_compressed_c_bnez :
                                       (is_c_j ? opcode_compressed_c_j :
                                        (is_c_jal ? opcode_compressed_c_jal :
                                         (is_c_jalr ? opcode_compressed_c_jalr :
                                          (is_c_jr ? opcode_compressed_c_jr :
                                           (is_c_li ? opcode_compressed_c_li :
                                            (is_c_lui ? opcode_compressed_c_lui :
                                             (is_c_lw ? opcode_compressed_c_lw :
                                              (is_c_lwsp ? opcode_compressed_c_lwsp :
                                               (is_c_mv ? opcode_compressed_c_mv :
                                                (is_c_or ? opcode_compressed_c_or :
                                                 (is_c_slli ? opcode_compressed_c_slli :
                                                  (is_c_srai ? opcode_compressed_c_srai :
                                                   (is_c_srli ? opcode_compressed_c_srli :
                                                    (is_c_sub ? opcode_compressed_c_sub :
                                                     (is_c_sw ? opcode_compressed_c_sw :
                                                      (is_c_swsp ? opcode_compressed_c_swsp :
                                                       (is_c_xor ? opcode_compressed_c_xor : 7'b0000000)))))))))))))))))))))))));
    assign funct3_compressed = (is_c_add ? funct3_compressed_c_add :
                                (is_c_addi ? funct3_compressed_c_addi :
                                 (is_c_addi16sp ? funct3_compressed_c_addi16sp :
                                  (is_c_addi4spn ? funct3_compressed_c_addi4spn :
                                   (is_c_and ? funct3_compressed_c_and :
                                    (is_c_andi ? funct3_compressed_c_andi :
                                     (is_c_beqz ? funct3_compressed_c_beqz :
                                      (is_c_bnez ? funct3_compressed_c_bnez :
                                       (is_c_j ? funct3_compressed_c_j :
                                        (is_c_jal ? funct3_compressed_c_jal :
                                         (is_c_jalr ? funct3_compressed_c_jalr :
                                          (is_c_jr ? funct3_compressed_c_jr :
                                           (is_c_li ? funct3_compressed_c_li :
                                            (is_c_lui ? funct3_compressed_c_lui :
                                             (is_c_lw ? funct3_compressed_c_lw :
                                              (is_c_lwsp ? funct3_compressed_c_lwsp :
                                               (is_c_mv ? funct3_compressed_c_mv :
                                                (is_c_or ? funct3_compressed_c_or :
                                                 (is_c_slli ? funct3_compressed_c_slli :
                                                  (is_c_srai ? funct3_compressed_c_srai :
                                                   (is_c_srli ? funct3_compressed_c_srli :
                                                    (is_c_sub ? funct3_compressed_c_sub :
                                                     (is_c_sw ? funct3_compressed_c_sw :
                                                      (is_c_swsp ? funct3_compressed_c_swsp :
                                                       (is_c_xor ? funct3_compressed_c_xor : 3'b000)))))))))))))))))))))))));
    assign funct7_compressed = (is_c_add ? funct7_compressed_c_add :
                                (is_c_addi ? funct7_compressed_c_addi :
                                 (is_c_addi16sp ? funct7_compressed_c_addi16sp :
                                  (is_c_addi4spn ? funct7_compressed_c_addi4spn :
                                   (is_c_and ? funct7_compressed_c_and :
                                    (is_c_andi ? funct7_compressed_c_andi :
                                     (is_c_beqz ? funct7_compressed_c_beqz :
                                      (is_c_bnez ? funct7_compressed_c_bnez :
                                       (is_c_j ? funct7_compressed_c_j :
                                        (is_c_jal ? funct7_compressed_c_jal :
                                         (is_c_jalr ? funct7_compressed_c_jalr :
                                          (is_c_jr ? funct7_compressed_c_jr :
                                           (is_c_li ? funct7_compressed_c_li :
                                            (is_c_lui ? funct7_compressed_c_lui :
                                             (is_c_lw ? funct7_compressed_c_lw :
                                              (is_c_lwsp ? funct7_compressed_c_lwsp :
                                               (is_c_mv ? funct7_compressed_c_mv :
                                                (is_c_or ? funct7_compressed_c_or :
                                                 (is_c_slli ? funct7_compressed_c_slli :
                                                  (is_c_srai ? funct7_compressed_c_srai :
                                                   (is_c_srli ? funct7_compressed_c_srli :
                                                    (is_c_sub ? funct7_compressed_c_sub :
                                                     (is_c_sw ? funct7_compressed_c_sw :
                                                      (is_c_swsp ? funct7_compressed_c_swsp :
                                                       (is_c_xor ? funct7_compressed_c_xor : 7'b0000000)))))))))))))))))))))))));
    assign imm_val_compressed = (is_c_add ? imm_val_compressed_c_add :
                                 (is_c_addi ? imm_val_compressed_c_addi :
                                  (is_c_addi16sp ? imm_val_compressed_c_addi16sp :
                                   (is_c_addi4spn ? imm_val_compressed_c_addi4spn :
                                    (is_c_and ? imm_val_compressed_c_and :
                                     (is_c_andi ? imm_val_compressed_c_andi :
                                      (is_c_beqz ? imm_val_compressed_c_beqz :
                                       (is_c_bnez ? imm_val_compressed_c_bnez :
                                        (is_c_j ? imm_val_compressed_c_j :
                                         (is_c_jal ? imm_val_compressed_c_jal :
                                          (is_c_jalr ? imm_val_compressed_c_jalr :
                                           (is_c_jr ? imm_val_compressed_c_jr :
                                            (is_c_li ? imm_val_compressed_c_li :
                                             (is_c_lui ? imm_val_compressed_c_lui :
                                              (is_c_lw ? imm_val_compressed_c_lw :
                                               (is_c_lwsp ? imm_val_compressed_c_lwsp :
                                                (is_c_mv ? imm_val_compressed_c_mv :
                                                 (is_c_or ? imm_val_compressed_c_or :
                                                  (is_c_slli ? imm_val_compressed_c_slli :
                                                   (is_c_srai ? imm_val_compressed_c_srai :
                                                    (is_c_srli ? imm_val_compressed_c_srli :
                                                     (is_c_sub ? imm_val_compressed_c_sub :
                                                      (is_c_sw ? imm_val_compressed_c_sw :
                                                       (is_c_swsp ? imm_val_compressed_c_swsp :
                                                        (is_c_xor ? imm_val_compressed_c_xor : 32'b0)))))))))))))))))))))))));
    assign shamt_val_compressed = (is_c_add ? shamt_val_compressed_c_add :
                                   (is_c_addi ? shamt_val_compressed_c_addi :
                                    (is_c_addi16sp ? shamt_val_compressed_c_addi16sp :
                                     (is_c_addi4spn ? shamt_val_compressed_c_addi4spn :
                                      (is_c_and ? shamt_val_compressed_c_and :
                                       (is_c_andi ? shamt_val_compressed_c_andi :
                                        (is_c_beqz ? shamt_val_compressed_c_beqz :
                                         (is_c_bnez ? shamt_val_compressed_c_bnez :
                                          (is_c_j ? shamt_val_compressed_c_j :
                                           (is_c_jal ? shamt_val_compressed_c_jal :
                                            (is_c_jalr ? shamt_val_compressed_c_jalr :
                                             (is_c_jr ? shamt_val_compressed_c_jr :
                                              (is_c_li ? shamt_val_compressed_c_li :
                                               (is_c_lui ? shamt_val_compressed_c_lui :
                                                (is_c_lw ? shamt_val_compressed_c_lw :
                                                 (is_c_lwsp ? shamt_val_compressed_c_lwsp :
                                                  (is_c_mv ? shamt_val_compressed_c_mv :
                                                   (is_c_or ? shamt_val_compressed_c_or :
                                                    (is_c_slli ? shamt_val_compressed_c_slli :
                                                     (is_c_srai ? shamt_val_compressed_c_srai :
                                                      (is_c_srli ? shamt_val_compressed_c_srli :
                                                       (is_c_sub ? shamt_val_compressed_c_sub :
                                                        (is_c_sw ? shamt_val_compressed_c_sw :
                                                         (is_c_swsp ? shamt_val_compressed_c_swsp :
                                                          (is_c_xor ? shamt_val_compressed_c_xor : 6'b000000)))))))))))))))))))))))));
    assign rs1_compressed = (is_c_add ? rs1_compressed_c_add :
                             (is_c_addi ? rs1_compressed_c_addi :
                              (is_c_addi16sp ? rs1_compressed_c_addi16sp :
                               (is_c_addi4spn ? rs1_compressed_c_addi4spn :
                                (is_c_and ? rs1_compressed_c_and :
                                 (is_c_andi ? rs1_compressed_c_andi :
                                  (is_c_beqz ? rs1_compressed_c_beqz :
                                   (is_c_bnez ? rs1_compressed_c_bnez :
                                    (is_c_j ? rs1_compressed_c_j :
                                     (is_c_jal ? rs1_compressed_c_jal :
                                      (is_c_jalr ? rs1_compressed_c_jalr :
                                       (is_c_jr ? rs1_compressed_c_jr :
                                        (is_c_li ? rs1_compressed_c_li :
                                         (is_c_lui ? rs1_compressed_c_lui :
                                          (is_c_lw ? rs1_compressed_c_lw :
                                           (is_c_lwsp ? rs1_compressed_c_lwsp :
                                            (is_c_mv ? rs1_compressed_c_mv :
                                             (is_c_or ? rs1_compressed_c_or :
                                              (is_c_slli ? rs1_compressed_c_slli :
                                               (is_c_srai ? rs1_compressed_c_srai :
                                                (is_c_srli ? rs1_compressed_c_srli :
                                                 (is_c_sub ? rs1_compressed_c_sub :
                                                  (is_c_sw ? rs1_compressed_c_sw :
                                                   (is_c_swsp ? rs1_compressed_c_swsp :
                                                    (is_c_xor ? rs1_compressed_c_xor : 5'b00000)))))))))))))))))))))))));
    assign rs2_compressed = (is_c_add ? rs2_compressed_c_add :
                             (is_c_addi ? rs2_compressed_c_addi :
                              (is_c_addi16sp ? rs2_compressed_c_addi16sp :
                               (is_c_addi4spn ? rs2_compressed_c_addi4spn :
                                (is_c_and ? rs2_compressed_c_and :
                                 (is_c_andi ? rs2_compressed_c_andi :
                                  (is_c_beqz ? rs2_compressed_c_beqz :
                                   (is_c_bnez ? rs2_compressed_c_bnez :
                                    (is_c_j ? rs2_compressed_c_j :
                                     (is_c_jal ? rs2_compressed_c_jal :
                                      (is_c_jalr ? rs2_compressed_c_jalr :
                                       (is_c_jr ? rs2_compressed_c_jr :
                                        (is_c_li ? rs2_compressed_c_li :
                                         (is_c_lui ? rs2_compressed_c_lui :
                                          (is_c_lw ? rs2_compressed_c_lw :
                                           (is_c_lwsp ? rs2_compressed_c_lwsp :
                                            (is_c_mv ? rs2_compressed_c_mv :
                                             (is_c_or ? rs2_compressed_c_or :
                                              (is_c_slli ? rs2_compressed_c_slli :
                                               (is_c_srai ? rs2_compressed_c_srai :
                                                (is_c_srli ? rs2_compressed_c_srli :
                                                 (is_c_sub ? rs2_compressed_c_sub :
                                                  (is_c_sw ? rs2_compressed_c_sw :
                                                   (is_c_swsp ? rs2_compressed_c_swsp :
                                                    (is_c_xor ? rs2_compressed_c_xor : 5'b00000)))))))))))))))))))))))));
    assign rd_compressed = (is_c_add ? rd_compressed_c_add :
                            (is_c_addi ? rd_compressed_c_addi :
                             (is_c_addi16sp ? rd_compressed_c_addi16sp :
                              (is_c_addi4spn ? rd_compressed_c_addi4spn :
                               (is_c_and ? rd_compressed_c_and :
                                (is_c_andi ? rd_compressed_c_andi :
                                 (is_c_beqz ? rd_compressed_c_beqz :
                                  (is_c_bnez ? rd_compressed_c_bnez :
                                   (is_c_j ? rd_compressed_c_j :
                                    (is_c_jal ? rd_compressed_c_jal :
                                     (is_c_jalr ? rd_compressed_c_jalr :
                                      (is_c_jr ? rd_compressed_c_jr :
                                       (is_c_li ? rd_compressed_c_li :
                                        (is_c_lui ? rd_compressed_c_lui :
                                         (is_c_lw ? rd_compressed_c_lw :
                                          (is_c_lwsp ? rd_compressed_c_lwsp :
                                           (is_c_mv ? rd_compressed_c_mv :
                                            (is_c_or ? rd_compressed_c_or :
                                             (is_c_slli ? rd_compressed_c_slli :
                                              (is_c_srai ? rd_compressed_c_srai :
                                               (is_c_srli ? rd_compressed_c_srli :
                                                (is_c_sub ? rd_compressed_c_sub :
                                                 (is_c_sw ? rd_compressed_c_sw :
                                                  (is_c_swsp ? rd_compressed_c_swsp :
                                                   (is_c_xor ? rd_compressed_c_xor : 5'b00000)))))))))))))))))))))))));
    assign is_jalr_compressed = (is_c_add ? is_jalr_compressed_c_add :
                                 (is_c_addi ? is_jalr_compressed_c_addi :
                                  (is_c_addi16sp ? is_jalr_compressed_c_addi16sp :
                                   (is_c_addi4spn ? is_jalr_compressed_c_addi4spn :
                                    (is_c_and ? is_jalr_compressed_c_and :
                                     (is_c_andi ? is_jalr_compressed_c_andi :
                                      (is_c_beqz ? is_jalr_compressed_c_beqz :
                                       (is_c_bnez ? is_jalr_compressed_c_bnez :
                                        (is_c_j ? is_jalr_compressed_c_j :
                                         (is_c_jal ? is_jalr_compressed_c_jal :
                                          (is_c_jalr ? is_jalr_compressed_c_jalr :
                                           (is_c_jr ? is_jalr_compressed_c_jr :
                                            (is_c_li ? is_jalr_compressed_c_li :
                                             (is_c_lui ? is_jalr_compressed_c_lui :
                                              (is_c_lw ? is_jalr_compressed_c_lw :
                                               (is_c_lwsp ? is_jalr_compressed_c_lwsp :
                                                (is_c_mv ? is_jalr_compressed_c_mv :
                                                 (is_c_or ? is_jalr_compressed_c_or :
                                                  (is_c_slli ? is_jalr_compressed_c_slli :
                                                   (is_c_srai ? is_jalr_compressed_c_srai :
                                                    (is_c_srli ? is_jalr_compressed_c_srli :
                                                     (is_c_sub ? is_jalr_compressed_c_sub :
                                                      (is_c_sw ? is_jalr_compressed_c_sw :
                                                       (is_c_swsp ? is_jalr_compressed_c_swsp :
                                                        (is_c_xor ? is_jalr_compressed_c_xor : 1'b0)))))))))))))))))))))))));
    assign offset_compressed = (is_c_add ? offset_compressed_c_add :
                                (is_c_addi ? offset_compressed_c_addi :
                                 (is_c_addi16sp ? offset_compressed_c_addi16sp :
                                  (is_c_addi4spn ? offset_compressed_c_addi4spn :
                                   (is_c_and ? offset_compressed_c_and :
                                    (is_c_andi ? offset_compressed_c_andi :
                                     (is_c_beqz ? offset_compressed_c_beqz :
                                      (is_c_bnez ? offset_compressed_c_bnez :
                                       (is_c_j ? offset_compressed_c_j :
                                        (is_c_jal ? offset_compressed_c_jal :
                                         (is_c_jalr ? offset_compressed_c_jalr :
                                          (is_c_jr ? offset_compressed_c_jr :
                                           (is_c_li ? offset_compressed_c_li :
                                            (is_c_lui ? offset_compressed_c_lui :
                                             (is_c_lw ? offset_compressed_c_lw :
                                              (is_c_lwsp ? offset_compressed_c_lwsp :
                                               (is_c_mv ? offset_compressed_c_mv :
                                                (is_c_or ? offset_compressed_c_or :
                                                 (is_c_slli ? offset_compressed_c_slli :
                                                  (is_c_srai ? offset_compressed_c_srai :
                                                   (is_c_srli ? offset_compressed_c_srli :
                                                    (is_c_sub ? offset_compressed_c_sub :
                                                     (is_c_sw ? offset_compressed_c_sw :
                                                      (is_c_swsp ? offset_compressed_c_swsp :
                                                       (is_c_xor ? offset_compressed_c_xor : 32'b0)))))))))))))))))))))))));
endmodule

module IssueManager(
        input  wire                 clk_in,			// system clock signal
        input  wire                 rst_in,			// reset signal
        input  wire					        rdy_in,			// ready signal, pause cpu when low

        input  wire                 flush_pipline,
        input  wire [31:0]          reset_PC_to,
        input  wire                 jalr_just_done,
        input  wire [31:0]          jalr_resulting_PC,
        input  wire                 issue_space_available,

        output wire                 is_issueing,
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

    wire [31:0] current_ins_to_decode;
    wire [31:0]  current_ins_offset;
    reg [31:0] current_PC;
    reg is_waiting_for_jalr;
    reg have_ins_processing;
    wire [31:0] ins_data;

    wire ins_ready;
    wire jalr_just_occured;
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
                .is_jalr(jalr_just_occured),
                .is_compressed_ins(is_compressed_ins)
            );

    wire try_fetch = (~(is_waiting_for_jalr|jalr_just_occured)) & issue_space_available & ins_ready;
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
                         .read_addr(current_PC+(is_issueing ? current_ins_offset : 0)),
                         .is_ready(ins_ready),
                         .read_data(ins_data)
                     );

    assign is_issueing = have_ins_processing & ins_ready;
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
            if (try_fetch) begin
                have_ins_processing <= 1'b1;
            end
            else if(is_issueing && !try_fetch) begin
                have_ins_processing <= 1'b0;
            end
            if (flush_pipline) begin
                current_PC <= reset_PC_to;
                is_waiting_for_jalr <= 1'b0;
            end
            else if (jalr_just_done && is_waiting_for_jalr) begin
                current_PC <= jalr_resulting_PC;
                is_waiting_for_jalr <= 1'b0;
            end
            else begin
                current_PC <= current_PC+(is_issueing ? current_ins_offset : 0);
                if (is_issueing) begin
                    is_waiting_for_jalr <= jalr_just_occured;
                end
            end
        end
    end

endmodule
