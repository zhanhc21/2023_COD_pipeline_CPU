module reg_file (
    input wire clk,
    input wire reset,

    input wire [4:0] waddr,
    input wire [31:0] wdata,
    input wire we,
    input wire [4:0] raddr_a,
    input wire [4:0] raddr_b,

    output wire [31:0] rdata_a,
    output wire [31:0] rdata_b
);  
    reg [31:0] regs [0:31];

    always_ff @ (posedge clk or posedge reset) begin
        if (reset) begin
            int i;
            for (i=0; i<32; i++)
                regs[i] <= 16'd0;
        end else if (we && waddr != 16'd0) begin
            regs[waddr] <= wdata;
        end
    end
    assign rdata_a = regs[raddr_a];
    assign rdata_b = regs[raddr_b];
endmodule