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
	wire signed [15:0] resta_out [4:0][7:0];
	wire signed [15:0] suma_out [4:0][7:0];
    wire tm_output_selector;

    reg signed [31:0] threshold_levels [39:0];
    reg signed [31:0] threshold_value_read_reg;

    (* dont_touch = "true" *) wire Data_Available_wire;                     //  out std_logic;                                              -- ACTIVE HIGH when LOCAL primitives are calculated
    (* dont_touch = "true" *) wire [8:0] Time_Peak_wire;                    //  out std_logic_vector(8 downto 0);                           -- Time in Samples to achieve de Max peak
    (* dont_touch = "true" *) wire [8:0] Time_Pulse_UB_wire;                //  out std_logic_vector(8 downto 0);                           -- Time in Samples of the light pulse signal is UNDER BASELINE (without undershoot)
    (* dont_touch = "true" *) wire [9:0] Time_Pulse_OB_wire;                //  out std_logic_vector(9 downto 0);                           -- Time in Samples of the light pulse signal is OVER BASELINE (undershoot)
    (* dont_touch = "true" *) wire [13:0] Max_Peak_wire;                    //  out std_logic_vector(13 downto 0);                          -- Amplitude in ADC counts od the peak
    (* dont_touch = "true" *) wire [22:0] Charge_wire;                      //  out std_logic_vector(22 downto 0);                          -- Charge of the light pulse (without undershoot) in ADC*samples
    (* dont_touch = "true" *) wire [3:0] Number_Peaks_UB_wire;              //  out std_logic_vector(3 downto 0);                           -- Number of peaks detected when signal is UNDER BASELINE (without undershoot).  
    (* dont_touch = "true" *) wire [3:0] Number_Peaks_OB_wire;              //  out std_logic_vector(3 downto 0);                           -- Number of peaks detected when signal is OVER BASELINE (undershoot).  
    (* dont_touch = "true" *) wire [13:0] filtered_dout_wire;               //  out std_logic_vector (13 downto 0);                         -- HIGH PASS Filtered signal
    (* dont_touch = "true" *) wire [14:0] Baseline_wire;                    //  out std_logic_vector(14 downto 0);                          -- Real Time calculated BASELINE
    (* dont_touch = "true" *) wire [14:0] Amplitude_wire;                   //  out std_logic_vector(14 downto 0);                          -- Real Time calculated AMPLITUDE
    (* dont_touch = "true" *) wire Peak_Current_wire;                       //  out std_logic;                                              -- ACTIVE HIGH when a peak is detected
    (* dont_touch = "true" *) wire [13:0] Slope_Current_wire;               //  out std_logic_vector(13 downto 0);                          -- Real Time calculated SLOPE
    (* dont_touch = "true" *) wire [6:0] Slope_Threshold_wire;              //  out std_logic_vector(6 downto 0);                           -- Threshold over the slope to detect Peaks
    (* dont_touch = "true" *) wire Detection_wire;                          //  out std_logic;                                              -- ACTIVE HIGH when primitives are being calculated (during light pulse)
    (* dont_touch = "true" *) wire Sending_wire;                            //  out std_logic;                                              -- ACTIVE HIGH when colecting data for self-trigger frame
    (* dont_touch = "true" *) wire Info_Previous_wire;                      //  out std_logic;                                              -- ACTIVE HIGH when self-trigger is produced by a waveform between two frames 
    (* dont_touch = "true" *) wire Data_Available_Trailer_wire;             //  out std_logic;                                              -- ACTIVE HIGH when metadata is ready
    (* dont_touch = "true" *) wire [31:0] Trailer_Word_0_wire;              //  out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    (* dont_touch = "true" *) wire [31:0] Trailer_Word_1_wire;              //  out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    (* dont_touch = "true" *) wire [31:0] Trailer_Word_2_wire;              //  out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    (* dont_touch = "true" *) wire [31:0] Trailer_Word_3_wire;              //  out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    (* dont_touch = "true" *) wire [31:0] Trailer_Word_4_wire;              //  out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    (* dont_touch = "true" *) wire [31:0] Trailer_Word_5_wire;              //  out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    (* dont_touch = "true" *) wire [31:0] Trailer_Word_6_wire;              //  out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    (* dont_touch = "true" *) wire [31:0] Trailer_Word_7_wire;              //  out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    (* dont_touch = "true" *) wire [31:0] Trailer_Word_8_wire;              //  out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    (* dont_touch = "true" *) wire [31:0] Trailer_Word_9_wire;              //  out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    (* dont_touch = "true" *) wire [31:0] Trailer_Word_10_wire;             //  out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    (* dont_touch = "true" *) wire [31:0] Trailer_Word_11_wire;             //  out std_logic_vector(31 downto 0)                           -- TRAILER WORD with metada (Local Trigger Primitives)


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
              if(i == 0 && j == 1) begin // comment to have 40 channels
                
                //k_low_pass_filter lpf(
                //    .clk(clk),
                //    .reset(reset),
                //    .enable(enable),
                //    .x(x_i[i][j]),
                //    .y(lpf_out[i][j])
                //);

                //IIRFilter_integrator_optimized hpf(
                //    .clk(clk),
                //    .reset(reset),
                //    .n_1_reset(n_1_reset),
                //    .enable(enable),
                //    .x(resta_out[i][j]),
                //    //.x(x_i[i][j]),
                //    .y(hpf_out[i][j])
                //);

                //filtroIIR_movmean25_cfd mov_mean_cfd(
                //    .clk(clk),
                //    .reset(reset),
                //    .n_1_reset(n_1_reset),
                //    .enable(enable),
                //    .output_selector(tm_output_selector),
                //    .threshold(threshold_levels[i*8 + j]),
                //    .x(hpf_out[i][j]),
                //    .trigger(trigger_output[i*8 + j]),
                //    .y(movmean_out[i][j])
                //);

                Self_Trigger_Primitive_Calculation ciemat_selftrigger_module(
                    .clock(clk),                                               //=> aclk,                           // AFE clock
                    .reset(reset),                                             //=> reset,                          // Reset signal. ACTIVE HIGH
                    .din(x_i[i][j][13:0]),                                     //=> afe_dat,                        // Data coming from the Filter Block / Raw data from AFEs
                    .Config_Param(threshold_levels[i*8 + j][13:0]),            //=> st_config,                      // Configure parameters for filtering & self-trigger bloks
                    .Self_trigger(trigger_output[i*8 + j]),                    //=> triggered,                      // Self-Trigger signal comming from the Self-Trigger block
                    .Data_Available(Data_Available_wire),                      //=> open,                           // ACTIVE HIGH when LOCAL primitives are calculated
                    .Time_Peak(Time_Peak_wire),                                //=> open,                           // Time in Samples to achieve de Max peak
                    .Time_Pulse_UB(Time_Pulse_UB_wire),                        //=> open,                           // Time in Samples of the light pulse signal is UNDER BASELINE (without undershoot)
                    .Time_Pulse_OB(Time_Pulse_OB_wire),                        //=> open,                           // Time in Samples of the light pulse signal is OVER BASELINE (undershoot)
                    .Max_Peak(Max_Peak_wire),                                  //=> open,                           // Amplitude in ADC counts od the peak
                    .Charge(Charge_wire),                                      //=> open,                           // Charge of the light pulse (without undershoot) in ADC*samples
                    .Number_Peaks_UB(Number_Peaks_UB_wire),                    //=> open,                           // Number of peaks detected when signal is UNDER BASELINE (without undershoot).  
                    .Number_Peaks_OB(Number_Peaks_OB_wire),                    //=> open,                           // Number of peaks detected when signal is OVER BASELINE (undershoot).  
                    .filtered_dout(filtered_dout_wire),                        //=> open,                           // HIGH PASS Filtered signal
                    .Baseline(Baseline_wire),                                  //=> Baseline_aux,                   // Real Time calculated BASELINE
                    .Amplitude(Amplitude_wire),                                //=> open,                           // Real Time calculated AMPLITUDE
                    .Peak_Current(Peak_Current_wire),                          //=> open,                           // ACTIVE HIGH when a peak is detected
                    .Slope_Current(Slope_Current_wire),                        //=> open,                           // Real Time calculated SLOPE
                    .Slope_Threshold(Slope_Threshold_wire),                    //=> open,                           // Threshold over the slope to detect Peaks
                    .Detection(Detection_wire),                                //=> open,                           // ACTIVE HIGH when primitives are being calculated (during light pulse)
                    .Sending(Sending_wire),                                    //=> open,                           // ACTIVE HIGH when colecting data for self-trigger frame
                    .Info_Previous(Info_Previous_wire),                        //=> Info_Previous_aux,              // ACTIVE HIGH when self-trigger is produced by a waveform between two frames 
                    .Data_Available_Trailer(Data_Available_Trailer_wire),      //=> Data_Available_Trailer_aux,     // ACTIVE HIGH when metadata is ready
                    .Trailer_Word_0(Trailer_Word_0_wire),                      //=> Trailer_Word_0_aux,             // TRAILER WORD with metada (Local Trigger Primitives)
                    .Trailer_Word_1(Trailer_Word_1_wire),                      //=> Trailer_Word_1_aux,             // TRAILER WORD with metada (Local Trigger Primitives)
                    .Trailer_Word_2(Trailer_Word_2_wire),                      //=> Trailer_Word_2_aux,             // TRAILER WORD with metada (Local Trigger Primitives)
                    .Trailer_Word_3(Trailer_Word_3_wire),                      //=> Trailer_Word_3_aux,             // TRAILER WORD with metada (Local Trigger Primitives)
                    .Trailer_Word_4(Trailer_Word_4_wire),                      //=> Trailer_Word_4_aux,             // TRAILER WORD with metada (Local Trigger Primitives)
                    .Trailer_Word_5(Trailer_Word_5_wire),                      //=> Trailer_Word_5_aux,             // TRAILER WORD with metada (Local Trigger Primitives)
                    .Trailer_Word_6(Trailer_Word_6_wire),                      //=> Trailer_Word_6_aux,             // TRAILER WORD with metada (Local Trigger Primitives)
                    .Trailer_Word_7(Trailer_Word_7_wire),                      //=> Trailer_Word_7_aux,             // TRAILER WORD with metada (Local Trigger Primitives)
                    .Trailer_Word_8(Trailer_Word_8_wire),                      //=> Trailer_Word_8_aux,             // TRAILER WORD with metada (Local Trigger Primitives)
                    .Trailer_Word_9(Trailer_Word_9_wire),                      //=> Trailer_Word_9_aux,             // TRAILER WORD with metada (Local Trigger Primitives)
                    .Trailer_Word_10(Trailer_Word_10_wire),                    //=> Trailer_Word_10_aux,            // TRAILER WORD with metada (Local Trigger Primitives)
                    .Trailer_Word_11(Trailer_Word_11_wire)                     //=> Trailer_Word_11_aux             // TRAILER WORD with metada (Local Trigger Primitives)
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

                assign resta_out[i][j] = (enable==0) ?   x_i[i][j] : 
                                         (enable==1) ?   (x_i[i][j] - lpf_out[i][j]) : 
                                         16'bx; 
                
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
                end else if(i == 0 && j == 2) begin
                    assign y[((i*9 + j)*16 + 15) : ((i*9 + j)*16)] = {15'b0,trigger_output[i*8 + j - 1]};
                end else begin // comment to have 40 channels
                    assign y[((i*9 + j)*16 + 15) : ((i*9 + j)*16)] = x[((i*9 + j)*16 + 15) : ((i*9 + j)*16)];
                end
            end
		end
		
	endgenerate
	
    assign threshold_value_read = threshold_value_read_reg;
    assign tm_output_selector = (output_selector == 2'b00) ?   1'b0 : //hpf 
                                (output_selector == 2'b01) ?   1'b0 : //movmean
                                (output_selector == 2'b10) ?   1'b1 : //movmean cfd
                                (output_selector == 2'b11) ?   1'b0 : //unfiltered
                                 1'bx;

endmodule