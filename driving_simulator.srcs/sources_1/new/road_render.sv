`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/15/2026 10:42:47 AM
// Design Name: 
// Module Name: road_render
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module road_render(
    input logic clk,
    input logic reset,
    input logic frame_clk,

    input logic [9:0] DrawX, DrawY,
    input logic [15:0] player_dist,
    input logic signed [11:0] player_x,

    output logic [7:0] red,
    output logic [7:0] green,
    output logic [7:0] blue,
    output logic signed [15:0] road_center_out,
    output logic [15:0] road_half_width_out,
    output logic [9:0] road_start_out,
    output logic [9:0] road_end_out,
    output logic off_road
);
    
    localparam int SCREEN_W = 640;
    localparam int SCREEN_H = 480;
    localparam int HORIZON = 200;
    localparam int CENTER_X = 320;
    
    localparam int ROAD_FULLY_Y = 360;
    
    localparam int TOP_ROAD_HALF_WIDTH = 16;
    localparam int BOTTOM_ROAD_HALF_WIDTH = 640;
    
    localparam int TOP_LANE_HALF_WIDTH = 1;
    localparam int BOTTOM_LANE_HALF_WIDTH = 6;
    
    localparam int FAR_SHIFT_GAIN = 2;
    
    localparam int BOTTOM_SHIFT_GAIN_NUM = 1;
    localparam int BOTTOM_sHIFT_GAIN_DEN = 4;
    
    localparam int FAR_CENTER_MIN = 60;
    localparam int FAR_CENTER_MAX = 580;
    
    localparam int DASH_PERIOD = 16'd64;
    localparam int DASH_ON = 16'd24;
    
    logic [15:0] depth, road_width_unused;
    logic signed [15:0] curve;
    logic [7:0] scenery, object_type;
    logic [11:0] lut_idx;
    
    
    logic [15:0] sample_dist, road_half_width, lane_half_width;
    logic signed [15:0] road_center, bottom_center, far_center;
    
    logic [15:0] t, t_max;
    
    logic in_road;
    logic in_lane_dash;
    logic dash_on;
    
    logic [15:0] dash_phase;
    
    logic [31:0] width_interp_tmp, lane_width_interp_tmp;
    logic signed [31:0] center_interp_tmp;
    
    logic [9:0] road_start, road_end;
    
    logic [15:0] t2;
    logic signed [31:0] curve_offset_tmp;
    logic signed [15:0] curve_offset;
    
    logic signed [15:0] road_start_real, road_end_real;
    logic signed [15:0] screen_road_center;
    logic [15:0] t_clamped;
    
    logic off_road_next;
    
    logic signed [31:0] player_shift_tmp;
    logic signed [15:0] player_shift;
    
    logic [15:0] curb_width;
    logic left_curb, right_curb, in_curb;
    logic curb_red;
    logic signed [15:0] left_curb_start, left_curb_end;
    logic signed [15:0] right_curb_start, right_curb_end;
    
    logic start_line_zone;
    logic checker_white;
    
    logic [9:0] road_x;

    
    world_lut lut_inst(
        .dist_addr(lut_idx),
        .y_addr(DrawY),
        .depth(depth),
        .curve(curve),
        .road_width(road_width_unused),
        .scenery(scenery),
        .object_type(object_type)
    );
    
    logic signed [15:0] scanned_road_center;

    road_curve_scan curve_scan_inst(
        .clk(clk),
        .reset(reset),
        .frame_clk(frame_clk),
        .player_dist(player_dist),
        .player_x(12'sd0),
        .query_y(DrawY[8:0]),
        .road_center(scanned_road_center)
    );
    
    always_comb
    begin
        red = 8'd0;
        green = 8'd0;
        blue = 8'd0;
        
        sample_dist = player_dist + depth;
        lut_idx = sample_dist[13:3];
        
        bottom_center = CENTER_X;
        far_center = CENTER_X;
        road_center = CENTER_X;
        
        road_center_out     = CENTER_X;
        road_half_width_out = TOP_ROAD_HALF_WIDTH;
        road_start_out      = 10'd0;
        road_end_out        = 10'd639;
        
        t = 16'd0;
        t_max = ROAD_FULLY_Y - HORIZON;
        
        road_half_width = TOP_ROAD_HALF_WIDTH;
        lane_half_width = TOP_LANE_HALF_WIDTH;
        
        in_road = 1'b0;
        in_lane_dash = 1'b0;
        dash_on = 1'b0;
        dash_phase = 16'd0;
        
        center_interp_tmp = 32'sd0;
        width_interp_tmp = 32'd0;
        lane_width_interp_tmp = 32'd0;
        
        curb_width = 16'd0;
        left_curb = 1'b0;
        right_curb = 1'b0;
        in_curb = 1'b0;
        curb_red = 1'b0;
        
        left_curb_start = 16'sd0;
        left_curb_end = 16'sd0;
        right_curb_start = 16'sd0;
        right_curb_end = 16'sd0;
        
        road_x = 10'd0;

        
        if (DrawY < HORIZON) 
        begin
            // sky
            red = 8'd11;
            green = 8'd15;
            blue = 8'd15;
        end
        else
        begin
            t = DrawY - HORIZON;

            if (t > t_max)
                t_clamped = t_max;
            else
                t_clamped = t;
                
            player_shift_tmp = $signed(player_x) * $signed({1'b0, t_clamped});
            player_shift = player_shift_tmp / $signed({1'b0, t_max});
            
            width_interp_tmp =
                TOP_ROAD_HALF_WIDTH
                + ((BOTTOM_ROAD_HALF_WIDTH - TOP_ROAD_HALF_WIDTH) * t_clamped) / t_max;
            
            road_half_width = width_interp_tmp[15:0];
            
            if (road_half_width < 16'd2)
                road_half_width = 16'd2;
            
            lane_half_width =
                TOP_LANE_HALF_WIDTH
                + ((BOTTOM_LANE_HALF_WIDTH - TOP_LANE_HALF_WIDTH) * t) / t_max;
            
            // use website-style accumulated center
            road_center = scanned_road_center - player_shift;
            
            road_start_real = road_center - $signed(road_half_width);
            road_end_real   = road_center + $signed(road_half_width);
            
            curb_width = lane_half_width << 2;

            if (curb_width < 16'd3)
                curb_width = 16'd3;
            else if (curb_width > 16'd24)
                curb_width = 16'd24;
            
            left_curb_start  = road_start_real - $signed(curb_width);
            left_curb_end    = road_start_real;
            
            right_curb_start = road_end_real;
            right_curb_end   = road_end_real + $signed(curb_width);
            
            left_curb =
                ($signed({1'b0, DrawX}) >= left_curb_start) &&
                ($signed({1'b0, DrawX}) <  left_curb_end);
            
            right_curb =
                ($signed({1'b0, DrawX}) >  right_curb_start) &&
                ($signed({1'b0, DrawX}) <= right_curb_end);
            
            in_curb = left_curb || right_curb;
            
            // ?? lane dash?? sample_dist ?????
            curb_red = ((sample_dist >> 5) & 16'd1);

            
            if (road_start_real < 0)
                road_start = 10'd0;
            else if (road_start_real > 639)
                road_start = 10'd639;
            else
                road_start = road_start_real[9:0];
            
            if (road_end_real < 0)
                road_end = 10'd0;
            else if (road_end_real > 639)
                road_end = 10'd639;
            else
                road_end = road_end_real[9:0];
                
            road_x = DrawX - road_start;
            
            road_center_out     = road_center;
            road_half_width_out = road_half_width;
            road_start_out      = road_start;
            road_end_out        = road_end;
            
            in_road = ((DrawX >= road_start) && (DrawX <= road_end));
            
            start_line_zone = in_road && (object_type == 8'd2);
            if (DrawY < 10'd250)
                checker_white = road_x[1] ^ sample_dist[1];
            else if (DrawY < 10'd310)
                checker_white = road_x[2] ^ sample_dist[2];
            else
                checker_white = road_x[3] ^ sample_dist[3];
            
            dash_phase = sample_dist % DASH_PERIOD;
            dash_on = (dash_phase < DASH_ON);
            
            in_lane_dash = in_road &&
                           (DrawX >= road_center - $signed(lane_half_width)) &&
                           (DrawX <= road_center + $signed(lane_half_width)) &&
                           dash_on;
            
            if (start_line_zone)
            begin
                if (checker_white) begin
                    red   = 8'd15;
                    green = 8'd15;
                    blue  = 8'd15;
                end else begin
                    red   = 8'd0;
                    green = 8'd0;
                    blue  = 8'd0;
                end
            end
            else if (in_lane_dash)
            begin
                // yellow dashed center line
                red = 8'd15;
                green = 8'd13;
                blue = 8'd0;
            end
            else if (in_road)
            begin
                // road
                red = 8'd100;
                green = 8'd100;
                blue = 8'd100;
            end
            else if (in_curb)
            begin
                if (curb_red) begin
                    red   = 8'd15;
                    green = 8'd0;
                    blue  = 8'd0;
                end else begin
                    red   = 8'd15;
                    green = 8'd15;
                    blue  = 8'd15;
                end
            end
            else
            begin 
                // grass
                if (scenery == 8'd1) 
                begin
                    // forest ground
                    red   = 8'd5;
                    green = 8'd10;
                    blue  = 8'd6;
                end else begin
                    // normal grass
                    red   = 8'd5;
                    green = 8'd10;
                    blue  = 8'd6;
                end 
            end
        end
        off_road_next = off_road;

        if (DrawY == 10'd360 && DrawX == 10'd0) begin
            off_road_next =
                (road_start_real > 16'sd10) ||
                (road_end_real   < 16'sd629);
        end
    end
    always_ff @(posedge clk) begin
        if (reset)
            off_road <= 1'b0;
        else
            off_road <= off_road_next;
    end
endmodule
