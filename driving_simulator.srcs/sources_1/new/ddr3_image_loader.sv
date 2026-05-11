module ddr3_image_loader (
    input  logic        ui_clk,
    input  logic        ui_rst,
    input  logic        init_calib_complete,

    input  logic [63:0] img_word64,
    input  logic        img_valid_pulse,
    input  logic        img_load_done,

    output logic [26:0] app_addr,
    output logic [2:0]  app_cmd,
    output logic        app_en,
    input  logic        app_rdy,

    output logic [63:0] app_wdf_data,
    output logic        app_wdf_end,
    output logic        app_wdf_wren,
    output logic [7:0]  app_wdf_mask,
    input  logic        app_wdf_rdy,

    input  logic [63:0] app_rd_data,
    input  logic        app_rd_data_valid,
    input  logic        app_rd_data_end,

    output logic        lb_we,
    output logic [7:0]  lb_waddr,
    output logic [63:0] lb_wdata,

    output logic        done,

    output logic        debug_word_seen,
    output logic        debug_burst_written,
    output logic        debug_read_started,
    output logic [3:0]  debug_state,
    
    input  logic [9:0] read_line_y,
    input  logic [8:0] read_x_word_offset,
    input  logic       read_line_req,
    output logic       line_ready,
    output logic [9:0] line_ready_y
);

    localparam int WORDS_PER_LINE  = 160;
    localparam int BURSTS_PER_LINE = 80;
    localparam int TOTAL_BURSTS    = 51200;
    localparam int IMAGE_H = 200;
    localparam int TOTAL_LINES = 200;

    typedef enum logic [3:0] {
        S_IDLE,
        S_WAIT_WORD0,
        S_WAIT_WORD1,
        S_WRITE0,
        S_WRITE1,
        S_WAIT_LOAD_DONE,
        S_READ_CMD,
        S_WAIT_READS,
        S_DONE
    } state_t;

    state_t state;

    logic [63:0] word0, word1;
    logic [15:0] wr_burst_idx;
    logic [6:0]  rd_burst_idx;
    logic [7:0]  rd_beat_count;

    assign debug_state = state;
    
    logic [15:0] read_base_burst;
    logic [9:0]  latched_line_y;
    
    logic [9:0] read_line_idx;
    
    logic read_req_sync0, read_req_sync1, read_req_prev;
    logic read_line_pulse;
    logic [9:0] read_line_y_sync0, read_line_y_sync1;
    
    always_ff @(posedge ui_clk or posedge ui_rst) begin
        if (ui_rst) begin
            read_req_sync0 <= 1'b0;
            read_req_sync1 <= 1'b0;
            read_req_prev  <= 1'b0;
            read_line_y_sync0 <= 10'd0;
            read_line_y_sync1 <= 10'd0;
        end else begin
            read_req_sync0 <= read_line_req;
            read_req_sync1 <= read_req_sync0;
            read_req_prev  <= read_req_sync1;
    
            read_line_y_sync0 <= read_line_y;
            read_line_y_sync1 <= read_line_y_sync0;
        end
    end
    
    assign read_line_pulse = read_req_sync1 ^ read_req_prev;

    always_comb begin
        app_addr     = 27'd0;
        app_cmd      = 3'b000;
        app_en       = 1'b0;

        app_wdf_data = 64'd0;
        app_wdf_end  = 1'b0;
        app_wdf_wren = 1'b0;
        app_wdf_mask = 8'd0;

        lb_we        = 1'b0;
        lb_waddr     = rd_beat_count;
        lb_wdata     = app_rd_data;
        
//        read_base_burst = (latched_line_y << 6) + (latched_line_y << 4);
        read_base_burst = (latched_line_y << 8) + (read_x_word_offset << 1);

        case (state)
            S_WRITE0: begin
                if (app_rdy && app_wdf_rdy) begin
                    app_addr     = {wr_burst_idx, 3'b000};
                    app_cmd      = 3'b000;
                    app_en       = 1'b1;

                    app_wdf_data = word0;
                    app_wdf_wren = 1'b1;
                    app_wdf_end  = 1'b0;
                end
            end

            S_WRITE1: begin
                if (app_wdf_rdy) begin
                    app_wdf_data = word1;
                    app_wdf_wren = 1'b1;
                    app_wdf_end  = 1'b1;
                end
            end

            S_READ_CMD: begin
                if (app_rdy && rd_burst_idx < BURSTS_PER_LINE) begin
                    app_addr = {(read_base_burst + rd_burst_idx), 3'b000};
                    app_cmd  = 3'b001;
                    app_en   = 1'b1;
                end

                if (app_rd_data_valid) begin
                    lb_we    = 1'b1;
                    lb_waddr = rd_beat_count;
                    lb_wdata = app_rd_data;
                end
            end

            S_WAIT_READS: begin
                if (app_rd_data_valid) begin
                    lb_we    = 1'b1;
                    lb_waddr = rd_beat_count;
                    lb_wdata = app_rd_data;
                end
            end

            default: begin
            end
        endcase
    end

    always_ff @(posedge ui_clk) begin
        if (ui_rst || !init_calib_complete) begin
            state               <= S_IDLE;
            word0               <= 64'd0;
            word1               <= 64'd0;
            wr_burst_idx        <= 15'd0;
            rd_burst_idx        <= 7'd0;
            rd_beat_count       <= 8'd0;
            done                <= 1'b0;
            debug_word_seen     <= 1'b0;
            debug_burst_written <= 1'b0;
            debug_read_started  <= 1'b0;
            read_line_idx <= 10'd0;
            latched_line_y      <= 10'd0;
            line_ready   <= 1'b0;
            line_ready_y <= 10'd0;
        end else begin
            done <= 1'b0;
            
            case (state)
                S_IDLE: begin
                    word0         <= 64'd0;
                    word1         <= 64'd0;
                    wr_burst_idx  <= 15'd0;
                    rd_burst_idx  <= 7'd0;
                    rd_beat_count <= 8'd0;
                    done          <= 1'b0;
                    state         <= S_WAIT_WORD0;
                end

                S_WAIT_WORD0: begin
                    if (img_load_done) begin
                        latched_line_y  <= 10'd0;
                        read_line_idx   <= 10'd0;
                        rd_burst_idx    <= 7'd0;
                        rd_beat_count   <= 8'd0;
                        debug_read_started <= 1'b1;
                        state <= S_READ_CMD;
                    end
                    else if (img_valid_pulse) begin
                        word0 <= img_word64;
                        debug_word_seen <= 1'b1;
                        state <= S_WAIT_WORD1;
                    end
                end

                S_WAIT_WORD1: begin
                    if (img_valid_pulse) begin
                        word1 <= img_word64;
                        debug_word_seen <= 1'b1;
                        state <= S_WRITE0;
                    end
                end

                S_WRITE0: begin
                    if (app_rdy && app_wdf_rdy)
                        state <= S_WRITE1;
                end

                S_WRITE1: begin
                    if (app_wdf_rdy) begin
                        debug_burst_written <= 1'b1;

                        if (wr_burst_idx == TOTAL_BURSTS - 1) begin
                            wr_burst_idx <= 15'd0;
                            state <= S_WAIT_LOAD_DONE;
                        end else begin
                            wr_burst_idx <= wr_burst_idx + 15'd1;
                            state <= S_WAIT_WORD0;
                        end
                    end
                end

                S_WAIT_LOAD_DONE: begin
                    if (img_load_done) begin
                        latched_line_y  <= 10'd0;
                        read_line_idx   <= 10'd0;
                        rd_burst_idx    <= 7'd0;
                        rd_beat_count   <= 8'd0;
                        debug_read_started <= 1'b1;
                        state <= S_READ_CMD;
                    end
                end

                S_READ_CMD: begin
                    if (app_rdy && rd_burst_idx < BURSTS_PER_LINE)
                        rd_burst_idx <= rd_burst_idx + 7'd1;
                
                    if (app_rd_data_valid) begin
                        if (rd_beat_count == WORDS_PER_LINE - 1) begin
                            line_ready   <= 1'b1;
                            line_ready_y <= latched_line_y;
                            done         <= 1'b1;
                            state        <= S_DONE;
                        end else begin
                            rd_beat_count <= rd_beat_count + 8'd1;
                
                            if (rd_burst_idx == BURSTS_PER_LINE)
                                state <= S_WAIT_READS;
                        end
                    end else begin
                        if (rd_burst_idx == BURSTS_PER_LINE)
                            state <= S_WAIT_READS;
                    end
                end

                S_WAIT_READS: begin
                    if (app_rd_data_valid) begin
                        if (rd_beat_count == WORDS_PER_LINE - 1) begin
                            line_ready <= 1'b1;
                            line_ready_y <= latched_line_y;
                            done <= 1'b1;
                            state <= S_DONE;
                        end else begin
                            rd_beat_count <= rd_beat_count + 8'd1;
                        end
                    end
                end

                S_DONE: begin
                    line_ready <= 1'b1;
                
                    if (read_line_pulse) begin
                        line_ready <= 1'b0;
                        latched_line_y <= read_line_y_sync1;
                        rd_burst_idx <= 7'd0;
                        rd_beat_count <= 8'd0;
                        state <= S_READ_CMD;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule