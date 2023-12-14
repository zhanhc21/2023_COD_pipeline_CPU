module WB_Stage (
    input wire clk_i,
    input wire rst_i,

    // signals from MEM stage
    input wire [31:0] wb_pc_i,
    input wire [31:0] wb_instr_i,
    input wire [31:0] wb_rf_wdata_i,
    input wire [4:0]  wb_rf_waddr_i,
    input wire        wb_rf_wen_i,

    // stall signal and flush signal
    input wire stall_i,
    input wire flush_i,

    // signals to regfile
    output reg [31:0] rf_wdata_o,
    output reg [ 4:0] rf_waddr_o,
    output reg        rf_wen_o,

    // signals to controller
    output reg [31:0] rf_wdata_controller_o,
    output reg [ 4:0] rf_waddr_controller_o,
    output reg        rf_wen_controller_o
);
    // TODO: stall signal and flush signal
    always_comb begin
        rf_wen_o = wb_rf_wen_i;
        rf_waddr_o = wb_rf_waddr_i;
        rf_wdata_o = wb_rf_wdata_i;
    end
    
    reg [31:0] rf_wdata_o_reg;
    reg [4:0] rf_waddr_o_reg;
    reg        rf_wen_o_reg;
    always_ff @ (posedge clk_i) begin
        if (wb_rf_wen_i) begin
            rf_wdata_controller_o <= wb_rf_wdata_i;
            rf_waddr_controller_o <= wb_rf_waddr_i;
            rf_wen_controller_o <= wb_rf_wen_i;
        end else begin
            rf_wen_controller_o <= 1'b0;
        end
    end
endmodule