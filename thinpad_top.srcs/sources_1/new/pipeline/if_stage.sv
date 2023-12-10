module IF_Stage #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire clk_i,
    input wire rst_i,

    // stall signal and flush signal
    input wire stall_i,
    input wire flush_i,

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

    // signals to ID stage
    output reg [31:0] id_pc_o,
    output reg [31:0] id_instr_o,
    // pc to csr as time interrupt occur
    output reg [31:0] int_pc_o
);
    // stall signal and flush signal
    reg [31:0] pc_reg;
    reg [31:0] pc_now_reg;
    reg [31:0] inst_reg;

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
        end else if (stall_i) begin
            wb_cyc_o <= 1'b0;
            wb_stb_o <= 1'b0;
            wb_addr_o <= 32'b0;
            wb_data_o <= 32'b0;
            wb_sel_o <= 4'b0;
            wb_we_o <= 1'b0;

            pc_reg <= pc_reg;
            pc_now_reg <= pc_now_reg;
            inst_reg <= inst_reg;
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
        end else begin
            wb_cyc_o <= 1'b1;
            wb_stb_o <= 1'b1;
            wb_we_o <= 1'b0;
            wb_sel_o <= 4'b1111;
            // if (pc_mux_exc_i || pc_mux_ret_i) begin
            //     wb_addr_o <= pc_from_csr_i;
            //     pc_reg <= pc_from_csr_i;
            //     pc_now_reg <= 32'h0;
            //     inst_reg <= 32'h0;
            // end else 
            if (pc_mux_i == 1) begin
                wb_addr_o <= pc_from_exe_i;
                pc_reg <= pc_from_exe_i;
                pc_now_reg <= 32'h0;
                inst_reg <= 32'h0;
            end else begin
                wb_addr_o <= pc_reg;
            end

            if (wb_ack_i && (!pc_mux_i || wb_addr_o == pc_from_exe_i) && (!pc_mux_ret_i || wb_addr_o == pc_from_csr_i)) begin
                wb_cyc_o <= 1'b0;
                wb_stb_o <= 1'b0;
                wb_we_o <= 1'b0;
                wb_sel_o <= 4'b0000;
                if (wb_data_i) begin
                    inst_reg <= wb_data_i;
                    pc_now_reg <= pc_reg;
                    pc_reg <= pc_reg + 32'h00000004;
                end else begin
                    pc_now_reg <= pc_now_reg;
                    pc_reg <= pc_reg;
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

    always_comb begin
        if (pc_mux_exc_i)
            int_pc_o = pc_reg;
    end
endmodule