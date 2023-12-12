module ICache #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter CACHE_SIZE = 64
) (
    input wire clk_i,
    input wire rst_i,
    // fence_i
    input wire fence_i_i,

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
    cache_table_t [63:0] cache_regs;

    cache_table_t record;
    reg cache_ack_reg;
    reg [DATA_WIDTH-1:0] cache_data_reg;

    reg cache_hit;
    assign cache_hit = cache_regs[cache_addr_i[7:2]].valid == 1 && cache_regs[cache_addr_i[7:2]].tag == cache_addr_i[31:8];

    logic [DATA_WIDTH-1:0] hit_data;
    always_comb begin
        if (cache_hit) begin
            hit_data = cache_regs[cache_addr_i[7:2]].data;
        end else if (wb_ack_i && wb_addr_o == cache_addr_i) begin
            hit_data = wb_data_i;
        end else begin
            hit_data = 32'h0;
        end
    end
    
    always_comb begin
        cache_ack_o = 1'b0; 
        cache_data_o = 32'h0;

        if (~cache_en_i) begin
            cache_ack_o = 1'b0;
        end else begin
            cache_ack_o = cache_hit | (wb_ack_i & (wb_addr_o == cache_addr_i));
            cache_data_o = hit_data;
        end
    end

    typedef enum logic [2:0] {
        STATE_IDLE = 0,
        STATE_READ = 1
    } state_t;
    state_t state;

    integer i;
    // to wishbone
    always_ff @ (posedge clk_i) begin
        if (rst_i) begin
            cache_ack_reg <= 1'b0;
            cache_data_reg <= 32'h0;
            state <= STATE_IDLE;
            for (i=0; i<64; i++)
                cache_regs[i] <= 55'd0;
        end else if (fence_i_i == 1'b1) begin
            for (i=0; i<64; i++)
                cache_regs[i] <= 55'd0;
        end else begin
            if (state == STATE_IDLE) begin
                if (cache_en_i && !cache_hit) begin
                    wb_cyc_o <= 1'b1;
                    wb_stb_o <= 1'b1;
                    wb_addr_o <= cache_addr_i;
                    wb_sel_o <= 4'b1111;
                    wb_we_o <= 1'b0;
                    state <= STATE_READ;
                end
            end else begin
                if (wb_ack_i) begin
                    if ((
                        (wb_data_i[6:0] == 7'b0110011 && wb_data_i[14:12] == 3'b100) // R xor
                      || (wb_data_i[6:0] == 7'b0010011 && (wb_data_i[14:12] == 3'b000 || wb_data_i[14:12] == 3'b110)) // addi 
                      || wb_data_i[6:0] == 7'b1100011 || wb_data_i[6:0] == 7'b1101111 || wb_data_i[6:0] == 7'b1100111 // beq
                    ))
                    begin
                        cache_regs[cache_addr_i[7:2]].valid <= 1'b1;
                        cache_regs[cache_addr_i[7:2]].tag <= cache_addr_i[31:8];
                        cache_regs[cache_addr_i[7:2]].data <= wb_data_i;
                    end
                    wb_cyc_o <= 1'b0;
                    wb_stb_o <= 1'b0;
                    state <= STATE_IDLE;
                end
            end
        end
    end
endmodule
