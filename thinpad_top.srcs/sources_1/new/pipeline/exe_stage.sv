`include "../include/csr.vh"

module EXE_Stage (
    input wire clk_i,
    input wire rst_i,

    // signals from ID stage
    input wire [31:0] exe_pc_i,
    input wire [31:0] exe_instr_i,
    input wire [ 4:0] exe_rf_raddr_a_i,
    input wire [ 4:0] exe_rf_raddr_b_i,
    input wire [31:0] exe_rf_rdata_a_i,
    input wire [31:0] exe_rf_rdata_b_i,
    input wire [31:0] exe_imm_i,
    input wire        exe_mem_en_i,
    input wire        exe_mem_wen_i,
    input wire [ 3:0] exe_alu_op_i,
    input wire        exe_alu_a_mux_i,    // 0: rs1, 1: pc
    input wire        exe_alu_b_mux_i,    // 0: imm, 1: rs2
    input wire [ 4:0] exe_rf_waddr_i,
    input wire        exe_rf_wen_i,
    input wire [11:0] exe_csr_waddr_i,
    input wire        exe_csr_wen_i,

    input wire        exe_exc_en_i,
    input wire [30:0] exe_exc_code_i,
    input wire [31:0] exe_exc_pc_i,

    // stall signal and flush signal
    input wire stall_i,
    input wire flush_i,

    // signals from forward unit
    input wire [31:0] exe_forward_alu_a_i,
    input wire [31:0] exe_forward_alu_b_i,
    input wire exe_forward_alu_a_mux_i,
    input wire exe_forward_alu_b_mux_i,
    input wire mem_finish_i,

    output reg [31:0] if_pc_o,
    output reg        if_pc_mux_o,        // 0: pc+4, 1: exe_pc

    // signals to MEM stage
    output reg  [31:0] mem_pc_o,
    output reg  [31:0] mem_instr_o,
    output reg  [31:0] mem_mem_wdata_o,   // DM wdata
    output reg  [31:0] mem_alu_result_o,  // DM waddr
    output reg         mem_mem_en_o,      // if use DM
    output reg         mem_mem_wen_o,     // if write DM (0: read DM, 1: write DM)
    output reg  [4:0]  mem_rf_waddr_o,    // rf addr
    output reg         mem_rf_wen_o,      // if write back (rf)
    output reg         mem_exc_en_o,
    output reg  [30:0] mem_exc_code_o,
    output reg  [31:0] mem_exc_pc_o,

    // signals to ALU
    input  wire [31:0] alu_result_i,
    output reg  [31:0] alu_operand_a_o,
    output reg  [31:0] alu_operand_b_o,
    output reg  [ 3:0] alu_op_o,

    // signals to CSR
    output reg         csr_wen_o,
    output reg  [31:0] csr_wdata_o,
    output reg  [11:0] csr_waddr_o,

    // signals to BTB
    output reg [31:0] exe_branch_src_pc_o,
    output reg [31:0] exe_branch_tgt_pc_o,
    output reg        exe_branch_en_o,  // 1: take a branch
    output reg        exe_branch_mispred_o,  // 1: mispredict

    input wire        exe_branch_taken_i
); 

    logic [6:0]  opcode;
    op_type instr_type;

    // inst decode
    always_comb begin
        opcode = exe_instr_i[6:0];
        case (opcode)
            7'b0110011: begin
                case(exe_instr_i[14:12])
                    3'b000: begin
                        instr_type = ADD;
                    end
                    3'b111: begin
                        if (exe_instr_i[31:25] == 7'b0000000)
                            instr_type = AND;
                        else // (exe_instr_i[31:25] == 7'b0100000)
                            instr_type = ANDN;
                    end
                    3'b110: begin
                        if (exe_instr_i[31:25] == 7'b0000101)
                            instr_type = MINU;
                        else
                            instr_type = OR;
                    end
                    3'b100: begin
                        instr_type = XOR;
                    end
                    3'b011: begin
                        instr_type = SLTU;
                    end
                    default: begin // (exe_instr_i[14:12] == 3'b001)
                        instr_type = SBSET;
                    end
                endcase
            end
            7'b0010011: begin
                case(exe_instr_i[14:12])
                    3'b000: begin
                        instr_type = ADDI;
                    end
                    3'b111: begin
                        instr_type = ANDI;
                    end
                    3'b110: begin
                        instr_type = ORI;
                    end
                    3'b001: begin
                        instr_type = SLLI;
                    end
                    default: begin
                        instr_type = SRLI;
                    end
                endcase
            end
            7'b0010111: instr_type = AUIPC;
            7'b1100011: begin
                if (exe_instr_i[14:12] == 3'b000)
                    instr_type = BEQ;
                else // (exe_instr_i[14:12] == 3'b001)
                    instr_type = BNE;
            end
            7'b1101111: instr_type = JAL;
            7'b1100111: instr_type = JALR;
            7'b0000011: begin
                if (exe_instr_i[14:12] == 3'b000)
                    instr_type = LB;
                else // (exe_instr_i[14:12] == 3'b010)
                    instr_type = LW; 
            end
            7'b0110111: instr_type = LUI;
            7'b0100011: begin
                if (exe_instr_i[14:12] == 3'b000)
                    instr_type = SB;
                else // (exe_instr_i[14:12] == 3'b010)
                    instr_type = SW; 
            end
            7'b1110011: begin
                case(exe_instr_i[14:12])
                    3'b011: begin
                        instr_type = CSRRC;
                    end
                    3'b010: begin
                        instr_type = CSRRS;
                    end
                    3'b001: begin
                        instr_type = CSRRW;
                    end
                    default: begin
                        case(exe_instr_i[31:20])
                            12'b000000000001: begin
                                instr_type = EBREAK;
                            end
                            12'b000000000000: begin
                                instr_type = ECALL;
                            end
                            default: begin
                                instr_type = MRET;
                            end
                        endcase
                    end
                endcase
            end
            7'b1110111: begin
                instr_type = CRAS16;
            end
            default: instr_type = NOP;
        endcase
    end

    always_comb begin
        alu_op_o = exe_alu_op_i;
        if (exe_alu_a_mux_i == 1'b1)
            alu_operand_a_o = exe_pc_i;
        else if (exe_forward_alu_a_mux_i)
            alu_operand_a_o = exe_forward_alu_a_i;
        else
            alu_operand_a_o = exe_rf_rdata_a_i;
        
        if (exe_alu_b_mux_i == 1'b0)
            // imm
            alu_operand_b_o = exe_imm_i;
        else if (exe_forward_alu_b_mux_i)
            alu_operand_b_o = exe_forward_alu_b_i;
        else 
            // rs2
            alu_operand_b_o = exe_rf_rdata_b_i;
    end

    always_comb begin
        csr_wen_o = exe_csr_wen_i;
        csr_waddr_o = exe_csr_waddr_i;
        if (instr_type != CSRRW)
            csr_wdata_o = alu_result_i;
        else
            csr_wdata_o = exe_rf_rdata_a_i;
    end

    always_comb begin
        case (instr_type)
            BEQ: begin
                exe_branch_src_pc_o = exe_pc_i;
                exe_branch_tgt_pc_o = alu_result_i;
            end
            BNE: begin
                exe_branch_src_pc_o = exe_pc_i;
                exe_branch_tgt_pc_o = alu_result_i;
            end
            JAL: begin
                exe_branch_src_pc_o = exe_pc_i;
                exe_branch_tgt_pc_o = alu_result_i;
            end
            JALR: begin
                exe_branch_src_pc_o = exe_pc_i;
                if (exe_forward_alu_a_mux_i)
                    exe_branch_tgt_pc_o = (exe_imm_i + exe_forward_alu_a_i) & ~1;
                else
                    exe_branch_tgt_pc_o = (exe_imm_i + exe_rf_rdata_a_i) & ~1;
            end
            default: begin
                exe_branch_src_pc_o = 32'b0;
                exe_branch_tgt_pc_o = 32'b0;
            end
        endcase
    end

    always_ff @ (posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            if_pc_mux_o <= 1'b0;
            if_pc_o <= 32'h80000000;
            mem_pc_o <= 32'h0;
            mem_instr_o <= 32'h0;
            mem_alu_result_o <= 32'h0;
            mem_mem_wdata_o <= 32'h0;
            mem_mem_en_o <= 1'b0;
            mem_mem_wen_o <= 1'b0;
            mem_rf_wen_o <= 1'b0;
            mem_rf_waddr_o <= 5'b0;
            mem_exc_en_o    <= 1'b0;
            mem_exc_pc_o    <= 32'b0;
            mem_exc_code_o  <= 31'b0;

            exe_branch_en_o <= 1'b0;
            exe_branch_mispred_o <= 1'b0;
        end else begin
            if (stall_i == 1'b0 && (exe_pc_i == if_pc_o || exe_pc_i == 32'h0 || if_pc_o == 32'h0 ) &&
            (mem_pc_o != exe_pc_i || mem_instr_o != exe_instr_i)) begin
                if (exe_pc_i == 32'h800010b8) begin
                    mem_pc_o <= exe_pc_i;
                end
                if (exe_pc_i == 32'h800010ac) begin
                    mem_pc_o <= exe_pc_i;
                end
                if (exe_pc_i == 32'h800008ec) begin
                    mem_pc_o <= exe_pc_i;
                end
                if (exe_pc_i == 32'h80000204) begin
                    mem_pc_o <= exe_pc_i;
                end
                mem_pc_o         <= exe_pc_i;
                mem_instr_o      <= exe_instr_i;
                mem_mem_en_o     <= exe_mem_en_i;
                mem_mem_wen_o    <= exe_mem_wen_i;
                mem_alu_result_o <= alu_result_i;
                mem_rf_waddr_o   <= exe_rf_waddr_i;
                mem_rf_wen_o     <= exe_rf_wen_i;

                case (instr_type)
                    BEQ: begin
                        if ((exe_forward_alu_a_mux_i == 1'b1 && exe_forward_alu_b_mux_i == 1'b0 && exe_forward_alu_a_i == exe_rf_rdata_b_i)
                            || (exe_forward_alu_a_mux_i == 1'b0 && exe_forward_alu_b_mux_i == 1'b1 && exe_forward_alu_b_i == exe_rf_rdata_a_i)
                            || (exe_forward_alu_a_mux_i == 1'b1 && exe_forward_alu_b_mux_i == 1'b1 && exe_forward_alu_a_i == exe_forward_alu_b_i)
                            || (exe_forward_alu_a_mux_i == 1'b0 && exe_forward_alu_b_mux_i == 1'b0 && exe_rf_rdata_a_i == exe_rf_rdata_b_i)) begin
                            
                            if (exe_branch_taken_i) begin
                                if_pc_mux_o <= 1'b0;
                                if_pc_o <= alu_result_i;

                                exe_branch_mispred_o <= 1'b0;
                            end else begin
                                if_pc_mux_o <= 1'b1;
                                if_pc_o <= alu_result_i;

                                exe_branch_mispred_o <= 1'b1;
                            end
                        end 
//                        else if (exe_rf_rdata_a_i == exe_rf_rdata_b_i) begin
//                            if_pc_mux_o <= 1'b1;
//                            if_pc_o <= alu_result_i;
//                            //if_pc_o <= exe_pc_i + (exe_imm_i << 1) | SignExt;
//                        end 
                        else begin

                            if (exe_branch_taken_i) begin
                                if_pc_mux_o <= 1'b1;
                                if_pc_o <= exe_pc_i + 32'd4;

                                exe_branch_mispred_o <= 1'b1;
                            end else begin
                                if_pc_mux_o <= 1'b0;
                                if_pc_o <= exe_pc_i + 32'd4;

                                exe_branch_mispred_o <= 1'b0;
                            end
                            
                        end

                        exe_branch_en_o <= 1'b1;
                    end
                    BNE: begin
                        if ((exe_forward_alu_a_mux_i == 1'b1 && exe_forward_alu_b_mux_i == 1'b0 && exe_forward_alu_a_i != exe_rf_rdata_b_i)
                            || (exe_forward_alu_a_mux_i == 1'b0 && exe_forward_alu_b_mux_i == 1'b1 && exe_forward_alu_b_i != exe_rf_rdata_a_i)
                            || (exe_forward_alu_a_mux_i == 1'b1 && exe_forward_alu_b_mux_i == 1'b1 && exe_forward_alu_a_i != exe_forward_alu_b_i)
                            || (exe_forward_alu_a_mux_i == 1'b0 && exe_forward_alu_b_mux_i == 1'b0 && exe_rf_rdata_a_i != exe_rf_rdata_b_i) && alu_result_i != 0) begin
                            
                            if (exe_branch_taken_i) begin
                                if_pc_mux_o <= 1'b0;
                                if_pc_o <= alu_result_i;

                                exe_branch_mispred_o <= 1'b0;
                            end else begin
                                if_pc_mux_o <= 1'b1;
                                if_pc_o <= alu_result_i;

                                exe_branch_mispred_o <= 1'b1;
                            end

                        end 
//                        else if (exe_rf_rdata_a_i != exe_rf_rdata_b_i && alu_result_i != 0) begin
//                            if_pc_mux_o <= 1'b1;
//                            if_pc_o <= alu_result_i; 
//                        end 
                        else begin
                            
                            if (exe_branch_taken_i) begin
                                if_pc_mux_o <= 1'b1;
                                if_pc_o <= exe_pc_i + 32'd4;

                                exe_branch_mispred_o <= 1'b1;
                            end else begin
                                if_pc_mux_o <= 1'b0;
                                if_pc_o <= exe_pc_i + 32'd4;

                                exe_branch_mispred_o <= 1'b0;
                            end

                        end

                        exe_branch_en_o <= 1'b1;
                    end
                    SB: begin
                        if_pc_mux_o <= 1'b0;
                        if_pc_o <= exe_pc_i + 32'h00000004;
                        // write rs2[7:0] into ram
                        mem_mem_wdata_o <= exe_rf_rdata_b_i[7:0] << ((alu_result_i % 4) * 8); 

                        exe_branch_en_o <= 1'b0;
                        exe_branch_mispred_o <= 1'b0;
                    end
                    SW: begin
                        if_pc_mux_o <= 1'b0;
                        if_pc_o <= exe_pc_i + 32'h00000004;
                        // write rs2 into ram   
                        mem_mem_wdata_o <= exe_rf_rdata_b_i << ((alu_result_i % 4) * 8);

                        exe_branch_en_o <= 1'b0;
                        exe_branch_mispred_o <= 1'b0;
                    end
                    LUI: begin
                        if_pc_mux_o <= 1'b0;
                        if_pc_o <= exe_pc_i + 32'h00000004;
                        mem_alu_result_o <= exe_imm_i;

                        exe_branch_en_o <= 1'b0;
                        exe_branch_mispred_o <= 1'b0;
                    end
                    JAL: begin
                        
                        if (exe_branch_taken_i) begin
                            if_pc_mux_o <= 1'b0;
                            // pc += offset
                            if_pc_o <= alu_result_i;

                            exe_branch_mispred_o <= 1'b0;
                        end else begin
                            if_pc_mux_o <= 1'b1;
                            // pc += offset
                            if_pc_o <= alu_result_i;

                            exe_branch_mispred_o <= 1'b1;
                        end
                        
                        mem_alu_result_o <= exe_pc_i + 32'd4;

                        exe_branch_en_o <= 1'b1;
                    end
                    JALR: begin

                        if (exe_branch_taken_i) begin
                            if_pc_mux_o <= 1'b0;
                            // pc = rs1 + offset
                            if (exe_forward_alu_a_mux_i)
                                if_pc_o <= (exe_imm_i + exe_forward_alu_a_i) & ~1;
                            else
                                if_pc_o <= (exe_imm_i + exe_rf_rdata_a_i) & ~1;
                            
                            exe_branch_mispred_o <= 1'b1;
                        end else begin
                            if_pc_mux_o <= 1'b1;
                            // pc = rs1 + offset
                            if (exe_forward_alu_a_mux_i)
                                if_pc_o <= (exe_imm_i + exe_forward_alu_a_i) & ~1;
                            else
                                if_pc_o <= (exe_imm_i + exe_rf_rdata_a_i) & ~1;
                            
                            exe_branch_mispred_o <= 1'b1;
                        end

                        mem_alu_result_o <= exe_pc_i + 32'd4;

                        exe_branch_en_o <= 1'b1;
                        
                    end
                    NOP: begin
                        if_pc_mux_o <= 1'b0;
//                        if_pc_o <= if_pc_o;
                        if_pc_o <= 32'b0;
                        mem_mem_en_o <= 1'b0;
                        mem_mem_wen_o <= 1'b0;
                        mem_rf_wen_o <= 1'b0;

                        exe_branch_en_o <= 1'b0;
                        exe_branch_mispred_o <= 1'b0;
                    end
                    CSRRC: begin
                        if_pc_mux_o <= 1'b0;
                        if_pc_o <= exe_pc_i + 32'h00000004;
                        mem_alu_result_o <= exe_imm_i;
                        
                        exe_branch_en_o <= 1'b0;
                        exe_branch_mispred_o <= 1'b0;
                    end
                    CSRRS: begin
                        if_pc_mux_o <= 1'b0;
                        if_pc_o <= exe_pc_i + 32'h00000004;
                        mem_alu_result_o <= exe_imm_i;
                        
                        exe_branch_en_o <= 1'b0;
                        exe_branch_mispred_o <= 1'b0;
                    end
                    CSRRW: begin
                        if_pc_mux_o <= 1'b0;
                        if_pc_o <= exe_pc_i + 32'h00000004;
                        mem_alu_result_o <= exe_imm_i;

                        exe_branch_en_o <= 1'b0;
                        exe_branch_mispred_o <= 1'b0;
                    end
                    MRET: begin
                        if_pc_mux_o <= 1'b0;
                        if_pc_o <= 32'h0;
                        
                        exe_branch_en_o <= 1'b0;
                        exe_branch_mispred_o <= 1'b0;   
                    end
                    ECALL: begin
                        if_pc_mux_o <= 1'b0;
                        if_pc_o <= 32'h0;
                        
                        exe_branch_en_o <= 1'b0;
                        exe_branch_mispred_o <= 1'b0;   
                    end
                    EBREAK: begin
                        if_pc_mux_o <= 1'b0;
                        if_pc_o <= 32'h0;
                        
                        exe_branch_en_o <= 1'b0;
                        exe_branch_mispred_o <= 1'b0;   
                    end
                    // add(i),and(i),or(i),auipc,lb,lw,xor,slli,srli,andn,sbset,minu,sltu,ebreak,ecall,mret
                    CRAS16: begin
                        mem_alu_result_o <= alu_result_i;
                        if_pc_mux_o <= 1'b0;
                        if_pc_o <= exe_pc_i + 32'd4;

                        exe_branch_en_o <= 1'b0;
                        exe_branch_mispred_o <= 1'b0;
                    end
                    default: begin
                        if_pc_mux_o <= 1'b0;
                        if_pc_o <= exe_pc_i + 32'd4;

                        exe_branch_en_o <= 1'b0;
                        exe_branch_mispred_o <= 1'b0;       
                    end
                endcase
            end else if (flush_i) begin
                if_pc_o <= 32'b0;
                if_pc_mux_o <= 1'b0;

                mem_pc_o <= 32'b0;
                mem_instr_o <= 32'b0;
                mem_mem_wdata_o <= 32'b0;
                mem_alu_result_o <= 32'b0;
                mem_mem_en_o <= 1'b0;
                mem_mem_wen_o <= 1'b0;
                mem_rf_waddr_o <= 5'b0;
                mem_rf_wen_o <= 1'b0;

                exe_branch_en_o <= 1'b0;
                exe_branch_mispred_o <= 1'b0;
            end else begin
                if_pc_o <= if_pc_o;
                if_pc_mux_o <= if_pc_mux_o;

                mem_pc_o <= mem_pc_o;
                mem_instr_o <= mem_instr_o;
                mem_mem_wdata_o <= mem_mem_wdata_o;
                mem_alu_result_o <= mem_alu_result_o;
                mem_mem_en_o <= mem_mem_en_o;
                mem_mem_wen_o <= mem_mem_wen_o;
                mem_rf_waddr_o <= mem_rf_waddr_o;
                mem_rf_wen_o <= mem_rf_wen_o;

                exe_branch_en_o <= 1'b0;
                exe_branch_mispred_o <= 1'b0;
            end
            mem_exc_en_o    <= exe_exc_en_i;
            mem_exc_pc_o    <= exe_exc_pc_i;
            mem_exc_code_o  <= exe_exc_code_i;
        end
    end
endmodule