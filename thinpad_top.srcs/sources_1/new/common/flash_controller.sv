module flash_controller #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,

    parameter FLASH_ADDR_WIDTH = 23
) (
    input wire clk_i,
    input wire rst_i,

    // Wishbone slave interface
    input wire wb_cyc_i,
    input wire wb_stb_i,
    output reg wb_ack_o,
    input wire [ADDR_WIDTH-1:0] wb_addr_i,
    input wire [DATA_WIDTH-1:0] wb_data_i,
    output reg [DATA_WIDTH-1:0] wb_data_o,
    input wire [DATA_WIDTH/8-1:0] wb_sel_i,
    input wire wb_we_i,

    output wire [FLASH_ADDR_WIDTH:0] flash_addr_o,
    inout wire [15:0] flash_data,
    output wire flash_rp_n_o,  // 低有效
    output wire flash_vpen_o,
    output wire flash_ce_n_o,  // 低有效
    output wire flash_oe_n_o,  // 低有效
    output wire flash_we_n_o,  // 低有效
    output wire flash_byte_n_o  // 0: 8 bit, 1: 16 bit
);

    reg [15:0] flash_data_i_comb;
    reg [15:0] flash_data_o_comb;
    reg flash_data_t_comb;

    assign flash_data = flash_data_t_comb ? 16'bz : flash_data_o_comb;
    assign flash_data_i_comb = flash_data;
    assign flash_data_t_comb = 1'b1;  // always read

    reg [FLASH_ADDR_WIDTH:0] flash_addr_reg;
    reg flash_ce_n_o_reg;
    reg flash_oe_n_o_reg;

    reg [15:0] flash_data_lo_reg;
    reg [15:0] flash_data_hi_reg;
    reg [31:0] wb_data_o_reg;

    assign flash_addr_o = flash_addr_reg;
    assign flash_ce_n_o = flash_ce_n_o_reg;
    assign flash_oe_n_o = flash_oe_n_o_reg;

    always_comb begin
        wb_data_o_reg = {flash_data_hi_reg, flash_data_lo_reg};
        if (wb_cyc_i && wb_stb_i && !wb_we_i) begin
            if (!rst_i) begin
                flash_ce_n_o_reg = 1'b0;
                flash_oe_n_o_reg = 1'b0;
            end else begin
                flash_ce_n_o_reg = 1'b1;
                flash_oe_n_o_reg = 1'b1;
            end
        end else begin
            flash_ce_n_o_reg = 1'b1;
            flash_oe_n_o_reg = 1'b1;
        end
    end

    assign flash_rp_n_o = 1'b1;
    assign flash_vpen_o = 1'b1;
    assign flash_we_n_o = 1'b1;
    assign flash_byte_n_o = 1'b1; // 16 位模式

    typedef enum logic [3:0] {
        STATE_IDLE = 0,

        STATE_READ_LO = 1,
        STATE_READ_HI = 2,

        STATE_DONE = 3
    } state_t;
    state_t state;

    always @(posedge clk_i) begin
        if (rst_i) begin
            flash_addr_reg <= 23'b0;
            flash_data_lo_reg <= 16'b0;
            flash_data_hi_reg <= 16'b0;

            wb_ack_o <= 1'b0;
            state <= STATE_IDLE;
        end else begin
            case (state)
                STATE_IDLE: begin
                    wb_ack_o <= 1'b0;
                    if (wb_cyc_i && wb_stb_i) begin
                        if (wb_we_i) begin
                            state <= STATE_DONE;
                        end else begin
                            flash_data_lo_reg <= 16'b0;
                            flash_data_hi_reg <= 16'b0;
                            flash_addr_reg <= wb_addr_i[22:0];
                            state <= STATE_READ_LO;
                        end
                    end
                end

                STATE_READ_LO: begin
                    wb_ack_o <= 1'b0;
                    flash_data_lo_reg <= flash_data_i_comb;
                    flash_addr_reg <= flash_addr_reg + 23'd2;
                    state <= STATE_READ_HI;
                end

                STATE_READ_HI: begin
                    wb_ack_o <= 1'b0;
                    flash_data_hi_reg <= flash_data_i_comb;
                    state <= STATE_DONE;
                end

                STATE_DONE: begin
                    wb_ack_o <= 1'b1;
                    state <= STATE_IDLE;
                end
            endcase
        end
    end
  
endmodule