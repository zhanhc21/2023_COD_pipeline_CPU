module MEM_Stage (
    input wire clk_i,
    input wire rst_i,

    // wishbone signals
    input  wire        wb_ack_i,
    input  wire [31:0] wb_data_i,

    output reg         wb_cyc_o,
    output reg         wb_stb_o,
    output reg  [31:0] wb_addr_o,
    output reg  [31:0] wb_data_o,
    output reg  [ 3:0] wb_sel_o,
    output reg         wb_we_o,

    // signals from EXE stage
    input wire [31:0] mem_pc_i,
    input wire [31:0] mem_instr_i,
    input wire [31:0] mem_mem_wdata_i,
    input wire        mem_mem_en_i,
    input wire        mem_mem_wen_i,     // if write DM (0: read DM, 1: write DM)
    input wire [31:0] mem_alu_result_i,
    input wire [4:0] mem_rf_waddr_i,
    input wire        mem_rf_wen_i,

    // stall signal and flush signal
    output reg mem_finish_o,
    output reg busy_o,
    input wire stall_i,
    input wire flush_i,

    // signals to WB(write back) stage
    output reg [31:0] wb_pc_o,
    output reg [31:0] wb_instr_o,
    output reg [31:0] wb_rf_wdata_o, // WB data
    output reg [4:0] wb_rf_waddr_o, // WB adddr
    output reg        wb_rf_wen_o,    // if write back (WB)

    // dcache signals
    output reg [31:0] mem_wb_addr_o,
    output reg [31:0] mem_wb_data_o,
    output reg [ 3:0] mem_wb_sel_o,
    output reg        mem_is_store_o,  // 1: store
    output reg        mem_is_load_o,  // 1: load
    output reg        mem_data_is_from_load_o,  // 1: load first time, means data is clean

    input wire [31:0] mem_write_back_addr_i,
    input wire [31:0] mem_write_back_data_i,
    input wire [ 3:0] mem_write_back_sel_i,
    input wire        mem_write_back_en_i,

    input wire        mem_hit_i,
    input wire [31:0] mem_load_data_i
);

    logic [6:0]  opcode;
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
        ANDN  = 19,
        SBSET = 20,
        MINU  = 21,
        NOP   = 22
    } op_type;
    op_type instr_type, past_instr_type;
    logic [31:0] past_mem_instr_i;
    logic mem_finish;
    assign mem_finish_o = mem_finish;
    always_ff @ (posedge clk_i) begin
        if (rst_i)
            mem_finish <= 1'b1;
        else begin
            past_mem_instr_i <= mem_instr_i;
            if (!mem_mem_en_i | past_mem_instr_i != mem_instr_i)
                mem_finish <= 1'b0;
            if (wb_ack_i)
                mem_finish <= 1'b1;
        end
    end

    // inst decode
    always_comb begin
        opcode = mem_instr_i[6:0];
        case (opcode)
            7'b0110011: begin
                if (mem_instr_i[14:12] == 3'b000)
                    instr_type = ADD;
                else if (mem_instr_i[14:12] == 3'b111) begin
                    if (mem_instr_i[31:25] == 7'b0000000)
                        instr_type = AND;
                    else // (mem_instr_i[31:25] == 7'b0100000)
                        instr_type = ANDN;
                end 
                else if (mem_instr_i[14:12] == 3'b110) begin
                    if (mem_instr_i[31:25] == 7'b0000101)
                        instr_type = MINU;
                    else
                        instr_type = OR;
                end
                else if (mem_instr_i[14:12] == 3'b100)
                    instr_type = XOR;
                else // (mem_instr_i[14:12] == 3'b001)
                    instr_type = SBSET;
            end
            7'b0010011: begin
                if (mem_instr_i[14:12] == 3'b000)
                    instr_type = ADDI;
                else if (mem_instr_i[14:12] == 3'b111)
                    instr_type = ANDI;
                else if (mem_instr_i[14:12] == 3'b110)
                    instr_type = ORI;
                else if (mem_instr_i[14:12] == 3'b001)
                    instr_type = SLLI;
                else // (mem_instr_i[14:12] == 3'b101)
                    instr_type = SRLI;
            end
            7'b0010111: instr_type = AUIPC;
            7'b1100011: begin
                if (mem_instr_i[14:12] == 3'b000)
                    instr_type = BEQ;
                else // (mem_instr_i[14:12] == 3'b001)
                    instr_type = BNE;
            end
            7'b1101111: instr_type = JAL;
            7'b1100111: instr_type = JALR;
            7'b0000011: begin
                if (mem_instr_i[14:12] == 3'b000)
                    instr_type = LB;
                else // (mem_instr_i[14:12] == 3'b010)
                    instr_type = LW; 
            end
            7'b0110111: instr_type = LUI;
            7'b0100011: begin
                if (mem_instr_i[14:12] == 3'b000)
                    instr_type = SB;
                else // (mem_instr_i[14:12] == 3'b010)
                    instr_type = SW; 
            end
            default: instr_type = NOP;
        endcase
    end

    always_ff @ (posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            wb_cyc_o    <= 1'b0;
            wb_stb_o    <= 1'b0;
            wb_we_o     <= 1'b0;
            wb_sel_o    <= 4'b0;
            wb_rf_wen_o <= 1'b0;
            wb_pc_o <= 32'h0;
            wb_instr_o <= 32'h0;
            wb_rf_waddr_o <= 5'b0;
            wb_rf_wdata_o <= 32'h0;
            wb_rf_wen_o <= 1'b0;
            wb_addr_o <= 32'h0;
            wb_data_o <= 32'h0;
            busy_o      <= 1'b0;
        end else begin
            if (mem_mem_en_i) begin
                wb_cyc_o  <= 1'b1;
                wb_stb_o  <= 1'b1;
                busy_o    <= 1'b1;
                wb_addr_o <= mem_alu_result_i;
                if (mem_mem_wen_i) begin
                    // S type: write ram
                    wb_we_o   <= 1'b1;
                    wb_data_o <= mem_mem_wdata_i;
                    if (instr_type == SB)
                        case (mem_alu_result_i[1:0])
                            2'b00: wb_sel_o <= 4'b0001;
                            2'b01: wb_sel_o <= 4'b0010;
                            2'b10: wb_sel_o <= 4'b0100;
                            2'b11: wb_sel_o <= 4'b1000;
                        endcase
                    else
                        wb_sel_o <= 4'b1111;
                    if (wb_ack_i) begin
                        wb_cyc_o  <= 1'b0;
                        wb_stb_o  <= 1'b0;
                        wb_we_o   <= 1'b0;
                        busy_o    <= 1'b0;
                        wb_pc_o <= mem_pc_i;
                        wb_instr_o <= mem_instr_i;
                        wb_rf_waddr_o <= mem_rf_waddr_i;
                        wb_rf_wen_o <= mem_rf_wen_i;
                    end
                end else begin
                    // L type: read ram
                    wb_we_o   <= 1'b0;
                    wb_data_o <= 32'b0;
                    wb_sel_o <= 4'b1111;
                    // write back to regfile
                    if (wb_ack_i && wb_addr_o != 32'h0) begin
                        wb_cyc_o  <= 1'b0;
                        wb_stb_o  <= 1'b0;
                        wb_we_o   <= 1'b0;
                        busy_o    <= 1'b0;
                        wb_pc_o <= mem_pc_i;
                        wb_instr_o <= mem_instr_i;
                        wb_rf_waddr_o <= mem_rf_waddr_i;
                        wb_rf_wen_o <= mem_rf_wen_i;
                        if (instr_type == LW)
                            wb_rf_wdata_o <= wb_data_i;
                        else case (mem_alu_result_i[1:0])
                            2'b00: wb_rf_wdata_o <= {{25{wb_data_i[7]}}, wb_data_i[6: 0]};
                            2'b01: wb_rf_wdata_o <= {{25{wb_data_i[15]}}, wb_data_i[14: 8]};
                            2'b10: wb_rf_wdata_o <= {{25{wb_data_i[23]}}, wb_data_i[22:16]};
                            2'b11: wb_rf_wdata_o <= {{25{wb_data_i[31]}}, wb_data_i[30:24]};
                        endcase
                        wb_pc_o <= mem_pc_i;
                        wb_instr_o <= mem_instr_i;
                        wb_rf_waddr_o <= mem_rf_waddr_i;
                        wb_rf_wen_o <= mem_rf_wen_i;
//                        wb_rf_wdata_o <= wb_data_i >> ((mem_alu_result_i % 4) * 8);
                    end
                end
                // wirte or read ram finish
                if (mem_finish) begin
                    wb_cyc_o  <= 1'b0;
                    wb_stb_o  <= 1'b0;
                    wb_we_o   <= 1'b0;
                    busy_o    <= 1'b0;
                    wb_data_o <= 32'b0;
                    wb_addr_o <= 32'b0;
                    wb_sel_o  <= 4'b0;
                end
            end else begin 
                // no need for ram
                wb_cyc_o  <= 1'b0;
                wb_stb_o  <= 1'b0;
                wb_we_o   <= 1'b0;
                wb_addr_o <= 32'b0;
                wb_data_o <= 32'b0;
                wb_sel_o  <= 4'b0;
                busy_o    <= 1'b0;
                // add, lui  e.g.
                wb_rf_wdata_o <= mem_alu_result_i;
                wb_pc_o <= mem_pc_i;
                wb_instr_o <= mem_instr_i;
                wb_rf_waddr_o <= mem_rf_waddr_i;
                wb_rf_wen_o <= mem_rf_wen_i;
            end
        end
    end
endmodule