module btb #(
    parameter NUM_ENTRIES = 64,
    parameter TABLE_LENGTH = 6
) (
    input wire clk_i,
    input wire rst_i,

    // signals from EXE stage
    input wire [31:0] exe_branch_src_pc_i,
    input wire [31:0] exe_branch_tgt_pc_i,
    input wire        exe_branch_en_i, // 1: take a branch
    input wire        exe_branch_mispred_i,  // 1: mispredict
    
    // signals from IF stage
    input wire [31:0] if_now_pc_i,
    
    output reg [31:0] if_next_pc_o,
    output reg        if_hit_o,
    output reg        exe_branch_taken_o
);

    reg [31:0]  src_pc_reg [NUM_ENTRIES-1:0];
    reg [31:0]  tgt_pc_reg [NUM_ENTRIES-1:0];
    reg [ 1:0] predict_reg [NUM_ENTRIES-1:0];
    reg          valid_reg [NUM_ENTRIES-1:0];

    reg [TABLE_LENGTH-1:0] exe_pc_hash_reg;
    reg [TABLE_LENGTH-1:0] if_pc_hash_reg;

    reg [31:0] exe_find_src_reg;
    reg [31:0] exe_find_tgt_reg;
    reg [ 1:0] exe_find_pred_reg;
    reg        exe_find_valid_reg;

    reg [31:0] if_find_src_reg;
    reg [31:0] if_find_tgt_reg;
    reg [ 1:0] if_find_pred_reg;
    reg        if_find_valid_reg;

    reg [31:0] if_next_pc_reg;

    integer i;

    always_comb begin
        exe_pc_hash_reg = exe_branch_src_pc_i[TABLE_LENGTH+1:2];
        if_pc_hash_reg = if_now_pc_i[TABLE_LENGTH+1:2];

        exe_find_src_reg = src_pc_reg[exe_pc_hash_reg];
        exe_find_tgt_reg = tgt_pc_reg[exe_pc_hash_reg];
        exe_find_pred_reg = predict_reg[exe_pc_hash_reg];
        exe_find_valid_reg = valid_reg[exe_pc_hash_reg];

        if_find_src_reg = src_pc_reg[if_pc_hash_reg];
        if_find_tgt_reg = tgt_pc_reg[if_pc_hash_reg];
        if_find_pred_reg = predict_reg[if_pc_hash_reg];
        if_find_valid_reg = valid_reg[if_pc_hash_reg];
    end

    always_ff @ (posedge clk_i) begin
        if (rst_i) begin
            for (i = 0; i < NUM_ENTRIES; i = i + 1) begin
                src_pc_reg[i] <= 32'd0;
                tgt_pc_reg[i] <= 32'd0;
                valid_reg[i] <= 1'b0;
                predict_reg[i] <= 2'b0;
            end
        end else begin
            if (exe_branch_en_i) begin
                src_pc_reg[exe_pc_hash_reg] <= exe_branch_src_pc_i;
                tgt_pc_reg[exe_pc_hash_reg] <= exe_branch_tgt_pc_i;
                valid_reg[exe_pc_hash_reg] <= 1'b1;

                if (exe_branch_mispred_i) begin
                    case(exe_find_pred_reg)
                        2'b00: begin
                            predict_reg[exe_pc_hash_reg] <= 2'b01;
                        end
                        2'b01: begin
                            predict_reg[exe_pc_hash_reg] <= 2'b11;
                        end
                        2'b11: begin
                            predict_reg[exe_pc_hash_reg] <= 2'b10;
                        end
                        2'b10: begin
                            predict_reg[exe_pc_hash_reg] <= 2'b00;
                        end
                    endcase
                end else begin
                    case(exe_find_pred_reg)
                        2'b00: begin
                            predict_reg[exe_pc_hash_reg] <= 2'b00;
                        end
                        2'b01: begin
                            predict_reg[exe_pc_hash_reg] <= 2'b00;
                        end
                        2'b11: begin
                            predict_reg[exe_pc_hash_reg] <= 2'b11;
                        end
                        2'b10: begin
                            predict_reg[exe_pc_hash_reg] <= 2'b11;
                        end
                    endcase
                end
            end
        end
    end

    always_comb begin
        if (exe_find_valid_reg == 1'b1 && exe_find_src_reg == exe_branch_src_pc_i && exe_find_tgt_reg == exe_branch_tgt_pc_i) begin
            if (exe_find_pred_reg[1] == 1'b0) begin
                exe_branch_taken_o = 1'b0;
            end else begin
                exe_branch_taken_o = 1'b1;
            end
        end else begin
            exe_branch_taken_o = 1'b0;
        end
    end

    always_comb begin
        if (if_find_valid_reg == 1'b1 && if_find_src_reg == if_now_pc_i) begin
            if (if_find_pred_reg[1] == 1'b0) begin  // predict branch not taken
                if_next_pc_reg = if_now_pc_i + 32'd4;
                if_hit_o = 1'b0;
            end else begin  // predict branch taken
                if_next_pc_reg = if_find_tgt_reg;
                if_hit_o = 1'b1;
            end
        end else begin  // not hit
            if_next_pc_reg = if_now_pc_i + 32'd4;
            if_hit_o = 1'b0;
        end
    end

    assign if_next_pc_o = if_next_pc_reg;
endmodule