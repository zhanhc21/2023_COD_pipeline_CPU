module IF_Stage #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire clk_i,
    input wire rst_i,

    // stall signal and flush signal
    input wire stall_i,
    input wire flush_i,
    output wire busy_o,

    // pc mux signals
    input wire [31:0] pc_from_exe_i,
    input wire        pc_mux_i,  // 0: pc, 1: exe_pc
    input wire [31:0] pc_from_csr_i,
    input wire        pc_mux_ret_i, // 1: enable
    input wire        pc_mux_exc_i,
    
    // wishbone signals
    output reg wb_cyc_o,
    output reg wb_stb_o,
    input wire wb_ack_i,
    output reg [ADDR_WIDTH-1:0] wb_addr_o,
    output reg [DATA_WIDTH-1:0] wb_data_o,
    input wire [DATA_WIDTH-1:0] wb_data_i,
    output reg [DATA_WIDTH/8-1:0] wb_sel_o,
    output reg wb_we_o,

    // BTB signals
    output reg [31:0] if_now_pc_o,
    input wire [31:0] if_next_pc_i,
    input wire        if_hit_i,

    // signals to ID stage
    output reg [31:0] id_pc_o,
    output reg [31:0] id_instr_o,

    // signal to ICache
    output reg fence_i_o
);
    // stall signal and flush signal
    reg [31:0] pc_reg;
    reg [31:0] pc_now_reg;
    reg [31:0] inst_reg;
    typedef enum logic {
        STATE_IDLE = 0,
        STATE_READ = 1
    } state_t;
    state_t state;
    assign busy_o = state;
    always_ff @ (posedge clk_i) begin
        if (rst_i) begin
            wb_cyc_o <= 1'b0;
            wb_stb_o <= 1'b0;
            wb_addr_o <= 32'b0;
            wb_data_o <= 32'b0;
            wb_sel_o <= 4'b0;
            wb_we_o <= 1'b0;

            pc_reg <= 32'h80000000;
            pc_now_reg <= 32'h80000000;
            inst_reg <= 32'b0;
            state <= STATE_IDLE;
        end else if (stall_i && state == STATE_IDLE) begin
            wb_cyc_o <= 1'b0;
            wb_stb_o <= 1'b0;
            wb_addr_o <= 32'b0;
            wb_data_o <= 32'b0;
            wb_sel_o <= 4'b0;
            wb_we_o <= 1'b0;

            pc_reg <= pc_reg;
            pc_now_reg <= pc_now_reg;
            inst_reg <= inst_reg;
            state <= STATE_IDLE;
        end else if (flush_i) begin
            wb_cyc_o <= 1'b0;
            wb_stb_o <= 1'b0;
            wb_addr_o <= 32'b0;
            wb_data_o <= 32'b0;
            wb_sel_o <= 4'b0;
            wb_we_o <= 1'b0;

            pc_reg <= pc_reg;
            pc_now_reg <= 32'b0;
            inst_reg <= 32'b0;
            fence_i_o <= 1'b0;
            if (pc_mux_i == 1) begin
                pc_reg <= pc_from_exe_i;
                pc_now_reg <= 32'h0;
            end else if (pc_mux_exc_i | pc_mux_ret_i) begin
                pc_reg <= pc_from_csr_i;
                pc_now_reg <= 32'h0;
            end
            state <= STATE_IDLE;
        end else begin
            if (state == STATE_IDLE) begin
                wb_cyc_o <= 1'b1;
                wb_stb_o <= 1'b1;
                wb_we_o <= 1'b0;
                wb_sel_o <= 4'b1111;
                fence_i_o <= 1'b0;
                if (pc_mux_i == 1) begin
                    wb_addr_o <= pc_from_exe_i;
                    pc_reg <= pc_from_exe_i;
                    pc_now_reg <= 32'h0;
                    inst_reg <= 32'h0;
                end else if (pc_mux_exc_i | pc_mux_ret_i) begin
                    wb_addr_o <= pc_from_csr_i;
                    pc_reg <= pc_from_csr_i;
                    pc_now_reg <= 32'h0;
                    inst_reg <= 32'h0;
                end else begin
                    wb_addr_o <= pc_reg;
                end
                state <= STATE_READ;
            end else begin

                if (wb_ack_i) begin
                    wb_cyc_o <= 1'b0;
                    wb_stb_o <= 1'b0;
                    wb_we_o <= 1'b0;
                    wb_sel_o <= 4'b0000;
                    // fence_i
                    if (wb_data_i[6:0] == 7'b0001111) begin
                        fence_i_o <= 1'b1;
                    end else if (wb_data_i) begin
                        inst_reg <= wb_data_i;
                        pc_now_reg <= pc_reg;
                        pc_reg <= if_next_pc_i;
                    end else begin
                        pc_now_reg <= pc_now_reg;
                        pc_reg <= pc_reg;
                    end
                    state <= STATE_IDLE;
                end
            end
        end
    end

    always_ff @ (posedge clk_i) begin
        if (rst_i) begin
            id_pc_o <= 32'h80000000;
            id_instr_o <= 32'b0;
        end else begin
            id_pc_o <= pc_now_reg;
            id_instr_o <= inst_reg;
        end
    end
    
    assign if_now_pc_o = pc_reg;
endmodule