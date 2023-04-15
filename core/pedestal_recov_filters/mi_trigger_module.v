`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// University: UNIMIB 
// Engineer: Esteban Cristaldo, MSc
//
// Create Date: July 1, 2022, 5:51:46 PM
// Design Name: filtering_and_selftrigger
// Module Name: mi_trigger_module.v
// Project Name: selftrigger@bicocca
// Target Devices: DAPHNE V2
//
//////////////////////////////////////////////////////////////////////////////////
module mi_trigger_module(
    input wire clk,
	input wire reset,
    input wire enable,
    input wire output_selector,
    input wire signed[15:0] x,
    input wire signed[31:0] threshold,
    output wire trigger,
    output wire signed[15:0] y
);
    
    wire [15:0] w1, w2;

	moving_integrator_filter mif(
	.clk(clk),
	.reset(reset), 
	.enable(enable), 
	.x(x),
    .y(w1)
	);

	constant_fraction_discriminator cfd(
    .clk(clk),
	.reset(reset),
    .enable(enable),
    .x(w1),
    .threshold(threshold),
    .trigger(trigger),
    .y(w2)
	);

	assign y = (output_selector == 1'b0) ?   w1 : 
               (output_selector == 1'b1) ?   w2 :
               16'bx;

endmodule