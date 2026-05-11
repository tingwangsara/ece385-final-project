`timescale 1ns / 1ps

module world_lut(
    input  logic [10:0] dist_addr, // 0 ~ 2047
    input  logic [8:0]  y_addr,
    output logic [15:0] depth,
    output logic signed [15:0] curve,
    output logic [15:0] road_width,
    output logic [7:0]  scenery,
    output logic [7:0]  object_type
);

    localparam int SCREEN_H  = 480;
    localparam int HORIZON   = 200;
    localparam int TRACK_LEN = 2048;

    logic [15:0] depth_lut        [0:SCREEN_H-1];
    logic signed [15:0] curve_lut [0:TRACK_LEN-1];
    logic [15:0] width_lut        [0:TRACK_LEN-1];
    logic [7:0]  scenery_lut      [0:TRACK_LEN-1];
    logic [7:0]  object_lut       [0:TRACK_LEN-1];

    integer i;
    integer t;

    initial begin
        // ------------------------------------------------------------
        // depth LUT
        // ------------------------------------------------------------
        for (i = 0; i < SCREEN_H; i++) begin
            if (i < HORIZON)
                depth_lut[i] = 16'd16;
            else begin
                t = i - HORIZON + 32;
                depth_lut[i] = 16'd8192 / t;
            end
        end

        // ------------------------------------------------------------
        // default track
        // ------------------------------------------------------------
        for (i = 0; i < TRACK_LEN; i++) begin
            curve_lut[i]   = 16'sd0;
            width_lut[i]   = 16'd120;
            scenery_lut[i] = 8'd0;
            object_lut[i]  = 8'd0;
        end

        // ------------------------------------------------------------
        // scenery / objects
        // ------------------------------------------------------------
        for (i = 256; i < 512; i++) begin
            scenery_lut[i] = 8'd1;
            object_lut[i]  = 8'd1;
        end

        for (i = 1152; i < 1536; i++) begin
            scenery_lut[i] = 8'd1;
            object_lut[i]  = 8'd1;
        end
        
        // start / finish checker marker
        for (i = 8; i < 9; i++)
        begin
            object_lut[i] = 8'd2;
        end

        // ============================================================
        // curve layout, total length 2048
        // positive = right curve
        // negative = left curve
        // ============================================================

        // 0 ~ 159: straight
        for (i = 0; i < 160; i++) curve_lut[i] = 16'sd0;

        // 160 ~ 511: right curve
        for (i = 160; i < 192; i++) curve_lut[i] = 16'sd1;
        for (i = 192; i < 224; i++) curve_lut[i] = 16'sd2;
        for (i = 224; i < 256; i++) curve_lut[i] = 16'sd3;
        for (i = 256; i < 416; i++) curve_lut[i] = 16'sd3;
        for (i = 416; i < 448; i++) curve_lut[i] = 16'sd2;
        for (i = 448; i < 512; i++) curve_lut[i] = 16'sd1;

        // 512 ~ 639: short straight
        for (i = 512; i < 640; i++) curve_lut[i] = 16'sd0;

        // 640 ~ 959: left curve
        for (i = 640; i < 672; i++) curve_lut[i] = -16'sd1;
        for (i = 672; i < 704; i++) curve_lut[i] = -16'sd2;
        for (i = 704; i < 736; i++) curve_lut[i] = -16'sd3;
        for (i = 736; i < 864; i++) curve_lut[i] = -16'sd3;
        for (i = 864; i < 896; i++) curve_lut[i] = -16'sd2;
        for (i = 896; i < 960; i++) curve_lut[i] = -16'sd1;

        // 960 ~ 1087: straight
        for (i = 960; i < 1088; i++) curve_lut[i] = 16'sd0;

        // 1088 ~ 1471: S curve: right then left
        for (i = 1088; i < 1120; i++) curve_lut[i] = 16'sd1;
        for (i = 1120; i < 1152; i++) curve_lut[i] = 16'sd2;
        for (i = 1152; i < 1248; i++) curve_lut[i] = 16'sd3;
        for (i = 1248; i < 1280; i++) curve_lut[i] = 16'sd2;
        for (i = 1280; i < 1312; i++) curve_lut[i] = 16'sd1;

        for (i = 1312; i < 1344; i++) curve_lut[i] = -16'sd1;
        for (i = 1344; i < 1376; i++) curve_lut[i] = -16'sd2;
        for (i = 1376; i < 1440; i++) curve_lut[i] = -16'sd3;
        for (i = 1440; i < 1472; i++) curve_lut[i] = -16'sd2;

        // 1472 ~ 1663: gentle left exit
        for (i = 1472; i < 1536; i++) curve_lut[i] = -16'sd1;
        for (i = 1536; i < 1664; i++) curve_lut[i] = 16'sd0;

        // 1664 ~ 1855: fast right bend
        for (i = 1664; i < 1696; i++) curve_lut[i] = 16'sd1;
        for (i = 1696; i < 1728; i++) curve_lut[i] = 16'sd2;
        for (i = 1728; i < 1792; i++) curve_lut[i] = 16'sd4;
        for (i = 1792; i < 1824; i++) curve_lut[i] = 16'sd2;
        for (i = 1824; i < 1856; i++) curve_lut[i] = 16'sd1;

        // 1856 ~ 2047: straight finish
        for (i = 1856; i < 2048; i++) curve_lut[i] = 16'sd0;
    end

    always_comb begin
        depth       = depth_lut[y_addr];
        curve       = curve_lut[dist_addr];
        road_width  = width_lut[dist_addr];
        scenery     = scenery_lut[dist_addr];
        object_type = object_lut[dist_addr];
    end

endmodule