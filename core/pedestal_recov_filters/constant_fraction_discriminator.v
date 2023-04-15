`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// University: UNIMIB 
// Engineer: Esteban Cristaldo, MSc
//
// Create Date: July 1, 2022, 5:51:46 PM
// Design Name: filtering_and_selftrigger
// Module Name: constant_fraction_discriminator.v
// Project Name: selftrigger@bicocca
// Target Devices: DAPHNE V2
//
//////////////////////////////////////////////////////////////////////////////////
module constant_fraction_discriminator(
    input wire clk,
	input wire reset,
    input wire enable,
    input wire signed[15:0] x,
    input wire signed[31:0] threshold,
    output wire trigger,
    output wire signed[15:0] y
);
    
	parameter shift_delay = 15;
    
    reg reset_reg, enable_reg;
    reg trigger_reg, trigger_threshold, trigger_crossover;

    reg signed [15:0] in_reg;
    reg signed [15:0] y_1, y_2;
    reg [7:0] counter_threshold;

	wire signed [15:0] w1;

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
			in_reg <= 0;
		end else if(enable_reg) begin
			in_reg <= x;
			y_1 <= in_reg - w1;
			y_2 <= y_1;
			trigger_reg <= (trigger_threshold && trigger_crossover);
		end
	end

	generate genvar i;
		for(i=0; i<=15; i=i+1) begin : srlc32e_i_inst
				SRLC32E #(
				   .INIT(32'h00000000),    // Initial contents of shift register
				   .IS_CLK_INVERTED(1'b0)  // Optional inversion for CLK
				)SRLC32E_inst (
			   .Q(w1[i]),     // 1-bit output: SRL Data
			   .Q31(), // 1-bit output: SRL Cascade Data
			   .A(shift_delay),     // 5-bit input: Selects SRL depth
			   .CE(enable_reg),   // 1-bit input: Clock enable
			   .CLK(clk), // 1-bit input: Clock
			   .D(in_reg[i])      // 1-bit input: SRL Data
			);
		end
	endgenerate

	//////////////////// TRIGGER CONDITIONS. ///////////////////////
    // threshold condition. DAPHNE signals have negative rising edge.
	always @(posedge clk) begin
	    if (reset_reg || counter_threshold[7]) begin
			trigger_threshold <= 1'b0;
		end else if(enable_reg) begin
			if (($signed(in_reg) < -($signed(threshold))) || trigger_threshold) begin
			     trigger_threshold <= 1'b1;
			end
		end
	end
    // threshold counter to wait for zero crossing, can be put is the process above 
    // but decided to separate it in another process block, just to make it more clear.
    // currently fixed at 128 cycles or samples.
    // Verified according to simulations.
	always @(posedge clk) begin
	    if (reset_reg || counter_threshold[7]) begin
	        counter_threshold <= 8'b0;
		end else if(enable_reg && trigger_threshold) begin
			counter_threshold <= counter_threshold + 1'b1;
		end
	end

    // zero crossing condition. 
	always @(posedge clk) begin
	    if (reset_reg || counter_threshold[7]) begin
	        trigger_crossover <= 1'b0;
		end else if(enable_reg && trigger_threshold) begin
			if (($signed(y_1) >= $signed(16'd0)) && ($signed(y_2) < $signed(16'd0))) begin
			     trigger_crossover <= 1'b1;
			end
		end
	end
    //////////////////// TRIGGER DEAD TIME CONDITIONS. ///////////////////////
    // condition to allow spy registers to have stable data. (if not already implemented)
    // This functionality is implemented inside spy.vhd in the 'fsm_process'. Triggers are
    // ignored during 'store' state.

    assign y = y_1;
    assign trigger = trigger_reg;

endmodule