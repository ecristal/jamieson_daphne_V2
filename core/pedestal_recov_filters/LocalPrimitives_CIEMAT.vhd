----------------------------------------------------------------------------------
-- Company: CIEMAT
-- Engineer: Ignacio López de Rego Benedi
-- 
-- Create Date: 15.04.2024 11:04:11
-- Design Name: 
-- Module Name: LocalPrimitives_CIEMAT - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity LocalPrimitives_CIEMAT is
port(
    clock:                          in  std_logic;                                              -- AFE clock
    reset:                          in  std_logic;                                              -- Reset signal. ACTIVE HIGH
    Self_trigger:                   in  std_logic;                                              -- Self-Trigger signal comming from the Self-Trigger block
    din:                            in  std_logic_vector(13 downto 0);                          -- Data coming from the Filter Block / Raw data from AFEs
    Interface_LOCAL_Primitves_IN:   in  std_logic_vector(23 downto 0);                          -- Interface with Local Primitives calculation BLOCK --> DEPENDS ON SELF-TRIGGER ALGORITHM 
    Interface_LOCAL_Primitves_OUT:  out std_logic_vector(23 downto 0);                          -- Interface with Local Primitives calculation BLOCK --> DEPENDS ON SELF-TRIGGER ALGORITHM 
    Data_Available:                 out std_logic;                                              -- ACTIVE HIGH when LOCAL primitives are calculated
    Time_Peak:                      out std_logic_vector(8 downto 0);                           -- Time in Samples to achieve de Max peak
    Time_Pulse_UB:                  out std_logic_vector(8 downto 0);                           -- Time in Samples of the light pulse signal is UNDER BASELINE (without undershoot)
    Time_Pulse_OB:                  out std_logic_vector(9 downto 0);                           -- Time in Samples of the light pulse signal is OVER BASELINE (undershoot)
    Max_Peak:                       out std_logic_vector(13 downto 0);                          -- Amplitude in ADC counts od the peak
    Charge:                         out std_logic_vector(22 downto 0);                          -- Charge of the light pulse (without undershoot) in ADC*samples
    Number_Peaks_UB:                out std_logic_vector(3 downto 0);                           -- Number of peaks detected when signal is UNDER BASELINE (without undershoot).  
    Number_Peaks_OB:                out std_logic_vector(3 downto 0);                           -- Number of peaks detected when signal is OVER BASELINE (undershoot).  
    Baseline:                       out std_logic_vector(14 downto 0);                            -- TO BE REMOVED AFTER DEBUGGING
    Amplitude:                      out std_logic_vector(14 downto 0);                            -- TO BE REMOVED AFTER DEBUGGING
    High_Freq_Noise:                out std_logic                                                 -- ACTIVE HIGH when high freq noise is detected 
--    Trailer_Word_0:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
--    Trailer_Word_1:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
--    Trailer_Word_2:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
--    Trailer_Word_3:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
--    Trailer_Word_4:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
--    Trailer_Word_5:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
--    Trailer_Word_6:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
--    Trailer_Word_7:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
--    Trailer_Word_8:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
--    Trailer_Word_9:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
--    Trailer_Word_10:                out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
--    Trailer_Word_11:                out std_logic_vector(31 downto 0)                           -- TRAILER WORD with metada (Local Trigger Primitives)
);
end LocalPrimitives_CIEMAT;

architecture Behavioral of LocalPrimitives_CIEMAT is

-- INTERFACE with SELF-TRIGGER BLOCK signals
signal Interface_LOCAL_Primitves_IN_reg: std_logic_vector(23 downto 0);
signal Peak_Current: std_logic:='0'; -- ACTIVE HIGH When a Peak is detected.
signal Peak_Current_delay1: std_logic:='0'; -- ACTIVE HIGH When a Peak is detected. 
signal Peak_Current_delay2: std_logic:='0'; -- ACTIVE HIGH When a Peak is detected. 
signal Peak_Current_delay3: std_logic:='0'; -- ACTIVE HIGH When a Peak is detected. 
signal Peak_Current_delay4: std_logic:='0'; -- ACTIVE HIGH When a Peak is detected. 
signal Peak_Current_delay5: std_logic:='0'; -- ACTIVE HIGH When a Peak is detected.  
signal Peak_Current_delay6: std_logic:='0'; -- ACTIVE HIGH When a Peak is detected.
signal Peak_Current_delay7: std_logic:='0'; -- ACTIVE HIGH When a Peak is detected.
signal Peak_Current_delay8: std_logic:='0'; -- ACTIVE HIGH When a Peak is detected.
signal Peak_Current_delay9: std_logic:='0'; -- ACTIVE HIGH When a Peak is detected.
signal Sending: std_logic:='0'; -- ACTIVE HIGH When the frame format is being formed 1024 samples = 64 presamples + 960 samples.  
signal Previous_Frame: std_logic:='0'; -- ACTIVE HIGH When there is info from previous frame format. 
signal Slope_Current: std_logic_vector(13 downto 0):= (others=>'0'); -- Real value of the Slope of the signal. 

-- Previous Calculations required (BASELINE , AMPLITUDE) signals
--signal din_delay1, din_delay2, din_delay3, din_delay4, din_delay5, din_delay6, din_delay7, din_delay8: std_logic_vector(13 downto 0); -- clk delay signals in order to estimate baseline using Simple Moving Average of 16 samples 
--signal din_delay9, din_delay10, din_delay11, din_delay12, din_delay13, din_delay14, din_delay15, din_delay16: std_logic_vector(13 downto 0); -- clk delay signals in order to estimate baseline using Simple Moving Average of 16 samples
--signal Baseline_Sum1_aux, Baseline_Sum1_reg: std_logic_vector(16 downto 0); 
--signal Baseline_Sum2_aux, Baseline_Sum2_reg: std_logic_vector(16 downto 0);
--signal Baseline_Sum3_aux, Baseline_Sum3_reg: std_logic_vector(16 downto 0);
--signal Baseline_Sum4_aux, Baseline_Sum4_reg: std_logic_vector(16 downto 0);
--signal Baseline_Sum5_aux, Baseline_Sum5_reg: std_logic_vector(16 downto 0);
--signal Baseline_Sum6_aux, Baseline_Sum6_reg: std_logic_vector(16 downto 0);
--signal Baseline_Sum7_aux, Baseline_Sum7_reg: std_logic_vector(16 downto 0);

signal din_delay1 : std_logic_vector(13 downto 0);
signal Baseline_Err_aux : std_logic_vector(11 downto 0);
signal Baseline_Add: std_logic_vector(14 downto 0):= (others=>'0'); 
signal Baseline_current:std_logic_vector(13 downto 0):= (others=>'0'); 
signal Baseline_delay1, Baseline_delay2, Baseline_delay3, Baseline_delay4, Baseline_delay5, Baseline_delay6 :std_logic_vector(13 downto 0):= (others=>'0');
signal Baseline_delay7, Baseline_delay8, Baseline_delay9, Baseline_delay10, Baseline_delay11, Baseline_delay12 :std_logic_vector(13 downto 0):= (others=>'0'); 
signal Baseline_delay13, Baseline_delay14, Baseline_delay15, Baseline_delay16:std_logic_vector(13 downto 0):= (others=>'0');
signal Baseline_delay17, Baseline_delay18, Baseline_delay19, Baseline_delay20:std_logic_vector(13 downto 0):= (others=>'0');  
signal Amplitude_Aux: std_logic_vector(14 downto 0):= (others=>'0'); 
signal Amplitude_current:std_logic_vector(14 downto 0):= (others=>'0'); 

-- LOCAL TRIGGER PRIMITIVES CALCULATION signals
signal Time_Peak_Current:   std_logic_vector(8 downto 0):= (others=>'0');       -- Time in Samples to achieve de Max peak
signal Time_Pulse_UB_Current: std_logic_vector(8 downto 0):= (others=>'0');     -- Time in Samples of the light pulse signal is UNDER BASELINE (without undershoot)
signal Time_Pulse_OB_Current: std_logic_vector(9 downto 0):= (others=>'0');     -- Time in Samples of the light pulse signal is OVER BASELINE (undershoot)
signal Time_Pulse_UB_2_Current: std_logic_vector(9 downto 0):= (others=>'0');   -- Time in Samples of the light pulse signal is UNDER THE BASELINE 2
signal Max_Peak_Current:   std_logic_vector(14 downto 0):= (others=>'0');       -- Amplitude in ADC counts od the peak
signal Charge_Current:   std_logic_vector(22 downto 0):= (others=>'0');         -- Charge of the light pulse (without undershoot) in ADC*samples
signal Number_Peaks_UB_Current:   std_logic_vector(3 downto 0):= (others=>'0'); -- Number of peaks detected when signal is UNDER BASELINE (without undershoot).  
signal Number_Peaks_OB_Current:   std_logic_vector(3 downto 0):= (others=>'0'); -- Number of peaks detected when signal is OVER BASELINE (undershoot).  
-- NOISE CHECK signals
signal High_Freq_Noise_aux: std_logic:='0'; -- ACTIVE HIGH when high freq noise is detected  

type Detection_State is   (No_Detection, Detection_UB, Detection_OB, Detection_UB_2, Data);
signal CurrentState_Detection, NextState_Detection: Detection_State;
signal Peak_Detection: std_logic :='0';
CONSTANT Minimum_Time_UB : integer := 20; --  320 ns (Just in case the signal is really noisy) --> Minumum undershoot is 6us
CONSTANT Minimum_Time_Undershoot: integer := 100; -- 5*Minimum_Time_UB, 1600 ns
signal Detection_Time: integer:=2048; 
CONSTANT Max_Detection_Time : integer := 2048; -- Maximun time allowed in detection mode --> 2 frames (2*1024). 
--signal Data_Available: std_logic :='0';

-- SELF-TRIGGER FRAME FORMAT signals
--type Frame_State is   (Idle, One, Two, Three, Four, Five, TrailerWords_Ready);
--signal CurrentState_Frame, NextState_Frame: Frame_State;

-- FRAME FORMTAT TRAILER WORDS FILLING signals 
--signal Detection_Count: integer:=0; -- Number of detections while data is being packed in the frame 
--CONSTANT Max_Detection_Frame : integer := 5; -- Max number of light detections per self-trigger frame

begin


----------------------- BASELINE AND AMPLITUDE CALCULATION    -----------------------
--Baseline_Sum7_aux     <= std_logic_vector(unsigned(Baseline_Sum6_reg)+unsigned(resize(unsigned('0'& din_delay13),17)));
--Baseline_Sum6_aux     <= std_logic_vector(unsigned(Baseline_Sum5_reg)+unsigned(resize(unsigned('0'& din_delay11),17)));
--Baseline_Sum5_aux     <= std_logic_vector(unsigned(Baseline_Sum4_reg)+unsigned(resize(unsigned('0'& din_delay9),17)));
--Baseline_Sum4_aux     <= std_logic_vector(unsigned(Baseline_Sum3_reg)+unsigned(resize(unsigned('0'& din_delay7),17)));
--Baseline_Sum3_aux     <= std_logic_vector(unsigned(Baseline_Sum2_reg)+unsigned(resize(unsigned('0'& din_delay5),17)));
--Baseline_Sum2_aux     <= std_logic_vector(unsigned(Baseline_Sum1_reg)+unsigned(resize(unsigned('0'& din_delay3),17)));
--Baseline_Sum1_aux     <= std_logic_vector(unsigned(resize(unsigned('0'& din),17))+unsigned(resize(unsigned('0'& din_delay1),17)));

--Baseline_Add    <= '0' & Baseline_Sum7_reg(16 downto 3);
Amplitude_Aux        <= std_logic_vector(signed('0' & din) - signed('0' & Baseline_delay20));

Baseline_Err_aux     <= std_logic_vector(unsigned("0" & din(13 downto 3)) - unsigned("0" & Baseline_Current(13 downto 3)));
Baseline_Add         <= std_logic_vector(signed('0' & Baseline_Current) + signed(resize(signed(Baseline_Err_aux),15)));

Baseline            <= ('0' & Baseline_delay4); -- TO BE REMOVED AFTER DEBUGGING
Amplitude           <= Amplitude_current; -- TO BE REMOVED AFTER DEBUGGING
Baseline_Amplitude: process(clock, reset)
begin
    if (clock'event and clock='1') then
        din_delay1 <= din;
        if(reset='1')then
            Baseline_Current    <= din;
            Baseline_delay1     <= din;
            Baseline_delay2     <= din;
            Baseline_delay3     <= din;
            Baseline_delay4     <= din;
            Baseline_delay5     <= din;
            Baseline_delay6     <= din;
            Baseline_delay7     <= din;
            Baseline_delay8     <= din;
            Baseline_delay9     <= din;
            Baseline_delay10     <= din;
            Baseline_delay11     <= din;
            Baseline_delay12     <= din;
            Baseline_delay13     <= din;
            Baseline_delay14     <= din;
            Baseline_delay15     <= din;
            Baseline_delay16     <= din;
            Baseline_delay17     <= din;
            Baseline_delay18     <= din;
            Baseline_delay19     <= din;
            Baseline_delay20     <= din;
            Amplitude_Current    <= (others=>'0');  
        else
            Amplitude_Current    <= Amplitude_Aux;
            if(Peak_Detection='1')then
                Baseline_Current    <= Baseline_delay20;
                Baseline_delay1     <= Baseline_delay20;
                Baseline_delay2     <= Baseline_delay20;
                Baseline_delay3     <= Baseline_delay20;
                Baseline_delay4     <= Baseline_delay20;
                Baseline_delay5     <= Baseline_delay20;
                Baseline_delay6     <= Baseline_delay20;
                Baseline_delay7     <= Baseline_delay20;
                Baseline_delay8     <= Baseline_delay20;
                Baseline_delay9     <= Baseline_delay20;
                Baseline_delay10    <= Baseline_delay20;
                Baseline_delay11    <= Baseline_delay20;
                Baseline_delay12    <= Baseline_delay20;
                Baseline_delay13    <= Baseline_delay20;
                Baseline_delay14    <= Baseline_delay20;
                Baseline_delay15    <= Baseline_delay20;
                Baseline_delay16    <= Baseline_delay20;
                Baseline_delay17    <= Baseline_delay20;
                Baseline_delay18    <= Baseline_delay20;
                Baseline_delay19    <= Baseline_delay20;
                Baseline_delay20    <= Baseline_delay20;
            else
                Baseline_delay20    <= Baseline_delay19;
                Baseline_delay19    <= Baseline_delay18;
                Baseline_delay18    <= Baseline_delay17;
                Baseline_delay17    <= Baseline_delay16;
                Baseline_delay16    <= Baseline_delay15;
                Baseline_delay15    <= Baseline_delay14;
                Baseline_delay14    <= Baseline_delay13;
                Baseline_delay13    <= Baseline_delay12;
                Baseline_delay12    <= Baseline_delay11;
                Baseline_delay11    <= Baseline_delay10;
                Baseline_delay10    <= Baseline_delay9;
                Baseline_delay9     <= Baseline_delay8;
                Baseline_delay8     <= Baseline_delay7;
                Baseline_delay7     <= Baseline_delay6;
                Baseline_delay6     <= Baseline_delay5;
                Baseline_delay5     <= Baseline_delay4;
                Baseline_delay4     <= Baseline_delay3;
                Baseline_delay3     <= Baseline_delay2;
                Baseline_delay2     <= Baseline_delay1;
                Baseline_delay1     <= Baseline_Current;
                Baseline_Current    <= Baseline_Add(13 downto 0);    
            end if;
        end if;
    end if;
end process Baseline_Amplitude;

----------------------- LOCAL PRIMITIVES CALCULATION    -----------------------


-- FSM DETECTION: This Finite Sate Machine determines if there is a light detection or not.
--      * No Detection --> Continous Baseline Calculation 
--      * Detection_UB --> Baseline is constant, Primitives calculation (Max _Amplitude, Time to max, Charge, Width_UB, number of pekas UB)
--      * Detection_OB --> Baseline is constant, Primitives calculation (Width_OB, number of pekas OB)
--      * Detection_UB_2 --> Baseline is constant. Only the time during this stage is calculated.
--      * Data --> Shows data of primitives calculated in previous stage  
Next_State_Detection: process(CurrentState_Detection, Self_Trigger, Amplitude_Current, Slope_Current, Time_Pulse_OB_Current, Time_Pulse_UB_2_Current, Detection_Time, Peak_Current, Peak_Current_delay1, Peak_Current_delay2, Peak_Current_delay3, Peak_Current_delay4, Peak_Current_delay5, Peak_Current_delay6, Peak_Current_delay7, Peak_Current_delay8, Peak_Current_delay9)
begin
    case CurrentState_Detection is
        when No_Detection =>
            if(Self_Trigger='1')then
                NextState_Detection <= Detection_UB;
            else
                NextState_Detection <= No_Detection; 
            end if;
        when Detection_UB =>
            if(signed(Amplitude_Current)>=0) then
                NextState_Detection <= Detection_OB;
            elsif (Detection_Time<=0) then
                NextState_Detection <= No_Detection;
            else
                NextState_Detection <= Detection_UB;
            end if;
        when Detection_OB => 
            if ((signed(Amplitude_Current)<=0) and (Peak_Current='0') and (Peak_Current_delay1='0')and (Peak_Current_delay2='0')and (Peak_Current_delay3='0')and (Peak_Current_delay4='0')and (Peak_Current_delay5='0')and (Peak_Current_delay6='0')and (Peak_Current_delay7='0')and (Peak_Current_delay8='0')and (Peak_Current_delay9='0') and (unsigned(Time_Pulse_OB_Current)>=Minimum_Time_Undershoot))then
                NextState_Detection <= Detection_UB_2;
            elsif (Detection_Time<=0) then
                NextState_Detection <= No_Detection;
            else
                NextState_Detection <= Detection_OB;
            end if;
        when Detection_UB_2 => 
            if ((signed(Amplitude_Current)>=0) and (unsigned(Time_Pulse_UB_2_Current)>=Minimum_Time_Undershoot))then
                NextState_Detection <= Data;
            elsif (Detection_Time<=0) then
                NextState_Detection <= No_Detection;
            else
                NextState_Detection <= Detection_UB_2;
            end if;  
        when Data =>
            if(Self_Trigger='1')then
                NextState_Detection <= Detection_UB;
            else
                NextState_Detection <= No_Detection; 
            end if;        
    end case;
end process Next_State_Detection;

FFs_Detection: process(clock, reset, Amplitude_Current, Peak_Current, High_Freq_Noise_aux)
begin
    if ((reset='1') or (High_Freq_Noise_aux='1'))  then
        CurrentState_Detection      <= No_Detection;                 -- Primitives calculation available. Active HIGH
        Time_Peak_Current           <= (others=>'0');       -- Time in Samples to achieve de Max peak
        Time_Pulse_UB_Current       <= (others=>'0');       -- Time in Samples of the light pulse (without undershoot)
        Time_Pulse_OB_Current       <= (others=>'0');
        Time_Pulse_UB_2_Current     <= (others=>'0'); 
        Max_Peak_Current            <= (others=>'0');       -- Amplitude in ADC counts od the peak
        Charge_Current              <= (others=>'0');       -- Charge of the light pulse (without undershoot) in ADC*samples
        Number_Peaks_UB_Current     <= (others=>'0');
        Number_Peaks_OB_Current     <= (others=>'0');
        Detection_Time              <= Max_Detection_Time; 

    elsif(clock'event and clock='1') then
        CurrentState_Detection <= NextState_Detection;
        if (CurrentState_Detection=No_Detection) then               -- Primitives calculation available. Active HIGH
            Time_Peak_Current       <= (others=>'0');       -- Time in Samples to achieve de Max peak
            Time_Pulse_UB_Current   <= "000000001";       -- Time in Samples of the light pulse (without undershoot)
            Time_Pulse_OB_Current   <= "0000000001";
            Time_Pulse_UB_2_Current <= "0000000001"; 
            Max_Peak_Current        <= (others=>'0');       -- Amplitude in ADC counts od the peak
            Charge_Current          <= (others=>'0');       -- Charge of the light pulse (without undershoot) in ADC*samples
            Number_Peaks_UB_Current <= "0001";
            Number_Peaks_OB_Current <= "0000";
            Detection_Time          <= Max_Detection_Time; 
        elsif(CurrentState_Detection=Detection_UB) then
            Time_Pulse_UB_Current <= std_logic_vector(unsigned(Time_Pulse_UB_Current) + to_unsigned(1,9));
            Charge_Current<= std_logic_vector(signed(Charge_Current) - signed(Amplitude_Current));
            Detection_Time <= Detection_Time - 1;
            if (signed(Max_Peak_Current)<= (- signed(Amplitude_Current))) then 
                Time_Peak_Current <= Time_Pulse_UB_Current(8 downto 0); 
                Max_Peak_Current <= std_logic_vector(- signed(Amplitude_Current)); 
            else
                Time_Peak_Current <= Time_Peak_Current; 
                Max_Peak_Current <= Max_Peak_Current; 
            end if;
            
            if (Peak_Current='1') then 
                Number_Peaks_UB_Current <= std_logic_vector(unsigned(Number_Peaks_UB_Current) + to_unsigned(1,4)); 
            else
                Number_Peaks_UB_Current <= Number_Peaks_UB_Current; 
            end if;
        elsif(CurrentState_Detection=Detection_OB) then
            Time_Pulse_OB_Current <= std_logic_vector(unsigned(Time_Pulse_OB_Current) + to_unsigned(1,10));
            Detection_Time <= Detection_Time - 1;            
            if (Peak_Current='1') then 
                Number_Peaks_OB_Current <= std_logic_vector(unsigned(Number_Peaks_OB_Current) + to_unsigned(1,4)); 
            else
                Number_Peaks_OB_Current <= Number_Peaks_OB_Current; 
            end if;
         elsif(CurrentState_Detection=Detection_UB_2) then
            Time_Pulse_UB_2_Current <= std_logic_vector(unsigned(Time_Pulse_UB_2_Current) + to_unsigned(1,10));
            Detection_Time <= Detection_Time - 1;
        end if;
    end if;
end process FFs_Detection;

Output_Detection: process(CurrentState_Detection,Time_Peak_Current,Time_Pulse_UB_Current, Time_Pulse_OB_Current,Max_Peak_Current, Charge_Current, Number_Peaks_UB_Current,Number_Peaks_OB_Current)
begin
    case CurrentState_Detection is
        when No_Detection => 
            Peak_Detection <= '0';
            Data_Available <= '0';                  -- Primitives calculation available. Active HIGH
            Time_Peak <= (others=>'0');                                                -- Time in Samples to achieve de Max peak
            Time_Pulse_UB<= (others=>'0');                          -- Time in Samples of the light pulse signal is UNDER BASELINE (without undershoot)
            Time_Pulse_OB<= (others=>'0');                           -- Time in Samples of the light pulse signal is OVER BASELINE (undershoot)
            Max_Peak<= (others=>'0');                          -- Amplitude in ADC counts od the peak
            Charge<= (others=>'0');                          -- Charge of the light pulse (without undershoot) in ADC*samples
            Number_Peaks_UB<= (others=>'0');                           -- Number of peaks detected when signal is UNDER BASELINE (without undershoot).  
            Number_Peaks_OB<= (others=>'0');                           -- Number of peaks detected when signal is OVER BASELINE (undershoot).  
        when Detection_UB =>        
            Peak_Detection <= '1'; 
            Data_Available <= '0';                  -- Primitives calculation available. Active HIGH
            Time_Peak <= (others=>'0');                                                -- Time in Samples to achieve de Max peak
            Time_Pulse_UB<= (others=>'0');                          -- Time in Samples of the light pulse signal is UNDER BASELINE (without undershoot)
            Time_Pulse_OB<= (others=>'0');                           -- Time in Samples of the light pulse signal is OVER BASELINE (undershoot)
            Max_Peak<= (others=>'0');                          -- Amplitude in ADC counts od the peak
            Charge<= (others=>'0');                          -- Charge of the light pulse (without undershoot) in ADC*samples
            Number_Peaks_UB<= (others=>'0');                           -- Number of peaks detected when signal is UNDER BASELINE (without undershoot).  
            Number_Peaks_OB<= (others=>'0');        
        when Detection_OB =>        
            Peak_Detection <= '1'; 
            Data_Available <= '0';                  -- Primitives calculation available. Active HIGH  
            Time_Peak <= (others=>'0');                                                -- Time in Samples to achieve de Max peak
            Time_Pulse_UB<= (others=>'0');                          -- Time in Samples of the light pulse signal is UNDER BASELINE (without undershoot)
            Time_Pulse_OB<= (others=>'0');                           -- Time in Samples of the light pulse signal is OVER BASELINE (undershoot)
            Max_Peak<= (others=>'0');                          -- Amplitude in ADC counts od the peak
            Charge<= (others=>'0');                          -- Charge of the light pulse (without undershoot) in ADC*samples
            Number_Peaks_UB<= (others=>'0');                           -- Number of peaks detected when signal is UNDER BASELINE (without undershoot).  
            Number_Peaks_OB<= (others=>'0');
        when Detection_UB_2 =>        
            Peak_Detection <= '1'; 
            Data_Available <= '0';                  -- Primitives calculation available. Active HIGH
            Time_Peak <= (others=>'0');                                                -- Time in Samples to achieve de Max peak
            Time_Pulse_UB<= (others=>'0');                          -- Time in Samples of the light pulse signal is UNDER BASELINE (without undershoot)
            Time_Pulse_OB<= (others=>'0');                           -- Time in Samples of the light pulse signal is OVER BASELINE (undershoot)
            Max_Peak<= (others=>'0');                          -- Amplitude in ADC counts od the peak
            Charge<= (others=>'0');                          -- Charge of the light pulse (without undershoot) in ADC*samples
            Number_Peaks_UB<= (others=>'0');                           -- Number of peaks detected when signal is UNDER BASELINE (without undershoot).  
            Number_Peaks_OB<= (others=>'0');        
       when Data => 
            Peak_Detection <= '0';
            Data_Available <= '1';                  -- Primitives calculation available. Active HIGH
            Time_Peak <= Time_Peak_Current;                                                -- Time in Samples to achieve de Max peak
            Time_Pulse_UB <= Time_Pulse_UB_Current;                          -- Time in Samples of the light pulse signal is UNDER BASELINE (without undershoot)
            Time_Pulse_OB <= Time_Pulse_OB_Current;                           -- Time in Samples of the light pulse signal is OVER BASELINE (undershoot)
            Max_Peak <= Max_Peak_Current(13 downto 0);                          -- Amplitude in ADC counts od the peak
            Charge <= Charge_Current;                          -- Charge of the light pulse (without undershoot) in ADC*samples
            Number_Peaks_UB <= Number_Peaks_UB_Current;                           -- Number of peaks detected when signal is UNDER BASELINE (without undershoot).  
            Number_Peaks_OB <= Number_Peaks_OB_Current;                  
    end case;
end process Output_Detection;

----------------------- PEAK CURRENT DELAY     -----------------------
Peak_Delay: process(clock, reset)
begin
    if (clock'event and clock='1') then
        if(reset='1')then
            Peak_Current_delay1 <= '0';
            Peak_Current_delay2 <= '0';
            Peak_Current_delay3 <= '0'; 
            Peak_Current_delay4 <= '0';
            Peak_Current_delay5 <= '0'; 
            Peak_Current_delay6 <= '0';
            Peak_Current_delay7 <= '0';
            Peak_Current_delay8 <= '0';
            Peak_Current_delay9 <= '0';
        else
            Peak_Current_delay1 <= Peak_Current;
            Peak_Current_delay2 <= Peak_Current_delay1;
            Peak_Current_delay3 <= Peak_Current_delay2; 
            Peak_Current_delay4 <= Peak_Current_delay3;
            Peak_Current_delay5 <= Peak_Current_delay4; 
            Peak_Current_delay6 <= Peak_Current_delay5;
            Peak_Current_delay7 <= Peak_Current_delay6;
            Peak_Current_delay8 <= Peak_Current_delay7;
            Peak_Current_delay9 <= Peak_Current_delay8;
        end if;
    end if;
end process Peak_Delay;

----------------------- HIGH FREQUENCY NOISE CHECK    -----------------------
Noise_Check: process(clock,Time_Pulse_UB_Current, CurrentState_Detection)
begin
    if(clock'event and clock='1') then
        if ((CurrentState_Detection = Detection_OB ) and (unsigned(Time_Pulse_UB_Current)< Minimum_Time_UB)) then
            High_Freq_Noise_aux <='1'; 
        else
            High_Freq_Noise_aux <='0'; 
        end if;
    end if;
end process Noise_Check;

High_Freq_Noise <= High_Freq_Noise_aux;

----------------------- INTERFACE WITH LOCAL PRIMITIVES CALCULATION BLOCK    -----------------------

-- Data coming from SELF_TRIGGER Block
Get_Interface_Params: process(clock)
begin
    if (clock'event and clock='1') then
        Interface_LOCAL_Primitves_IN_reg <= Interface_LOCAL_Primitves_IN;
    end if;
end process Get_Interface_Params;

Peak_Current <= Interface_LOCAL_Primitves_IN(0);
Slope_Current <= Interface_LOCAL_Primitves_IN(14 downto 1);


-- Data being sent to LOCAL PRIMITVE Calculation Block
Interface_LOCAL_Primitves_OUT(0)<= Peak_Detection;
Interface_LOCAL_Primitves_OUT(23 downto 1)<= (others=>'0');
end Behavioral;
