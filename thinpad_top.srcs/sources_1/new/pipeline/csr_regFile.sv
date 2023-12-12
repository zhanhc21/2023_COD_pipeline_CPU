`include "../include/csr.vh"

module csr_regFile (
    input wire clk_i,
    input wire rst_i,

    // ID stage read csr
    input wire [11:0] csr_raddr_i,
    output reg [31:0] csr_rdata_o,

    // EXE stage write csr
    input wire        csr_wen_i,
    input wire [11:0] csr_waddr_i,
    input wire [31:0] csr_wdata_i,

    input wire        mret_i,

    // signals from mem stage
    input wire        exc_en_i,      // if exc occurred
    input wire [30:0] exc_code_i, 
    input wire [31:0] exc_pc_i,      // pc of exc instr from mem stage
    
    // interupt signals
    input wire        timer_i,
    output reg        timer_o,       // time interrupt signal to mem stage

    output reg [31:0] csr_pc_o,
    output reg        pc_mux_exc_o,
    output reg        pc_mux_ret_o
);  

    // csr regs
    logic [31:0] mtvec;
    logic [ 1:0] mtvec_mode;
    logic [29:0] mtvec_base;
    assign mtvec = {mtvec_base, mtvec_mode};

    logic [31:0] mscratch;
    logic [31:0] mepc;

    logic [31:0] mcause;
    logic        mcause_interrupt;  // 1 interrupt  0 exception
    logic [30:0] mcause_exc_code;
    assign mcause = {mcause_interrupt, mcause_exc_code};

    logic [31:0] mstatus;
    // M mode
    logic        mstatus_mie;
    logic        mstatus_mpie;
    logic [ 1:0] mstatus_mpp;  // previous privilege mode
    // S mode
    logic        mstatus_sie;
    logic        mstatus_spie;
    logic        mstatus_spp;
    assign mstatus = {19'b0, mstatus_mpp, 2'b0, mstatus_spp, mstatus_mpie, 1'b0, mstatus_spie, 1'b0, mstatus_mie, 1'b0, mstatus_sie, 1'b0};
    
    logic [31:0] mie;
    // M mode
    logic        mie_mtie;   // timer interrupt enable
    logic        mie_msie;   // software interrupt enable 
    logic        mie_meie;   // external interrupt enable
    // S mode
    logic        mie_seie;
    logic        mie_stie;
    logic        mie_ssie;
    assign mie = {20'b0, mie_meie, 1'b0, mie_seie, 1'b0, mie_mtie, 1'b0, mie_stie, 1'b0, mie_msie, 1'b0, mie_ssie, 1'b0};

    logic [31:0] mip;
    // M mode
    logic        mip_mtip;   // timer interrupt pending
    logic        mip_msip;   // software interrupt pending
    logic        mip_meip;   // external interrupt pending
    // S mode
    logic        mip_seip;
    logic        mip_stip;
    logic        mip_ssip;
    assign mip = {20'b0, mip_meip, 1'b0, mip_seip, 1'b0, mip_mtip, 1'b0, mip_stip, 1'b0, mip_msip, 1'b0, mip_ssip, 1'b0};
    // current privilege mode
    logic [ 1:0] cur_p_mode;   

    logic        time_interrupt_occur;
    assign time_interrupt_occur = mie_mtie & mip_mtip;
    assign timer_o = time_interrupt_occur;

    always_ff @ (posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            mtvec_mode  <= `DIRECT;
            mtvec_base  <= 30'b0;
            mscratch    <= 32'b0;
            mepc        <= 32'b0;
            mcause_interrupt <= 1'b0;
            mcause_exc_code  <= 31'b0;

            mstatus_mie  <= 1'b0;
            mstatus_mpie <= 1'b1;
            mstatus_mpp  <= `M_MODE;
            mstatus_sie  <= 1'b0;
            mstatus_spie <= 1'b0;
            mstatus_spp  <= 1'b0;

            mie_mtie     <= 1'b0;
            mie_msie     <= 1'b0;
            mie_meie     <= 1'b0;
            mie_stie     <= 1'b0;
            mie_ssie     <= 1'b0;
            mie_seie     <= 1'b0;

            mip_mtip     <= 1'b0;
            mip_msip     <= 1'b0;
            mip_meip     <= 1'b0;
            mip_stip     <= 1'b0;
            mip_ssip     <= 1'b0;
            mip_seip     <= 1'b0;

            cur_p_mode  <= `M_MODE;
        end else begin
            if (csr_wen_i) begin
                case (csr_waddr_i)
                    `MSTATUS: begin
                        case (cur_p_mode)
                            `M_MODE: begin
                                mstatus_mie  <= csr_wdata_i[3];
                                mstatus_mpie <= csr_wdata_i[7];
                                mstatus_mpp  <= csr_wdata_i[12:11];
                                mstatus_sie  <= csr_wdata_i[1];
                                mstatus_spie <= csr_wdata_i[5];
                                mstatus_spp  <= csr_wdata_i[8];
                            end
                            `S_MODE: begin
                                mstatus_sie  <= csr_wdata_i[1];
                                mstatus_spie <= csr_wdata_i[5];
                                mstatus_spp  <= csr_wdata_i[8];
                            end
                            default: begin
                                // do nothing
                            end
                        endcase                                       
                    end
                    `MIE: begin
                        case (cur_p_mode)
                            `M_MODE: begin
                                mie_meie  <= csr_wdata_i[11];
                                mie_mtie  <= csr_wdata_i[7];
                                mie_msie  <= csr_wdata_i[3];
                                mie_seie  <= csr_wdata_i[9];
                                mie_stie  <= csr_wdata_i[5];
                                mie_ssie  <= csr_wdata_i[1];
                            end
                            `S_MODE: begin
                                mie_seie  <= csr_wdata_i[9];
                                mie_stie  <= csr_wdata_i[5];
                                mie_ssie  <= csr_wdata_i[1];
                            end
                            default: begin
                                // do nothing
                            end
                        endcase                                                    
                    end
                    `MIP: begin
                        if (cur_p_mode == `M_MODE) begin
                            mip_seip <= csr_wdata_i[9];
                            mip_stip <= csr_wdata_i[5];
                            mip_ssip <= csr_wdata_i[1];
                        end
                    end
                    `MTVEC: begin
                        mtvec_base <= csr_wdata_i[31:2];
                        mtvec_mode <= csr_wdata_i[1:0];
                    end
                    `MSCRATCH: begin                            
                        mscratch <= csr_wdata_i;
                    end
                    `MEPC: begin             
                        mepc <= {csr_wdata_i[31:2], 2'b00};
                    end
                    `MCAUSE: begin
                        mcause_interrupt <= csr_wdata_i[31];
                        mcause_exc_code  <= csr_wdata_i[30:0];                 
                    end
                    default: begin
                        // do nothing
                    end
                endcase
            end else begin
                if (timer_i) begin
                    mip_mtip <= 1'b1;
                end else begin
                    mip_mtip <= 1'b0;
                end
                // exception process
                if (exc_en_i) begin
                    mcause_interrupt <= `EXCEPTION;
                    mcause_exc_code  <= exc_code_i;

                    mstatus_mpie <= mstatus_mie;
                    mstatus_mie  <= 1'b0;
                    mstatus_mpp  <= cur_p_mode;

                    if (exc_code_i == `ECALL_U) begin
                        case (cur_p_mode)
                            `U_MODE: mcause_exc_code <= `ECALL_U;
                            `S_MODE: mcause_exc_code <= `ECALL_S;
                            `M_MODE: mcause_exc_code <= `ECALL_M;
                            default: begin
                                // do nothing
                            end
                        endcase
                    end
                    // point to next instr
                    if (exc_code_i == `EBREAK || exc_code_i == `ECALL_U) begin
                        mepc <= exc_pc_i + 4;
                    end else begin
                        mepc <= exc_pc_i;
                    end
                end else if (time_interrupt_occur) begin
                    // time interrupt process
                    mcause_interrupt <= `INTERRUPT;
                    mcause_exc_code  <= `MACHINE_TIMER_INTERRUPT;
                    mie_mtie         <= 1'b1;
                    mepc             <= exc_pc_i;
                    mstatus_mpie     <= mstatus_mie;
                    mstatus_mie      <= 1'b0;
                    mstatus_mpp      <= cur_p_mode;
                end else if (mret_i) begin
                    cur_p_mode   <= mstatus_mpp;
                    mstatus_mie  <= mstatus_mpie;
                    mstatus_mpie <= 1'b1;
                    mip_mtip     <= 1'b0;
                    mie_mtie     <= 1'b0;
                end
            end
        end
    end

    always_comb begin
        case (csr_raddr_i)
            `MSTATUS:  csr_rdata_o = mstatus;
            `MIE:      csr_rdata_o = mie;
            `MIP:      csr_rdata_o = mip;
            `MTVEC:    csr_rdata_o = mtvec;
            `MSCRATCH: csr_rdata_o = mscratch;
            `MEPC:     csr_rdata_o = mepc;
            `MCAUSE:   csr_rdata_o = mcause;
            default:   csr_rdata_o = 32'b0;
        endcase
        // pc to if stage
        if (exc_en_i) begin
            csr_pc_o     = {mtvec_base, 2'b0};
            pc_mux_exc_o = 1'b1;
            pc_mux_ret_o = 1'b0;
        end else if (time_interrupt_occur) begin
            if (mtvec_mode == `DIRECT) begin
                csr_pc_o = {mtvec_base, 2'b0};
            end else begin
                csr_pc_o = {mtvec_base, 2'b0} + 4 * mcause_exc_code;
            end
            pc_mux_exc_o = 1'b1;
            pc_mux_ret_o = 1'b0;
        end else if (mret_i) begin
            csr_pc_o = mepc;
            pc_mux_exc_o = 1'b0;
            pc_mux_ret_o = 1'b1;
        end else begin
            csr_pc_o = 32'b0;
            pc_mux_exc_o = 1'b0;
            pc_mux_ret_o = 1'b0;
        end
    end
endmodule