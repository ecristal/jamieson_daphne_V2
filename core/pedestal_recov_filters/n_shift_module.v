`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// University: UNIMIB 
// Engineer: Esteban Cristaldo, MSc
//
// Create Date: April 12, 2024
// Design Name: n shifter
// Module Name: n_shift_module
// Project Name: selftrigger@bicocca
// Target Devices: DAPHNE V2
//
//////////////////////////////////////////////////////////////////////////////////
module n_shift_module(
	input wire clk,
	input wire reset, 
	input wire enable, 
	input wire n_shift[3:0],
	input wire signed[15:0] x,
    output wire signed[22:0] y
);
    
    
	reg signed [22:0] out_reg;
	

	always @(posedge clk) begin 
		if(reset) begin 
			out_reg <= 23'b0;
		end else if(enable) begin     
		    out_reg <= x <<< n_shift; 
		end else begin
		    out_reg <= 23'b0;
		end
	end
	
	assign y = out_reg;
endmodule