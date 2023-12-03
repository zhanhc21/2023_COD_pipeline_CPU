module csr_regFile (
    input wire clk_i,
    input wire rst_i,

    // TODO 考虑发生在哪一阶段
    input wire [ 4:0] raddr_i;
    output reg [31:0] rdata_o;

    // TODO 考虑发生在哪一阶段
    input wire        we_i;
    input wire [ 4:0] waddr_i;
    input wire [31:0] wdata_i;

    
);
    logic [31:0] mtvec;
    logic [31:0] mscratch;
    logic [31:0] mepc;
    logic [31:0] mcause;
    logic [31:0] mstatus;
    logic [31:0] mie;
    logic [31:0] mip;

    logic [31:0] mtime;
    logic [31:0] mtimecmp;

    typedef enum logic [3:0] {
        MTVEC    = 0,
        MSCRATCH = 1,
        MEPC     = 2,
        MCAUSE   = 3,
        MSTATUS  = 4,
        MIE      = 5,
        MIP      = 6
    } reg_type_t;

    always_ff @ (posedge clk_i or posedge rst_i) begin
        if (rst_i) begin

        end else begin

        end
    end
endmodule