`timescale 1ns / 1ps

module object_render(
    input logic clk,
    input  logic [9:0] DrawX, DrawY,
    input  logic [15:0] player_dist,
    input  logic signed [9:0] player_x,
    input  logic signed [15:0] center_lut_in [0:479],
    input  logic [9:0] road_start_in,
    input  logic [9:0] road_end_in,
    output logic object_on,
    output logic [3:0] red,
    output logic [3:0] green,
    output logic [3:0] blue
    );

    localparam int HORIZON                = 200;
    localparam int CENTER_X               = 320;
    localparam int ROAD_FULLY_Y           = 359;
    localparam int TOP_ROAD_HALF_WIDTH    = 16;
    localparam int BOTTOM_ROAD_HALF_WIDTH = 640;
    localparam int TREE_WORLD_OFFSET      = 30;     //decreased from 80 to make trees closer to the road
    localparam int NUM_TREES              = 5;
    localparam int TREE_SPACING           = 30;

    localparam int T0 = 130;
    localparam int T1 = 160;
    localparam int T2 = 190;
    localparam int T3 = 220;
    localparam int T4 = 250;

    logic [9:0] inv_depth_lut [0:1023];

    integer i;

    initial begin
        for (i = 0; i < 1024; i++) begin
            inv_depth_lut[i] = 10'(8192 / (i + 32));
        end
    end

    logic [15:0] road_width_unused;
    logic signed [15:0] curve;
    logic [7:0] scenery, object_type;
    logic [9:0]  lut_index;

    // Per-tree signals (5 trees)
    logic [9:0]  tree_base_y [0:4];
    logic [9:0]  tree_top_y  [0:4];
    logic [15:0] tree_h      [0:4];
    logic [15:0] trunk_h     [0:4];
    logic [15:0] trunk_w     [0:4];
    logic [15:0] canopy_r    [0:4];
    logic signed [15:0] tree_x_left  [0:4];
    logic signed [15:0] tree_x_right [0:4];
    logic signed [15:0] tree_x_left_base  [0:4];
    logic signed [15:0] tree_x_right_base [0:4];
    logic tree_visible [0:4];
    logic signed [15:0] rel_y   [0:4];
    logic signed [15:0] dx_left [0:4];
    logic signed [15:0] dx_right[0:4];

    // Road at base scanline per tree
    logic [15:0] t_base          [0:4];
    logic [31:0] width_at_base   [0:4];
    logic [15:0] road_hw_base    [0:4];
    logic [15:0] scaled_off_base [0:4];

    logic in_trunk_L  [0:4];
    logic in_trunk_R  [0:4];
    logic in_leaf_L   [0:4];
    logic in_leaf_R   [0:4];
    logic tree_enable [0:4];

    logic [15:0] depth_unused;

    world_lut lut_inst(
        .dist_addr(lut_index),
        .y_addr(DrawY[8:0]),
        .depth(depth_unused),
        .curve(curve),
        .road_width(road_width_unused),
        .scenery(scenery),
        .object_type(object_type)
    );

    always_comb begin
        logic [15:0] tree_dist_0, tree_dist_1, tree_dist_2, tree_dist_3, tree_dist_4;

        tree_dist_0 = (16'd1040 - player_dist) & 16'h1FFF;
        tree_dist_1 = (16'd1440 - player_dist) & 16'h1FFF;
        tree_dist_2 = (16'd1840 - player_dist) & 16'h1FFF;
        tree_dist_3 = (16'd2240 - player_dist) & 16'h1FFF;
        tree_dist_4 = (16'd2640 - player_dist) & 16'h1FFF;

        tree_enable[0] = (tree_dist_0 > 16'd256) && (tree_dist_0 < 16'd7800);
        tree_enable[1] = (tree_dist_1 > 16'd256) && (tree_dist_1 < 16'd7800);
        tree_enable[2] = (tree_dist_2 > 16'd256) && (tree_dist_2 < 16'd7800);
        tree_enable[3] = (tree_dist_3 > 16'd256) && (tree_dist_3 < 16'd7800);
        tree_enable[4] = (tree_dist_4 > 16'd256) && (tree_dist_4 < 16'd7800);

        tree_base_y[0] = 10'(HORIZON) + inv_depth_lut[tree_dist_0[12:3]] - 10'd32;
        tree_base_y[1] = 10'(HORIZON) + inv_depth_lut[tree_dist_1[12:3]] - 10'd32;
        tree_base_y[2] = 10'(HORIZON) + inv_depth_lut[tree_dist_2[12:3]] - 10'd32;
        tree_base_y[3] = 10'(HORIZON) + inv_depth_lut[tree_dist_3[12:3]] - 10'd32;
        tree_base_y[4] = 10'(HORIZON) + inv_depth_lut[tree_dist_4[12:3]] - 10'd32;
    end
    always_ff @(posedge clk) begin
        for (int h = 0; h < 5; h++) begin
            if (DrawY == tree_base_y[h]-1) begin        //clock cycle delay?
                tree_x_left_base[h]  <= $signed({1'b0, road_start_in})
                                        - $signed({1'b0, scaled_off_base[h][9:0]});
                tree_x_right_base[h] <= $signed({1'b0, road_end_in})
                                        + $signed({1'b0, scaled_off_base[h][9:0]});
            end
        end
    end
    genvar h;
    generate
        for (h = 0; h < 5; h++) begin : tree_gen
            always_comb begin
                tree_h[h]   = 16'd10 + {6'b0, (tree_base_y[h] - 10'(HORIZON))};
                trunk_h[h]  = (tree_h[h] >> 1) + (tree_h[h] >> 2);
                trunk_w[h]  = 16'd2 + (tree_h[h] >> 5);
                canopy_r[h] = 16'd4 + (tree_h[h] >> 3);

                if (tree_h[h]   > 16'd120) tree_h[h]   = 16'd120;
                if (trunk_h[h]  > 16'd80)  trunk_h[h]  = 16'd80;
                if (trunk_w[h]  > 16'd10)  trunk_w[h]  = 16'd10;
                if (canopy_r[h] > 16'd40)  canopy_r[h] = 16'd40;

                tree_top_y[h] = (tree_base_y[h] > tree_h[h][9:0]) ?
                                (tree_base_y[h] - tree_h[h][9:0]) : 10'd0;

                tree_visible[h] = tree_enable[h] &&
                                  (DrawY >= tree_top_y[h]) &&
                                  (DrawY <= tree_base_y[h]) &&
                                  (tree_base_y[h] > 10'd0) &&
                                  (tree_base_y[h] < 10'(ROAD_FULLY_Y));

                // road width at tree base for offset calculation
                t_base[h]        = {6'b0, tree_base_y[h]} - HORIZON;
                width_at_base[h] = TOP_ROAD_HALF_WIDTH +
                    ((BOTTOM_ROAD_HALF_WIDTH - TOP_ROAD_HALF_WIDTH) * t_base[h]) /
                    (ROAD_FULLY_Y - HORIZON);
                road_hw_base[h]  = width_at_base[h][15:0];

                scaled_off_base[h] = (TREE_WORLD_OFFSET * road_hw_base[h]) /
                                      BOTTOM_ROAD_HALF_WIDTH;

                // use road_start_in/road_end_in - exact road edges at current DrawY
                tree_x_left[h]  = tree_x_left_base[h];
                tree_x_right[h] = tree_x_right_base[h];

                rel_y[h]    = $signed({1'b0, tree_base_y[h]}) - $signed({1'b0, DrawY});
                dx_left[h]  = $signed({1'b0, DrawX}) - tree_x_left[h];
                dx_right[h] = $signed({1'b0, DrawX}) - tree_x_right[h];

                in_trunk_L[h] = tree_visible[h] &&
                    (rel_y[h] >= 0) && (rel_y[h] < $signed(trunk_h[h])) &&
                    (dx_left[h] >= -$signed(trunk_w[h])) &&
                    (dx_left[h] <=  $signed(trunk_w[h]));

                in_trunk_R[h] = tree_visible[h] &&
                    (rel_y[h] >= 0) && (rel_y[h] < $signed(trunk_h[h])) &&
                    (dx_right[h] >= -$signed(trunk_w[h])) &&
                    (dx_right[h] <=  $signed(trunk_w[h]));

                in_leaf_L[h] = tree_visible[h] &&
                    (rel_y[h] >= $signed(trunk_h[h]) - $signed(canopy_r[h] >>> 1)) &&
                    (rel_y[h] <= $signed(trunk_h[h]) + $signed(canopy_r[h])) &&
                    (dx_left[h] >= -$signed(canopy_r[h])) &&
                    (dx_left[h] <=  $signed(canopy_r[h]));

                in_leaf_R[h] = tree_visible[h] &&
                    (rel_y[h] >= $signed(trunk_h[h]) - $signed(canopy_r[h] >>> 1)) &&
                    (rel_y[h] <= $signed(trunk_h[h]) + $signed(canopy_r[h])) &&
                    (dx_right[h] >= -$signed(canopy_r[h])) &&
                    (dx_right[h] <=  $signed(canopy_r[h]));
            end
        end
    endgenerate

    always_comb begin
        object_on = 1'b0;
        red       = 4'd0;
        green     = 4'd0;
        blue      = 4'd0;
        lut_index = player_dist[12:3];

        if (in_leaf_L[4] || in_leaf_R[4] ||
            in_leaf_L[3] || in_leaf_R[3] ||
            in_leaf_L[2] || in_leaf_R[2] ||
            in_leaf_L[1] || in_leaf_R[1] ||
            in_leaf_L[0] || in_leaf_R[0]) begin
            object_on = 1'b1;
            red   = 4'd1;
            green = 4'd7;
            blue  = 4'd1;
        end
        else if (in_trunk_L[4] || in_trunk_R[4] ||
                 in_trunk_L[3] || in_trunk_R[3] ||
                 in_trunk_L[2] || in_trunk_R[2] ||
                 in_trunk_L[1] || in_trunk_R[1] ||
                 in_trunk_L[0] || in_trunk_R[0]) begin
            object_on = 1'b1;
            red   = 4'd7;
            green = 4'd4;
            blue  = 4'd1;
        end
    end
endmodule