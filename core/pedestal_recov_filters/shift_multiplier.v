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
	input wire coefficient[6:0],
	input wire signed[15:0] x,
    output wire signed[22:0] y
);
    
	wire signed [22:0] shift_n_value[7:0];

	generate genvar i;
		for(i=0; i<=7; i=i+1) begin : i_instance
			n_shift_module shift_module_(
				.clk(clk),
				.reset(reset),
				.enable(coefficient[i]),
				.n_shift_module(i),
				.x(x),
				.y(shift_n_value[i])
			);
		end
	endgenerate

	y = shift_n_value[0] + shift_n_value[1] + shift_n_value[2] + shift_n_value[3] + shift_n_value[4] + shift_n_value[5] + shift_n_value[6] + shift_n_value[7];

endmodule