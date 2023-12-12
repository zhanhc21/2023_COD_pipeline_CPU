module pipeline #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
) (
    input wire clk_i,
    input wire rst_i,

    // wishbone master IM
    output reg wbm_cyc_im,
    output reg wbm_stb_im,
    input wire wbm_ack_im,
    output reg [ADDR_WIDTH-1:0] wbm_addr_im,
    output reg [DATA_WIDTH-1:0] wbm_data_o_im,
    input wire [DATA_WIDTH-1:0] wbm_data_i_im,
    output reg [DATA_WIDTH/8-1:0] wbm_sel_im,
    output reg wbm_we_im,
    // wishbone master MEM
    output reg wbm_cyc_dm,
    output reg wbm_stb_dm,
    input wire wbm_ack_dm,
    output reg [ADDR_WIDTH-1:0] wbm_addr_dm,
    output reg [DATA_WIDTH-1:0] wbm_data_o_dm,
    input reg  [DATA_WIDTH-1:0] wbm_data_i_dm,
    output reg [DATA_WIDTH/8-1:0] wbm_sel_dm,
    output reg wbm_we_dm,

    // csr time signal
    input wire timeout_signal,
    // ICache
    output reg fence_i_o
);
  
    // regfile signals
    logic [31:0] rf_rdata_a_i;
    logic [31:0] rf_rdata_b_i;
    logic [ 4:0] rf_raddr_a_o;
    logic [ 4:0] rf_raddr_b_o;
    logic [ 4:0] rf_waddr_o;
    logic [31:0] rf_wdata_o;
    logic rf_wen_o;
    reg_file u_reg_file(
        .clk(clk_i),
        .reset(rst_i),
        .waddr(rf_waddr_o),
        .wdata(rf_wdata_o),
        .we(rf_wen_o),
        .raddr_a(rf_raddr_a_o),
        .rdata_a(rf_rdata_a_i),
        .raddr_b(rf_raddr_b_o),
        .rdata_b(rf_rdata_b_i)
    ); 

    // CSR signals
    logic [31:0] csr_rdata_i;
    logic [11:0] csr_raddr_o;
    logic [31:0] csr_wdata_o;
    logic [11:0] csr_waddr_o;
    logic        csr_wen_o;

    logic        trap_en_signal;
    logic        trap_type_signal;    // 1 interrupt  0 exception
    logic [30:0] trap_code_signal;
    logic [31:0] trap_val_signal;
    logic [31:0] trap_pc_signal;
 
    // exception
    logic        exc_en_signal;
    logic [30:0] exc_code_signal;
    logic [31:0] exc_pc_signal;
    logic [31:0] exc_val_signal;

    logic        mret_singal;

    logic        exc_occur_signal;
    logic        ret_occur_signal;
    logic [31:0] csr_if_pc;  // mtvec异常处理程序地址 / pc recovered as mret

    logic        time_interrupt_occur;  // serve as signal to get pc as time interrupt occuring from mem stage

    csr_regFile u_csr_regFile (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .csr_raddr_i(csr_raddr_o),
        .csr_rdata_o(csr_rdata_i),
        .csr_waddr_i(csr_waddr_o),
        .csr_wdata_i(csr_wdata_o),
        .csr_wen_i(csr_wen_o),
        .mret_i(mret_singal),
        .exc_en_i(exc_en_signal),
        .exc_code_i(exc_code_signal),
        .exc_pc_i(exc_pc_signal),
        .timer_i(timeout_signal),
        .timer_o(time_interrupt_occur),
        .csr_pc_o(csr_if_pc),
        .pc_mux_ret_o(ret_occur_signal),
        .pc_mux_exc_o(exc_occur_signal)
    );

    // IF signals
    logic [31:0] if_id_pc;
    logic [31:0] if_id_instr;

    // ID signals
    logic [31:0] id_exe_pc;
    logic [31:0] id_exe_instr;
    logic [ 4:0] id_exe_rf_raddr_a;
    logic [ 4:0] id_exe_rf_raddr_b;
    logic [31:0] id_exe_rf_rdata_a;
    logic [31:0] id_exe_rf_rdata_b;
    logic [31:0] id_exe_imm;
    logic        id_exe_mem_en;
    logic        id_exe_mem_wen;
    logic [ 3:0] id_exe_alu_op;
    logic        id_exe_alu_a_mux;
    logic        id_exe_alu_b_mux;
    logic [ 4:0] id_exe_rf_waddr;
    logic        id_exe_rf_wen;
    logic [11:0] id_exe_csr_waddr;
    logic        id_exe_csr_wen;
    logic        id_exe_exc_en;
    logic [31:0] id_exe_exc_pc;
    logic [30:0] id_exe_exc_code;

    // EXE signals
    logic [31:0] exe_mem_pc;
    logic [31:0] exe_mem_instr;
    logic [31:0] exe_mem_mem_data;
    logic        exe_mem_mem_en;
    logic        exe_mem_mem_wen;
    logic [31:0] exe_mem_alu_result;
    logic [ 4:0] exe_mem_rf_waddr;
    logic        exe_mem_rf_wen;
    logic        exe_mem_exc_en;
    logic [30:0] exe_mem_exc_code;
    logic [31:0] exe_mem_exc_pc;
    logic [31:0] exe_if_pc;
    logic        exe_if_pc_mux;
    logic [31:0] alu_result;
    logic [31:0] alu_operand_a;
    logic [31:0] alu_operand_b;
    logic [ 3:0] alu_op;

    alu u_alu (
        .a  (alu_operand_a),
        .b  (alu_operand_b),
        .op (alu_op),
        .y (alu_result)
    );

    // MEM signals
    logic [31:0] mem_wb_pc;
    logic [31:0] mem_wb_instr;
    logic [31:0] mem_wb_rf_wdata;
    logic [4:0]  mem_wb_rf_waddr;
    logic        mem_wb_rf_wen;

    // pipeline controller signals
    logic if_busy;
    logic mem_busy;
    logic exe_first_time;
    
    logic if_stall;
    logic if_flush;
    logic id_stall;
    logic id_flush;
    logic exe_flush;
    logic exe_stall;
    logic mem_stall;
    logic mem_flush;
    logic wb_stall;
    logic wb_flush;
    
    logic [31:0] exe_forward_alu_a;
    logic [31:0] exe_forward_alu_b;
    logic exe_forward_alu_a_mux;
    logic exe_forward_alu_b_mux;
    logic mem_finish;
    
    logic [4:0] rf_waddr_controller;
    logic [31:0] rf_wdata_controller;
    logic rf_wen_controller;

    logic [31:0] exe_mem_instr_i;
    // BTB signal
    logic [31:0] exe_branch_src_pc_i;
    logic [31:0] exe_branch_tgt_pc_i;
    logic        exe_branch_en_i;
    logic        exe_branch_mispred_i;
    logic [31:0] if_now_pc_i;
    logic [31:0] if_next_pc_o;
    logic        exe_branch_taken_o;
    logic        if_hit_o;

    btb u_btb(
        .clk_i(clk_i),
        .rst_i(rst_i),

        .exe_branch_src_pc_i(exe_branch_src_pc_i),
        .exe_branch_tgt_pc_i(exe_branch_tgt_pc_i),
        .exe_branch_en_i(exe_branch_en_i),
        .exe_branch_mispred_i(exe_branch_mispred_i),

        .if_now_pc_i(if_now_pc_i),
        .if_next_pc_o(if_next_pc_o),
        .if_hit_o(if_hit_o),

        .exe_branch_taken_o(exe_branch_taken_o)
    );


    /* ========== IF stage ========== */
    IF_Stage u_if_stage(
        .clk_i(clk_i),
        .rst_i(rst_i),

        // stall signal and flush signal
        .stall_i(if_stall),
        .flush_i(if_flush),
        .busy_o(if_busy),

        // pc mux signals
        .pc_from_exe_i(exe_if_pc),
        .pc_mux_i(exe_if_pc_mux), // 0: pc+4, 1: exe_pc
        .pc_from_csr_i(csr_if_pc),
        .pc_mux_ret_i(ret_occur_signal),
        .pc_mux_exc_i(exc_occur_signal),
        
        // wishbone signals
        .wb_cyc_o(wbm_cyc_im),
        .wb_stb_o(wbm_stb_im),
        .wb_ack_i(wbm_ack_im),
        .wb_addr_o(wbm_addr_im),
        .wb_data_o(wbm_data_o_im),
        .wb_data_i(wbm_data_i_im),
        .wb_sel_o(wbm_sel_im),
        .wb_we_o(wbm_we_im),

        // BTB signals
        .if_now_pc_o(if_now_pc_i),
        .if_next_pc_i(if_next_pc_o),
        .if_hit_i(if_hit_o),
        
        // signals to ID stage
        .id_pc_o(if_id_pc),
        .id_instr_o(if_id_instr),

        // signal to ICache
        .fence_i_o(fence_i_o)
    );

    /* ========== ID stage ========== */
    ID_Stage u_id_stage(
        .clk_i(clk_i),
        .rst_i(rst_i),

        // signals from IF stage
        .id_pc_i(if_id_pc),
        .id_instr_i(if_id_instr),

        // stall signal and flush signal
        .stall_i(id_stall),
        .flush_i(id_flush),

        // regfile signals
        .rf_rdata_a_i(rf_rdata_a_i),
        .rf_rdata_b_i(rf_rdata_b_i),
        .rf_raddr_a_o(rf_raddr_a_o),
        .rf_raddr_b_o(rf_raddr_b_o),

        // csr signals
        .csr_rdata_i(csr_rdata_i),
        .csr_raddr_o(csr_raddr_o),

        // signal to controller
        .exe_first_time_o(exe_first_time),
        .mret_o(mret_singal),

        // signals to EXE stage
        .exe_pc_o(id_exe_pc),
        .exe_instr_o(id_exe_instr),
        .exe_rf_raddr_a_o(id_exe_rf_raddr_a),
        .exe_rf_raddr_b_o(id_exe_rf_raddr_b),
        .exe_rf_rdata_a_o(id_exe_rf_rdata_a),
        .exe_rf_rdata_b_o(id_exe_rf_rdata_b),
        .exe_imm_o(id_exe_imm),
        .exe_mem_en_o(id_exe_mem_en),
        .exe_mem_wen_o(id_exe_mem_wen),
        .exe_alu_op_o(id_exe_alu_op),
        .exe_alu_a_mux_o(id_exe_alu_a_mux),  // 0: rs1, 1: pc
        .exe_alu_b_mux_o(id_exe_alu_b_mux),  // 0: imm, 1: rs2
        .exe_rf_waddr_o(id_exe_rf_waddr),
        .exe_rf_wen_o(id_exe_rf_wen),
        .exe_csr_waddr_o(id_exe_csr_waddr),
        .exe_csr_wen_o(id_exe_csr_wen),
        .exe_exc_en_o(id_exe_exc_en),
        .exe_exc_code_o(id_exe_exc_code),
        .exe_exc_pc_o(id_exe_exc_pc)
    );

    /* ========== EXE stage ========== */
    EXE_Stage u_exe_stage(
        .clk_i(clk_i),
        .rst_i(rst_i),

        // signals from ID stage
        .exe_pc_i(id_exe_pc),
        .exe_instr_i(id_exe_instr),
        .exe_rf_raddr_a_i(id_exe_rf_raddr_a),
        .exe_rf_raddr_b_i(id_exe_rf_raddr_b),
        .exe_rf_rdata_a_i(id_exe_rf_rdata_a),
        .exe_rf_rdata_b_i(id_exe_rf_rdata_b),
        .exe_imm_i(id_exe_imm),
        .exe_mem_en_i(id_exe_mem_en),
        .exe_mem_wen_i(id_exe_mem_wen),
        .exe_alu_op_i(id_exe_alu_op),
        .exe_alu_a_mux_i(id_exe_alu_a_mux),
        .exe_alu_b_mux_i(id_exe_alu_b_mux),
        .exe_rf_waddr_i(id_exe_rf_waddr),
        .exe_rf_wen_i(id_exe_rf_wen),
        .exe_csr_waddr_i(id_exe_csr_waddr),
        .exe_csr_wen_i(id_exe_csr_wen),
        .exe_exc_en_i(id_exe_exc_en),
        .exe_exc_code_i(id_exe_exc_code),
        .exe_exc_pc_i(id_exe_exc_pc),

        // stall signal and flush signal
        .stall_i(exe_stall),
        .flush_i(exe_flush),

        // signals from forward unit
        .exe_forward_alu_a_i(exe_forward_alu_a),
        .exe_forward_alu_b_i(exe_forward_alu_b),
        .exe_forward_alu_a_mux_i(exe_forward_alu_a_mux),
        .exe_forward_alu_b_mux_i(exe_forward_alu_b_mux),
        .mem_finish_i(mem_finish),

        .if_pc_o(exe_if_pc),
        .if_pc_mux_o(exe_if_pc_mux),     // 0: pc+4, 1: exe_pc

        // signals to MEM stage
        .mem_pc_o(exe_mem_pc),
        .mem_instr_o(exe_mem_instr),
        .mem_mem_wdata_o(exe_mem_mem_data), // DM wdata
        .mem_alu_result_o(exe_mem_alu_result), // DM waddr
        .mem_mem_en_o(exe_mem_mem_en), // if use DM
        .mem_mem_wen_o(exe_mem_mem_wen), // if write DM (0: read DM, 1: write DM)
        .mem_rf_waddr_o(exe_mem_rf_waddr), // WB addr
        .mem_rf_wen_o(exe_mem_rf_wen),  // if write back (WB)
        .mem_exc_en_o(exe_mem_exc_en),
        .mem_exc_code_o(exe_mem_exc_code),
        .mem_exc_pc_o(exe_mem_exc_pc),

        // signals to alu
        .alu_result_i (alu_result),
        .alu_operand_a_o (alu_operand_a),
        .alu_operand_b_o (alu_operand_b),
        .alu_op_o (alu_op),

        // signals to csr
        .csr_wen_o(csr_wen_o),
        .csr_wdata_o(csr_wdata_o),
        .csr_waddr_o(csr_waddr_o),

        // signals to BTB
        .exe_branch_src_pc_o(exe_branch_src_pc_i),
        .exe_branch_tgt_pc_o(exe_branch_tgt_pc_i),
        .exe_branch_en_o(exe_branch_en_i),
        .exe_branch_mispred_o(exe_branch_mispred_i),

        .exe_branch_taken_i(exe_branch_taken_o)
    );

    /* ========== MEM stage ========== */
    MEM_Stage u_mem_stage(
        .clk_i(clk_i),
        .rst_i(rst_i),

        // wishbone signals
        .wb_cyc_o(wbm_cyc_dm),
        .wb_stb_o(wbm_stb_dm),
        .wb_ack_i(wbm_ack_dm),
        .wb_addr_o(wbm_addr_dm),
        .wb_data_o(wbm_data_o_dm),
        .wb_data_i(wbm_data_i_dm),
        .wb_sel_o(wbm_sel_dm),
        .wb_we_o(wbm_we_dm),

        // signals from EXE stage
        .mem_pc_i(exe_mem_pc),
        .mem_instr_i(exe_mem_instr),
        .mem_mem_wdata_i(exe_mem_mem_data),
        .mem_mem_en_i(exe_mem_mem_en),
        .mem_mem_wen_i(exe_mem_mem_wen),
        .mem_alu_result_i(exe_mem_alu_result),
        .mem_rf_waddr_i(exe_mem_rf_waddr),
        .mem_rf_wen_i(exe_mem_rf_wen),
        .mem_exc_en_i(exe_mem_exc_en),
        .mem_exc_code_i(exe_mem_exc_code),
        .mem_exc_pc_i(exe_mem_exc_pc),

        // stall signal and flush signal
        .mem_finish_o(mem_finish),
        .busy_o(mem_busy),
        .stall_i(mem_stall),
        .flush_i(mem_flush),

        // signals to WB(write back) stage
        .wb_pc_o(mem_wb_pc),
        .wb_instr_o(mem_wb_instr),
        .wb_rf_wdata_o(mem_wb_rf_wdata), // WB data
        .wb_rf_waddr_o(mem_wb_rf_waddr), // WB adddr
        .wb_rf_wen_o(mem_wb_rf_wen),     // if write back (WB)

        // signals to csr
        .exc_en_o(exc_en_signal),
        .exc_code_o(exc_code_signal),
        .exc_pc_o(exc_pc_signal),
        .time_en_i(time_interrupt_occur)
    );

    /* ========== WB stage ========== */
    WB_Stage u_wb_stage(
        .clk_i(clk_i),
        .rst_i(rst_i),

        // signals from MEM stage
        .wb_pc_i(mem_wb_pc),
        .wb_instr_i(mem_wb_instr),
        .wb_rf_wdata_i(mem_wb_rf_wdata),
        .wb_rf_waddr_i(mem_wb_rf_waddr),
        .wb_rf_wen_i(mem_wb_rf_wen),

        // stall signal and flush signal
        .stall_i(wb_stall),
        .flush_i(wb_flush),

        // signals to regfile
        .rf_wdata_o(rf_wdata_o),
        .rf_waddr_o(rf_waddr_o),
        .rf_wen_o(rf_wen_o),

        // signals to controller
        .rf_wdata_controller_o(rf_wdata_controller),
        .rf_waddr_controller_o(rf_waddr_controller),
        .rf_wen_controller_o(rf_wen_controller)
    );

    /* ========== Pipeline Controller ========== */
    pipeline_controller u_pipeline_controller(
        .clk_i(clk_i),
        .rst_i(rst_i),

        // signals from ID/EXE pipeline registers
        .exe_pc_i(id_exe_pc),
        .exe_rf_raddr_a_i(id_exe_rf_raddr_a),
        .exe_rf_raddr_b_i(id_exe_rf_raddr_b),
        .exe_mem_en_i(id_exe_mem_en),
        .exe_mem_wen_i(id_exe_mem_wen),
        .exe_rf_waddr_i(id_exe_rf_waddr),
        .exe_first_time_i(exe_first_time),
        
        // signals from EXE/MEM pipeline registers
        .mem_pc_i(exe_mem_pc),
        .mem_rf_wdata_i(exe_mem_alu_result),
        .mem_rf_waddr_i(exe_mem_rf_waddr),
        .mem_rf_wen_i(exe_mem_rf_wen),
        .mem_mem_en_i(exe_mem_mem_en),
        .mem_mem_wen_i(exe_mem_mem_wen),
        .exe_mem_instr_i(exe_mem_instr),

        // signals from MEM/WB pipeline registers
        .wb_rf_wdata_i(mem_wb_rf_wdata),
        .wb_rf_waddr_i(mem_wb_rf_waddr),
        .wb_rf_wen_i(mem_wb_rf_wen),
        .exe_if_pc_mux_i(exe_if_pc_mux),

        // signals from csr registers
        .csr_pc_mux_ret_i(ret_occur_signal),
        .csr_pc_mux_exc_i(exc_occur_signal),

        // signals from WB
        .rf_wdata_controller_i(rf_wdata_controller),
        .rf_waddr_controller_i(rf_waddr_controller),
        .rf_wen_controller_i(rf_wen_controller),
        
        // memory busy signals (IF & MEM)
        .mem_finish_i(mem_finish),
        .mem_busy_i(mem_busy),
        .if_busy_i(if_busy),

        // stall and flush signals
        .if_stall_o(if_stall),
        .id_stall_o(id_stall),
        .exe_stall_o(exe_stall),
        .mem_stall_o(mem_stall),
        .wb_stall_o(wb_stall),
        .if_flush_o(if_flush),
        .id_flush_o(id_flush),
        .exe_flush_o(exe_flush),
        .mem_flush_o(mem_flush),
        .wb_flush_o(wb_flush),

        // data hazard signals (forward unit)
        .exe_forward_alu_a_o(exe_forward_alu_a),
        .exe_forward_alu_b_o(exe_forward_alu_b),
        .exe_forward_alu_a_mux_o(exe_forward_alu_a_mux),
        .exe_forward_alu_b_mux_o(exe_forward_alu_b_mux)
    );
endmodule