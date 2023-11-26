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

    // stall signal and flush signal
    input wire stall_i,
    input wire flush_i,

    output reg [31:0] if_pc_o,
    output reg        if_pc_mux_o,        // 0: pc+4, 1: exe_pc

    // signals to MEM stage
    output reg  [31:0] mem_pc_o,
    output reg  [31:0] mem_instr_o,
    output reg  [31:0] mem_mem_wdata_o,   // DM wdata
    output reg  [31:0] mem_alu_result_o,  // DM waddr
    output reg         mem_mem_en_o,      // if use DM
    output reg         mem_mem_wen_o,     // if write DM (0: read DM, 1: write DM)
    output reg  [ 4:0] mem_rf_waddr_o,    // rf addr
    output reg         mem_rf_wen_o,       // if write back (rf)

    // signals to ALU
    input  wire [31:0] alu_result_i,
    output reg  [31:0] alu_operand_a_o,
    output reg  [31:0] alu_operand_b_o,
    output reg  [ 3:0] alu_op_o
); 

    logic [6:0]  opcode;
    logic [31:0] SignExt;
    typedef enum logic [4:0] {
        ADD   = 0,
        ADDI  = 1,
        AND   = 2,
        ANDI  = 3,
        AUIPC = 4,
        BEQ   = 5,
        BNE   = 6,
        JAL   = 7,
        JALR  = 8,
        LB    = 9,
        LUI   = 10,
        LW    = 11,
        OR    = 12,
        ORI   = 13,
        SB    = 14,
        SLLI  = 15,
        SRLI  = 16,
        SW    = 17,
        XOR   = 18,
        NOP   = 19
    } op_type;
    op_type instr_type;

    // inst decode
    always_comb begin
        opcode = exe_instr_i[6:0];
        SignExt = {{20{exe_imm_i[10]}}, {12{1'b0}}};
        case (opcode)
            7'b0110011: begin
                if (exe_instr_i[14:12] == 3'b000)
                    instr_type = ADD;
                else if (exe_instr_i[14:12] == 3'b111)
                    instr_type = AND;
                else if (exe_instr_i[14:12] == 3'b110)
                    instr_type = OR;
                else // (exe_instr_i[14:12] == 3'b100)
                    instr_type = XOR;
            end
            7'b0010011: begin
                if (exe_instr_i[14:12] == 3'b000)
                    instr_type = ADDI;
                else if (exe_instr_i[14:12] == 3'b111)
                    instr_type = ANDI;
                else if (exe_instr_i[14:12] == 3'b110)
                    instr_type = ORI;
                else if (exe_instr_i[14:12] == 3'b001)
                    instr_type = SLLI;
                else // (exe_instr_i[14:12] == 3'b101)
                    instr_type = SRLI;
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
            default: instr_type = NOP;
        endcase
    end

    always_comb begin
        if (stall_i == 1'b0) begin
            alu_op_o = exe_alu_op_i;
            if (exe_alu_a_mux_i == 1'b0)
                alu_operand_a_o = exe_rf_rdata_a_i;
            else
                alu_operand_a_o = exe_pc_i;
            if (exe_alu_b_mux_i == 1'b0)
                alu_operand_b_o = exe_imm_i;
            else 
                alu_operand_b_o = exe_rf_rdata_b_i;
        end else begin
            alu_op_o = 4'd1;
            alu_operand_a_o = 32'h0;
            alu_operand_b_o = 32'h0;
        end
    end

    always_ff @ (posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            if_pc_mux_o <= 1'b0;
            if_pc_o <= exe_pc_i;
            mem_mem_en_o <= 1'b0;
            mem_mem_wen_o <= 1'b0;
            mem_rf_wen_o <= 1'b0;
        end else begin
            mem_pc_o         <= exe_pc_i;
            mem_instr_o      <= exe_instr_i;
            mem_alu_result_o <= alu_result_i;
            mem_mem_en_o     <= exe_mem_en_i;
            mem_mem_wen_o    <= exe_mem_wen_i;
            mem_rf_waddr_o   <= exe_rf_waddr_i;
            mem_rf_wen_o     <= exe_rf_wen_i;

            case (instr_type)
                BEQ: begin 
                    if (alu_result_i == 0) begin
                        if_pc_mux_o <= 1'b1;
                        if_pc_o <= exe_pc_i + (exe_imm_i << 1) | SignExt;               
                    end else begin
                        if_pc_mux_o <= 1'b0;
                        if_pc_o <= exe_pc_i;
                    end
                end
                BNE: begin
                    if (alu_result_i != 0) begin
                        if_pc_mux_o <= 1'b1;
                        if_pc_o <= exe_pc_i + (exe_imm_i << 1) | SignExt;    
                    end else begin
                        if_pc_mux_o <= 1'b0;
                        if_pc_o <= exe_pc_i;        
                    end
                end
                LB: begin
                    if_pc_mux_o <= 1'b0;
                    if_pc_o <= exe_pc_i;               
                end
                SB: begin
                    if_pc_mux_o <= 1'b0;
                    if_pc_o <= exe_pc_i;
                    mem_mem_wdata_o <= exe_rf_rdata_b_i[7:0] << ((alu_result_i % 4) * 8); // write rs2[7:0] into ram
                end
                SW: begin
                    if_pc_mux_o <= 1'b0;
                    if_pc_o <= exe_pc_i;
                    mem_mem_wdata_o <= exe_rf_rdata_b_i << ((alu_result_i % 4) * 8); // write rs2 into ram   
                end
                LUI: begin
                    mem_alu_result_o <= exe_imm_i;
                end
                NOP: begin
                    if_pc_mux_o <= 1'b0;
                    if_pc_o <= exe_pc_i;
                    mem_mem_en_o <= 1'b0;
                    mem_mem_wen_o <= 1'b0;
                    mem_rf_wen_o <= 1'b0;
                end
                default: begin
                    if_pc_mux_o <= 1'b0;
                    if_pc_o <= exe_pc_i;                  
                end
            endcase
        end
    end
endmodule