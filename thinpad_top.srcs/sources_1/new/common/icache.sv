module ICache #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter CACHE_SIZE = 64
) (
    input wire clk_i,
    input wire rst_i,

    // signal from CPU
    input wire cache_en_i,
    input wire [ADDR_WIDTH-1:0] cache_addr_i,

    // signal to CPU
    output reg cache_ack_o,
    output reg [DATA_WIDTH-1:0] cache_data_o,

    // signal from sram (wishbone)
    input wire wb_ack_i,
    input wire [DATA_WIDTH-1:0] wb_data_i,

    // signal to sram (wishbone)
    output reg wb_cyc_o, 
    output reg wb_stb_o, 
    output reg [ADDR_WIDTH-1:0] wb_addr_o,
    output reg [DATA_WIDTH/8-1:0] wb_sel_o,
    output reg wb_we_o
);
    typedef struct packed{
        logic valid;
        logic [23:0] tag;
        logic [31:0] data;
    } cache_table_t;
    
    // Buffer index: 6 bits(2^6=64) ||valid: 1 bit| tag: 24| data: 32|| 
    cache_table_t [56:0] cache_regs;

    cache_table_t record;
    reg cache_ack_reg;
    reg [DATA_WIDTH-1:0] cache_data_reg;
//    always_comb begin
////        record = cache_regs[cache_addr_i[7:2]];
//        if (cache_en_i) begin
//            if (cache_regs[cache_addr_i[7:2]].valid == 1 && cache_regs[cache_addr_i[7:2]].tag == cache_addr_i[31:8]) begin
//                cache_ack_o = 1'b1;
//                cache_data_o = cache_regs[cache_addr_i[7:2]].data;
//            end else if (cache_ack_reg) begin
//                cache_ack_o = 1'b1;
//                cache_data_o = cache_data_reg;
//            end else begin
//                cache_ack_o = 1'b0;
//                cache_data_o = 32'h00000000;
//            end
//        end else begin
//            cache_ack_o = 1'b0;
//            cache_data_o = 32'h00000000;
//        end
//    end
    
    integer i;
    // to wishbone
    always_ff @ (posedge clk_i) begin
        if (rst_i) begin
            wb_cyc_o <= 1'b0;
            wb_stb_o <= 1'b0;
            wb_addr_o <= 32'b0;
            wb_sel_o <= 4'b0;
            wb_we_o <= 1'b0;
            cache_ack_reg <= 1'b0;
            cache_data_reg <= 32'h0;
            for (i=0; i<64; i++)
                cache_regs[i] <= 57'd0;
        end else begin
            if (cache_ack_o == 1'b1) begin
                cache_ack_o <= 1'b0;
            end else 
            if (cache_en_i && cache_addr_i[31:8]!=cache_regs[cache_addr_i[7:2]].tag && cache_addr_i != 32'h0) begin
                wb_cyc_o <= 1'b1;
                wb_stb_o <= 1'b1;
                wb_we_o <= 1'b0;
                wb_sel_o <= 4'b1111;
                wb_addr_o <= cache_addr_i;
                if (wb_ack_i) begin
                    wb_cyc_o <= 1'b0;
                    wb_stb_o <= 1'b0;
                    wb_we_o <= 1'b0;
                    wb_sel_o <= 4'b0000;
                    if (
//                    wb_data_i[6:0] == 7'b0110111 || wb_data_i[6:0] == 7'b0010111 // lui auipc 
                        wb_data_i[6:0] == 7'b0010011 && wb_data_i[14:12] == 3'b000
                    )
                    begin
                        cache_regs[cache_addr_i[7:2]].valid <= 1'b1;
                        cache_regs[cache_addr_i[7:2]].tag <= cache_addr_i[31:8];
                        cache_regs[cache_addr_i[7:2]].data <= wb_data_i;
                    end
                    cache_ack_o <= 1'b1;
                    cache_data_o <= wb_data_i;
                end
            end else if (cache_en_i && cache_addr_i[31:8]==cache_regs[cache_addr_i[7:2]].tag ) begin
                cache_ack_o <= 1'b1;
                cache_data_o <= cache_regs[cache_addr_i[7:2]].data;
            end else begin
                cache_ack_o <= 1'b0;
                cache_data_o <= 32'h0;
                wb_cyc_o <= 1'b0;
                wb_stb_o <= 1'b0;
                wb_addr_o <= 32'b0;
                wb_sel_o <= 4'b0;
                wb_we_o <= 1'b0;
            end
        end
    end
endmodule