-- st_xc.vhd
-- self trigger using matching filter for single-double-triple PE detection
--
-- This module implements a cross correlation matching filter that uses the 
-- data coming from one channel in order to generate a self trigger signal output
-- whenever simple events occur. This matching filter is capable of detecting
-- Single PhotonElectrons, Double PhotonElectrons, Triple PhotonElectrons 
-- The filtered "always-zero" data is data that has almost no overshoot nor undershoot
-- it is used to calculate local peaks inside the waveform. Changing the data causes another 
-- trigger when it should not since it's the same peak, therefore this value must be adjusted
-- in the trigger primitives calculation
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
    din_mm: in std_logic_vector(13 downto 0); -- filtered "always-zero" data
    threshold: in std_logic_vector(41 downto 0); -- matching filter trigger threshold values
    triggered: out std_logic;
    xcorr_calc: out std_logic_vector(27 downto 0)
);
end st_xc;

architecture st_xc_arch of st_xc is

    -- timer to enable the self trigger (stabilization time of the filter)
    signal filt_ready: std_logic := '0';
    signal filt_timer: integer := 6250;
    constant filt_timer_stable: integer := 6250;

    -- self trigger input data and finite state machine signals 
    signal din_xcorr: std_logic_vector(13 downto 0) := (others => '0');
    signal data_sel, rst_xcorr_regs: std_logic := '0';
    signal event_timer: integer := 894;
    constant event_timer_limit : integer := 894;
    
    -- finite state machine states
    type state_type is (reset_st, stand_by, self_triggered, peak_finder, peak_found, event_finished);
    signal current_state, next_state : state_type;
    
    -- cross correlator inner signals
    type type_r_st_xc_dat is array (0 to 30) of std_logic_vector(13 downto 0);
    type type_s_r_st_xc_dat is array (0 to 30) of signed(13 downto 0);
    type type_r_st_xc_mult is array (0 to 31) of signed(27 downto 0);
    type type_r_st_xc_add is array (0 to 4) of signed(27 downto 0);

    signal r_st_xc_dat: type_r_st_xc_dat := (others => (others => '0'));
    signal s_r_st_xc_dat: type_s_r_st_xc_dat := (others => (others => '0'));
    signal r_st_xc_mult: type_r_st_xc_mult := (others => (others => '0'));
    signal r_st_xc_add: type_r_st_xc_add := (others => (others => '0'));

    -- signals to enable the trigger
    signal trig_en: std_logic := '1'; 
    signal din_reg0, din_reg1, din_reg2: std_logic_vector(13 downto 0) := (others => '0');
    signal s_din, s_din_reg0, s_din_reg1, s_din_reg2: signed(13 downto 0) := (others => '0');
    
    -- final calculation buffer delays
    signal xcorr_o_reg0, xcorr_o_reg1: signed(27 downto 0) := (others => '0');

    -- threshold signals (threshold window)
    signal s_threshold: signed(27 downto 0);
    signal en_threshold: signed(13 downto 0);
    signal trig_ignore_count: std_logic_vector(7 downto 0) := (others => '0');
    signal was_triggered: std_logic := '0';

    -- matching filter template
    type template is array (0 to 31) of signed(13 downto 0);
    constant sig_templ: template := (
        to_signed(integer(1),14),
        to_signed(integer(0),14),
        to_signed(integer(0),14),
        to_signed(integer(0),14),
        to_signed(integer(0),14),
        to_signed(integer(0),14),
        to_signed(integer(-1),14),
        to_signed(integer(-1),14),
        to_signed(integer(-1),14),
        to_signed(integer(-1),14),
        to_signed(integer(-1),14),
        to_signed(integer(-2),14),
        to_signed(integer(-2),14),
        to_signed(integer(-3),14),
        to_signed(integer(-4),14),
        to_signed(integer(-4),14),
        to_signed(integer(-5),14),
        to_signed(integer(-5),14),
        to_signed(integer(-6),14),
        to_signed(integer(-7),14),
        to_signed(integer(-6),14),
        to_signed(integer(-7),14),
        to_signed(integer(-7),14),
        to_signed(integer(-7),14),
        to_signed(integer(-7),14),
        to_signed(integer(-6),14),
        to_signed(integer(-5),14),
        to_signed(integer(-4),14),
        to_signed(integer(-3),14),
        to_signed(integer(-2),14),
        to_signed(integer(-1),14),
        to_signed(integer(0),14)
    );

begin

    -- define the configuration of the trigger
-------------------------------------------------------------------------------------------------------------------
    -- trigger threshold to ignore larger events
    en_threshold <= signed(threshold(41 downto 28));

    -- trigger modification to compare the cross correlation output
    s_threshold <= signed(threshold(27 downto 0));
    
    -- disable the trigger feature
-------------------------------------------------------------------------------------------------------------------
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
    
    -- input data mux selector 
-------------------------------------------------------------------------------------------------------------------
    -- NOTE: This mux is used to change the input data between normal data and "always-zero" data
    din_xcorr <= din_mm when (data_sel = '1') else din;
    
    -- use "for generates" in order to create a pipeline with a desired amount of registers
    -- fill all of the registers by using 4 clock ticks delays
    st_xc_buff_gen: for i in 0 to 30 generate
        undersampling_ticks_gen: for j in 13 downto 0 generate
            -- generate 4 ticks in between samples to generate a proper undersampling (4 clock ticks)

            -- first register, which is the original data from the AFEs
            gendelay_reg0: if (i=0) generate
                srl16e_inst_0 : srl16e
                    port map(
                        -- must set input a3a2a1a0 as "0001" so that it has 2 bits of depth (which means 4 clock ticks)
                        clk => clock,
                        ce => '1',
                        a0 => '1',
                        a1 => '0',
                        a2 => '0',
                        a3 => '0',  
                        d => din_xcorr(j), -- input AFE data bit to the register
                        q => r_st_xc_dat(i)(j) -- delayed output data bit of the signal
                    );
            end generate gendelay_reg0;

            -- next registers, which are "cascaded"
            gendelay_regn: if (i>0) generate
                srl16e_inst_bit : srl16e
                    port map(
                        -- must set input a3a2a1a0 as "0001" so that it has 2 bits of depth (which means 4 clock ticks)
                        clk => clock,
                        ce => '1',
                        a0 => '1',
                        a1 => '0',
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
    st_xc_mult_gen: for i in 0 to 31 generate        
        -- initial multiplication
        st_xc_mult_0: if (i=0) generate
            st_xc_mult_proc: process(clock, reset, din_xcorr)
            begin
                if rising_edge(clock) then
                    if (reset='1') then
                        r_st_xc_mult(i) <= (others => '0');
                    else
                        r_st_xc_mult(i) <= signed(din_xcorr)*sig_templ(i);
                    end if;
                end if;
            end process st_xc_mult_proc;
        end generate st_xc_mult_0;
        
        -- consecutive multiplication
        st_xc_mult_n: if (i>0) generate
            st_xc_mult_proc: process(clock, reset, s_r_st_xc_dat)
            begin
                if rising_edge(clock) then
                    if (reset='1') then
                        r_st_xc_mult(i) <= (others => '0');
                    else
                        r_st_xc_mult(i) <= s_r_st_xc_dat(i-1)*sig_templ(i);
                    end if;
                end if;
            end process st_xc_mult_proc;
        end generate st_xc_mult_n;
    end generate st_xc_mult_gen;

    -- addition of the multiplications
    add_proc: process(clock, reset, r_st_xc_mult, r_st_xc_add, xcorr_o_reg0)
    begin
        if rising_edge(clock) then
            if ( ( reset='1' ) or ( rst_xcorr_regs='1' ) ) then
                r_st_xc_add <= (others => (others => '0'));
                xcorr_o_reg0 <= (others => '0');
                xcorr_o_reg1 <= (others => '0');
            else
                -- first pipeline stage
                r_st_xc_add(0) <= r_st_xc_mult(0) + r_st_xc_mult(1) + r_st_xc_mult(2) + r_st_xc_mult(3) +
                                  r_st_xc_mult(4) + r_st_xc_mult(5) + r_st_xc_mult(6) + r_st_xc_mult(7);
                -- second pipeline stage
                r_st_xc_add(1) <= r_st_xc_mult(8) + r_st_xc_mult(9) + r_st_xc_mult(10) + r_st_xc_mult(11) +
                                  r_st_xc_mult(12) + r_st_xc_mult(13) + r_st_xc_mult(14) + r_st_xc_mult(15);
                -- third pipeline stage
                r_st_xc_add(2) <= r_st_xc_mult(16) + r_st_xc_mult(17) + r_st_xc_mult(18) + r_st_xc_mult(19) +
                                  r_st_xc_mult(20) + r_st_xc_mult(21) + r_st_xc_mult(22) + r_st_xc_mult(23);
                -- fourth pipeline stage
                r_st_xc_add(3) <= r_st_xc_mult(24) + r_st_xc_mult(25) + r_st_xc_mult(26) + r_st_xc_mult(27) +
                                  r_st_xc_mult(28) + r_st_xc_mult(29) + r_st_xc_mult(30) + r_st_xc_mult(31);

                -- final addition
                r_st_xc_add(4) <= r_st_xc_add(0) + r_st_xc_add(1) + r_st_xc_add(2) + r_st_xc_add(3);

                -- register the old values to keep track of how the calculation is behaving
                xcorr_o_reg0 <= r_st_xc_add(4);
                xcorr_o_reg1 <= xcorr_o_reg0;
            end if;
        end if;
    end process add_proc;
    
    -- trigger and peak detector Finite State Machine 
-------------------------------------------------------------------------------------------------------------------
    -- this Finite State Machine uses the cross correlation output to determine when a
    -- self trigger must be asserted. If this condition is met, it then changes the data input
    -- input and starts searching for local peaks. whenever the baseline is recovered, 
    -- it starts again to look for a trigger
    -- State 0: reset
    -- State 1: trigger finder (searchs for a main self trigger signal)
    -- State 1: self triggered (once inside spends 1 clk cycle and informs of the trigger)
    -- State 2: peak finder (after the main trigger was asserted, it starts to find for peaks)
    -- State 3: peak was found (spends 1 cycle here, then returns to scan for more peaks)
    -- after the baseline is fully regained, it comes back again to State 0
    
    -- process to sync change the states of the FSM
    reg_states: process(clock, reset, next_state)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                current_state <= reset_st;
            else
                current_state <= next_state;
            end if;
        end if;
    end process reg_states;
    
    -- process to define why the states change
    mod_states: process(current_state, r_st_xc_add, xcorr_o_reg0, xcorr_o_reg1)
    begin
        next_state <= current_state; -- Declare default state for current_state to avoid latches, default is to stay in current state
        case (current_state) is
            when reset_st =>
                next_state <= stand_by;
            when stand_by =>
                if ( ( r_st_xc_add(r_st_xc_add'HIGH)>s_threshold ) and ( xcorr_o_reg0>s_threshold ) 
                       and ( xcorr_o_reg1<s_threshold or xcorr_o_reg1=s_threshold ) and ( trig_en='1' )  and ( filt_ready='1' ) ) then
                    next_state <= self_triggered;
                end if;
            when self_triggered =>
                next_state <= peak_finder;
            when peak_finder =>
                if ( event_timer<=0 ) then
                    next_state <= event_finished;
                else
                    if ( ( r_st_xc_add(r_st_xc_add'HIGH)>s_threshold ) and ( xcorr_o_reg0>s_threshold ) 
                           and ( xcorr_o_reg1<s_threshold or xcorr_o_reg1=s_threshold ) ) then
                        next_state <= peak_found;
                    end if;
                end if;
            when peak_found =>
                next_state <= peak_finder;
            when event_finished =>
                -- spend one cycle here to restart cross correlation values
                next_state <= stand_by;
            when others =>
                -- do nothing
        end case;
    end process mod_states;
    
    -- finite state machine outputs (conditions to trigger and select the input data)
    do_states: process(current_state)
    begin
        case (current_state) is
            when self_triggered =>
                triggered <= '1';
                data_sel <= '0';
                rst_xcorr_regs <= '0'; 
            when peak_finder =>
                triggered <= '0';
                data_sel <= '1';
                rst_xcorr_regs <= '0';
            when peak_found =>
                triggered <= '1';
                data_sel <= '1';
                rst_xcorr_regs <= '0';
            when event_finished =>
                triggered <= '0';
                data_sel <= '0';
                -- cross correlation values must be reset since the input data will be different next cycle
                -- this happens too in self_triggered state, however, the change in the data shows that the
                -- cross correlation values are on the same region of above the threshold, therefore no need
                -- to reset and update its registers
                rst_xcorr_regs <= '1';
            when others =>
                -- includes reset_st and stand_by states
                triggered <= '0';
                data_sel <= '0';
                rst_xcorr_regs <= '0';
        end case;
    end process; 
    
    -- clocked process to count the length of the event
    event_timer_proc: process(clock, reset, current_state, event_timer)
    begin
        if rising_edge(clock) then
            if ( ( reset='1' ) or ( current_state=reset_st ) or ( current_state=stand_by ) 
                   or ( current_state=self_triggered ) or ( current_state=event_finished ) ) then
                event_timer <= event_timer_limit;
            else
                if ( ( current_state=peak_finder ) or ( current_state=peak_found ) ) then
                    event_timer <= event_timer - 1;
                end if;
            end if;
        end if;
    end process event_timer_proc;
    
    -- clocked process to disable the trigger while the filter stabilizes after a reset
    trig_disable_filt_proc: process(clock, reset, filt_timer)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                filt_timer <= filt_timer_stable;
                filt_ready <= '0';
            else
                if (filt_timer>0) then
                    filt_timer <= filt_timer - 1;
                    filt_ready <= '0';
                else
                    filt_timer <= filt_timer;
                    filt_ready <= '1';
                end if;
            end if;
        end if;
    end process trig_disable_filt_proc;
    
    xcorr_calc <= std_logic_vector(r_st_xc_add(4));

end st_xc_arch;