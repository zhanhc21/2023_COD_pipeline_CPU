module ICache #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter CACHE_SIZE = 64
) (
    input wire clk,
    input wire rst,

    // signal from MMU
    input wire cache_en_i,
    input wire [ADDR_WIDTH-1:0] cache_addr_i,
    input wire [DATA_WIDTH-1:0] cache_data_i,

    // signal to MMU
    output logic cache_ack_o,
    output logic [DATA_WIDTH-1:0] cache_data_o,

    // signal from sram (wishbone)
    input wire wb_ack_i,
    input wire [DATA_WIDTH-1:0] wb_dat_i,

    // signal to sram (wishbone)
    output wire wb_cyc_o, 
    output logic wb_stb_o, 
    output logic [ADDR_WIDTH-1:0] wb_adr_o,
    output logic [DATA_WIDTH-1:0] wb_dat_o,
    output logic [DATA_WIDTH/8-1:0] wb_sel_o,
    output logic wb_we_o
);

    // Buffer index: 6 bits(2^6=64)|valid: 1 bit| tag: 24| data: 32| 
    reg [56:0] cache_regs [0:CACHE_SIZE-1];

    reg [56:0] record;
    always_comb begin
        record = cache_regs[cache_addr_i[7:2]];
        if (cache_en) begin
            if (record[0] == 1 && record[24:1] == cache_addr_i[31:8]) begin
                cache_ack_o = 1'b1;
                cache_data_o = record[56:25];
            end else begin
                cache_ack = 1'b0;
                cache_data_o = 0x00000000;
            end
        end else begin
            cache_ack_o = 1'b0;
            cache_data_o = 0x00000000;
        end
    end

    // to wishbone
    always_ff @ (posedge clk_i) begin
        if (rst_i) begin
            wb_cyc_o <= 1'b0;
            wb_stb_o <= 1'b0;
            wb_addr_o <= 32'b0;
            wb_data_o <= 32'b0;
            wb_sel_o <= 4'b0;
            wb_we_o <= 1'b0;
        end else begin
            wb_cyc_o <= 1'b1;
            wb_stb_o <= 1'b1;
            wb_we_o <= 1'b0;
            wb_sel_o <= 4'b1111;
            if (wb_ack_i) begin
                wb_cyc_o <= 1'b0;
                wb_stb_o <= 1'b0;
                wb_we_o <= 1'b0;
                wb_sel_o <= 4'b0000;
                if (wb_data_i) begin
                    
                end
                end
            end
        end
    end
endmodule