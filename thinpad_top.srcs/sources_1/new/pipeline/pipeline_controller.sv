module pipeline_controller(
    input wire clk_i,
    input wire rst_i,

    // signals from ID stage
    input wire [4:0] id_rf_raddr_a_i,
    input wire [4:0] id_rf_raddr_b_i,

    // signals from ID/EXE pipeline registers
    input wire [31:0] exe_pc_i,
    input wire [4:0] exe_rf_raddr_a_i,
    input wire [4:0] exe_rf_raddr_b_i,
    input wire        exe_mem_en_i,
    input wire        exe_mem_wen_i,
    input wire [4:0] exe_rf_waddr_i,
    input wire exe_first_time_i,

    // signals from EXE/MEM pipeline registers
    input wire [31:0] mem_rf_wdata_i,
    input wire [4:0] mem_rf_waddr_i,
    input wire        mem_rf_wen_i,
    input wire        mem_mem_en_i,
    input wire        mem_mem_wen_i,

    // signals from MEM/WB pipeline registers
    input wire [31:0] wb_rf_wdata_i,
    input wire [4:0] wb_rf_waddr_i,
    input wire        wb_rf_wen_i,
    input wire exe_if_pc_mux_i,

    // wishbone busy signals
    input wire if_busy_i,
    input wire mem_busy_i,

    // stall and flush signals
    output reg if_stall_o,
    output reg id_stall_o,
    output reg exe_stall_o,
    output reg mem_stall_o,
    output reg wb_stall_o,
    output reg if_flush_o,
    output reg id_flush_o,
    output reg exe_flush_o,
    output reg mem_flush_o,
    output reg wb_flush_o,

    // data hazard signals (forward unit)
    output reg [31:0] exe_forward_alu_a_o,
    output reg [31:0] exe_forward_alu_b_o,
    output reg exe_forward_alu_a_mux_o,
    output reg exe_forward_alu_b_mux_o
);

    logic m_busy;  // if memory busy (IF/MEM)
    reg [31:0] exe_pc_i_reg;

    assign m_busy = if_busy_i | mem_busy_i;


    // structure(memory) hazard
    always_comb begin
        if_stall_o = 1'b0;
        id_stall_o = 1'b0;
        exe_stall_o = 1'b0;
        mem_stall_o = 1'b0;
        wb_stall_o = 1'b0;
        if_flush_o = 1'b0;
        id_flush_o = 1'b0;
        exe_flush_o = 1'b0;
        mem_flush_o = 1'b0;
        wb_flush_o = 1'b0;

        if (mem_busy_i) begin  // stall if memory is busy
            if_stall_o = 1'b1;
        end else if (exe_if_pc_mux_i == 1'b1) begin  // branch and jump, flush ID & EXE
            id_flush_o = 1'b1;
            exe_flush_o = 1'b1;
        end else if (exe_mem_en_i && !exe_mem_wen_i &&  // load hazard
            (exe_rf_waddr_i == id_rf_raddr_a_i || exe_rf_waddr_i == id_rf_raddr_b_i)) begin
            if_stall_o = 1'b1;
            id_stall_o = 1'b1;
            exe_stall_o = 1'b1;
        end
    end

    // data hazard
    always_comb begin
        exe_forward_alu_a_o = 32'h0000_0000;
        exe_forward_alu_b_o = 32'h0000_0000;
        exe_forward_alu_a_mux_o = 1'b0;
        exe_forward_alu_b_mux_o = 1'b0;

        // ALU@EXE/MEM->ALU
        if (exe_first_time_i) begin
            if (mem_rf_wen_i) begin
                if (mem_rf_waddr_i == exe_rf_raddr_a_i && mem_rf_waddr_i != 0) begin
                    exe_forward_alu_a_o = mem_rf_wdata_i;
                    exe_forward_alu_a_mux_o = 1'b1;
                end
                if (mem_rf_waddr_i == exe_rf_raddr_b_i && mem_rf_waddr_i != 0) begin
                    exe_forward_alu_b_o = mem_rf_wdata_i;
                    exe_forward_alu_b_mux_o = 1'b1;
                end
            end
            // ALU@MEM/WB->ALU
            if (wb_rf_wen_i) begin
                if(wb_rf_waddr_i == exe_rf_raddr_a_i) begin
                    exe_forward_alu_a_o = wb_rf_wdata_i;
                    exe_forward_alu_a_mux_o = 1'b1;
                end
                if(wb_rf_waddr_i == exe_rf_raddr_b_i) begin
                    exe_forward_alu_b_o = wb_rf_wdata_i;
                    exe_forward_alu_b_mux_o = 1'b1;
                end
            end
        end  
    end
    

endmodule