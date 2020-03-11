-------------------------------------------------------------------------------
-- Title      : System control
-- Project    : Column Controller CPV
-------------------------------------------------------------------------------
-- File       : sys_ctrl.vhd
-- Author     : Clive Seguna <clive.seguna@cern.ch>
-- Company    : University of Malta
-- Created    : 2018-01-01
-- Last update: 2020-03-04
-- Platform   : Quartus Prime 18.1.0
-- Target     : Cyclone V GX
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: System control creates instructions for other fabric blocks
--              depending on decoded LVDS commands.
--              Converts signals from 50 MHz to 10 MHz clock domain.
--              Provides control to fill internal RAM with thresholds.
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CERN
-------------------------------------------------------------------------------
--  Revisions  :
--  Date          Version   Author    Description
--  2019-01-01    1.0       cseguna   Created
--  2020-02-05    1.1       ashangar  LVDS decoder added
--  2020-02-27    1.2       ashangar  RAM control added
--                                    LVDS commands replaced by simple pulses.
-------------------------------------------------------------------------------

Library IEEE;
Use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity sys_ctrl is
  port (
    ARST          : in  std_logic;
    
    -- 50M LVDS clock domain
    CLK50         : in  std_logic;
    lvds_cmd_i    : in  std_logic_vector(3 downto 0);
    realign_o     : out std_logic;
    sub_cmp_o     : out std_logic;
    ram_addr_o    : out std_logic_vector(8 downto 0);
    ram_data_o    : out std_logic_vector(8 downto 0);
    ram_wren_o    : out std_logic;
    ram_select_o  : out unsigned (1 downto 0);
    
    -- 10M Dilogic and Gassiplex clock domain
    CLK10         : in  std_logic;
    trigger_o     : out std_logic;
    stop_read_o   : out std_logic;
    read_conf_o   : out std_logic;
    write_conf_o  : out std_logic
  );
end entity;


architecture beh of sys_ctrl is

-------------------------------------------------------------------------------
---- Component declaration ----------------------------------------------------

-------------------------------------------------------------------------------
------ Signal declaration -----------------------------------------------------
  
  signal s_lvds_cmd       : std_logic_vector(3 downto 0) := x"0";
  
  signal s_zs_state       : std_logic := '0';
  signal s_zs_state_reg   : std_logic := '0';
  signal s_zs_off         : std_logic := '0';
  signal s_zs_on          : std_logic := '0';
  
  signal s_event_start    : std_logic := '0';
  signal s_event_stop     : std_logic := '0';
  signal s_conf_read      : std_logic := '0';
  signal s_slow_start     : std_logic := '0';
  signal s_slow_stop      : std_logic := '0';
  signal s_slow_conf_read : std_logic := '0';
  signal s_conf_write     : std_logic := '0';
  signal s_trigger_reg    : std_logic := '0';
  signal s_stop_reg       : std_logic := '0';
  signal s_read_conf_reg  : std_logic := '0';
  signal s_write_conf_reg : std_logic := '0';
  signal s_channel_cnt    : unsigned (8 downto 0) := (others => '0');
  
  signal s_is_data        : std_logic := '0';
  signal s_word_num       : std_logic_vector(1 downto 0) := "00";
  signal s_data           : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ram_data       : std_logic_vector(8 downto 0) := (others => '0');
  signal s_ram_addr       : std_logic_vector(8 downto 0) := (others => '0');
  signal s_ram_wren       : std_logic := '0';
  signal s_ram_select     : unsigned (1 downto 0) := "00";

-------------------------------------------------------------------------------
------ Architecture begin -----------------------------------------------------
begin

  INST_lvds_decoder: entity work.lvds_decoder
    port map (
      ARST          => ARST,
      CLK           => CLK50,
      lvds_cmd_i    => lvds_cmd_i,
      conf_read_o   => s_conf_read,
      zs_off_o      => s_zs_off,
      zs_on_o       => s_zs_on,
      event_start_o => s_event_start,
      event_stop_o  => s_event_stop,
      realign_o     => realign_o,
      is_data_o     => s_is_data,
      word_num_o    => s_word_num,
      data_o        => s_data
    );
  
-------------------------------------------------------------------------------
------ Zero suppression -------------------------------------------------------

  s_zs_state_reg <= s_zs_state when rising_edge(CLK50);
  s_zs_state <= '1' when s_zs_on  = '1' else
                '0' when s_zs_off = '1' else
                s_zs_state_reg;
  sub_cmp_o <= s_zs_state;

-------------------------------------------------------------------------------
------ Create 100 ns START pulse ----------------------------------------------

  START_HOLD: process(CLK50, ARST)
    variable v_start_cnt : natural range 0 to 7 := 0;
  begin
    if ARST = '1' then
      s_slow_start    <= '0';
      v_start_cnt     := 0;
    elsif rising_edge(CLK50) then
      if s_event_start = '1' then 
        v_start_cnt   := 5;
      end if;
      if v_start_cnt > 0 then
        v_start_cnt   := v_start_cnt - 1;
        s_slow_start  <= '1';
      else
        s_slow_start  <= '0';
      end if;
    end if;
  end process START_HOLD;
  
-------------------------------------------------------------------------------
------ Create 100 ns STOP pulse -----------------------------------------------

  STOP_HOLD: process(CLK50, ARST)
    variable v_stop_cnt : natural range 0 to 7 := 0;
  begin
    if ARST = '1' then
      s_slow_stop   <= '0';
      v_stop_cnt    := 0;
    elsif rising_edge(CLK50) then
      if s_event_stop = '1' then 
        v_stop_cnt  := 5;
      end if;
      if v_stop_cnt > 0 then
        v_stop_cnt  := v_stop_cnt - 1;
        s_slow_stop <= '1';
      else
        s_slow_stop <= '0';
      end if;
    end if;
  end process STOP_HOLD;
  
-------------------------------------------------------------------------------
------ Create 100 ns CONF_READ pulse ------------------------------------------

  CONF_READ_HOLD: process(CLK50, ARST)
    variable v_conf_read_cnt : natural range 0 to 7 := 0;
  begin
    if ARST = '1' then
      s_slow_conf_read  <= '0';
      v_conf_read_cnt   := 0;
    elsif rising_edge(CLK50) then
      if s_conf_read = '1' then 
        v_conf_read_cnt := 5;
      end if;
      if v_conf_read_cnt > 0 then
        v_conf_read_cnt := v_conf_read_cnt - 1;
        s_slow_conf_read <= '1';
      else
        s_slow_conf_read <= '0';
      end if;
    end if;
  end process CONF_READ_HOLD;
  
-------------------------------------------------------------------------------
------ Clock domain crossing 50M -> 10M ---------------------------------------

  CDC_TRG: process(CLK10, ARST)
  begin
    if ARST = '1' then
      s_trigger_reg     <= '0';
      s_stop_reg        <= '0';
      s_read_conf_reg   <= '0';
      s_write_conf_reg  <= '0';
    elsif rising_edge(CLK10) then
      s_trigger_reg     <= s_slow_start;
      s_stop_reg        <= s_slow_stop;
      s_read_conf_reg   <= s_slow_conf_read;
      s_write_conf_reg  <= s_conf_write;
    end if;
  end process CDC_TRG;
  
  trigger_o     <= s_trigger_reg;
  stop_read_o   <= s_stop_reg;
  read_conf_o   <= s_read_conf_reg;
  write_conf_o  <= s_write_conf_reg;
  
-------------------------------------------------------------------------------
------ Write thresholds to RAM ------------------------------------------------

  s_conf_write  <= '1' when s_ram_select = "11" 
                        and s_channel_cnt = 64*5 - 1
                       else '0';

  ram_addr_o    <= s_ram_addr;
  ram_data_o    <= s_ram_data;
  ram_wren_o    <= s_ram_wren;
  ram_select_o  <= s_ram_select;
                       
  WREN_CTRL: process(CLK50, ARST)
  begin
    if ARST = '1' then
      s_ram_wren  <='0';
    elsif falling_edge(CLK50) then
      s_ram_wren  <= s_is_data;
    end if;
  end process;
  
  DATA_TO_RAM: process(CLK50, ARST)
  begin
    if ARST = '1' then
      s_ram_data    <= (others => '0');
    elsif rising_edge(CLK50) then
      case s_word_num is
        when "11" =>
          s_ram_data(8) <= s_data(0);
        when "10" =>
          s_ram_data(7 downto 4) <= s_data;
        when "01" =>
          s_ram_data(3 downto 0) <= s_data;
        when others =>
          null;
      end case;
    end if;
  end process;
  
  RAM_WRITE_CTRL: process(CLK50, ARST)
  begin
    if ARST = '1' then
      s_ram_addr    <= (others => '0');
      s_ram_select  <= "00";
      s_channel_cnt <= (others => '0');
    elsif rising_edge(CLK50) then
      if s_is_data = '1' then
        if s_channel_cnt < 64*5 - 1 then
          s_channel_cnt <= s_channel_cnt + 1;
          s_ram_addr    <= std_logic_vector(s_channel_cnt);
        else
          s_channel_cnt <= (others => '0');
          s_ram_select  <= s_ram_select + 1;
        end if;
      end if;
    end if;
  end process;

end architecture;
