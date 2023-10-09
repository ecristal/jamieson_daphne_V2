`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// University: UNIMIB 
// Engineer: Esteban Cristaldo, MSc
//
// Create Date: July 1, 2022, 5:51:46 PM
// Design Name: filtering_and_selftrigger
// Module Name: moving_integrator_filter.v
// Project Name: selftrigger@bicocca
// Target Devices: DAPHNE V2
//
//////////////////////////////////////////////////////////////////////////////////
module moving_integrator_filter(
	input wire clk,
	input wire reset, 
	input wire enable, 
	input wire signed [15:0] x,
    output wire signed [15:0] y
);
    
	parameter k = 25;
    
    reg reset_reg, enable_reg;
    reg signed [15:0] in_reg;
	reg signed [15:0] y_1;
	reg signed [47:0] wm;

	wire signed [15:0] w1, w2;
	wire signed [24:0] mult1;
	wire signed [17:0] mult2;


	always @(posedge clk) begin 
		if(reset) begin
			reset_reg <= 1'b1;
			enable_reg <= 1'b0;
		end else if (enable) begin
			reset_reg <= 1'b0;
			enable_reg <= 1'b1;
		end else begin 
			reset_reg <= 1'b0;
			enable_reg <= 1'b0;
		end
	end

	always @(posedge clk) begin
		if(reset_reg) begin
			y_1 <= 0;
			in_reg <= 0;
		end else if(enable_reg) begin
			wm <= mult1*mult2;
			y_1 <= w1;
			in_reg <= x;
		end
	end

	generate genvar i;
		for(i=0; i<=15; i=i+1) begin : srlc32e_i_inst
				SRLC32E #(
				   .INIT(32'h00000000),    // Initial contents of shift register
				   .IS_CLK_INVERTED(1'b0)  // Optional inversion for CLK
					) 
					SRLC32E_inst (
				   .Q(w2[i]),     // 1-bit output: SRL Data
				   .Q31(), // 1-bit output: SRL Cascade Data
				   .A(k),     // 5-bit input: Selects SRL depth
				   .CE(enable_reg),   // 1-bit input: Clock enable
				   .CLK(clk), // 1-bit input: Clock
				   .D(in_reg[i])      // 1-bit input: SRL Data
				);
		end
	endgenerate

	assign w1 = in_reg + y_1 - w2;
	assign mult1 = {w1,9'b0};
	assign mult2 = 18'b000010100011110110;
    assign y = wm[41:26];

endmodule