-- st_xc_filt.vhd
-- high pass first order IIR filter for the matching filter self trigger module
--
-- This module implements a high pass first order IIR filter designed to eliminate the baseline 
-- in the data coming from one single channel so that the matching filter used to self trigger 
-- this channel works as intended. An IIR filter implemented is a connection of a FIR forward 
-- and a feedback FIR
--
-- Daniel Avila Gomez <daniel.avila.gomez@cern.ch> 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_signed.all;

library unisim;
use unisim.vcomponents.all;

entity st_xc_filt is
port(
    reset: in std_logic;
    clock: in std_logic; -- AFE clock 62.500 MHz
    din: in std_logic_vector(13 downto 0); -- AFE data (with baseline)
    dout: out std_logic_vector(13 downto 0) -- filtered AFE data (no baseline)
);
end st_xc_filt;

architecture st_xc_filt_arch of st_xc_filt is

    -- coefficients are represented in Q1.17 format
    constant num: signed(17 downto 0) := to_signed(integer(130973),18);
    constant den: signed(17 downto 0) := to_signed(integer(130874),18);

    -- module interconnect
    signal in_A: std_logic_vector(29 downto 0) := (others => '0');
    signal in_D: std_logic_vector(24 downto 0) := (others => '0');
    signal out_0: std_logic_vector(47 downto 0) := (others => '0');
    signal out_1: std_logic_vector(47 downto 0) := (others => '0'); -- past output value multiplied with the coefficient
    signal out_0_resized: std_logic_vector(29 downto 0) := (others => '0'); -- resized value of the output, so that it fits the DSP slice multiplication input
    signal out_0_shift: std_logic_vector(47 downto 0) := (others => '0'); -- refers to the right shifted, integer value of the filter's output
    signal out_1_shift: std_logic_vector(47 downto 0) := (others => '0');
    signal out_0_less_1: std_logic_vector(47 downto 0) := (others => '0'); -- refers to the output of the module but minus nuber 1
    signal out_0_inv: std_logic_vector(47 downto 0) := (others => '0'); -- refers to the last subtraction but inverted with a not gate

begin

    -- transform input to signed
    in_A <= std_logic_vector(resize(unsigned(din),30));
    in_D <= std_logic_vector(resize(unsigned(din),25));

    -- forward FIR filter (input signal and its register)
    fir_forward: DSP48E1
    generic map(
        A_INPUT            => "DIRECT",
        B_INPUT            => "DIRECT",
        USE_DPORT          => TRUE, -- use the D port so that the pre subtraction can be performed
        USE_MULT           => "MULTIPLY",
        USE_SIMD           => "ONE48",
        AUTORESET_PATDET   => "NO_RESET",
        MASK               => X"3fffffffffff",
        PATTERN            => X"000000000000",
        SEL_MASK           => "MASK",
        SEL_PATTERN        => "PATTERN",
        USE_PATTERN_DETECT => "NO_PATDET",
        ACASCREG           => 1,
        ADREG              => 1, -- use one pipeline stage
        ALUMODEREG         => 0,
        AREG               => 2, -- use two pipeline stages
        BCASCREG           => 0,
        BREG               => 0,
        CARRYINREG         => 0,
        CARRYINSELREG      => 0,
        CREG               => 1, -- use one pipeline stage
        DREG               => 1, -- use one pipeline stage
        INMODEREG          => 0,
        MREG               => 1, -- use one pipeline stage
        OPMODEREG          => 0,
        PREG               => 0
    )   
    port map(
        ACOUT             => open,
        BCOUT             => open,
        CARRYCASCOUT      => open,
        MULTSIGNOUT       => open,
        PCOUT             => open,
        OVERFLOW          => open,
        PATTERNBDETECT    => open,
        PATTERNDETECT     => open,
        UNDERFLOW         => open,
        CARRYOUT          => open,
        P                 => out_0,
        ACIN              => b"000000000000000000000000000000",
        BCIN              => b"000000000000000000",
        CARRYCASCIN       => '0',
        MULTSIGNIN        => '0',
        PCIN              => X"000000000000",
        ALUMODE           => X"0",
        CARRYINSEL        => b"000",
        CLK               => clock,
        INMODE            => b"01100",
        OPMODE            => b"0110101",
        A                 => in_A,
        B                 => std_logic_vector(num),
        C                 => out_1_shift,
        CARRYIN           => '0',
        D                 => in_D,
        CEA1              => '1',
        CEA2              => '1',
        CEAD              => '1',
        CEALUMODE         => '0',
        CEB1              => '0',
        CEB2              => '0',
        CEC               => '1',
        CECARRYIN         => '0',
        CECTRL            => '0',
        CED               => '1',
        CEINMODE          => '0',
        CEM               => '1',
        CEP               => '0',
        RSTA              => reset,
        RSTALLCARRYIN     => '0',
        RSTALUMODE        => '0',
        RSTB              => '0',
        RSTC              => reset,
        RSTCTRL           => '0',
        RSTD              => reset,
        RSTINMODE         => '0',
        RSTM              => reset,
        RSTP              => '0' 
    );

    -- output of this FIR filter is the current y[n] value
    -- right shift it to turn it into a Q14.18 format representation (embedded in a 48 bit signed)
    out_0_shift <= std_logic_vector(shift_right(signed(out_0),6));
    -- resize it so it fits within 30 bits
    out_0_resized <= std_logic_vector(resize(signed(out_0_shift),30));

    -- feedback FIR filter (output signal)
    fir_feedback: DSP48E1
    generic map(
        A_INPUT            => "DIRECT",
        B_INPUT            => "DIRECT",
        USE_DPORT          => FALSE,
        USE_MULT           => "MULTIPLY",
        USE_SIMD           => "ONE48",
        AUTORESET_PATDET   => "NO_RESET",
        MASK               => X"3fffffffffff",
        PATTERN            => X"000000000000",
        SEL_MASK           => "MASK",
        SEL_PATTERN        => "PATTERN",
        USE_PATTERN_DETECT => "NO_PATDET",
        ACASCREG           => 0,
        ADREG              => 1,
        ALUMODEREG         => 0,
        AREG               => 0,
        BCASCREG           => 0,
        BREG               => 0,
        CARRYINREG         => 0,
        CARRYINSELREG      => 0,
        CREG               => 1,
        DREG               => 1,
        INMODEREG          => 0,
        MREG               => 0,
        OPMODEREG          => 0,
        PREG               => 0
    )   
    port map(
        ACOUT             => open,
        BCOUT             => open,
        CARRYCASCOUT      => open,
        MULTSIGNOUT       => open,
        PCOUT             => open,
        OVERFLOW          => open,
        PATTERNBDETECT    => open,
        PATTERNDETECT     => open,
        UNDERFLOW         => open,
        CARRYOUT          => open,
        P                 => out_1,
        ACIN              => b"000000000000000000000000000000",
        BCIN              => b"000000000000000000",
        CARRYCASCIN       => '0',
        MULTSIGNIN        => '0',
        PCIN              => X"000000000000",
        ALUMODE           => X"0",
        CARRYINSEL        => b"000",
        CLK               => clock,
        INMODE            => b"00000",
        OPMODE            => b"0000101",
        A                 => out_0_resized,
        B                 => std_logic_vector(den),
        C                 => X"ffffffffffff",
        CARRYIN           => '0',
        D                 => b"1111111111111111111111111",
        CEA1              => '0',
        CEA2              => '0',
        CEAD              => '0',
        CEALUMODE         => '0',
        CEB1              => '0',
        CEB2              => '0',
        CEC               => '0',
        CECARRYIN         => '0',
        CECTRL            => '0',
        CED               => '0',
        CEINMODE          => '0',
        CEM               => '0',
        CEP               => '0',
        RSTA              => '0',
        RSTALLCARRYIN     => '0',
        RSTALUMODE        => '0',
        RSTB              => '0',
        RSTC              => '0',
        RSTCTRL           => '0',
        RSTD              => '0',
        RSTINMODE         => '0',
        RSTM              => '0',
        RSTP              => '0' 
    );

    -- out_1 has a 48 bit representation but the real representation is 11 bits shifted to the left, bring it back
    out_1_shift <= std_logic_vector(shift_right(signed(out_1),11));

    -- assign the filter's output (ince it should be an integer, it must be properly rounded, up or down if needed)
    -- NOTE that if the fractional part is greater or equal to 0.5 and the value is positive we should round up, else round down
    -- another condition must be given for the rounding when the number is negative, whih is the opposite case.
    -- a simple right shift of the result only rounds down the value, so this filter may always bring a negative average, not that close to 0 as intended
    round_proc: process(out_0, out_0_less_1, out_0_inv)
    begin
        if (out_0(out_0'HIGH)='1') then
            -- the output of the filter is negative
            -- transform the twos complement representation and find the original number
            out_0_less_1 <= std_logic_vector(signed(out_0)-1);
            out_0_inv <= NOT(out_0_less_1);

            -- find if the fractional part is equal or greater than 0.5
            if (out_0_inv>=X"10000") then
                -- fractional part of negative number is 0.5 or higher, we must round down
                -- this negative number only needs to be right shifted
                dout <= std_logic_vector(resize(shift_right(signed(out_0),17),14));
            else
                -- round up the signal by right shifting and adding one
                dout <= std_logic_vector(resize(shift_right(signed(out_0),17),14)+1);
            end if;
        else
            -- no need to find a two's complement
            out_0_less_1 <= (others => '0');
            out_0_inv <= (others => '0');

            if (out_0>=X"10000") then
                -- fractional part is equal or greater than 0.5 so round up
                dout <= std_logic_vector(resize(shift_right(signed(out_0),17),14)+1);
            else
                -- round down, by only right shifting the signal
                dout <= std_logic_vector(resize(shift_right(signed(out_0),17),14));
            end if;
        end if;
    end process round_proc;

end st_xc_filt_arch;
