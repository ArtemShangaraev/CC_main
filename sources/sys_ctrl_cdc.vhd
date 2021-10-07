-------------------------------------------------------------------------------
-- Title      : System control CDC
-- Project    : Column Controller CPV
-------------------------------------------------------------------------------
-- File       : sys_ctrl_cdc.vhd
-- Author     : Artem Shangaraev <artem.shangaraev@cern.ch>
-- Company    : NRC "Kurchatov institute" - IHEP
-- Created    : 2021-04-08
-- Last update: 2021-04-08
-- Platform   : Quartus Prime 18.1.0
-- Target     : Cyclone V GX
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Converts signals from 40 MHz (LVDS parallel)
--              to 8 MHz clock domain (Dilogic and Gassiplex).
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CERN
-------------------------------------------------------------------------------

Library IEEE;
Use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity sys_ctrl_cdc is
  port (
    ARST            : in  std_logic;
    
    -- LVDS clock domain
    CLK_FAST        : in  std_logic;
    trigger_i       : in  std_logic;
    stop_read_i     : in  std_logic;
    accept_data_i   : in  std_logic;
    reject_data_i   : in  std_logic;
    read_conf_i     : in  std_logic;
    load_conf_i     : in  std_logic;
    check_status_i  : in  std_logic;
    
    -- FEE clock domain
    CLK_SLOW        : in  std_logic;
    trigger_o       : out std_logic;
    stop_read_o     : out std_logic;
    accept_data_o   : out std_logic;
    reject_data_o   : out std_logic;
    read_conf_o     : out std_logic;
    load_conf_o     : out std_logic;
    check_status_o  : out std_logic
  );
end entity;


architecture structural of sys_ctrl_cdc is

-------------------------------------------------------------------------------
---- Component declaration ----------------------------------------------------

-------------------------------------------------------------------------------
------ Signal declaration -----------------------------------------------------

  -- Extended 40M signals, 5 tacts
  signal s_slow_start         : std_logic := '0';
  signal s_slow_stop          : std_logic := '0';
  signal s_slow_accept_data   : std_logic := '0';
  signal s_slow_reject_data   : std_logic := '0';
  signal s_slow_conf_read     : std_logic := '0';
  signal s_slow_conf_load     : std_logic := '0';
  signal s_slow_check_status  : std_logic := '0';
  
  -- 8M clock domain
  signal s_trigger_reg      : std_logic := '0';
  signal s_stop_reg         : std_logic := '0';
  signal s_accept_data_reg  : std_logic := '0';
  signal s_reject_data_reg  : std_logic := '0';
  signal s_read_conf_reg    : std_logic := '0';
  signal s_load_conf_reg    : std_logic := '0';
  signal s_check_status_reg : std_logic := '0';
  
-------------------------------------------------------------------------------
------ Architecture begin -----------------------------------------------------
begin

-------------------------------------------------------------------------------
------ Create long START pulse ------------------------------------------------

  START_HOLD: process(CLK_FAST, ARST)
    variable v_start_cnt : natural range 0 to 7 := 0;
  begin
    if ARST = '1' then
      s_slow_start    <= '0';
      v_start_cnt     := 0;
    elsif rising_edge(CLK_FAST) then
      if trigger_i = '1' then 
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
------ Create long STOP pulse -------------------------------------------------

  STOP_HOLD: process(CLK_FAST, ARST)
    variable v_stop_cnt : natural range 0 to 7 := 0;
  begin
    if ARST = '1' then
      s_slow_stop   <= '0';
      v_stop_cnt    := 0;
    elsif rising_edge(CLK_FAST) then
      if stop_read_i = '1' then 
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
------ Create long ACCEPT_DATA pulse ------------------------------------------

  ACCEPT_HOLD: process(CLK_FAST, ARST)
    variable v_accept_cnt : natural range 0 to 7 := 0;
  begin
    if ARST = '1' then
      s_slow_accept_data   <= '0';
      v_accept_cnt    := 0;
    elsif rising_edge(CLK_FAST) then
      if accept_data_i = '1' then 
        v_accept_cnt  := 5;
      end if;
      if v_accept_cnt > 0 then
        v_accept_cnt  := v_accept_cnt - 1;
        s_slow_accept_data <= '1';
      else
        s_slow_accept_data <= '0';
      end if;
    end if;
  end process ACCEPT_HOLD;
  
-------------------------------------------------------------------------------
------ Create long REJECT_DATA pulse ------------------------------------------

  REJECT_HOLD: process(CLK_FAST, ARST)
    variable v_reject_cnt : natural range 0 to 7 := 0;
  begin
    if ARST = '1' then
      s_slow_reject_data   <= '0';
      v_reject_cnt    := 0;
    elsif rising_edge(CLK_FAST) then
      if reject_data_i = '1' then 
        v_reject_cnt  := 5;
      end if;
      if v_reject_cnt > 0 then
        v_reject_cnt  := v_reject_cnt - 1;
        s_slow_reject_data <= '1';
      else
        s_slow_reject_data <= '0';
      end if;
    end if;
  end process REJECT_HOLD;
  
-------------------------------------------------------------------------------
------ Create long CONF_READ pulse --------------------------------------------

  CONF_READ_HOLD: process(CLK_FAST, ARST)
    variable v_conf_read_cnt : natural range 0 to 7 := 0;
  begin
    if ARST = '1' then
      s_slow_conf_read  <= '0';
      v_conf_read_cnt   := 0;
    elsif rising_edge(CLK_FAST) then
      if read_conf_i = '1' then 
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
------ Create long CONF_LOAD pulse --------------------------------------------

  CONF_LOAD_HOLD: process(CLK_FAST, ARST)
    variable v_conf_load_cnt : natural range 0 to 7 := 0;
  begin
    if ARST = '1' then
      s_slow_conf_load  <= '0';
      v_conf_load_cnt   := 0;
    elsif rising_edge(CLK_FAST) then
      if load_conf_i = '1' then 
        v_conf_load_cnt := 5;
      end if;
      if v_conf_load_cnt > 0 then
        v_conf_load_cnt := v_conf_load_cnt - 1;
        s_slow_conf_load <= '1';
      else
        s_slow_conf_load <= '0';
      end if;
    end if;
  end process CONF_LOAD_HOLD;
  
-------------------------------------------------------------------------------
------ Create long CHECK_STATUS pulse -----------------------------------------

  CHECK_STATUS_HOLD: process(CLK_FAST, ARST)
    variable v_check_status_cnt : natural range 0 to 7 := 0;
  begin
    if ARST = '1' then
      s_slow_check_status  <= '0';
      v_check_status_cnt   := 0;
    elsif rising_edge(CLK_FAST) then
      if check_status_i = '1' then 
        v_check_status_cnt := 5;
      end if;
      if v_check_status_cnt > 0 then
        v_check_status_cnt := v_check_status_cnt - 1;
        s_slow_check_status <= '1';
      else
        s_slow_check_status <= '0';
      end if;
    end if;
  end process CHECK_STATUS_HOLD;
  
-------------------------------------------------------------------------------
------ Clock domain crossing FAST to SLOW -------------------------------------

  CDC_TRG: process(CLK_SLOW, ARST)
  begin
    if ARST = '1' then
      s_trigger_reg       <= '0';
      s_stop_reg          <= '0';
      s_accept_data_reg   <= '0';
      s_reject_data_reg   <= '0';
      s_read_conf_reg     <= '0';
      s_load_conf_reg     <= '0';
      s_check_status_reg  <= '0';
    elsif rising_edge(CLK_SLOW) then
      s_trigger_reg       <= s_slow_start;
      s_stop_reg          <= s_slow_stop;
      s_accept_data_reg   <= s_slow_accept_data;
      s_reject_data_reg   <= s_slow_reject_data;
      s_read_conf_reg     <= s_slow_conf_read;
      s_load_conf_reg     <= s_slow_conf_load;
      s_check_status_reg  <= s_slow_check_status;
    end if;
  end process CDC_TRG;
  
  trigger_o       <= s_trigger_reg;
  stop_read_o     <= s_stop_reg;
  accept_data_o   <= s_accept_data_reg;
  reject_data_o   <= s_reject_data_reg;
  read_conf_o     <= s_read_conf_reg;
  load_conf_o     <= s_load_conf_reg;
  check_status_o  <= s_check_status_reg;
  
end architecture;
