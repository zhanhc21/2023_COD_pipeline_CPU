`include "csr.vh"

module csr_regFile (
    input wire clk_i,
    input wire rst_i,

    // ID stage read csr
    input wire [11:0] raddr_i,
    output reg [31:0] rdata_o,

    // EXE stage write csr
    input wire        wen_i,
    input wire [11:0] waddr_i,
    input wire [31:0] wdata_i,

    // interupt signals from controller
    input wire external_i,
    input wire softwire_i,
    input wire timer_i
);
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
    logic        mstatus_ie;   // Current Interrupt Enable
    logic        mstatus_pie;  // Previous Interrupt Enable
    logic [ 1:0] mstatus_pp;   // Previous Privilege Mode
    assign mstatus = {19'b0, mstatus_pp, 3'b0, mstatus_pie, 3'b0, mstatus_ie, 3'b0};

    logic [31:0] mie;
    logic        mie_tie;   // timer interrupt enable
    logic        mie_sie;   // software interrupt enable 
    logic        mie_eie;   // external interrupt enable
    assign mie = {20'b0, mie_eie, 3'b0, mie_tie, 3'b0, mie_sie, 3'b0};

    logic [31:0] mip;
    logic        mip_tip;   // timer interrupt pending
    logic        mip_sip;   // software interrupt pending
    logic        mip_eip;   // external interrupt pending
    assign mip = {20'b0, mip_eip, 3'b0, mip_tip, 3'b0, mip_sip, 3'b0};

    logic [31:0] mtime;
    logic [31:0] mtimecmp;



    always_ff @ (posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            mtvec_mode  <= `DIRECT;
            mtvec_base  <= 30'b0;

            mscratch    <= 32'b0;
            mepc        <= 32'b0;

            mcause_interrupt <= 1'b0;
            mcause_exc_code  <= 31'b0;

            mstatus_ie  <= 1'b0;
            mstatus_pie <= 1'b1;
            mstatus_pp  <= `U_MODE;

            mie_tie     <= 1'b0;
            mie_sie     <= 1'b0;
            mie_eie     <= 1'b0;

            mip_tip     <= 1'b0;
            mip_sip     <= 1'b0;
            mip_eip     <= 1'b0;
    
            mtime       <= 32'b0;
            mtimecmp    <= 32'b0;
        end else begin
            if (wen_i) begin
                case (waddr_i)
                    `MSTATUS: begin
                        case (wdata_i[12:11])
                            `M_MODE: begin
                                mstatus_ie  <= wdata_i[3];
                                // update pie & pp before interruption
                                if (!wdata_i[3]) begin
                                    mstatus_pie <= wdata_i[7];
                                    mstatus_pp  <= `M_MODE;
                                end
                            end
                            // `S_MODE: begin
                            //     if (`S_MODE >= mstatus_pp) begin
                            //         mstatus_ie <= wdata_i[1];
                            //         if (!wdata_i[1]) begin
                            //             mstatus_pie <= wdata_i[5];
                            //             mstatus_pp  <= `S_MODE;
                            //         end
                            //     end else begin
                            //         mstatus_ie  <= mstatus_ie;
                            //         mstatus_pie <= mstatus_pie;
                            //         mstatus_pp  <= mstatus_pp;
                            //     end
                            // end
                            // `U_MODE: begin
                            //     if (`U_MODE == mstatus_pp) begin
                            //         mstatus_ie <= wdata_i[0];
                            //         if (!wdata_i[0]) begin
                            //             mstatus_pie <= wdata_i[4];
                            //             mstatus_pp  <= `U_MODE;
                            //         end
                            //     end else begin
                            //         mstatus_ie  <= mstatus_ie;
                            //         mstatus_pie <= mstatus_pie;
                            //         mstatus_pp  <= mstatus_pp;
                            //     end                         
                            // end
                            default: begin
                                mstatus_ie  <= mstatus_ie;
                                mstatus_pie <= mstatus_pie;
                                mstatus_pp  <= mstatus_pp;
                            end
                        endcase                                       
                    end
                    `MIE: begin
                        if (wdata_i[12:11] == `M_MODE) begin
                            mie_tie <= wdata_i[7];
                            mie_sie <= wdata_i[3];
                            mie_eie <= wdata_i[11];
                        end else begin
                            mie_tie <= mie_tie;
                            mie_sie <= mie_sie;
                            mie_eie <= mie_eie;
                        end                                                    
                    end
                    `MTVEC: begin
                        mtvec <= wdata_i;
                    end
                    `MSCRATCH: begin                            
                        mscratch <= wdata_i;
                    end
                    `MEPC: begin             
                        mepc <= {wdata_i[31:2], 2'b00};
                    end
                    `MCAUSE: begin
                        mcause_interrupt <= wdata_i[31];
                        mcause_exc_code  <= wdata_i[30:0];                 
                    end
                    default: begin
                        // do nothing
                    end
                endcase
            end else begin
                case (raddr_i)
                    `MSTATUS:  rdata_o <= mstatus;
                    `MIE:      rdata_o <= mie;
                    `MIP:      rdata_o <= mip;
                    `MTVEC:    rdata_o <= mtvec;
                    `MSCRATCH: rdata_o <= mscratch;
                    `MEPC:     rdata_o <= mepc;
                    `MCAUSE:   rdata_o <= mcause;
                    default: begin
                        // do nothing
                    end
                endcase
            end
            
            // `MIP: begin
            //     mip_tip <= timer_i;
            //     mip_sip <= softwire_i;
            //     mip_eip <= external_i;
            // end
        end
    end
endmodule