module pipeline_controller(
    input wire clk_i,
    input wire rst_i,

    // signals from ID/EXE pipeline registers
    input wire [31:0] exe_pc_i,
    input wire [ 4:0] exe_rf_raddr_a_i,
    input wire [ 4:0] exe_rf_raddr_b_i,
    input wire        exe_mem_en_i,
    input wire        exe_mem_wen_i,
    input wire [ 4:0] exe_rf_waddr_i,
    input wire        exe_first_time_i,

    // signals from EXE/MEM pipeline registers
    input wire [31:0] mem_pc_i,
    input wire [31:0] mem_rf_wdata_i,
    input wire [ 4:0] mem_rf_waddr_i,
    input wire        mem_rf_wen_i,
    input wire        mem_mem_en_i,
    input wire        mem_mem_wen_i,
    input wire [31:0] exe_mem_instr_i,

    // signals from MEM/WB pipeline registers
    input wire [31:0] wb_rf_wdata_i,
    input wire [ 4:0] wb_rf_waddr_i,
    input wire        wb_rf_wen_i,
    input wire        exe_if_pc_mux_i,

    // signals from csr registers
    input wire        csr_pc_mux_ret_i,
    input wire        csr_pc_mux_exc_i,

    // signals from WB
    input wire [31:0] rf_wdata_controller_i,
    input wire [ 4:0] rf_waddr_controller_i,
    input wire        rf_wen_controller_i,

    // wishbone busy signals
    input wire if_busy_i,
    input wire mem_busy_i,
    input wire mem_finish_i,

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
    output reg        exe_forward_alu_a_mux_o,
    output reg        exe_forward_alu_b_mux_o
);

    typedef enum logic [2:0] {
        STATE_IDLE = 0,
        STATE_FLUSH = 1,
        STATE_DONE = 2
    } state_t;
    state_t state;
    
    always_ff @ (posedge clk_i) begin
        if (rst_i) begin
            state <= STATE_IDLE;
        end else begin
            if (state == STATE_IDLE) begin
                if (exe_if_pc_mux_i == 1'b1 && if_busy_i == 1'b0) begin
                    state <= STATE_FLUSH;
                end else
                    state <= STATE_IDLE;
            end else if (state == STATE_FLUSH) begin
                    state <= STATE_DONE;
            end else begin
                if (exe_if_pc_mux_i == 1'b0) 
                    state <= STATE_IDLE;
                else
                    state <= STATE_DONE;
            end
        end
    end
    
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
            id_stall_o = 1'b1;
            exe_stall_o = 1'b1;
        end else if (exe_if_pc_mux_i == 1'b1 && if_busy_i == 1'b0 && state != STATE_DONE) begin  // branch and jump, flush ID & EXE
            if_flush_o = 1'b1;
            id_flush_o = 1'b1;
//            exe_flush_o = 1'b1;
        end else if (csr_pc_mux_exc_i | csr_pc_mux_ret_i) begin // jump to mtvec, flush ID & EXE & MEM
            if_flush_o = 1'b1;
            id_flush_o = 1'b1;
//            exe_flush_o = 1'b1;
        end
        // else if (exe_mem_en_i && !exe_mem_wen_i &&  // load hazard
        //     (exe_rf_waddr_i == id_rf_raddr_a_i || exe_rf_waddr_i == id_rf_raddr_b_i)) begin
        //     if_stall_o = 1'b1;
        //     id_stall_o = 1'b1;
        //     exe_stall_o = 1'b1;
        // end
    end

    // data hazard
    always_comb begin
        exe_forward_alu_a_o = 32'h0000_0000;
        exe_forward_alu_b_o = 32'h0000_0000;
        exe_forward_alu_a_mux_o = 1'b0;
        exe_forward_alu_b_mux_o = 1'b0;

        // ALU@EXE/MEM->ALU
        if (exe_first_time_i) begin
            if (mem_rf_wen_i && !mem_mem_en_i) begin
                if (mem_rf_waddr_i == exe_rf_raddr_a_i && !$isunknown(mem_rf_wdata_i) && mem_rf_waddr_i != 0) begin
                    exe_forward_alu_a_o = mem_rf_wdata_i;
                    exe_forward_alu_a_mux_o = 1'b1;
                end
                if (mem_rf_waddr_i == exe_rf_raddr_b_i && !$isunknown(mem_rf_wdata_i) && mem_rf_waddr_i != 0) begin
                    exe_forward_alu_b_o = mem_rf_wdata_i;
                    exe_forward_alu_b_mux_o = 1'b1;
                end
            end
            // ALU@MEM/WB->ALU
            else if (wb_rf_wen_i) begin
                if(wb_rf_waddr_i == exe_rf_raddr_a_i && !$isunknown(wb_rf_wdata_i) && wb_rf_waddr_i != 0
                ) begin
                    exe_forward_alu_a_o = wb_rf_wdata_i;
                    exe_forward_alu_a_mux_o = 1'b1;
                end
                if(wb_rf_waddr_i == exe_rf_raddr_b_i && !$isunknown(wb_rf_wdata_i) && wb_rf_waddr_i != 0
                ) begin
                    exe_forward_alu_b_o = wb_rf_wdata_i;
                    exe_forward_alu_b_mux_o = 1'b1;
                end
            end
            // DM@WB->ALU
            else if (rf_wen_controller_i) begin
                if(rf_waddr_controller_i == exe_rf_raddr_a_i && !$isunknown(rf_wdata_controller_i) 
                && rf_waddr_controller_i != 0) begin
                    exe_forward_alu_a_o = rf_wdata_controller_i;
                    exe_forward_alu_a_mux_o = 1'b1;
                end
                if(rf_waddr_controller_i == exe_rf_raddr_b_i && !$isunknown(rf_wdata_controller_i) 
                && rf_waddr_controller_i != 0) begin
                    exe_forward_alu_b_o = rf_wdata_controller_i;
                    exe_forward_alu_b_mux_o = 1'b1;
                end
            end
        end  
    end
endmodule