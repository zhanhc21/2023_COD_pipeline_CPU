`include "csr.vh"

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

    // signals from controller
    input wire        trap_en_i,      // if int/exc occurred
    input wire        recover_i,
    input wire        trap_type_i,    // 1 interrupt  0 exception
    input wire [30:0] trap_code_i, 
    input wire [31:0] trap_pc_i,      // pc of trapped instr
    input wire [31:0] trap_val_i,     // addr_exc: addr / illegal_instr: instr / else: 0
    
    
    // interupt signals
    // input wire external_i,
    // input wire softwire_i,
    // input wire timer_i

    output reg [31:0] csr_pc_o
);  

    // csr regs
    logic [31:0] mtvec;
    logic [ 1:0] mtvec_mode;
    logic [31:2] mtvec_base;
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
    
    logic [ 1:0] cur_p_mode;   // current privilege mode


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
                        mtvec <= csr_wdata_i;
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
                // trap process
                if (trap_en_i) begin
                    mcause_interrupt <= trap_type_i;
                    mcause_exc_code  <= trap_code_i;
                    // point to next instr
                    if (trap_type_i == `EBREAK || trap_type_i == `ECALL_U)
                        mepc         <= trap_pc_i + 4;
                    else
                        mepc         <= trap_pc_i;
                    mscratch         <= trap_val_i;
                    if (!trap_type_i) begin
                        mstatus_mpie <= mstatus_mie;
                        mstatus_mie  <= 1'b0;
                        mstatus_mpp  <= cur_p_mode;
                    end
                end
                if (recover_i) begin
                    mstatus_mie  <= mstatus_mpie;
                    mstatus_mpie <= 1'b1;
                end
            end
        end
    end

    always_comb begin
        case (csr_raddr_i)
            `MSTATUS:  csr_rdata_o <= mstatus;
            `MIE:      csr_rdata_o <= mie;
            `MIP:      csr_rdata_o <= mip;
            `MTVEC:    csr_rdata_o <= mtvec;
            `MSCRATCH: csr_rdata_o <= mscratch;
            `MEPC:     csr_rdata_o <= mepc;
            `MCAUSE:   csr_rdata_o <= mcause;
            default:   csr_rdata_o <= 32'b0;
        endcase
        if (trap_en_i) begin
            if (mtvec_mode == `DIRECT)
                csr_pc_o = {2'b0, mtvec_base};
            else
                if (trap_type_i) // interrupt
                    csr_pc_o = {2'b0, mtvec_base} + 4 * mcause_exc_code;
                else
                    csr_pc_o = {2'b0, mtvec_base};
        end else if (recover_i) begin
            csr_pc_o = mepc;
        end else begin
            csr_pc_o = 32'b0;
        end
    end
endmodule