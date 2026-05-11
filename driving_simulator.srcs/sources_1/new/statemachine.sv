`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/22/2026 10:58:16 AM
// Design Name: 
// Module Name: statemachine
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


module statemachine(
    input logic clk, reset, traffic_light_off,
    output logic traffic_light_on
    
    );
    
    enum logic [2:0] {
		s_0, s_1
	} state, state_nxt;   // Internal state logic
	
	always_ff @ (posedge clk or posedge reset)
	begin
		if (reset) 
			state <= s_0;
	    else if (state == s_1)
		    state <= s_1;
		else if (traffic_light_off)
			state <= s_1;
	    else
	        state <= s_0; 
	end
	
	always_comb
	begin 
		
		// Default controls signal values so we don't have to set each signal
		// in each state case below (If we don't set all signals in each state,
		// we can create an inferred latch
		
	
		// Assign relevant control signals based on current state
		case (state) 
			s_0 :   
			//MAR<-PC , PC<-PC+1
				begin 
					traffic_light_on = 1'b1;
				end
			s_1 : //you may have to think about this as well to adapt to ram with wait-states
			//MDR<=M[MAR]
				begin
					traffic_light_on = 1'b0;
				end
			default : ;
		endcase
    end
	
endmodule
