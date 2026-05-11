`timescale 1ns / 1ps

module road_curve_scan(
    input  logic clk,
    input  logic reset,
    input  logic frame_clk,

    input  logic [15:0] player_dist,
    input  logic signed [9:0] player_x,
    input  logic [8:0] query_y,

    output logic signed [15:0] road_center,
    output logic signed [15:0] center_lut_out [0:479]
);

    localparam int SCREEN_H = 480;
    localparam int HORIZON  = 200;
    localparam int ROAD_FULLY_Y = 360;
    localparam int CENTER_X = 320;

    localparam int DRAW_SEGMENTS = 1024;
    localparam int SEG_STEP      = 8;
    localparam int CURVE_SHIFT   = 6;

    logic signed [15:0] center_lut [0:SCREEN_H-1];

    logic frame_d;
    logic scanning;

    logic [10:0] seg_n;
    logic [8:0] curr_y;
    logic [8:0] prev_y;

    logic signed [31:0] x_acc;
    logic signed [31:0] dx_acc;

    logic [17:0] seg_dist;
    logic [10:0] lut_idx;

    logic signed [15:0] curve;
    logic [15:0] depth_unused;
    logic [15:0] road_width_unused;
    logic [7:0] scenery_unused;
    logic [7:0] object_unused;

    logic signed [31:0] bottom_center;
    logic signed [31:0] center_tmp;

    function automatic [8:0] seg_to_y(input [10:0] n);
        logic [31:0] y_tmp;
        begin
            y_tmp = HORIZON + (32'd1024 / (n + 16));
    
            if (y_tmp > ROAD_FULLY_Y)
                seg_to_y = ROAD_FULLY_Y[8:0];
            else if (y_tmp < HORIZON)
                seg_to_y = HORIZON[8:0];
            else
                seg_to_y = y_tmp[8:0];
        end
    endfunction

    assign curr_y   = seg_to_y(seg_n);
    assign seg_dist = {2'b00, player_dist} + (seg_n * SEG_STEP);
    assign lut_idx  = seg_dist[13:3];

    world_lut scan_lut(
        .dist_addr(lut_idx),
        .y_addr(curr_y),
        .depth(depth_unused),
        .curve(curve),
        .road_width(road_width_unused),
        .scenery(scenery_unused),
        .object_type(object_unused)
    );

    integer i;

    always_ff @(posedge clk or posedge reset)
    begin
        if (reset)
        begin
            frame_d  <= 1'b0;
            scanning <= 1'b0;
            seg_n    <= 11'd0;
            prev_y   <= ROAD_FULLY_Y[8:0];
            x_acc    <= 32'sd0;
            dx_acc   <= 32'sd0;

            for (i = 0; i < SCREEN_H; i = i + 1)
                center_lut[i] <= CENTER_X;
        end
        else
        begin
            frame_d <= frame_clk;

            // start once per frame
            if (frame_clk && !frame_d)
            begin
                scanning <= 1'b1;
                seg_n    <= 11'd0;
                prev_y   <= ROAD_FULLY_Y[8:0];
                x_acc    <= 32'sd0;
                dx_acc   <= 32'sd0;

                for (i = 0; i < SCREEN_H; i = i + 1)
                    center_lut[i] <= CENTER_X;
            end
            else if (scanning)
            begin
                bottom_center = CENTER_X;
                center_tmp = bottom_center + (x_acc >>> CURVE_SHIFT);

                // curr_y goes from bottom toward horizon
                for (i = 0; i < SCREEN_H; i = i + 1)
                begin
                    if ((i >= curr_y) && (i <= prev_y))
                        center_lut[i] <= center_tmp[15:0];
                end

                x_acc  <= x_acc + dx_acc;
                dx_acc <= dx_acc + $signed(curve);

                prev_y <= curr_y;
                seg_n  <= seg_n + 1'b1;

                if ((seg_n >= DRAW_SEGMENTS - 1) || (curr_y <= HORIZON))
                    scanning <= 1'b0;
            end
        end
    end

    always_comb
    begin
        if (query_y < HORIZON)
            road_center = CENTER_X;
        else if (query_y > ROAD_FULLY_Y)
            road_center = center_lut[ROAD_FULLY_Y];
        else
            road_center = center_lut[query_y];
            
        center_lut_out = center_lut;
    end

endmodule