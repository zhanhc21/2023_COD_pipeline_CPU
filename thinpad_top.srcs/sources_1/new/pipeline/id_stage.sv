module ID_Stage (
    input wire clk_i,
    input wire rst_i,

    // signals from IF stage
    input wire [31:0] id_pc_i,
    input wire [31:0] id_instr_i,

    // stall signal and flush signal
    input wire stall_i,
    input wire flush_i,

    // regfile signals
    input wire [31:0] rf_rdata_a_i,
    input wire [31:0] rf_rdata_b_i,
    output reg [4:0] rf_raddr_a_o,
    output reg [4:0] rf_raddr_b_o,

    // csr signals
    input wire [31:0] csr_rdata_i,
    output reg [11:0] csr_raddr_o,
    
    // signal to controller
    output reg exe_first_time_o,
    output reg ebreak_o,
    output reg ecall_o,
    output reg mret_o,

    // signals to EXE stage
    output reg [31:0] exe_pc_o,
    output reg [31:0] exe_instr_o,
    output reg [ 4:0] exe_rf_raddr_a_o,
    output reg [ 4:0] exe_rf_raddr_b_o,
    output reg [31:0] exe_rf_rdata_a_o,
    output reg [31:0] exe_rf_rdata_b_o,
    output reg [31:0] exe_imm_o,
    output reg        exe_mem_en_o,  // 1: use
    output reg        exe_mem_wen_o,  // 1: enable
    output reg [ 3:0] exe_alu_op_o,
    output reg        exe_alu_a_mux_o,  // 0: rs1, 1: pc
    output reg        exe_alu_b_mux_o,  // 0: imm, 1: rs2
    output reg [ 4:0] exe_rf_waddr_o,
    output reg        exe_rf_wen_o,  // 1: enable

    output reg [11:0] exe_csr_waddr_o,
    output reg        exe_csr_wen_o  // 1: enable
);
    // TODO: stall signal and flush signal
    reg [31:0] pc_reg;

    reg [31:0] inst_reg;
    reg [ 2:0] inst_type_reg;
    reg [31:0] imm_gen_imm_i;

    reg [ 6:0] opcode_reg;
    reg [ 4:0] rd_reg;
    reg [ 2:0] funct3_reg;
    reg [ 6:0] funct6_reg;
    reg [12:0] funct12_reg;
    reg [ 4:0] rs1_reg;
    reg [ 4:0] rs2_reg;

    reg [3:0] alu_op_reg;
    reg       alu_a_mux_reg;  // 0: rs1, 1: pc
    reg       alu_b_mux_reg;  // 0: imm, 1: rs2

    reg [31:0] rdata_a_reg;
    reg [31:0] rdata_b_reg;

    reg mem_en_reg;  // 1: use
    reg mem_wen_reg;  // 1: enable
    reg rf_wen_reg;  // 1: enable

    reg [31:0] csr_rdata_reg;
    reg [11:0] csr_raddr_reg;

    reg [11:0] csr_waddr_reg;
    reg csr_wen_reg;  // 1: enable

    reg ebreak_reg;
    reg ecall_reg;
    reg mret_reg;

    imm_gen u_imm_gen(
        .inst(inst_reg),
        .imm_gen_type(inst_type_reg),
        .imm_gen_o(imm_gen_imm_i)
    );

    typedef enum logic [6:0] {
        OPCODE_ADD_AND_OR_XOR_ANDN_SBSET_MINU_SLTU = 7'b0110011,
        OPCODE_ADDI_ANDI_ORI_SLLI_SRLI = 7'b0010011,
        OPCODE_AUIPC = 7'b0010111,
        OPCODE_BEQ_BNE = 7'b1100011,
        OPCODE_JAL = 7'b1101111,
        OPCODE_JALR = 7'b1100111,
        OPCODE_LB_LW = 7'b0000011,
        OPCODE_LUI = 7'b0110111,
        OPCODE_SB_SW = 7'b0100011,
        OPCODE_CSRRC_CSRRS_CSRRW_EBREAK_ECALL_MRET = 7'b1110011
    } opcode_t;

    typedef enum logic [2:0] {
        TYPE_R = 0,
        TYPE_I = 1,
        TYPE_S = 2,
        TYPE_B = 3,
        TYPE_U = 4,
        TYPE_J = 5
    } inst_type_t;

    typedef enum logic [3:0] {
        ALU_DEFAULT = 4'd0,
        ALU_ADD = 4'd1,
        ALU_SUB = 4'd2,
        ALU_AND = 4'd3,
        ALU_OR = 4'd4,
        ALU_XOR = 4'd5,
        ALU_NOT = 4'd6,
        ALU_SLL = 4'd7,
        ALU_SRL = 4'd8,
        ALU_SRA = 4'd9,
        ALU_ROL = 4'd10,
        ALU_ANDN = 4'd11,
        ALU_SBSET = 4'd12,
        ALU_MINU = 4'd13,
        ALU_SLTU = 4'd14
    } alu_op_type_t;
    
    always_comb begin
        pc_reg = id_pc_i;
        inst_reg = id_instr_i;
        opcode_reg = id_instr_i[6:0];
        rd_reg = id_instr_i[11:7];
        funct3_reg = id_instr_i[14:12];
        funct6_reg = id_instr_i[31:25];
        funct12_reg = id_instr_i[31:20];

        rs1_reg = id_instr_i[19:15];
        rs2_reg = id_instr_i[24:20];
        csr_raddr_reg = id_instr_i[31:20];
        csr_waddr_reg = id_instr_i[31:20];

        rdata_a_reg = rf_rdata_a_i;
        rdata_b_reg = rf_rdata_b_i;

        csr_rdata_reg = csr_rdata_i;

        case(opcode_reg)
            OPCODE_ADD_AND_OR_XOR_ANDN_SBSET_MINU_SLTU: begin
                inst_type_reg = TYPE_R;
                case(funct3_reg)
                    3'b000: begin  // <instruction is ADD>
                        alu_op_reg = ALU_ADD;
                    end
                    3'b111: begin  // <instruction is AND or ANDN>
                        case (funct6_reg)
                            7'b0000000: alu_op_reg = ALU_AND;
                            7'b0100000: alu_op_reg = ALU_ANDN;
                            default:    alu_op_reg = ALU_DEFAULT;
                        endcase
                    end
                    3'b110: begin  // <instruction is OR or MINU>
                        case (funct6_reg)
                            7'b0000101: alu_op_reg = ALU_MINU;
                            7'b0000000: alu_op_reg = ALU_OR;
                            default:    alu_op_reg = ALU_DEFAULT;
                        endcase
                    end
                    3'b100: begin  // <instruction is XOR>
                        alu_op_reg = ALU_XOR;
                    end
                    3'b001: begin  // <instruction is SBSET>
                        alu_op_reg = ALU_SBSET;
                    end
                    3'b011: begin // <instruction is SLTU>
                        alu_op_reg = ALU_SLTU;
                    end
                    default: begin
                        alu_op_reg = ALU_DEFAULT;
                    end
                endcase
                alu_a_mux_reg = 0;
                alu_b_mux_reg = 1;
                rf_wen_reg = 1;
                mem_en_reg = 0;
                mem_wen_reg = 0;
                csr_wen_reg = 0;
                ebreak_reg = 0;
                ecall_reg = 0;
                mret_reg = 0;
            end
            OPCODE_ADDI_ANDI_ORI_SLLI_SRLI: begin
                inst_type_reg = TYPE_I;
                case(funct3_reg)
                    3'b000: begin  // <instruction is ADDI>
                        alu_op_reg = ALU_ADD;
                    end
                    3'b111: begin  // <instruction is ANDI>
                        alu_op_reg = ALU_AND;
                    end
                    3'b110: begin  // <instruction is ORI>
                        alu_op_reg = ALU_OR;
                    end
                    3'b001: begin  // <instruction is SLLI>
                        alu_op_reg = ALU_SLL;
                    end
                    3'b101: begin  // <instruction is SRLI>
                        alu_op_reg = ALU_SRL;
                    end
                    default: begin
                        alu_op_reg = ALU_DEFAULT;
                    end
                endcase
                alu_a_mux_reg = 0;
                alu_b_mux_reg = 0;
                rf_wen_reg = 1;
                mem_en_reg = 0;
                mem_wen_reg = 0;
                csr_wen_reg = 0;
                ebreak_reg = 0;
                ecall_reg = 0;
                mret_reg = 0;
            end
            OPCODE_AUIPC: begin
                inst_type_reg = TYPE_U;
                alu_op_reg = ALU_ADD;
                alu_a_mux_reg = 1;
                alu_b_mux_reg = 0;
                rf_wen_reg = 1;
                mem_en_reg = 0;
                mem_wen_reg = 0;
                csr_wen_reg = 0;
                ebreak_reg = 0;
                ecall_reg = 0;
                mret_reg = 0;
            end
            OPCODE_BEQ_BNE: begin
                inst_type_reg = TYPE_B;
                alu_op_reg = ALU_ADD;
                alu_a_mux_reg = 1;
                alu_b_mux_reg = 0;
                rf_wen_reg = 0;
                mem_en_reg = 0;
                mem_wen_reg = 0;
                csr_wen_reg = 0;
                ebreak_reg = 0;
                ecall_reg = 0;
                mret_reg = 0;
            end
            OPCODE_JAL: begin
                inst_type_reg = TYPE_J;
                alu_op_reg = ALU_ADD;
                alu_a_mux_reg = 1;
                alu_b_mux_reg = 0;
                rf_wen_reg = 1;
                mem_en_reg = 0;
                mem_wen_reg = 0;
                csr_wen_reg = 0;
                ebreak_reg = 0;
                ecall_reg = 0;
                mret_reg = 0;
            end
            OPCODE_JALR: begin  // NOTE: pc = alu_result & ~1
                inst_type_reg = TYPE_I;
                alu_op_reg = ALU_ADD;
                alu_a_mux_reg = 1;
                alu_b_mux_reg = 0;
                rf_wen_reg = 1;
                mem_en_reg = 0;
                mem_wen_reg = 0;
                rs2_reg = 5'b0;
                csr_wen_reg = 0;
                ebreak_reg = 0;
                ecall_reg = 0;
                mret_reg = 0;
            end
            OPCODE_LB_LW: begin
                inst_type_reg = TYPE_I;
                alu_op_reg = ALU_ADD;
                alu_a_mux_reg = 0;
                alu_b_mux_reg = 0;
                rf_wen_reg = 1;
                mem_en_reg = 1;
                mem_wen_reg = 0;
                rs2_reg = 5'b0;
                csr_wen_reg = 0;
                ebreak_reg = 0;
                ecall_reg = 0;
                mret_reg = 0;
            end
            OPCODE_LUI: begin
                inst_type_reg = TYPE_U;
                alu_op_reg = ALU_DEFAULT;
                alu_a_mux_reg = 0;
                alu_b_mux_reg = 0;
                rf_wen_reg = 1;
                mem_en_reg = 0;
                mem_wen_reg = 0;
                rs1_reg = 5'b0;
                rs2_reg = 5'b0;
                csr_wen_reg = 0;
                ebreak_reg = 0;
                ecall_reg = 0;
                mret_reg = 0;
            end
            OPCODE_SB_SW: begin
                inst_type_reg = TYPE_S;
                alu_op_reg = ALU_ADD;
                alu_a_mux_reg = 0;
                alu_b_mux_reg = 0;
                rf_wen_reg = 0;
                mem_en_reg = 1;
                mem_wen_reg = 1;
                csr_wen_reg = 0;
                ebreak_reg = 0;
                ecall_reg = 0;
                mret_reg = 0;
            end
            OPCODE_CSRRC_CSRRS_CSRRW_EBREAK_ECALL_MRET: begin
                inst_type_reg = TYPE_I;
                case(funct3_reg)
                    3'b011: begin  // <instruction is CSRRC>
                        alu_op_reg = ALU_ANDN;
                        rs2_reg = 5'b0;
                        rf_wen_reg = 1;
                        csr_wen_reg = 1;
                        ebreak_reg = 0;
                        ecall_reg = 0;
                        mret_reg = 0;
                    end
                    3'b010: begin // <instruction is CSRRS>
                        alu_op_reg = ALU_OR;
                        rs2_reg = 5'b0;
                        rf_wen_reg = 1;
                        csr_wen_reg = 1;
                        ebreak_reg = 0;
                        ecall_reg = 0;
                        mret_reg = 0;
                    end
                    3'b001: begin // <instruction is CSRRW>
                        alu_op_reg = ALU_ADD;
                        rs1_reg = 5'b0;
                        rs2_reg = 5'b0;
                        rf_wen_reg = 1;
                        csr_wen_reg = 1;
                        ebreak_reg = 0;
                        ecall_reg = 0;
                        mret_reg = 0;
                    end
                    3'b000: begin
                        case(funct12_reg)
                            12'b000000000001: begin // <instruction is EBREAK>
                                ebreak_reg = 1;
                                ecall_reg = 0;
                                mret_reg = 0;
                            end
                            12'b000000000000: begin // <instruction is ECALL>
                                ebreak_reg = 0;
                                ecall_reg = 1;
                                mret_reg = 0;
                            end
                            12'b001100000010: begin // <instruction is MRET>
                                ebreak_reg = 0;
                                ecall_reg = 0;
                                mret_reg = 1;
                            end
                            default: begin
                                ebreak_reg = 0;
                                ecall_reg = 0;
                                mret_reg = 0;
                            end
                        endcase
                        alu_op_reg = ALU_DEFAULT;
                        rs1_reg = 5'b0;
                        rs2_reg = 5'b0;
                        csr_raddr_reg = 12'b0;
                        rf_wen_reg = 0;
                        csr_wen_reg = 0;
                    end
                    default: begin
                        alu_op_reg = ALU_DEFAULT;
                        rs1_reg = 5'b0;
                        rs2_reg = 5'b0;
                        csr_raddr_reg = 12'b0;
                        rf_wen_reg = 0;
                        csr_wen_reg = 0;

                        ebreak_reg = 0;
                        ecall_reg = 0;
                        mret_reg = 0;
                    end
                endcase
                alu_a_mux_reg = 0;
                alu_b_mux_reg = 0;
                
                mem_en_reg = 0;
                mem_wen_reg = 0;
            end
            default: begin
                inst_type_reg = TYPE_R;
                alu_op_reg = ALU_DEFAULT;
                alu_a_mux_reg = 0;
                alu_b_mux_reg = 0;
                rf_wen_reg = 0;
                mem_en_reg = 0;
                mem_wen_reg = 0;
                rs1_reg = 5'b0;
                rs2_reg = 5'b0;
                csr_wen_reg = 0;
                ebreak_reg = 0;
                ecall_reg = 0;
                mret_reg = 0;
            end
        endcase
    end

    always_ff @ (posedge clk_i) begin
        if (rst_i) begin
            exe_pc_o <= 32'b0;
            exe_instr_o <= 32'b0;
            exe_rf_raddr_a_o <= 5'b0;
            exe_rf_raddr_b_o <= 5'b0;
            exe_rf_rdata_a_o <= 32'b0;
            exe_rf_rdata_b_o <= 32'b0;
            exe_imm_o <= 32'b0;
            exe_mem_en_o <= 1'b0;
            exe_mem_wen_o <= 1'b0;
            exe_alu_op_o <= 4'b0;
            exe_alu_a_mux_o <= 1'b0;
            exe_alu_b_mux_o <= 1'b0;
            exe_rf_waddr_o <= 5'b0;
            exe_rf_wen_o <= 1'b0;

            exe_csr_waddr_o <= 12'b0;
            exe_csr_wen_o <= 1'b0;

            ebreak_o <= 1'b0;
            ecall_o <= 1'b0;
            mret_o <= 1'b0;
        end else if (stall_i) begin
            exe_pc_o <= exe_pc_o;
            exe_instr_o <= exe_instr_o;
            exe_rf_raddr_a_o <= exe_rf_raddr_a_o;
            exe_rf_raddr_b_o <= exe_rf_raddr_b_o;
            exe_rf_rdata_a_o <= exe_rf_rdata_a_o;
            exe_rf_rdata_b_o <= exe_rf_rdata_b_o;
            exe_imm_o <= exe_imm_o;
            exe_mem_en_o <= exe_mem_en_o;
            exe_mem_wen_o <= exe_mem_wen_o;
            exe_alu_op_o <= exe_alu_op_o;
            exe_alu_a_mux_o <= exe_alu_a_mux_o;
            exe_alu_b_mux_o <= exe_alu_b_mux_o;
            exe_rf_waddr_o <= exe_rf_waddr_o;
            exe_rf_wen_o <= exe_rf_wen_o;

            exe_csr_waddr_o <= exe_csr_waddr_o;
            exe_csr_wen_o <= exe_csr_wen_o;
        end else if (flush_i) begin
            exe_pc_o <= 32'b0;
            exe_instr_o <= 32'b0;
            exe_rf_raddr_a_o <= 5'b0;
            exe_rf_raddr_b_o <= 5'b0;
            exe_rf_rdata_a_o <= 32'b0;
            exe_rf_rdata_b_o <= 32'b0;
            exe_imm_o <= 32'b0;
            exe_mem_en_o <= 1'b0;
            exe_mem_wen_o <= 1'b0;
            exe_alu_op_o <= 4'b0;
            exe_alu_a_mux_o <= 1'b0;
            exe_alu_b_mux_o <= 1'b0;
            exe_rf_waddr_o <= 5'b0;
            exe_rf_wen_o <= 1'b0;

            exe_csr_waddr_o <= 12'b0;
            exe_csr_wen_o <= 1'b0;
        end else begin
            if (exe_pc_o != pc_reg) begin
                exe_first_time_o <= 1'b1;
            end else begin
                exe_first_time_o <= 1'b0;
            end
            exe_pc_o <= pc_reg;
            exe_instr_o <= inst_reg;
            exe_rf_raddr_a_o <= rs1_reg;
            exe_rf_raddr_b_o <= rs2_reg;
            exe_rf_rdata_a_o <= rdata_a_reg;
            exe_rf_rdata_b_o <= rdata_b_reg;

            case (opcode_reg)
                OPCODE_CSRRC_CSRRS_CSRRW_EBREAK_ECALL_MRET: begin
                    case(funct3_reg)
                        3'b011: begin  // <instruction is CSRRC>
                            exe_imm_o <= csr_rdata_reg;
                        end
                        3'b010: begin // <instruction is CSRRS>
                            exe_imm_o <= csr_rdata_reg;
                        end
                        3'b001: begin // <instruction is CSRRW>
                            exe_imm_o <= csr_rdata_reg;
                        end
                        default: begin
                            exe_imm_o <= imm_gen_imm_i;
                        end
                    endcase
                end
                default: begin
                    exe_imm_o <= imm_gen_imm_i;
                end
            endcase

            exe_mem_en_o <= mem_en_reg;
            exe_mem_wen_o <= mem_wen_reg;
            exe_alu_op_o <= alu_op_reg;
            exe_alu_a_mux_o <= alu_a_mux_reg;
            exe_alu_b_mux_o <= alu_b_mux_reg;
            exe_rf_waddr_o <= rd_reg;
            exe_rf_wen_o <= rf_wen_reg;

            exe_csr_waddr_o <= csr_raddr_reg;
            exe_csr_wen_o <= csr_wen_reg;

            ebreak_o <= ebreak_reg;
            ecall_o <= ecall_reg;
            mret_o <= mret_reg;
        end
    end

    assign rf_raddr_a_o = rs1_reg;
    assign rf_raddr_b_o = rs2_reg;
    assign csr_raddr_o = csr_raddr_reg;
    
endmodule