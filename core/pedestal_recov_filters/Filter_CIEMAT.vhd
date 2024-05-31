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
signal Second_Filtered_delay13, Second_Filtered_delay14, Second_Filtered_delay15,Second_Filtered_delay16, Second_Filtered_delay17, Second_Filtered_delay18 : std_logic_vector(13 downto 0); -- Buffer for Simple moving average filtering
signal Second_Filtered_delay19, Second_Filtered_delay20, Second_Filtered_delay21,Second_Filtered_delay22, Second_Filtered_delay23, Second_Filtered_delay24 : std_logic_vector(13 downto 0); -- Buffer for Simple moving average filtering
signal Second_Filtered_delay25, Second_Filtered_delay26, Second_Filtered_delay27, Second_Filtered_delay28,Second_Filtered_delay29 : std_logic_vector(13 downto 0); -- Buffer for Simple moving average filtering
signal Second_Filtered_out: std_logic_vector(13 downto 0);-- Second stage silter output (real and delayed)
--signal Second_Filtered_select: std_logic_vector(14 downto 0); -- Select which element from the buffer to substract --> x(n-k)
--signal Second_Filtered_substract: std_logic_vector(14 downto 0); --    x(n) - x(n-k)
--signal Second_Filtered_substract_REG: std_logic_vector(14 downto 0); --    x(n) - x(n-k) REGISTERED
--signal Second_Filtered_substract_NEGATIVE: std_logic_vector(14 downto 0); --   -[x(n) - x(n-k)]
--signal Second_Filtered_substract_NEGATIVE_REG: std_logic_vector(14 downto 0); --   -[x(n) - x(n-k)] REGISTERED
--signal Second_Filtered_shift: std_logic_vector(14 downto 0); -- [x(n) - x(n-k)] / k
signal Second_Filtered_add: std_logic_vector(13 downto 0); -- SMA(n-1) + [ [x(n) - x(n-k)] / k ]
signal Second_Filtered_Sum1_aux, Second_Filtered_Sum1_reg: std_logic_vector(17 downto 0); 
signal Second_Filtered_Sum2_aux, Second_Filtered_Sum2_reg: std_logic_vector(17 downto 0);
signal Second_Filtered_Sum3_aux, Second_Filtered_Sum3_reg: std_logic_vector(17 downto 0);
signal Second_Filtered_Sum4_aux, Second_Filtered_Sum4_reg: std_logic_vector(17 downto 0);
signal Second_Filtered_Sum5_aux, Second_Filtered_Sum5_reg: std_logic_vector(17 downto 0);
signal Second_Filtered_Sum6_aux, Second_Filtered_Sum6_reg: std_logic_vector(17 downto 0);
signal Second_Filtered_Sum7_aux, Second_Filtered_Sum7_reg: std_logic_vector(17 downto 0);
signal Second_Filtered_Sum8_aux, Second_Filtered_Sum8_reg: std_logic_vector(17 downto 0);
signal Second_Filtered_Sum9_aux, Second_Filtered_Sum9_reg: std_logic_vector(17 downto 0);
signal Second_Filtered_Sum10_aux, Second_Filtered_Sum10_reg: std_logic_vector(17 downto 0);
signal Second_Filtered_Sum11_aux, Second_Filtered_Sum11_reg: std_logic_vector(17 downto 0);
signal Second_Filtered_Sum12_aux, Second_Filtered_Sum12_reg: std_logic_vector(17 downto 0);
signal Second_Filtered_Sum13_aux, Second_Filtered_Sum13_reg: std_logic_vector(17 downto 0);
signal Second_Filtered_Sum14_aux, Second_Filtered_Sum14_reg: std_logic_vector(17 downto 0);
signal Second_Filtered_Sum15_aux, Second_Filtered_Sum15_reg: std_logic_vector(17 downto 0);

-- post reset stabilization signals --> 32 clk cylcles so all the delays are properly filled
signal Reset_Timer: integer:=32; -- 32 clk
signal Not_allow_Filter: std_logic;
CONSTANT Reset_Timer_cnt : integer := 32; -- 32 clk

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


----------------------- SECOND STAGE OF THE FILTER: Simple Moving Average        -----------------------
--Second_Filter_Select4    <= std_logic_vector(shift_right(unsigned(Second_Filtered_Sum15),4));
--Second_Filter_Select3    <= std_logic_vector(shift_right(unsigned(Second_Filtered_Sum7),3));
--Second_Filter_Select2    <= std_logic_vector(shift_right(unsigned(Second_Filtered_Sum3),2));
--Second_Filter_Select1    <= std_logic_vector(shift_right(unsigned(Second_Filtered_Sum1),1));
Second_Filtered_Sum15_aux    <= std_logic_vector(unsigned(Second_Filtered_Sum14_reg)+unsigned(resize(unsigned('0'& Second_Filtered_delay29),18)));
Second_Filtered_Sum14_aux     <= std_logic_vector(unsigned(Second_Filtered_Sum13_reg)+unsigned(resize(unsigned('0'& Second_Filtered_delay27),18)));
Second_Filtered_Sum13_aux     <= std_logic_vector(unsigned(Second_Filtered_Sum12_reg)+unsigned(resize(unsigned('0'& Second_Filtered_delay25),18)));
Second_Filtered_Sum12_aux     <= std_logic_vector(unsigned(Second_Filtered_Sum11_reg)+unsigned(resize(unsigned('0'& Second_Filtered_delay23),18)));
Second_Filtered_Sum11_aux     <= std_logic_vector(unsigned(Second_Filtered_Sum10_reg)+unsigned(resize(unsigned('0'& Second_Filtered_delay21),18)));
Second_Filtered_Sum10_aux     <= std_logic_vector(unsigned(Second_Filtered_Sum9_reg)+unsigned(resize(unsigned('0'& Second_Filtered_delay19),18)));
Second_Filtered_Sum9_aux     <= std_logic_vector(unsigned(Second_Filtered_Sum8_reg)+unsigned(resize(unsigned('0'& Second_Filtered_delay17),18)));
Second_Filtered_Sum8_aux     <= std_logic_vector(unsigned(Second_Filtered_Sum7_reg)+unsigned(resize(unsigned('0'& Second_Filtered_delay15),18)));
Second_Filtered_Sum7_aux     <= std_logic_vector(unsigned(Second_Filtered_Sum6_reg)+unsigned(resize(unsigned('0'& Second_Filtered_delay13),18)));
Second_Filtered_Sum6_aux     <= std_logic_vector(unsigned(Second_Filtered_Sum5_reg)+unsigned(resize(unsigned('0'& Second_Filtered_delay11),18)));
Second_Filtered_Sum5_aux     <= std_logic_vector(unsigned(Second_Filtered_Sum4_reg)+unsigned(resize(unsigned('0'& Second_Filtered_delay9),18)));
Second_Filtered_Sum4_aux     <= std_logic_vector(unsigned(Second_Filtered_Sum3_reg)+unsigned(resize(unsigned('0'& Second_Filtered_delay7),18)));
Second_Filtered_Sum3_aux     <= std_logic_vector(unsigned(Second_Filtered_Sum2_reg)+unsigned(resize(unsigned('0'& Second_Filtered_delay5),18)));
Second_Filtered_Sum2_aux     <= std_logic_vector(unsigned(Second_Filtered_Sum1_reg)+unsigned(resize(unsigned('0'& Second_Filtered_delay3),18)));
Second_Filtered_Sum1_aux     <= std_logic_vector(unsigned(resize(unsigned('0'& First_Filtered_out),18))+unsigned(resize(unsigned('0'& Second_Filtered_delay1),18)));


---- Filter Arithmetic Operations for the filter
--Second_Filtered_substract <= std_logic_vector(signed('0' & First_Filtered_out)- signed(Second_Filtered_select));
--Second_Filtered_substract_NEGATIVE <= std_logic_vector(-(signed('0' & First_Filtered_out)- signed(Second_Filtered_select)));
--Second_Filtered_add <= std_logic_vector(signed('0' & Second_Filtered_out)+signed(Second_Filtered_shift));
---- Selects which element from the buffer to pick, and the shift (division)
--Second_Filter_Stage_Arithmetic: process(Second_Stage_Window_Size, Second_Filtered_substract_REG,Second_Filtered_substract_NEGATIVE_REG, Second_Filtered_delay2, Second_Filtered_delay4, Second_Filtered_delay8, Second_Filtered_delay16)
Second_Filter_Stage_Arithmetic: process(Second_Stage_Window_Size, Second_Filtered_Sum1_reg, Second_Filtered_Sum3_reg, Second_Filtered_Sum7_reg, Second_Filtered_Sum15_reg)
begin
    if (Second_Stage_Window_Size = "00") then
        Second_Filtered_add <= Second_Filtered_Sum1_reg(14 downto 1);
--            Second_Filtered_select <= "0" & Second_Filtered_delay2;
--            if(Second_Filtered_substract_REG(14)='0') then
--                Second_Filtered_shift  <= ('0' & Second_Filtered_substract_REG(14 downto 1)); 
--            else
--                Second_Filtered_shift  <= std_logic_vector( - signed('0' & Second_Filtered_substract_NEGATIVE_REG(14 downto 1))); 
--            end if;    
    elsif (Second_Stage_Window_Size = "01") then
        Second_Filtered_add <= Second_Filtered_Sum3_reg(15 downto 2);               
--            Second_Filtered_select <= "0" & Second_Filtered_delay4;
--            if(Second_Filtered_substract_REG(14)='0') then
--                Second_Filtered_shift  <= ("00" & Second_Filtered_substract_REG(14 downto 2)); 
--            else
--                Second_Filtered_shift  <= std_logic_vector( - signed("00" & Second_Filtered_substract_NEGATIVE_REG(14 downto 2))); 
--            end if;
    elsif (Second_Stage_Window_Size = "10") then 
        Second_Filtered_add <= Second_Filtered_Sum7_reg(16 downto 3);         
--            Second_Filtered_select <= "0" & Second_Filtered_delay8;
--            if(Second_Filtered_substract_REG(14)='0') then
--                Second_Filtered_shift  <= ("000" & Second_Filtered_substract_REG(14 downto 3)); 
--            else
--                Second_Filtered_shift  <= std_logic_vector( - signed("000" & Second_Filtered_substract_NEGATIVE_REG(14 downto 3))); 
--            end if;
    else
        Second_Filtered_add <= Second_Filtered_Sum15_reg(17 downto 4);    
--            Second_Filtered_select <= "0" & Second_Filtered_delay16;
--            if(Second_Filtered_substract_REG(14)='0') then
--                Second_Filtered_shift  <= ("0000" & Second_Filtered_substract_REG(14 downto 4)); 
--            else
--                Second_Filtered_shift  <= std_logic_vector( - signed("0000" & Second_Filtered_substract_NEGATIVE_REG(14 downto 4))); 
--            end if;
    end if;
end process Second_Filter_Stage_Arithmetic;

-- synchronous buffering data and filter output
Second_Filter_Stage: process(clock, reset)
begin
    if (clock'event and clock='1') then
        if(reset='1')then
--            Second_Filtered_delay1      <= First_Filtered_out;
--            Second_Filtered_delay2      <= First_Filtered_out; 
--            Second_Filtered_delay3      <= First_Filtered_out; 
--            Second_Filtered_delay4      <= First_Filtered_out; 
--            Second_Filtered_delay5      <= First_Filtered_out; 
--            Second_Filtered_delay6      <= First_Filtered_out; 
--            Second_Filtered_delay7      <= First_Filtered_out; 
--            Second_Filtered_delay8      <= First_Filtered_out; 
--            Second_Filtered_delay9      <= First_Filtered_out; 
--            Second_Filtered_delay10     <= First_Filtered_out; 
--            Second_Filtered_delay11     <= First_Filtered_out; 
--            Second_Filtered_delay12     <= First_Filtered_out; 
--            Second_Filtered_delay13     <= First_Filtered_out; 
--            Second_Filtered_delay14     <= First_Filtered_out; 
--            Second_Filtered_delay15     <= First_Filtered_out;
--            Second_Filtered_delay16      <= First_Filtered_out;
--            Second_Filtered_delay17     <= First_Filtered_out; 
--            Second_Filtered_delay18      <= First_Filtered_out; 
--            Second_Filtered_delay19      <= First_Filtered_out; 
--            Second_Filtered_delay20      <= First_Filtered_out; 
--            Second_Filtered_delay21      <= First_Filtered_out; 
--            Second_Filtered_delay22      <= First_Filtered_out; 
--            Second_Filtered_delay23      <= First_Filtered_out; 
--            Second_Filtered_delay24      <= First_Filtered_out; 
--            Second_Filtered_delay25     <= First_Filtered_out; 
--            Second_Filtered_delay26     <= First_Filtered_out; 
--            Second_Filtered_delay27     <= First_Filtered_out; 
--            Second_Filtered_delay28     <= First_Filtered_out; 
--            Second_Filtered_delay29     <= First_Filtered_out; 
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
            Second_Filtered_delay16      <= (others =>'0');
            Second_Filtered_delay17      <= (others =>'0'); 
            Second_Filtered_delay18      <= (others =>'0'); 
            Second_Filtered_delay19      <= (others =>'0'); 
            Second_Filtered_delay20      <= (others =>'0'); 
            Second_Filtered_delay21      <= (others =>'0');
            Second_Filtered_delay22      <= (others =>'0');
            Second_Filtered_delay23      <= (others =>'0'); 
            Second_Filtered_delay24      <= (others =>'0');
            Second_Filtered_delay25     <= (others =>'0'); 
            Second_Filtered_delay26     <= (others =>'0');
            Second_Filtered_delay27     <= (others =>'0'); 
            Second_Filtered_delay28     <= (others =>'0'); 
            Second_Filtered_delay29     <= (others =>'0'); 
            Second_Filtered_Sum1_reg    <= (others =>'0');
            Second_Filtered_Sum2_reg    <= (others =>'0');
            Second_Filtered_Sum3_reg    <= (others =>'0');
            Second_Filtered_Sum4_reg    <= (others =>'0');
            Second_Filtered_Sum5_reg    <= (others =>'0');
            Second_Filtered_Sum6_reg    <= (others =>'0');
            Second_Filtered_Sum7_reg    <= (others =>'0');
            Second_Filtered_Sum8_reg    <= (others =>'0');
            Second_Filtered_Sum9_reg    <= (others =>'0');
            Second_Filtered_Sum10_reg    <= (others =>'0');
            Second_Filtered_Sum11_reg    <= (others =>'0');
            Second_Filtered_Sum12_reg    <= (others =>'0');
            Second_Filtered_Sum13_reg    <= (others =>'0');
            Second_Filtered_Sum14_reg    <= (others =>'0');
            Second_Filtered_Sum15_reg    <= (others =>'0');
           
            -- Second_Filtered_delay16     <= First_Filtered_out;
            -- Second_Filtered_substract_REG <= (OTHERS=>'0');
            -- Second_Filtered_substract_NEGATIVE_REG <= (OTHERS=>'0');
            Second_Filtered_out         <= (others =>'0');
            --Second_Filtered_out         <= First_Filtered_out;  
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
            Second_Filtered_delay16      <= Second_Filtered_delay15;
            Second_Filtered_delay17     <= Second_Filtered_delay16; 
            Second_Filtered_delay18      <= Second_Filtered_delay17; 
            Second_Filtered_delay19      <= Second_Filtered_delay18;
            Second_Filtered_delay20      <= Second_Filtered_delay19; 
            Second_Filtered_delay21      <= Second_Filtered_delay20; 
            Second_Filtered_delay22      <= Second_Filtered_delay21; 
            Second_Filtered_delay23      <= Second_Filtered_delay22; 
            Second_Filtered_delay24      <= Second_Filtered_delay23; 
            Second_Filtered_delay25     <= Second_Filtered_delay24; 
            Second_Filtered_delay26     <= Second_Filtered_delay25; 
            Second_Filtered_delay27     <= Second_Filtered_delay26; 
            Second_Filtered_delay28     <= Second_Filtered_delay27; 
            Second_Filtered_delay29     <= Second_Filtered_delay28;
            Second_Filtered_Sum1_reg    <= Second_Filtered_Sum1_aux;
            Second_Filtered_Sum2_reg    <= Second_Filtered_Sum2_aux;
            Second_Filtered_Sum3_reg    <= Second_Filtered_Sum3_aux;
            Second_Filtered_Sum4_reg    <= Second_Filtered_Sum4_aux;
            Second_Filtered_Sum5_reg    <= Second_Filtered_Sum5_aux;
            Second_Filtered_Sum6_reg    <= Second_Filtered_Sum6_aux;
            Second_Filtered_Sum7_reg    <= Second_Filtered_Sum7_aux;
            Second_Filtered_Sum8_reg    <= Second_Filtered_Sum8_aux;
            Second_Filtered_Sum9_reg    <= Second_Filtered_Sum9_aux;
            Second_Filtered_Sum10_reg    <= Second_Filtered_Sum10_aux;
            Second_Filtered_Sum11_reg    <= Second_Filtered_Sum11_aux;
            Second_Filtered_Sum12_reg    <= Second_Filtered_Sum12_aux;
            Second_Filtered_Sum13_reg    <= Second_Filtered_Sum13_aux;
            Second_Filtered_Sum14_reg    <= Second_Filtered_Sum14_aux;
            Second_Filtered_Sum15_reg    <= Second_Filtered_Sum15_aux;  
            -- Second_Filtered_delay16     <= Second_Filtered_delay15;
            -- Second_Filtered_substract_REG <= Second_Filtered_substract;
            -- Second_Filtered_substract_NEGATIVE_REG <= Second_Filtered_substract_NEGATIVE;
            Second_Filtered_out         <= Second_Filtered_add(13 downto 0);
--            if (Second_Stage_Window_Size = "00") then
--                --Second_Filtered_out         <= Second_Filtered_add(13 downto 0);
--                Second_Filtered_out <= Second_Filter_Select1(13 downto 0);
--            elsif (Second_Stage_Window_Size = "01") then
--                --Second_Filtered_out         <= Second_Filtered_add(15 downto 2);
--                Second_Filtered_out <= Second_Filter_Select2(13 downto 0);
--            elsif (Second_Stage_Window_Size = "10") then
--                --Second_Filtered_out         <= Second_Filtered_add(16 downto 3);
--                Second_Filtered_out <= Second_Filter_Select3(13 downto 0);              
--            else
--                --Second_Filtered_out         <= Second_Filtered_add(17 downto 4);
--                Second_Filtered_out <= Second_Filter_Select4(13 downto 0); 
--            end if;     
        end if;
    end if;
end process Second_Filter_Stage;


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


----------------------- OUTPUT SELECTION: Filtered / Not Filtered                -----------------------

Output: process(Enable, Second_Filtered_out, din, Not_allow_Filter)
begin
    if((Enable='1') and (Not_allow_Filter='0'))then
        filtered_dout <= Second_Filtered_out;
    else
        filtered_dout <= din; 
    end if;
end process Output;

end Behavioral;
