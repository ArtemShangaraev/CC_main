-------------------------------------------------------------------------------
-- Title      : System control
-- Project    : Column Controller CPV
-------------------------------------------------------------------------------
-- File       : sys_ctrl.vhd
-- Author     : Clive Seguna <clive.seguna@cern.ch>
-- Company    : University of Malta
-- Author     : Artem Shangaraev <artem.shangaraev@cern.ch>
-- Company    : NRC "Kurchatov institute" - IHEP
-- Created    : 2018-01-01
-- Last update: 2021-03-24
-- Platform   : Quartus Prime 18.1.0
-- Target     : Cyclone V GX
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: System control creates instructions for other fabric blocks
--              depending on decoded LVDS commands.
--              Provides control to fill internal RAM with thresholds.
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CERN
-------------------------------------------------------------------------------

Library IEEE;
Use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity sys_ctrl is
  port (
    ARST            : in  std_logic;
    
    -- LVDS clock domain
    CLK_FAST           : in  std_logic;
    lvds_cmd_i      : in  std_logic_vector(3 downto 0);
    realign_o       : out std_logic;
    sub_cmp_o       : out std_logic;
    ram_addr_o      : out std_logic_vector(8 downto 0);
    ram_data_o      : out std_logic_vector(8 downto 0);
    ram_wren_o      : out std_logic;
    ram_select_o    : out unsigned (1 downto 0);
    
    -- FEE clock domain
    CLK_SLOW           : in  std_logic;
    trigger_o       : out std_logic;
    stop_read_o     : out std_logic;
    accept_data_o   : out std_logic;
    reject_data_o   : out std_logic;
    read_conf_o     : out std_logic;
    load_conf_o     : out std_logic;
    check_status_o  : out std_logic
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
  signal s_accept_data    : std_logic := '0';
  signal s_reject_data    : std_logic := '0';
  signal s_conf_read      : std_logic := '0';
  signal s_conf_load      : std_logic := '0';
  signal s_check_status   : std_logic := '0';
  
  signal s_channel_cnt    : unsigned (8 downto 0) := (others => '0');
  
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
      ARST            => ARST,
      CLK             => CLK_FAST,
      lvds_cmd_i      => lvds_cmd_i,
      conf_read_o     => s_conf_read,
      conf_load_o     => s_conf_load,
      zs_off_o        => s_zs_off,
      zs_on_o         => s_zs_on,
      event_start_o   => s_event_start,
      event_stop_o    => s_event_stop,
      accept_data_o   => s_accept_data,
      reject_data_o   => s_reject_data,
      realign_o       => realign_o,
      check_status_o  => s_check_status,
      word_num_o      => s_word_num,
      data_o          => s_data
    );
  
-------------------------------------------------------------------------------
------ Zero suppression -------------------------------------------------------

  s_zs_state_reg  <= s_zs_state when rising_edge(CLK_FAST);
  s_zs_state      <= '1' when s_zs_on  = '1' else
                     '0' when s_zs_off = '1' else
                     s_zs_state_reg;
  sub_cmp_o       <= s_zs_state;
  
  INST_commands_cdc: entity work.sys_ctrl_cdc
    port map (
      ARST            => ARST,
      CLK_FAST        => CLK_FAST,
      trigger_i       => s_event_start,
      stop_read_i     => s_event_stop,
      accept_data_i   => s_accept_data,
      reject_data_i   => s_reject_data,
      read_conf_i     => s_conf_read,
      load_conf_i     => s_conf_load,
      check_status_i  => s_check_status,
      CLK_SLOW        => CLK_SLOW,
      trigger_o       => trigger_o,
      stop_read_o     => stop_read_o,
      accept_data_o   => accept_data_o,
      reject_data_o   => reject_data_o,
      read_conf_o     => read_conf_o,
      load_conf_o     => load_conf_o,
      check_status_o  => check_status_o
    );
  
-------------------------------------------------------------------------------
------ Write thresholds to RAM ------------------------------------------------

  ram_addr_o    <= s_ram_addr;
  ram_data_o    <= s_ram_data;
  ram_wren_o    <= s_ram_wren;
  ram_select_o  <= s_ram_select;

  DATA_TO_RAM: process(CLK_FAST, ARST)
  begin
    if ARST = '1' then
      s_ram_data    <= (others => '0');
    elsif rising_edge(CLK_FAST) then
      case s_word_num is
        when "11" =>
          s_ram_data(8) <= s_data(0);
        when "10" =>
          s_ram_data(7 downto 4) <= s_data;
        when "01" =>
          s_ram_data(3 downto 0) <= s_data;
        when others =>
          s_ram_data    <= (others => '0');
      end case;
    end if;
  end process;
  
  RAM_WRITE_CTRL: process(CLK_FAST, ARST)
  begin
    if ARST = '1' then
      s_ram_addr    <= (others => '0');
      s_ram_select  <= "00";
      s_ram_wren    <= '0';
      s_channel_cnt <= (others => '0');
    elsif rising_edge(CLK_FAST) then
      if s_word_num = "01" then
        s_ram_wren      <= '1';
        if s_channel_cnt < 64*5-1 then
          s_channel_cnt <= s_channel_cnt + 1;
          s_ram_addr    <= std_logic_vector(s_channel_cnt);
        else
          s_channel_cnt <= (others => '0');
          if s_ram_select < 3 then
            s_ram_select  <= s_ram_select + 1;
          else
            s_ram_select <= "00";
          end if;
        end if;
      else
        s_ram_wren      <= '0';
      end if;
    end if;
  end process;

end architecture;
