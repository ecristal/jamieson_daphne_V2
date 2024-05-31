-- st_xc.vhd
-- self trigger using matching filter for single-double-triple PE detection
--
-- This module implements a cross correlation matching filter that uses the 
-- data coming from one channel in order to generate a self trigger signal output
-- whenever simple events occur. This matching filter is capable of detecting
-- Single PhotonElectrons, Double PhotonElectrons, Triple PhotonElectrons 
--
-- Daniel Avila Gomez <daniel.avila.gomez@cern.ch> & Edgar Rincon Gil <edgar.rincon.g@gmail.com>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_signed.all;

library unisim;
use unisim.vcomponents.all;

entity st_xc is
port(
    reset: in std_logic;
    clock: in std_logic; -- AFE clock 62.500 MHz
    din: in std_logic_vector(13 downto 0); -- filtered AFE data (no baseline)
    threshold: in std_logic_vector(41 downto 0); -- matching filter trigger threshold values
    triggered: out std_logic
);
end st_xc;

architecture st_xc_arch of st_xc is

    type type_r_st_xc_dat is array (0 to 15) of std_logic_vector(13 downto 0);
    type type_s_r_st_xc_dat is array (0 to 15) of signed(13 downto 0);
    type type_r_st_xc_mult is array (0 to 15) of signed(27 downto 0);
    type type_r_st_xc_add is array (0 to 2) of signed(27 downto 0);

    signal r_st_xc_dat: type_r_st_xc_dat := (others => (others => '0'));
    signal s_r_st_xc_dat: type_s_r_st_xc_dat := (others => (others => '0'));
    signal r_st_xc_mult: type_r_st_xc_mult := (others => (others => '0'));
    signal r_st_xc_add: type_r_st_xc_add := (others => (others => '0'));

    -- signals to enable the trigger
    signal trig_en: std_logic := '1'; 
    signal din_reg0, din_reg1, din_reg2: std_logic_vector(13 downto 0) := (others => '0');
    signal s_din, s_din_reg0, s_din_reg1, s_din_reg2: signed(13 downto 0) := (others => '0');

    -- threshold signals (threshold window)
    signal s_threshold: signed(27 downto 0);
    signal en_threshold: signed(13 downto 0);
    signal trig_ignore_count: std_logic_vector(7 downto 0) := (others => '0');

    -- matching filter template
    type template is array (0 to 15) of signed(13 downto 0);
    constant sig_templ: template := (
        to_signed(integer(1),14),
        to_signed(integer(0),14),
        to_signed(integer(0),14),
        to_signed(integer(-1),14),
        to_signed(integer(-1),14),
        to_signed(integer(-2),14),
        to_signed(integer(-3),14),
        to_signed(integer(-4),14),
        to_signed(integer(-5),14),
        to_signed(integer(-6),14),
        to_signed(integer(-7),14),
        to_signed(integer(-7),14),
        to_signed(integer(-6),14),
        to_signed(integer(-4),14),
        to_signed(integer(-2),14),
        to_signed(integer(0),14)
    );

begin

    -- trigger threshold to ignore larger events
    en_threshold <= signed(threshold(41 downto 28));

    -- trigger modification to compare the cross correlation output
    s_threshold <= signed(threshold(27 downto 0));

    -- generate some delays to see how the signal is behaving 
    din_reg_proc: process(clock, reset, s_din_reg0, s_din_reg1)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                din_reg0 <= (others => '0');
                din_reg1 <= (others => '0');
                din_reg2 <= (others => '0');
            else
                din_reg0 <= din;
                din_reg1 <= din_reg0;
                din_reg2 <= din_reg1;
            end if;
        end if;
    end process din_reg_proc;

    -- find the signed value of the registers
    s_din      <= signed(din);
    s_din_reg0 <= signed(din_reg0);
    s_din_reg1 <= signed(din_reg1);
    s_din_reg2 <= signed(din_reg2);

    -- compare the registers with the enabling threshold
    -- if the signal is smaller than the threshold, it means there is a big event therefore the trigger should be disabled
    en_trig_proc: process(clock, reset, trig_en, trig_ignore_count, s_din_reg0, s_din_reg1, s_din_reg2, en_threshold)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                trig_en <= '1';
            else
                -- disable the trigger
                if ( trig_en='1' and ( s_din_reg2>en_threshold and ( s_din_reg1<en_threshold or s_din_reg1=en_threshold ) and s_din_reg0<en_threshold and s_din<en_threshold ) ) then
                    -- three ticks ago we were above the threshold, two ticks we were at the same level or passed below it
                    -- one tick ago we were below it and now we are also below it, we are going down
                    -- therefore we are experiencing a big event
                    trig_en <= '0';
                end if;

                -- re enable the trigger
                if ( trig_en='0' ) then
                    -- since the event is considered as a large event, disable the trigger for a considerable amount of
                    -- clock ticks, in this case, up to the double of the trigger window (1.024us ... 2.048us)
                    if (trig_ignore_count=X"80") then
                        -- re start the countdown and re enable the trigger
                        trig_ignore_count <= (others => '0');
                        trig_en <= '1';
                    else
                        -- keep counting and keep the trigger disabled
                        trig_ignore_count <= std_logic_vector(trig_ignore_count + 1);
                    end if;
                end if;
            end if;
        end if;
    end process en_trig_proc;

    -- use "for generates" in order to create a pipeline with a desired amount of registers
    -- fill all of the registers by using 4 clock ticks delays
    st_xc_buff_gen: for i in 0 to 15 generate
        undersampling_ticks_gen: for j in 13 downto 0 generate
            -- generate 4 ticks in between samples to generate a proper undersampling (4 clock ticks)

            -- first register, which is the original data from the AFEs
            gendelay_reg0: if (i=0) generate
                srl16e_inst_0 : srl16e
                    port map(
                        -- must set input a3a2a1a0 as "0011" so that it has 2 bits of depth (which means 4 clock ticks)
                        clk => clock,
                        ce => '1',
                        a0 => '1',
                        a1 => '1',
                        a2 => '0',
                        a3 => '0',  
                        d => din(j), -- input AFE data bit to the register
                        q => r_st_xc_dat(i)(j) -- delayed output data bit of the signal
                    );
            end generate gendelay_reg0;

            -- next registers, which are "cascaded"
            gendelay_regn: if (i>0) generate
                srl16e_inst_bit : srl16e
                    port map(
                        -- must set input a3a2a1a0 as "0011" so that it has 2 bits of depth (which means 4 clock ticks)
                        clk => clock,
                        ce => '1',
                        a0 => '1',
                        a1 => '1',
                        a2 => '0',
                        a3 => '0',  
                        d => r_st_xc_dat(i-1)(j), -- input data bit to the register
                        q => r_st_xc_dat(i)(j) -- delayed output data bit of the signal
                    );
            end generate gendelay_regn;
        end generate undersampling_ticks_gen;

        -- since the registers are std_logic_vector, we must turn them into signed signals
        s_r_st_xc_dat(i) <= signed(r_st_xc_dat(i));
    end generate st_xc_buff_gen;

    -- multiply the data registers with the template
    st_xc_mult_gen: for i in 0 to 15 generate
        -- consecutive multiplication
        st_xc_mult_proc: process(clock, reset, s_r_st_xc_dat)
        begin
            if rising_edge(clock) then
                if (reset='1') then
                    r_st_xc_mult(i) <= (others => '0');
                else
                    r_st_xc_mult(i) <= s_r_st_xc_dat(i)*sig_templ(i);
                end if;
            end if;
        end process st_xc_mult_proc;
    end generate st_xc_mult_gen;

    -- addition of the multiplications
    add_proc: process(clock, reset, r_st_xc_mult, r_st_xc_add)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                r_st_xc_add <= (others => (others => '0'));
            else
                -- first pipeline stage
                r_st_xc_add(0) <= r_st_xc_mult(0) + r_st_xc_mult(1) + r_st_xc_mult(2) + r_st_xc_mult(3) +
                                  r_st_xc_mult(4) + r_st_xc_mult(5) + r_st_xc_mult(6) + r_st_xc_mult(7);
                -- second pipeline stage
                r_st_xc_add(1) <= r_st_xc_mult(8) + r_st_xc_mult(9) + r_st_xc_mult(10) + r_st_xc_mult(11) +
                                  r_st_xc_mult(12) + r_st_xc_mult(13) + r_st_xc_mult(14) + r_st_xc_mult(15);

                -- final addition
                r_st_xc_add(2) <= r_st_xc_add(0) + r_st_xc_add(1);
            end if;
        end if;
    end process add_proc;

    -- condition to trigger
    trig_proc: process(clock, reset, r_st_xc_add, s_threshold)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                triggered <= '0';
            else
                if ( ( r_st_xc_add(r_st_xc_add'HIGH)>s_threshold ) and trig_en='1' ) then
                    -- trigger happens only when we calculate a value bigger than the xcorr threshold and the event fits in the detection window 
                    triggered <= '1';
                else
                    triggered <= '0';
                end if;
            end if;
        end if;
    end process trig_proc;

end st_xc_arch;
