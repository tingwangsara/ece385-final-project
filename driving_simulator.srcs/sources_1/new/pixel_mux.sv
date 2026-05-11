`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/15/2026 11:03:50 AM
// Design Name: 
// Module Name: pixel_mux
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


module pixel_mux(
    input logic windshield_on, traffic_light_on, obj_on, traffic_pixel_on,
    input logic [3:0] road_red, road_green, road_blue, car_red, car_green, car_blue, obj_red, obj_green, obj_blue,
    input logic [11:0] traffic_out,
    input logic sky_on,
    input logic [11:0] sky_pixel,
    output logic [3:0] red, green, blue
    );
    
    always_comb
    begin
        if (traffic_light_on && traffic_pixel_on)
        begin
            red = (traffic_out & 12'hF00) >> 8;
            green = (traffic_out & 12'h0F0) >> 4;
            blue = traffic_out & 12'h00F;
        end
        else if (windshield_on)
        begin
            red = car_red;
            green = car_green;
            blue = car_blue;
        end
        else if (obj_on)
        begin
            red = obj_red;
            green = obj_green;
            blue = obj_blue;
        end
        else if (sky_on) begin
            red   = sky_pixel[11:8];
            green = sky_pixel[7:4];
            blue  = sky_pixel[3:0];
        end
        else 
        begin
            red = road_red;
            green = road_green;
            blue = road_blue;
        end
    end
endmodule
