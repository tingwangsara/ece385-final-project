`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/20/2026 03:59:27 PM
// Design Name: 
// Module Name: keyboard
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


module keyboard(
    input logic [7:0] keycode,
    output logic key_left, key_right, key_gas, key_brake
    );
    
    //changed for smooth steering
    always_comb begin
        key_left  = 1'b0;
        key_right = 1'b0;
        key_gas   = keycode[2];
        key_brake = keycode[3];
    end
    //changed for steering wheel
//    always_comb begin
//        key_left  = keycode[0];
//        key_right = keycode[1];
//        key_gas   = keycode[2];
//        key_brake = keycode[3];
//    end
//    always_comb begin
//        //modify to control ball motion with the keycode
//        if(keycode == 8'h1A)
//            begin //W, gas
//                key_left = 0;
//                key_right = 0;
//                key_gas = 1'b1;
//                key_brake = 0;
//            end
//        else if(keycode == 8'h16)
//            begin //S, brake
//                key_left = 0;
//                key_right = 0;
//                key_gas = 0;
//                key_brake = 1'b1;
//            end
//        else if(keycode == 8'h04)   
//            begin //A, left
//                key_left = 1'b1;
//                key_right = 0;
//                key_gas = 0;
//                key_brake = 0;
//            end
//        else if(keycode == 8'h07)  
//            begin //D, right
//                key_left = 0;
//                key_right = 1'b1;
//                key_gas = 0;
//                key_brake = 0;
//            end
//        else
//            begin
//                key_left = 0;
//                key_right = 0;
//                key_gas = 0;
//                key_brake = 0;
//            end
//    end
endmodule
