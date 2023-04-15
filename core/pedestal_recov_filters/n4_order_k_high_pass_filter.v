`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// University: UNIMIB 
// Engineer: Esteban Cristaldo, MSc
//
// Create Date: July 1, 2022, 5:51:46 PM
// Design Name: filtering_and_selftrigger
// Module Name: n4_order_k_high_pass_filter.v
// Project Name: selftrigger@bicocca
// Target Devices: DAPHNE V2
//
//////////////////////////////////////////////////////////////////////////////////
module n4_order_k_high_pass_filter(
	input wire clk,
	input wire reset, 
	input wire enable, 
	input wire signed [15:0] x,
    output wire signed [15:0] y
);

wire signed [15:0] w1, w2, w3;    

k_high_pass_filter hpf1(
                    .clk(clk),
                    .reset(reset),
                    .enable(enable),
                    .x(x),
                    .y(y)
                );

/*k_high_pass_filter hpf2(
                    .clk(clk),
                    .reset(reset),
                    .enable(enable),
                    .x(w1),
                    .y(w2)
                );

k_high_pass_filter hpf3(
                    .clk(clk),
                    .reset(reset),
                    .enable(enable),
                    .x(w2),
                    .y(w3)
                );

k_high_pass_filter hpf4(
                    .clk(clk),
                    .reset(reset),
                    .enable(enable),
                    .x(w3),
                    .y(y)
                );*/

endmodule