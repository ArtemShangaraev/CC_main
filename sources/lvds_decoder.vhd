-------------------------------------------------------------------------------
-- Title      : LVDS decoder
-- Project    : Column Controller CPV
-------------------------------------------------------------------------------
-- File       : lvds_decoder.vhd
-- Author     : Artem Shangaraev <artem.shangaraev@cern.ch>
-- Company    : NRC "Kurchatov institute" - IHEP
-- Created    : 2018-01-01
-- Last update: 2021-03-24
-- Platform   : Quartus Prime 18.1.0
-- Target     : Cyclone V GX
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Decodes incoming LVDS commands and creates pulses for 
--              system control module.
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CERN
-------------------------------------------------------------------------------

Library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity lvds_decoder is
  port (
    ARST            : in  std_logic;        -- async reset (active high)
    CLK             : in  std_logic;
    
    lvds_cmd_i      : in  std_logic_vector(3 downto 0);
    conf_load_o     : out std_logic;
    conf_read_o     : out std_logic;
    zs_off_o        : out std_logic;
    zs_on_o         : out std_logic;
    event_start_o   : out std_logic;
    event_stop_o    : out std_logic;
    accept_data_o   : out std_logic;
    reject_data_o   : out std_logic;
    realign_o       : out std_logic;
    check_status_o  : out std_logic;
    word_num_o      : out std_logic_vector(1 downto 0);
    data_o          : out std_logic_vector(3 downto 0)
  );
end entity;

architecture beh of lvds_decoder is

-------------------------------------------------------------------------------
------ Component declaration --------------------------------------------------

-------------------------------------------------------------------------------
------ Function declaration ---------------------------------------------------

  type t_cmd_word is (
    CMD_IDLE,
    CMD_START_OF_FRAME,
    CMD_END_OF_FRAME,
    CMD_CONF_READ,
    CMD_CONF_LOAD,
    CMD_ZS_OFF,
    CMD_ZS_ON,
    CMD_TRIGGER,
    CMD_ACCEPT,
    CMD_REJECT,
    CMD_CHECK_STATUS,
    CMD_BREAK,
    CMD_REALIGN,
    CMD_UNKNOWN
  );
  function to_cmd_word (
    constant lvds_cmd : std_logic_vector(3 downto 0)
  )
  return t_cmd_word is
  begin
    if    lvds_cmd = x"2" then
      return CMD_IDLE;
    elsif lvds_cmd = x"1" then
      return CMD_START_OF_FRAME;
    elsif lvds_cmd = x"3" then
      return CMD_END_OF_FRAME;
    elsif lvds_cmd = x"4" then
      return CMD_CONF_LOAD;
    elsif lvds_cmd = x"5" then
      return CMD_ZS_OFF;
    elsif lvds_cmd = x"6" then
      return CMD_ZS_ON;
    elsif lvds_cmd = x"7" then
      return CMD_TRIGGER;
    elsif lvds_cmd = x"8" then
      return CMD_ACCEPT;
    elsif lvds_cmd = x"9" then
      return CMD_REJECT;
    elsif lvds_cmd = x"A" then
      return CMD_CHECK_STATUS;
    elsif lvds_cmd = x"D" then
      return CMD_CONF_READ;
    elsif lvds_cmd = x"E" then
      return CMD_BREAK;
    elsif lvds_cmd = x"F" then
      return CMD_REALIGN;
    else
      return CMD_UNKNOWN;
    end if;
  end function to_cmd_word;
  
-------------------------------------------------------------------------------
------ Signal declaration -----------------------------------------------------

  signal s_conf_load    : std_logic := '0';
  signal s_conf_read    : std_logic := '0';
  signal s_zs_off       : std_logic := '0';
  signal s_zs_on        : std_logic := '0';
  signal s_start        : std_logic := '0';
  signal s_stop         : std_logic := '0';
  signal s_reject_data  : std_logic := '0';
  signal s_accept_data  : std_logic := '0';
  signal s_realign      : std_logic := '0';
  signal s_check_status : std_logic := '0';
  
  signal s_is_data      : std_logic := '0';
  signal s_data         : std_logic_vector (3 downto 0) := x"0";
  
  signal s_word_cnt     : natural range 0 to 3 := 0;
  signal s_new_word_cnt : natural range 0 to 3 := 0;

-------------------------------------------------------------------------------
------ Architecture begin -----------------------------------------------------
begin

  conf_load_o     <= s_conf_load    when s_is_data = '0' else '0';
  conf_read_o     <= s_conf_read    when s_is_data = '0' else '0';
  zs_off_o        <= s_zs_off       when s_is_data = '0' else '0';
  zs_on_o         <= s_zs_on        when s_is_data = '0' else '0';
  event_start_o   <= s_start        when s_is_data = '0' else '0';
  event_stop_o    <= s_stop         when s_is_data = '0' else '0';
  accept_data_o   <= s_accept_data  when s_is_data = '0' else '0';
  reject_data_o   <= s_reject_data  when s_is_data = '0' else '0';
  realign_o       <= s_realign      when s_is_data = '0' else '0';
  check_status_o  <= s_check_status when s_is_data = '0' else '0';
  
  word_num_o    <= std_logic_vector(to_unsigned(s_word_cnt, 2));
  data_o        <= s_data;

  state_update : process (CLK, ARST) is
  begin
    if ARST = '1' then
      s_word_cnt <= 0;
    elsif rising_edge(CLK) then
      s_word_cnt <= s_new_word_cnt;
    end if;
  end process state_update;

-------------------------------------------------------------------------------
------ Next state FSM ---------------------------------------------------------

  next_state : process (lvds_cmd_i, s_word_cnt) is
    variable v_word_cnt : natural range 0 to 3 := 0;
    variable v_cmd_word : t_cmd_word;
  begin
    v_word_cnt      := s_word_cnt;
    v_cmd_word      := to_cmd_word(lvds_cmd_i);
    
    s_conf_load     <= '0';
    s_conf_read     <= '0';
    s_zs_off        <= '0';
    s_zs_on         <= '0';
    s_start         <= '0';
    s_stop          <= '0';
    s_accept_data   <= '0';
    s_reject_data   <= '0';
    s_realign       <= '0';
    s_check_status  <= '0';
    
    s_is_data       <= '0';
    s_data          <= x"0";

    if s_word_cnt > 0 then                -- send data
      s_is_data   <= '1';
      s_data      <= lvds_cmd_i;
      v_word_cnt  := s_word_cnt - 1;
    else                                  -- parse input word
      case v_cmd_word is
        when CMD_IDLE =>
          null;
        when CMD_START_OF_FRAME =>
          v_word_cnt      := 3;
        when CMD_END_OF_FRAME =>
          s_is_data       <= '1';
        when CMD_CONF_READ =>
          s_conf_read     <= '1';
        when CMD_CONF_LOAD =>
          s_conf_load     <= '1';
        when CMD_ZS_OFF =>
          s_zs_off        <= '1';
        when CMD_ZS_ON =>
          s_zs_on         <= '1';
        when CMD_TRIGGER =>
          s_start         <= '1';
        when CMD_ACCEPT =>
          s_accept_data   <= '1';
        when CMD_REJECT =>
          s_reject_data   <= '1';
        when CMD_BREAK =>
          s_stop          <= '1';
        when CMD_REALIGN =>
          s_realign       <= '1';
        when CMD_CHECK_STATUS =>
          s_check_status  <= '1';
        when CMD_UNKNOWN => 
          null;
      end case;
    end if;

    s_new_word_cnt <= v_word_cnt;
    
  end process next_state;
  
end architecture;
