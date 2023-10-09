`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// University: UNIMIB 
// Engineer: Esteban Cristaldo, MSc
//
// Create Date: July 14, 2022, 11:53:42 AM
// Design Name: filtering_and_selftrigger
// Module Name: hpf_pedestal_recovery_filter_trigger.v
// Project Name: selftrigger@bicocca
// Target Devices: DAPHNE V1
//
//////////////////////////////////////////////////////////////////////////////////
module hpf_pedestal_recovery_filter_trigger(
	input wire clk,
	input wire reset,
    input wire n_1_reset,
	input wire enable,
    input wire write_threshold_value,
    input wire [7:0] threshold_ch,
    input wire signed [31:0] threshold_value,
    input wire [1:0] output_selector,
	input wire signed [719:0] x,
    output wire [39:0] trigger_output,
    output wire signed [31:0] threshold_value_read,
	output wire signed [719:0] y
);
	
	wire signed [15:0] lpf_out [4:0][7:0];
	wire signed [15:0] hpf_out [4:0][7:0];
    wire signed [15:0] movmean_out [4:0][7:0];
	wire signed [15:0] x_i [4:0][7:0];
    //wire signed [15:0] w_resta_out [4:0][7:0];
    wire signed [15:0] w_out [4:0][7:0];
	//wire signed [15:0] resta_out [4:0][7:0];
	wire signed [15:0] suma_out [4:0][7:0];
    wire tm_output_selector;

    reg signed [31:0] threshold_levels [39:0];
    reg signed [31:0] threshold_value_read_reg;

    always @(posedge clk) begin 
        if(reset) begin
           threshold_levels[0] <= $signed(99999);
           threshold_levels[1] <= $signed(99999);
           threshold_levels[2] <= $signed(99999);
           threshold_levels[3] <= $signed(99999);
           threshold_levels[4] <= $signed(99999);
           threshold_levels[5] <= $signed(99999);
           threshold_levels[6] <= $signed(99999);
           threshold_levels[7] <= $signed(99999);
           threshold_levels[8] <= $signed(99999);
           threshold_levels[9] <= $signed(99999);
           threshold_levels[10] <= $signed(99999);
           threshold_levels[11] <= $signed(99999);
           threshold_levels[12] <= $signed(99999);
           threshold_levels[13] <= $signed(99999);
           threshold_levels[14] <= $signed(99999);
           threshold_levels[15] <= $signed(99999);
           threshold_levels[16] <= $signed(99999);
           threshold_levels[17] <= $signed(99999);
           threshold_levels[18] <= $signed(99999);
           threshold_levels[19] <= $signed(99999);
           threshold_levels[20] <= $signed(99999);
           threshold_levels[21] <= $signed(99999);
           threshold_levels[22] <= $signed(99999);
           threshold_levels[23] <= $signed(99999);
           threshold_levels[24] <= $signed(99999);
           threshold_levels[25] <= $signed(99999);
           threshold_levels[26] <= $signed(99999);
           threshold_levels[27] <= $signed(99999);
           threshold_levels[28] <= $signed(99999);
           threshold_levels[29] <= $signed(99999);
           threshold_levels[30] <= $signed(99999);
           threshold_levels[31] <= $signed(99999);
           threshold_levels[32] <= $signed(99999);
           threshold_levels[33] <= $signed(99999);
           threshold_levels[34] <= $signed(99999);
           threshold_levels[35] <= $signed(99999);
           threshold_levels[36] <= $signed(99999);
           threshold_levels[37] <= $signed(99999);
           threshold_levels[38] <= $signed(99999);
           threshold_levels[39] <= $signed(99999);
        end else if (write_threshold_value) begin 
           threshold_levels[threshold_ch] <= $signed(threshold_value);
        end else if (~write_threshold_value) begin 
           threshold_value_read_reg <= $signed(threshold_levels[threshold_ch]);
        end
    end
    
	generate genvar i,j;
		for(i=0; i<=4; i=i+1) begin : i_instance
		    assign y[((i*9 + 8)*16 + 15) : ((i*9 + 8)*16)] = x[((i*9 + 8)*16 + 15) : ((i*9 + 8)*16)]; // (i*9 + j)*16
            for(j=0; j<=7; j=j+1) begin : j_instance
//                if(i == 2 && j == 0) begin // comment to have 40 channels
                k_low_pass_filter lpf(
                    .clk(clk),
                    .reset(reset),
                    .enable(enable),
                    .x(x_i[i][j]),
                    .y(lpf_out[i][j])
                );

                IIRFilter_integrator_optimized hpf(
                    .clk(clk),
                    .reset(reset),
                    .n_1_reset(n_1_reset),
                    .enable(enable),
                    //.x(resta_out[i][j]),
                    .x(x_i[i][j]),
                    .y(hpf_out[i][j])
                );

                mi_trigger_module filter_trigger(
                    .clk(clk),
                    .reset(reset),
                    //.n_1_reset(n_1_reset),
                    .enable(enable),
                    .output_selector(tm_output_selector),
                    .threshold(threshold_levels[i*8 + j]),
                    .x(hpf_out[i][j]),
                    .trigger(trigger_output[i*8 + j]),
                    .y(movmean_out[i][j])
                );

                /*always @(*) begin
                    if(en) begin
                        suma_out[i][j] <= (hpf_out[i][j] + lpf_out[i][j]);
                        resta_out[i][j] <= (x_i[i][j] - lpf_out[i][j]);
                    end else begin
                        suma_out[i][j] <= hpf_out[i][j];
                        resta_out[i][j] <= x_i[i][j];
                    end
                end*/

 //               assign resta_out[i][j] = (enable==0) ?   x_i[i][j] : 
 //                                        (enable==1) ?   (x_i[i][j] - lpf_out[i][j]) : 
 //                                        16'bx; // This part is not necessary given that there it will be removed by the HPF
                
                assign suma_out[i][j] = (enable==0) ?   hpf_out[i][j] : 
                                        (enable==1) ?   (hpf_out[i][j] + lpf_out[i][j]) : 
                                         16'bx;


                assign w_out[i][j] =    (output_selector == 2'b00) ?   suma_out[i][j] : 
                                        (output_selector == 2'b01) ?   lpf_out[i][j] + movmean_out[i][j] : //movmean
                                        (output_selector == 2'b10) ?   lpf_out[i][j] + movmean_out[i][j] : //movmean cfd
                                        (output_selector == 2'b11) ?   x_i[i][j] :
                                         16'bx;
               
                /*assign suma_out[i][j] = (en==0) ?   hpf_out[i][j] : 
                                        (en==1) ?   (hpf_out[i][j] + 16'd8000) : 
                                         16'bx;*/

                assign x_i[i][j] = x[((i*9 + j)*16 + 15) : ((i*9 + j)*16)];
                assign y[((i*9 + j)*16 + 15) : ((i*9 + j)*16)] = w_out[i][j];
                //assign w_resta_out[i][j] = resta_out[i][j];
 //               end else begin // comment to have 40 channels
 //                   assign y[((i*9 + j)*16 + 15) : ((i*9 + j)*16)] = x[((i*9 + j)*16 + 15) : ((i*9 + j)*16)];
 //               end
            end
		end
		
	endgenerate
	
    assign threshold_value_read = threshold_value_read_reg;
    assign tm_output_selector = (output_selector == 2'b00) ?   1'b0 : 
                                (output_selector == 2'b01) ?   1'b0 : //movmean
                                (output_selector == 2'b10) ?   1'b1 : //movmean cfd
                                (output_selector == 2'b11) ?   1'b0 :
                                 1'bx;

endmodule