module csr_time (
    input wire clk_i,
    input wire rst_i,

    input wire wb_cyc_i,
    input wire wb_stb_i,
    output reg wb_ack_o,

    input wire [31:0] wb_adr_i,
    input wire [31:0] wb_dat_i,
    output reg [31:0] wb_dat_o,
    input wire        wb_we_i,
    input wire [ 3:0] wb_sel_i,

    output reg timer_o
);
    logic [63:0] mtime;
    logic [63:0] mtimecmp;
    
    typedef enum logic [1:0] {
        IDLE = 0,
        DONE = 1
    } state_t;
    state_t state;

    // read
    always_comb begin
        if (wb_adr_i == 32'h200_BFF8)
            wb_dat_o = mtime[31:0];
        else if (wb_adr_i == 32'h200_BFF8 + 32'h4)
            wb_dat_o = mtime[63:32];
        else if (wb_adr_i == 32'h200_4000)
            wb_dat_o = mtimecmp[31:0];
        else if (wb_adr_i == 32'h200_4000 + 32'h4)
            wb_dat_o = mtimecmp[63:32];
        else
            wb_dat_o = 32'h0;
    end

    always_ff @ (posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            state    <= IDLE;
            mtime    <= 64'b0;
            mtimecmp <= 64'b0;
            wb_ack_o <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (wb_stb_i & wb_cyc_i) begin
                        if (wb_we_i) begin
                            case (wb_adr_i)
                                32'h200_BFF8:           mtime[ 31:0] <= wb_dat_i;
                                32'h200_BFF8 + 32'h4:   mtime[63:32] <= wb_dat_i;
                                32'h200_4000: begin
                                    mtimecmp[ 31:0] <= wb_dat_i;
                                    mtime <= mtime + 32'h1;
                                end          
                                32'h200_4000 + 32'h4: begin
                                    mtimecmp[63:32] <= wb_dat_i;
                                    mtime <= mtime + 32'h1;
                                end          
                                default: mtime <= mtime + 32'h1;
                            endcase
                        end else
                            mtime <= mtime + 32'h1;
                        wb_ack_o <= 1'b1;
                        state <= DONE;
                    end else
                        mtime <= mtime + 32'h1;
                end
                DONE: begin
                    wb_ack_o <= 1'b0;
                    state <= IDLE;
                    mtime <= mtime + 32'h1;
                end
            endcase
        end
    end

    assign timer_o = (mtime > mtimecmp) & (mtimecmp != 64'b0);
endmodule