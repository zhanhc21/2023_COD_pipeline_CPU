`timescale 1ns / 1ps
//
// WIDTH: bits in register hdata & vdata
// HSIZE: horizontal size of visible field 
// HFP: horizontal front of pulse
// HSP: horizontal stop of pulse
// HMAX: horizontal max size of value
// VSIZE: vertical size of visible field 
// VFP: vertical front of pulse
// VSP: vertical stop of pulse
// VMAX: vertical max size of value
// HSPP: horizontal synchro pulse polarity (0 - negative, 1 - positive)
// VSPP: vertical synchro pulse polarity (0 - negative, 1 - positive)
//
module vga_controller #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter WIDTH = 12,
    parameter HSIZE = 800,
    parameter HFP = 856,
    parameter HSP = 976,
    parameter HMAX = 1040,
    parameter VSIZE = 600,
    parameter VFP = 637,
    parameter VSP = 643,
    parameter VMAX = 666,
    parameter HSPP = 1,
    parameter VSPP = 1
) (
    input wire clk_i,
    input wire rst_i,

    // Wishbone slave interface
    input wire wb_cyc_i,
    input wire wb_stb_i,
    output logic wb_ack_o,
    input wire [ADDR_WIDTH-1:0] wb_addr_i,
    input wire [DATA_WIDTH-1:0] wb_data_i,
    input wire [DATA_WIDTH/8-1:0] wb_sel_i,
    input wire wb_we_i,

    // VGA output interface
    output wire [2:0] video_red_o,
    output wire [2:0] video_green_o,
    output wire [1:0] video_blue_o,
    output wire hsync_o,
    output wire vsync_o,
    output wire data_enable_o
);
    reg [14:0] hdata, vdata;
    reg [10:0] addr;
    reg [31:0] dout;
    reg [7:0] data;

    blk_mem u_bram (
        .clka(clk_i), 
        .ena(1'b1), 
        .wea(1'b0),
        .addra(addr),      // input wire [10:0] addra
        .dina(32'b0),        // input wire [31:0] dina
        .douta(dout),

        .clkb(clk_i),
        .enb(wb_we_i), 
        .web(wb_we_i),          
        .addrb(wb_addr_i[10:0]),      // input wire [10:0] addrb
        .dinb(wb_data_i),        // input wire [31:0] dinb
        .doutb()
    );

    // hdata
    always @(posedge clk_i) begin
        if (hdata == (HMAX - 1)) hdata <= 0;
        else hdata <= hdata + 1;
    end

    // vdata
    always @(posedge clk_i) begin
        if (hdata == (HMAX - 1)) begin
            if (vdata == (VMAX - 1)) vdata <= 0;
            else vdata <= vdata + 1;
        end
    end

    reg [31:0] wb_addr_reg;
    always @(posedge clk_i) begin
        if (wb_addr_i != wb_addr_reg && wb_addr_i != 0 && wb_cyc_i == 1'b1) begin
            wb_ack_o <= 1'b1;
            wb_addr_reg <= wb_addr_i;
        end else begin
            wb_ack_o <= 1'b0;
            wb_addr_reg <= wb_addr_i;
        end
    end

    always_comb begin
        addr = (hdata >> 3) + 15'd100 * (vdata >> 3);
        case (addr[1:0])
            2'b00: data = dout[7: 0];
            2'b01: data = dout[15: 8];
            2'b10: data = dout[23:16];
            2'b11: data = dout[31:24];
        endcase
    end


    // hsync & vsync & blank
    assign hsync_o = ((hdata >= HFP) && (hdata < HSP)) ? HSPP : !HSPP;
    assign vsync_o = ((vdata >= VFP) && (vdata < VSP)) ? VSPP : !VSPP;
    assign data_enable_o = ((hdata < HSIZE) & (vdata < VSIZE));
    assign video_red_o = data[2:0];
    assign video_green_o = data[5:3];
    assign video_blue_o = data[7:6];

endmodule