----------------------------------------------------------------------------------
-- Company: CIEMAT
-- Engineer: Ignacio López de Rego Benedi
-- 
-- Create Date: 10.04.2024 12:47:04
-- Design Name: 
-- Module Name: Filter_CIEMAT - Behavioral
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

------------------------- DESCRIPTION -----------------------------------
-- This Block filters the signal using low-pass filters to reduce high frequency noise. 
--      + As a FIRST stage Least Significant Bits are truncated --> CONFIGURABLE: Number of bits being truncated 1 or 2 
--      + As a SECOND stage a Simple Moving Average is used     --> CONFIGURABLE: Window size 4, 8, 16 or 32 samples.
--      + It is possible to ENABLE / DISABLE filtering
 
entity Filter_CIEMAT is
port(
    clock:          in  std_logic;                          -- AFE clock
    reset:          in  std_logic;                          -- Reset signal. ACTIVE HIGH 
    din:            in  std_logic_vector(13 downto 0);      -- Raw AFE data
    Config_Param:   in std_logic_vector(3 downto 0);        -- Config_Param[0] --> 1 = ENABLE filtering / 0 = DISABLE filtering 
                                                            -- Config_Param[1] --> '0' = 1 LSB truncated / '1' = 2 LSBs truncated 
                                                            -- Config_Param[3 downto 2] --> '00' = 2 Samples Window / '01' = 4 Samples Window / '10' = 8 Samples Window / '11' = 16 Samples Window
    filtered_dout:  out  std_logic_vector(13 downto 0)      -- Raw AFE data
);
end Filter_CIEMAT;

architecture Behavioral of Filter_CIEMAT is
-- DELAY INPUT signals 
signal din_delay1, din_delay2, din_delay3: std_logic_vector(13 downto 0);
-- CONFIGURATION signals 
signal Config_Param_Reg : std_logic_vector(3 downto 0):="1000";
signal Enable: std_logic :='1'; -- Enable Signal. Active HIGH
signal First_Stage_LSB: std_logic :='0'; -- SECOND STAGE filter configuration. '0' = 1 LSB truncated / '1' = 2 LSBs truncated 
signal Second_Stage_Window_Size: std_logic_vector(1 downto 0) := (others=>'0'); -- SECOND STAGE Averaging Window Size. '00' = 4 Samples / '01' = 8 Samples / '10' = 16 / '11' = 32 Samples
-- Filter FIRST stage signals 
signal First_Filtered_out: std_logic_vector(13 downto 0); -- First stage silter output
-- Filter SECOND stage signals 
signal Second_Filtered_delay1, Second_Filtered_delay2, Second_Filtered_delay3, Second_Filtered_delay4, Second_Filtered_delay5, Second_Filtered_delay6: std_logic_vector(13 downto 0); 
signal Second_Filtered_delay7, Second_Filtered_delay8, Second_Filtered_delay9, Second_Filtered_delay10, Second_Filtered_delay11, Second_Filtered_delay12: std_logic_vector(13 downto 0); 
signal Second_Filtered_delay13, Second_Filtered_delay14, Second_Filtered_delay15,Second_Filtered_delay16: std_logic_vector(13 downto 0); -- Buffer for Simple moving average filtering
signal Second_Filtered_out, Second_Filtered_out_delay1 : std_logic_vector(13 downto 0);-- Second stage silter output (real and delayed)
signal Second_Filtered_add, Second_Filtered_add_2: std_logic_vector(14 downto 0); -- SMA(n-1) + [ [x(n) - x(n-k)] / k ]
signal Second_Filtered_add_reg : std_logic_vector(13 downto 0);

signal Second_Filtered_Dif_aux, Second_Filtered_Dif_reg: std_logic_vector(13 downto 0);
signal Second_Filtered_Err_aux : std_logic_vector(12 downto 0);
signal Second_Filtered_Select: std_logic_vector(13 downto 0);

signal Second_Filtered_2_delay1, Second_Filtered_2_delay2, Second_Filtered_2_delay3, Second_Filtered_2_delay4, Second_Filtered_2_delay5, Second_Filtered_2_delay6: std_logic_vector(13 downto 0); 
signal Second_Filtered_2_delay7, Second_Filtered_2_delay8, Second_Filtered_2_delay9, Second_Filtered_2_delay10, Second_Filtered_2_delay11, Second_Filtered_2_delay12: std_logic_vector(13 downto 0); 
signal Second_Filtered_2_delay13, Second_Filtered_2_delay14, Second_Filtered_2_delay15,Second_Filtered_2_delay16: std_logic_vector(13 downto 0); -- Buffer for Simple moving average filtering
signal Second_Filtered_2_out, Second_Filtered_2_out_delay1 : std_logic_vector(13 downto 0);-- Second stage silter output (real and delayed)
signal Second_Filtered_2_add, Second_Filtered_2_add_2: std_logic_vector(14 downto 0); -- SMA(n-1) + [ [x(n) - x(n-k)] / k ]
signal Second_Filtered_2_add_reg : std_logic_vector(13 downto 0);

signal Second_Filtered_2_Dif_aux, Second_Filtered_2_Dif_reg: std_logic_vector(13 downto 0);
signal Second_Filtered_2_Err_aux : std_logic_vector(12 downto 0);
signal Second_Filtered_2_Select: std_logic_vector(13 downto 0);

--signal Third_Filtered_out: std_logic_vector(13 downto 0);-- Third stage filter output (real and delayed)
--signal Third_Filtered_add: std_logic_vector(14 downto 0);

-- post reset stabilization signals --> 64 clk cylcles so all the delays are properly filled
signal Reset_Timer: integer:=64; -- 64 clk
signal Not_allow_Filter: std_logic;
CONSTANT Reset_Timer_cnt : integer := 64; -- 64 clk

begin

----------------------- GET (Synchronous) AND UPDATE CONFIGURATION PARAMETERS     -----------------------

Get_Config_Params: process(clock)
begin
    if (clock'event and clock='1') then
        Config_Param_Reg <= Config_Param;
    end if;
end process Get_Config_Params;
-- Config_Param[0] --> 1 = ENABLE filtering / 0 = DISABLE filtering 
-- Config_Param[1] --> '0' = 1 LSB truncated / '1' = 2 LSBs truncated 
-- Config_Param[3 downto 2] --> '00' = 2 Samples Window / '01' = 4 Samples Window / '10' = 8 Samples Window / '11' = 16 Samples Window
Enable                      <= Config_Param_Reg(0);
First_Stage_LSB             <= Config_Param_Reg(1);
Second_Stage_Window_Size    <= Config_Param_Reg(3 downto 2);

----------------------- EXTRA DELAYS of input signal --> So the filter signal is in phase with the Raw data               -----------------------

Din_Delay_Stage: process(clock, reset)
begin
    if (clock'event and clock='1') then
        if(reset='1')then
            din_Delay1 <= (others =>'0');
            din_Delay2 <= (others =>'0');
            din_Delay3 <= (others =>'0');
        else
            din_Delay1 <= din;
            din_Delay2 <= din_Delay1;
            din_Delay3 <= din_Delay2;
        end if;
    end if;
end process Din_Delay_Stage;


----------------------- FIRST STAGE OF THE FILTER: Truncating LSBs               -----------------------

First_Filter_Stage: process(clock, reset)
begin
    if (clock'event and clock='1') then
        if(reset='1')then
            First_Filtered_out <= din;
        else
            if(First_Stage_LSB='0')then
                First_Filtered_out <= din and "11111111111110";
            else
                First_Filtered_out <= din and "11111111111100"; 
            end if;
        end if;
    end if;
end process First_Filter_Stage;


----------------------- SECOND STAGE OF THE FILTER: Low pass filtering to reduce High Freq noise    -----------------------

---- Filter Arithmetic Operations for the filter
Second_Filtered_Dif_aux      <= std_logic_vector(unsigned("000" & First_Filtered_out(13 downto 3)) - unsigned("000" & Second_Filtered_Select(13 downto 3)));
Second_Filtered_Err_aux      <= std_logic_vector(unsigned('0' & First_Filtered_out(13 downto 2)) - unsigned('0' & Second_Filtered_add_reg(13 downto 2)));
Second_Filtered_add          <= std_logic_vector(signed('0' & Second_Filtered_add_reg) + signed(resize(signed(Second_Filtered_Err_aux ),15)));-- + signed(resize(signed(Second_Filtered_Dif_aux),15)));
Second_Filtered_add_2        <= std_logic_vector(signed('0' & Second_Filtered_add_reg) + signed(resize(signed(Second_Filtered_Dif_reg ),15)));


---- Selects which element from the buffer to pick, and the shift (division)
Second_Filter_Stage_Arithmetic: process(Second_Stage_Window_Size, Second_Filtered_delay2, Second_Filtered_delay4, Second_Filtered_delay8, Second_Filtered_delay16)
begin
    if (Second_Stage_Window_Size = "00") then
        Second_Filtered_Select <= Second_Filtered_delay2;
    elsif (Second_Stage_Window_Size = "01") then
        Second_Filtered_Select <= Second_Filtered_delay4;               
    elsif (Second_Stage_Window_Size = "10") then 
        Second_Filtered_Select <= Second_Filtered_delay8;         
    else
        Second_Filtered_Select <= Second_Filtered_delay16;    
    end if;
end process Second_Filter_Stage_Arithmetic;

-- synchronous buffering data and filter output
Second_Filter_Stage: process(clock, reset)
begin
    if (clock'event and clock='1') then
        if(reset='1')then
            Second_Filtered_delay1      <= (others =>'0');
            Second_Filtered_delay2      <= (others =>'0'); 
            Second_Filtered_delay3      <= (others =>'0'); 
            Second_Filtered_delay4      <= (others =>'0'); 
            Second_Filtered_delay5      <= (others =>'0'); 
            Second_Filtered_delay6      <= (others =>'0'); 
            Second_Filtered_delay7      <= (others =>'0'); 
            Second_Filtered_delay8      <= (others =>'0'); 
            Second_Filtered_delay9      <= (others =>'0');
            Second_Filtered_delay10     <= (others =>'0'); 
            Second_Filtered_delay11     <= (others =>'0');
            Second_Filtered_delay12     <= (others =>'0'); 
            Second_Filtered_delay13     <= (others =>'0'); 
            Second_Filtered_delay14     <= (others =>'0'); 
            Second_Filtered_delay15     <= (others =>'0');
            Second_Filtered_delay16     <= (others =>'0');
            Second_Filtered_add_reg     <= (others =>'0');
            Second_Filtered_Dif_reg     <= (others =>'0');
            Second_Filtered_out         <= (others =>'0');
            --Second_Filtered_out_delay1   <= (others =>'0');
        else
            Second_Filtered_delay1      <= First_Filtered_out;
            Second_Filtered_delay2      <= Second_Filtered_delay1; 
            Second_Filtered_delay3      <= Second_Filtered_delay2; 
            Second_Filtered_delay4      <= Second_Filtered_delay3; 
            Second_Filtered_delay5      <= Second_Filtered_delay4; 
            Second_Filtered_delay6      <= Second_Filtered_delay5; 
            Second_Filtered_delay7      <= Second_Filtered_delay6; 
            Second_Filtered_delay8      <= Second_Filtered_delay7; 
            Second_Filtered_delay9      <= Second_Filtered_delay8; 
            Second_Filtered_delay10     <= Second_Filtered_delay9; 
            Second_Filtered_delay11     <= Second_Filtered_delay10; 
            Second_Filtered_delay12     <= Second_Filtered_delay11; 
            Second_Filtered_delay13     <= Second_Filtered_delay12; 
            Second_Filtered_delay14     <= Second_Filtered_delay13; 
            Second_Filtered_delay15     <= Second_Filtered_delay14;
            Second_Filtered_delay16     <= Second_Filtered_delay15; 
            Second_Filtered_add_reg     <= Second_Filtered_add(13 downto 0);
            Second_Filtered_Dif_reg     <= Second_Filtered_Dif_aux;
            --Second_Filtered_out_delay1   <= Second_Filtered_out;
            Second_Filtered_out         <= Second_Filtered_add_2(13 downto 0);   
        end if;
    end if;
end process Second_Filter_Stage;

-- Filter Arithmetic Operations for the filter
Second_Filtered_2_Dif_aux      <= std_logic_vector(unsigned("000" & Second_Filtered_out(13 downto 3)) - unsigned("000" & Second_Filtered_2_Select(13 downto 3)));
Second_Filtered_2_Err_aux      <= std_logic_vector(unsigned('0' & Second_Filtered_out(13 downto 2)) - unsigned('0' & Second_Filtered_2_add_reg(13 downto 2)));
Second_Filtered_2_add          <= std_logic_vector(signed('0' & Second_Filtered_2_add_reg) + signed(resize(signed(Second_Filtered_2_Err_aux ),15)));-- + signed(resize(signed(Second_Filtered_Dif_aux),15)));
Second_Filtered_2_add_2        <= std_logic_vector(signed('0' & Second_Filtered_2_add_reg) + signed(resize(signed(Second_Filtered_2_Dif_reg ),15)));


---- Selects which element from the buffer to pick, and the shift (division)
Second_Filter_2_Stage_Arithmetic: process(Second_Stage_Window_Size, Second_Filtered_2_delay2, Second_Filtered_2_delay4, Second_Filtered_2_delay8, Second_Filtered_2_delay16)
begin
    if (Second_Stage_Window_Size = "00") then
        Second_Filtered_2_Select <= Second_Filtered_2_delay2;
    elsif (Second_Stage_Window_Size = "01") then
        Second_Filtered_2_Select <= Second_Filtered_2_delay4;               
    elsif (Second_Stage_Window_Size = "10") then 
        Second_Filtered_2_Select <= Second_Filtered_2_delay8;         
    else
        Second_Filtered_2_Select <= Second_Filtered_2_delay16;    
    end if;
end process Second_Filter_2_Stage_Arithmetic;

-- synchronous buffering data and filter output
Second_Filter_2_Stage: process(clock, reset)
begin
    if (clock'event and clock='1') then
        if(reset='1')then
            Second_Filtered_2_delay1      <= (others =>'0');
            Second_Filtered_2_delay2      <= (others =>'0'); 
            Second_Filtered_2_delay3      <= (others =>'0'); 
            Second_Filtered_2_delay4      <= (others =>'0'); 
            Second_Filtered_2_delay5      <= (others =>'0'); 
            Second_Filtered_2_delay6      <= (others =>'0'); 
            Second_Filtered_2_delay7      <= (others =>'0'); 
            Second_Filtered_2_delay8      <= (others =>'0'); 
            Second_Filtered_2_delay9      <= (others =>'0');
            Second_Filtered_2_delay10     <= (others =>'0'); 
            Second_Filtered_2_delay11     <= (others =>'0');
            Second_Filtered_2_delay12     <= (others =>'0'); 
            Second_Filtered_2_delay13     <= (others =>'0'); 
            Second_Filtered_2_delay14     <= (others =>'0'); 
            Second_Filtered_2_delay15     <= (others =>'0');
            Second_Filtered_2_delay16     <= (others =>'0');
            Second_Filtered_2_add_reg     <= (others =>'0');
            Second_Filtered_2_Dif_reg     <= (others =>'0');
            Second_Filtered_2_out         <= (others =>'0');
            --Second_Filtered_2_out_delay1  <= (others =>'0');
        else
            Second_Filtered_2_delay1      <= Second_Filtered_out;
            Second_Filtered_2_delay2      <= Second_Filtered_2_delay1; 
            Second_Filtered_2_delay3      <= Second_Filtered_2_delay2; 
            Second_Filtered_2_delay4      <= Second_Filtered_2_delay3; 
            Second_Filtered_2_delay5      <= Second_Filtered_2_delay4; 
            Second_Filtered_2_delay6      <= Second_Filtered_2_delay5; 
            Second_Filtered_2_delay7      <= Second_Filtered_2_delay6; 
            Second_Filtered_2_delay8      <= Second_Filtered_2_delay7; 
            Second_Filtered_2_delay9      <= Second_Filtered_2_delay8; 
            Second_Filtered_2_delay10     <= Second_Filtered_2_delay9; 
            Second_Filtered_2_delay11     <= Second_Filtered_2_delay10; 
            Second_Filtered_2_delay12     <= Second_Filtered_2_delay11; 
            Second_Filtered_2_delay13     <= Second_Filtered_2_delay12; 
            Second_Filtered_2_delay14     <= Second_Filtered_2_delay13; 
            Second_Filtered_2_delay15     <= Second_Filtered_2_delay14;
            Second_Filtered_2_delay16     <= Second_Filtered_2_delay15; 
            Second_Filtered_2_add_reg     <= Second_Filtered_2_add(13 downto 0);
            Second_Filtered_2_Dif_reg     <= Second_Filtered_2_Dif_aux;
            --Second_Filtered_2_out_delay1  <= Second_Filtered_2_out;
            Second_Filtered_2_out         <= Second_Filtered_2_add_2(13 downto 0);   
        end if;
    end if;
end process Second_Filter_2_Stage;



----------------------- TIMER AFTER RESET       -----------------------

Timer_Reset_Stage: process(clock, reset)
begin
    if (clock'event and clock='1') then
        if(reset='1')then
            Reset_Timer <= Reset_Timer_cnt;
            Not_allow_Filter <= '1';
        else
            if(Reset_Timer>0)then
                Reset_Timer <= Reset_Timer - 1;
                Not_allow_Filter <= '1';
            else
                Reset_Timer <= Reset_Timer;
                Not_allow_Filter <= '0';
            end if;
        end if;
    end if;
end process Timer_Reset_Stage;

------------------------- THIRD STAGE OF THE FILTER: DC BLOCKER (High - Pass Filter) -----------------------

------ Filter Arithmetic Operations for the filter
--Third_Filtered_add          <= std_logic_vector(signed('0' & Second_Filtered_2_out) - signed('0' & Second_Filtered_2_out_delay1) + signed(resize(signed(Third_Filtered_out(13 downto 1) ),15))+ signed(resize(signed(Third_Filtered_out(13 downto 2) ),15))+ signed(resize(signed(Third_Filtered_out(13 downto 3) ),15))+ signed(resize(signed(Third_Filtered_out(13 downto 4) ),15)));

---- synchronous buffering data and filter output
--Third_Filter_Stage: process(clock, reset)
--begin
--    if (clock'event and clock='1') then
--        if(reset='1')then
--            Third_Filtered_out         <= (others =>'0');
--        else
--            Third_Filtered_out         <= Third_Filtered_add(13 downto 0);  
--        end if;
--    end if;
--end process Third_Filter_Stage;
----------------------- OUTPUT SELECTION: Filtered / Not Filtered                -----------------------

Output: process(Enable, Second_Filtered_2_out, din_Delay3, Not_allow_Filter)
begin
    if((Enable='1') and (Not_allow_Filter='0'))then
        filtered_dout <= Second_Filtered_2_out;
    else
        filtered_dout <= din_Delay3; 
    end if;
end process Output;

end Behavioral;
