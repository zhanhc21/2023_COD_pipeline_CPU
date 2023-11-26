`default_nettype none

module imm_gen (
    input wire [31:0] inst,
    input wire [2:0] imm_gen_type,
    output reg [31:0] imm_gen_o
);

    typedef enum logic [2:0] {
        TYPE_R = 0,
        TYPE_I = 1,
        TYPE_S = 2,
        TYPE_B = 3,
        TYPE_U = 4,
        TYPE_J = 5
    } type_t;

    always_comb begin
        case(imm_gen_type)
            TYPE_I: begin
                imm_gen_o = {{21{inst[31]}}, inst[30:20]};
            end
            TYPE_S: begin
                imm_gen_o = {{21{inst[31]}}, inst[30:25], inst[11:8], inst[7]};
            end
            TYPE_B: begin
                imm_gen_o = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
            end
            TYPE_U: begin
                imm_gen_o = {inst[31:12], 12'b0};
            end
            TYPE_J: begin
                imm_gen_o = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
            end
            default: begin
                imm_gen_o = 32'b0;
            end
        endcase
    end

endmodule