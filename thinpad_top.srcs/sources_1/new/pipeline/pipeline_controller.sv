module pipeline_controller(
    input wire clk_i,
    input wire rst_i,

    // signals from ID stage
    input wire [ 4:0] id_rf_raddr_a_i,
    input wire [ 4:0] id_rf_raddr_b_i,

    // signals from ID/EXE pipeline registers
    input wire [ 4:0] exe_rf_raddr_a_i,
    input wire [ 4:0] exe_rf_raddr_b_i,
    input wire        exe_mem_en_i,
    input wire        exe_mem_wen_i,
    input wire [ 4:0] exe_rf_waddr_i,

    // signals from EXE/MEM pipeline registers
    input wire [31:0] mem_rf_wdata_i,
    input wire [ 4:0] mem_rf_waddr_i,
    input wire        mem_rf_wen_i,
    input wire        mem_mem_en_i,
    input wire        mem_mem_wen_i,

    // signals from MEM/WB pipeline registers
    input wire [31:0] wb_rf_wdata_i,
    input wire [ 4:0] wb_rf_waddr_i,
    input wire        wb_rf_wen_i,

    // wishbone busy signals
    input wire if_busy_i,
    input wire mem_busy_i,

    // stall and flush signals
    output reg if_stall_o,
    output reg id_stall_o,
    output reg exe_stall_o,
    output reg mem_stall_o,
    output reg wb_stall_o,
    output reg if_flush_o,
    output reg id_flush_o,
    output reg exe_flush_o,
    output reg mem_flush_o,
    output reg wb_flush_o
);

    logic m_busy;  // if memory busy (IF/MEM)

    assign m_busy = if_busy_i | mem_busy_i;


    /* ========== memory hazard ========== */
    always_comb begin
        if_stall_o = 1'b0;
        id_stall_o = 1'b0;
        exe_stall_o = 1'b0;
        mem_stall_o = 1'b0;
        wb_stall_o = 1'b0;
        if_flush_o = 1'b0;
        id_flush_o = 1'b0;
        exe_flush_o = 1'b0;
        mem_flush_o = 1'b0;
        wb_flush_o = 1'b0;

        if (mem_busy) begin  // stall if memory is busy
            if_stall_o = 1'b1;
            id_stall_o = 1'b1;
            exe_stall_o = 1'b1;
            mem_stall_o = 1'b1;
            wb_stall_o = 1'b1;
        end else if (exe_if_pc_mux_i == 1'b1) begin  // branch and jump, flush ID & EXE
            id_flush_o = 1'b1;
            exe_flush_o = 1'b1;
        end
    end
  

endmodule