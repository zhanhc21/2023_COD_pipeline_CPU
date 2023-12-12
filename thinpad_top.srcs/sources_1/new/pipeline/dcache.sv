module dcache #(
    parameter NUM_ENTRIES = 64,
    parameter TABLE_LENGTH = 6
) (
    input wire clk_i,
    input wire rst_i,

    // signals from MEM stage
    input wire [31:0] mem_wb_addr_i,
    input wire [31:0] mem_wb_data_i,
    input wire [ 3:0] mem_wb_sel_i,
    input wire        mem_is_store_i,  // 1: store
    input wire        mem_is_load_i,  // 1: load
    input wire        mem_data_is_from_load_i,  // 1: load first time, means data is clean

    // need write back
    output reg [31:0] mem_write_back_addr_o,
    output reg [31:0] mem_write_back_data_o,
    output reg [ 3:0] mem_write_back_sel_o,
    output reg        mem_write_back_en_o,

    // load from dcache
    output reg        mem_hit_o,
    output reg [31:0] mem_load_data_o
);
    reg [31:0]  wb_addr_reg [NUM_ENTRIES-1:0];
    reg [31:0]  wb_data_reg [NUM_ENTRIES-1:0];
    reg [ 3:0]   wb_sel_reg [NUM_ENTRIES-1:0];
    reg        wb_valid_reg [NUM_ENTRIES-1:0];
    reg        wb_dirty_reg [NUM_ENTRIES-1:0];

    reg [TABLE_LENGTH-1:0] mem_addr_hash_reg;
    reg [31:0] mem_wb_addr_i_align_reg;

    reg [31:0]  mem_find_addr_reg;
    reg [31:0]  mem_find_data_reg;
    reg [ 3:0]   mem_find_sel_reg;
    reg        mem_find_valid_reg;
    reg        mem_find_dirty_reg;

    integer i;

    always_comb begin
        mem_addr_hash_reg = mem_wb_addr_i[TABLE_LENGTH+1:2];
        mem_wb_addr_i_align_reg = {mem_wb_addr_i[31:2], 2'b00};
        
        mem_find_addr_reg = wb_addr_reg[mem_addr_hash_reg];
        mem_find_data_reg = wb_data_reg[mem_addr_hash_reg];
        mem_find_sel_reg = wb_sel_reg[mem_addr_hash_reg];
        mem_find_valid_reg = wb_valid_reg[mem_addr_hash_reg];
        mem_find_dirty_reg = wb_dirty_reg[mem_addr_hash_reg];
    end

    // TODO: we have sb/lb, be aware of address!
    always_ff @ (posedge clk_i) begin
        if (rst_i) begin
            for (i = 0; i < NUM_ENTRIES; i = i + 1) begin
                wb_addr_reg[i] <= 32'b0;
                wb_data_reg[i] <= 32'b0;
                wb_sel_reg[i] <= 4'b0;
                wb_valid_reg[i] <= 1'b0;
                wb_dirty_reg[i] <= 1'b0;
            end
        end else begin
            if (mem_is_store_i) begin
                if (mem_find_valid_reg != 1'b1) begin // warm up
                    wb_addr_reg[mem_addr_hash_reg] <= mem_wb_addr_i_align_reg;

                    case(mem_wb_sel_i)
                        4'b0001: begin
                            wb_data_reg[mem_addr_hash_reg] <= {
                                mem_find_data_reg[31:8], mem_wb_data_i[7:0]
                            };
                            wb_sel_reg[mem_addr_hash_reg] <= {
                                mem_find_sel_reg[3:1], 1'b1
                            };
                        end
                        4'b0010: begin
                            wb_data_reg[mem_addr_hash_reg] <= {
                                mem_find_data_reg[31:16], mem_wb_data_i[15:8], mem_find_data_reg[7:0]
                            };
                            wb_sel_reg[mem_addr_hash_reg] <= {
                                mem_find_sel_reg[3:2], 1'b1, mem_find_sel_reg[0]
                            };
                        end
                        4'b0100: begin
                            wb_data_reg[mem_addr_hash_reg] <= {
                                mem_find_data_reg[31:24], mem_wb_data_i[23:16], mem_find_data_reg[15:0]
                            };
                            wb_sel_reg[mem_addr_hash_reg] <= {
                                mem_find_sel_reg[3], 1'b1, mem_find_sel_reg[1:0]
                            };
                        end
                        4'b1000: begin
                            wb_data_reg[mem_addr_hash_reg] <= {
                                mem_wb_data_i[31:24], mem_find_data_reg[23:0]
                            };
                            wb_sel_reg[mem_addr_hash_reg] <= {
                                1'b1, mem_find_sel_reg[2:0]
                            };
                        end
                        default: begin
                            wb_data_reg[mem_addr_hash_reg] <= mem_wb_data_i;
                            wb_sel_reg[mem_addr_hash_reg] <= 4'b1111;
                        end
                    endcase

                    wb_valid_reg[mem_addr_hash_reg] <= 1'b1;
                    if (mem_data_is_from_load_i) begin
                        wb_dirty_reg[mem_addr_hash_reg] <= 1'b0;
                    end else begin
                        wb_dirty_reg[mem_addr_hash_reg] <= 1'b1;
                    end
                end else if (mem_find_addr_reg != mem_wb_addr_i_align_reg) begin // conflict
                    wb_addr_reg[mem_addr_hash_reg] <= mem_wb_addr_i_align_reg;
                    
                    case(mem_wb_sel_i)
                        4'b0001: begin
                            wb_data_reg[mem_addr_hash_reg] <= {
                                mem_find_data_reg[31:8], mem_wb_data_i[7:0]
                            };
                            wb_sel_reg[mem_addr_hash_reg] <= {
                                mem_find_sel_reg[3:1], 1'b1
                            };
                        end
                        4'b0010: begin
                            wb_data_reg[mem_addr_hash_reg] <= {
                                mem_find_data_reg[31:16], mem_wb_data_i[15:8], mem_find_data_reg[7:0]
                            };
                            wb_sel_reg[mem_addr_hash_reg] <= {
                                mem_find_sel_reg[3:2], 1'b1, mem_find_sel_reg[0]
                            };
                        end
                        4'b0100: begin
                            wb_data_reg[mem_addr_hash_reg] <= {
                                mem_find_data_reg[31:24], mem_wb_data_i[23:16], mem_find_data_reg[15:0]
                            };
                            wb_sel_reg[mem_addr_hash_reg] <= {
                                mem_find_sel_reg[3], 1'b1, mem_find_sel_reg[1:0]
                            };
                        end
                        4'b1000: begin
                            wb_data_reg[mem_addr_hash_reg] <= {
                                mem_wb_data_i[31:24], mem_find_data_reg[23:0]
                            };
                            wb_sel_reg[mem_addr_hash_reg] <= {
                                1'b1, mem_find_sel_reg[2:0]
                            };
                        end
                        default: begin
                            wb_data_reg[mem_addr_hash_reg] <= mem_wb_data_i;
                            wb_sel_reg[mem_addr_hash_reg] <= 4'b1111;
                        end
                    endcase

                    wb_valid_reg[mem_addr_hash_reg] <= 1'b1;
                    if (mem_data_is_from_load_i) begin
                        wb_dirty_reg[mem_addr_hash_reg] <= 1'b0;
                    end else begin
                        wb_dirty_reg[mem_addr_hash_reg] <= 1'b1;
                    end
                end else begin // means hit, TODO: check data to decide dirty tag (0 if same)
                    wb_addr_reg[mem_addr_hash_reg] <= mem_wb_addr_i_align_reg;
                    
                    case(mem_wb_sel_i)
                        4'b0001: begin
                            wb_data_reg[mem_addr_hash_reg] <= {
                                mem_find_data_reg[31:8], mem_wb_data_i[7:0]
                            };
                            wb_sel_reg[mem_addr_hash_reg] <= {
                                mem_find_sel_reg[3:1], 1'b1
                            };
                        end
                        4'b0010: begin
                            wb_data_reg[mem_addr_hash_reg] <= {
                                mem_find_data_reg[31:16], mem_wb_data_i[15:8], mem_find_data_reg[7:0]
                            };
                            wb_sel_reg[mem_addr_hash_reg] <= {
                                mem_find_sel_reg[3:2], 1'b1, mem_find_sel_reg[0]
                            };
                        end
                        4'b0100: begin
                            wb_data_reg[mem_addr_hash_reg] <= {
                                mem_find_data_reg[31:24], mem_wb_data_i[23:16], mem_find_data_reg[15:0]
                            };
                            wb_sel_reg[mem_addr_hash_reg] <= {
                                mem_find_sel_reg[3], 1'b1, mem_find_sel_reg[1:0]
                            };
                        end
                        4'b1000: begin
                            wb_data_reg[mem_addr_hash_reg] <= {
                                mem_wb_data_i[31:24], mem_find_data_reg[23:0]
                            };
                            wb_sel_reg[mem_addr_hash_reg] <= {
                                1'b1, mem_find_sel_reg[2:0]
                            };
                        end
                        default: begin
                            wb_data_reg[mem_addr_hash_reg] <= mem_wb_data_i;
                            wb_sel_reg[mem_addr_hash_reg] <= 4'b1111;
                        end
                    endcase

                    wb_valid_reg[mem_addr_hash_reg] <= 1'b1;
                    wb_dirty_reg[mem_addr_hash_reg] <= 1'b1;
                end
            end
        end
    end

    always_comb begin
        if (mem_is_store_i) begin
            if (mem_find_valid_reg != 1'b1) begin // warm up
                mem_write_back_addr_o = 32'b0;
                mem_write_back_data_o = 32'b0;
                mem_write_back_sel_o = 4'b0;
                mem_write_back_en_o = 1'b0;

                mem_hit_o = 1'b0;
                mem_load_data_o = 32'b0;
            end else if (mem_find_addr_reg != mem_wb_addr_i_align_reg) begin
                if (mem_find_dirty_reg == 1'b0) begin // clean, didn't change
                    mem_write_back_addr_o = 32'b0;
                    mem_write_back_data_o = 32'b0;
                    mem_write_back_sel_o = 4'b0;
                    mem_write_back_en_o = 1'b0;
                end else begin // changed, need to write back
                    if (mem_find_sel_reg[0] == 1'b1) begin
                        mem_write_back_addr_o = wb_addr_reg[mem_addr_hash_reg];
                    end else if (mem_find_sel_reg[1] == 1'b1) begin
                        mem_write_back_addr_o = wb_addr_reg[mem_addr_hash_reg] + 32'd1;
                    end else if (mem_find_sel_reg[2] == 1'b1) begin
                        mem_write_back_addr_o = wb_addr_reg[mem_addr_hash_reg] + 32'd2;
                    end else begin
                        mem_write_back_addr_o = wb_addr_reg[mem_addr_hash_reg] + 32'd3;
                    end

                    mem_write_back_data_o = wb_data_reg[mem_addr_hash_reg];
                    mem_write_back_sel_o = wb_sel_reg[mem_addr_hash_reg];
                    mem_write_back_en_o = 1'b1;
                end

                mem_hit_o = 1'b0;
                mem_load_data_o = 32'b0;
            end else begin
                mem_write_back_addr_o = 32'b0;
                mem_write_back_data_o = 32'b0;
                mem_write_back_sel_o = 4'b0;
                mem_write_back_en_o = 1'b0;

                mem_hit_o = 1'b0;
                mem_load_data_o = 32'b0;
            end
        end else if (mem_is_load_i) begin
            if (mem_find_valid_reg != 1'b1) begin // didn't warm up
                mem_write_back_addr_o = 32'b0;
                mem_write_back_data_o = 32'b0;
                mem_write_back_sel_o = 4'b0;
                mem_write_back_en_o = 1'b0;

                mem_hit_o = 1'b0; // didn't hit
                mem_load_data_o = 32'b0;
            end else if (mem_find_addr_reg != mem_wb_addr_i_align_reg) begin
                if (mem_find_dirty_reg == 1'b0) begin // load new data
                    mem_write_back_addr_o = 32'b0;
                    mem_write_back_data_o = 32'b0;
                    mem_write_back_sel_o = 4'b0;
                    mem_write_back_en_o = 1'b0;
                end else begin // important! first write back, then load new data
                    if (mem_find_sel_reg[0] == 1'b1) begin
                        mem_write_back_addr_o = wb_addr_reg[mem_addr_hash_reg];
                    end else if (mem_find_sel_reg[1] == 1'b1) begin
                        mem_write_back_addr_o = wb_addr_reg[mem_addr_hash_reg] + 32'd1;
                    end else if (mem_find_sel_reg[2] == 1'b1) begin
                        mem_write_back_addr_o = wb_addr_reg[mem_addr_hash_reg] + 32'd2;
                    end else begin
                        mem_write_back_addr_o = wb_addr_reg[mem_addr_hash_reg] + 32'd3;
                    end

                    mem_write_back_data_o = wb_data_reg[mem_addr_hash_reg];
                    mem_write_back_sel_o = wb_sel_reg[mem_addr_hash_reg];
                    mem_write_back_en_o = 1'b1;
                end

                mem_hit_o = 1'b0; // didn't hit
                mem_load_data_o = 32'b0;
            end else begin // compare sel!
                case(mem_wb_sel_i)
                    4'b0001: begin
                        if (mem_find_sel_reg[0] == 1'b1) begin
                            mem_hit_o = 1'b1;
                        end else begin
                            mem_hit_o = 1'b0;
                        end
                    end
                    4'b0010: begin
                        if (mem_find_sel_reg[1] == 1'b1) begin
                            mem_hit_o = 1'b1;
                        end else begin
                            mem_hit_o = 1'b0;
                        end
                    end
                    4'b0100: begin
                        if (mem_find_sel_reg[2] == 1'b1) begin
                            mem_hit_o = 1'b1;
                        end else begin
                            mem_hit_o = 1'b0;
                        end
                    end
                    4'b1000: begin
                        if (mem_find_sel_reg[3] == 1'b1) begin
                            mem_hit_o = 1'b1;
                        end else begin
                            mem_hit_o = 1'b0;
                        end
                    end
                    default: begin
                        if (mem_find_sel_reg == 4'b1111) begin
                            mem_hit_o = 1'b1;
                        end else begin
                            mem_hit_o = 1'b0;
                        end
                    end
                endcase

                if (mem_hit_o == 1'b1) begin
                    mem_write_back_addr_o = 32'b0;
                    mem_write_back_data_o = 32'b0;
                    mem_write_back_sel_o = 4'b0;
                    mem_write_back_en_o = 1'b0;

                    mem_load_data_o = wb_data_reg[mem_addr_hash_reg];
                end else begin
                    if (mem_find_dirty_reg == 1'b0) begin // load new data
                        mem_write_back_addr_o = 32'b0;
                        mem_write_back_data_o = 32'b0;
                        mem_write_back_sel_o = 4'b0;
                        mem_write_back_en_o = 1'b0;
                    end else begin // important! first write back, then load new data
                        if (mem_find_sel_reg[0] == 1'b1) begin
                            mem_write_back_addr_o = wb_addr_reg[mem_addr_hash_reg];
                        end else if (mem_find_sel_reg[1] == 1'b1) begin
                            mem_write_back_addr_o = wb_addr_reg[mem_addr_hash_reg] + 32'd1;
                        end else if (mem_find_sel_reg[2] == 1'b1) begin
                            mem_write_back_addr_o = wb_addr_reg[mem_addr_hash_reg] + 32'd2;
                        end else begin
                            mem_write_back_addr_o = wb_addr_reg[mem_addr_hash_reg] + 32'd3;
                        end

                        mem_write_back_data_o = wb_data_reg[mem_addr_hash_reg];
                        mem_write_back_sel_o = wb_sel_reg[mem_addr_hash_reg];
                        mem_write_back_en_o = 1'b1;
                    end

                    mem_load_data_o = 32'b0;
                end
            end
        end else begin
            mem_write_back_addr_o = 32'b0;
            mem_write_back_data_o = 32'b0;
            mem_write_back_sel_o = 4'b0;
            mem_write_back_en_o = 1'b0;

            mem_hit_o = 1'b0;
            mem_load_data_o = 32'b0;
        end
    end

endmodule