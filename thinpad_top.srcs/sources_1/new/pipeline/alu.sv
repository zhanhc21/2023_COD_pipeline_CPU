module alu (
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [3:0] op,
    output wire [31:0] y
);
    logic [31:0] logic_y;
    logic [31:0] mod_b;
    always_comb begin
        mod_b = b & 32'd31;
        case (op)
            4'd1  : logic_y = a + b;
            4'd2  : logic_y = a - b;
            4'd3  : logic_y = a & b;
            4'd4  : logic_y = a | b;
            4'd5  : logic_y = a ^ b;
            4'd6  : logic_y = ~ a;
            4'd7  : logic_y = a << mod_b;
            4'd8  : logic_y = a >> mod_b;
            4'd9  : logic_y = $signed(a) >>> mod_b;
            4'd10 : logic_y = (a << mod_b) | (a >> (16-mod_b));
            4'd11 : logic_y = a & ~b;
            4'd12 : logic_y = a | (32'h1 << (b & 32'h1f));
            4'd13 : logic_y = (a < b) ? a : b;
            4'd14 : logic_y = (a < b) ? 32'd1 : 32'd0;
            default : logic_y = 32'd0;
        endcase
    end
    assign y = logic_y;
endmodule