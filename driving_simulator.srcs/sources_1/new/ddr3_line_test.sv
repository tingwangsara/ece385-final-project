module ddr3_line_test (
    input  logic        ui_clk,
    input  logic        ui_rst,
    input  logic        init_calib_complete,

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

    output logic [7:0]  debug_beat_count,
    output logic [3:0]  debug_state
);

    localparam int BURSTS_PER_LINE = 80;
    localparam int BEATS_PER_LINE  = 160;

    typedef enum logic [3:0] {
        S_IDLE,
        S_WRITE0,
        S_WRITE1,
        S_READ_CMD,
        S_WAIT_READS,
        S_DONE
    } state_t;

    state_t state;

    logic [6:0] wr_burst_idx;
    logic [6:0] rd_burst_idx;
    logic [7:0] rd_beat_count;

    assign debug_beat_count = rd_beat_count;
    assign debug_state = state;

    function automatic logic [15:0] pix(input logic [9:0] x);
        logic [11:0] rgb;
        begin
            rgb = {x[7:4], x[6:3], 4'hF};
            pix = {4'h0, rgb};
        end
    endfunction

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

        case (state)
            S_WRITE0: begin
                if (app_rdy && app_wdf_rdy) begin
                    app_addr     = {wr_burst_idx, 3'b000};
                    app_cmd      = 3'b000;
                    app_en       = 1'b1;

                    app_wdf_wren = 1'b1;
                    app_wdf_end  = 1'b0;
                    app_wdf_data = {
                        pix(wr_burst_idx * 8 + 3),
                        pix(wr_burst_idx * 8 + 2),
                        pix(wr_burst_idx * 8 + 1),
                        pix(wr_burst_idx * 8 + 0)
                    };
                end
            end

            S_WRITE1: begin
                if (app_wdf_rdy) begin
                    app_wdf_wren = 1'b1;
                    app_wdf_end  = 1'b1;
                    app_wdf_data = {
                        pix(wr_burst_idx * 8 + 7),
                        pix(wr_burst_idx * 8 + 6),
                        pix(wr_burst_idx * 8 + 5),
                        pix(wr_burst_idx * 8 + 4)
                    };
                end
            end

            S_READ_CMD: begin
                if (app_rdy && rd_burst_idx < BURSTS_PER_LINE) begin
                    app_addr = {rd_burst_idx, 3'b000};
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
            state         <= S_IDLE;
            wr_burst_idx  <= 7'd0;
            rd_burst_idx  <= 7'd0;
            rd_beat_count <= 8'd0;
            done          <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    wr_burst_idx  <= 7'd0;
                    rd_burst_idx  <= 7'd0;
                    rd_beat_count <= 8'd0;
                    done          <= 1'b0;
                    state         <= S_WRITE0;
                end

                S_WRITE0: begin
                    if (app_rdy && app_wdf_rdy)
                        state <= S_WRITE1;
                end

                S_WRITE1: begin
                    if (app_wdf_rdy) begin
                        if (wr_burst_idx == BURSTS_PER_LINE - 1) begin
                            wr_burst_idx <= 7'd0;
                            rd_burst_idx <= 7'd0;
                            rd_beat_count <= 8'd0;
                            state <= S_READ_CMD;
                        end else begin
                            wr_burst_idx <= wr_burst_idx + 7'd1;
                            state <= S_WRITE0;
                        end
                    end
                end

                S_READ_CMD: begin
                    if (app_rdy && rd_burst_idx < BURSTS_PER_LINE)
                        rd_burst_idx <= rd_burst_idx + 7'd1;

                    if (app_rd_data_valid) begin
                        if (rd_beat_count == BEATS_PER_LINE - 1) begin
                            done <= 1'b1;
                            state <= S_DONE;
                        end else begin
                            rd_beat_count <= rd_beat_count + 8'd1;
                        end
                    end

                    if (rd_burst_idx == BURSTS_PER_LINE && !done)
                        state <= S_WAIT_READS;
                end

                S_WAIT_READS: begin
                    if (app_rd_data_valid) begin
                        if (rd_beat_count == BEATS_PER_LINE - 1) begin
                            done <= 1'b1;
                            state <= S_DONE;
                        end else begin
                            rd_beat_count <= rd_beat_count + 8'd1;
                        end
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule