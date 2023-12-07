module csr_time (
    input wire clk_i,
    input wire rst_i,

    input wire wb_cyc_i,
    input wire wb_stb_i,
    input wire wb_ack_i,

    input wire [31:0] wb_adr_i,
    input wire [31:0] wb_dat_i,
    output reg [31:0] wb_dat_o,
    input wire        wb_we_i,
    input wire [ 3:0] wb_sel_i,

    output reg timer_o
);
    
endmodule