-------------------------------------------------------------------------------
-- Title        : Dilogic data generator
-- Project      :
-------------------------------------------------------------------------------
-- File         : dilogic_data_generator.vhd
-- Author       : Artem Shangaraev  <artem.shangaraev@cern.ch>
-- Company      : CERN / NRC "Kurchatov institute" - IHEP
-- Created      : 2021-04-19
-- Last update  : 2021-04-19
-- Target       : Cyclone V GX
-- Platform     : Quartus Prime 18.1
-- Standard     : VHDL'93/02
-------------------------------------------------------------------------------
-- Description  : Top level control of all 5-Dilogic cards.
--                Generator of data, splitter to 4 cards,
--                generator of control words.
--                Output is 32-bit word for XCVR.
-------------------------------------------------------------------------------
-- Copyright (c) 2021 CERN
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity dilogic_data_generator is
  port (
    arst            : in std_logic;
    
    -- 10M clock domain
    CLK10           : in  std_logic;
    trigger_i       : in  std_logic;
    data_ready_i    : in  std_logic;
    accept_data_i   : in  std_logic;
    reject_data_i   : in  std_logic;
    check_status_i  : in  std_logic;
    
    -- XCVR connection
    DATA_RDY_o      : out std_logic_vector(3 downto 0);
    DATAOUT_o       : out std_logic_vector(127 downto 0);
    CTRL_o          : out std_logic_vector(31 downto 0)
  );
end entity dilogic_data_generator;

architecture structural of dilogic_data_generator is

  type t_latch is (
    Allowed,
    Blocked
  );
  signal st_sending: t_latch := Allowed;
  
  type generator_state is (
    Idle,
    Wait_start,
    Send_data,
    Wait_stop,
    Stop_pulse
  );
  
  signal GEN_ST : generator_state := Idle;
  
  signal s_ctrl_word    : std_logic_vector (31 downto 0) := (others => '1');
  
  signal s_data         : std_logic_vector(31 downto 0) := (others => '0');
  signal s_data_rdy     : std_logic := '0';
  signal s_data_rdy_reg : std_logic := '0';
  
  signal s_word_cnt     : integer range 0 to 255  := 0;
  signal s_idle_cnt     : integer range 0 to 15   := 0;
  signal s_cnt          : integer range 0 to 255  := 0;
  
  constant c_card_id    : std_logic_vector (7 downto 0) := "11" & "10" & "01" & "00";
  signal s_dil_id       : unsigned(2 downto 0)          := "000";
  signal s_channel      : unsigned(5 downto 0)          := "000000";
  signal s_value        : std_logic_vector(11 downto 0) := x"0da";
  
  type t_mem is array(0 to 255) of std_logic_vector(31 downto 0);
  signal dil_data : t_mem := (others => (others => '0'));

begin

-------------------------------------------------------------------------------
-- Generation of control words
-------------------------------------------------------------------------------
  ALLOW_CTRL: process (CLK10, arst)
  begin
    if arst = '1' then
      st_sending <= Allowed;
    elsif rising_edge(CLK10) then
      case st_sending is
        when Allowed =>
          if reject_data_i = '1' then
            st_sending <= Blocked;
          end if;
        when Blocked =>
          if trigger_i = '1' or accept_data_i = '1' then
            st_sending <= Allowed;
          end if;
        when others =>
          null;
      end case;
    end if;
  end process ALLOW_CTRL;
  
  CTRL_WORDS: process (CLK10, arst)
  begin
    if arst = '1' then
      s_ctrl_word <= (others => '1');
    elsif rising_edge(CLK10) then
    
      if accept_data_i = '1' then
        s_ctrl_word <= x"A1FFFFFF";
        
      elsif GEN_ST = Stop_pulse then
        s_ctrl_word <= x"B1FFFFFF";
        
      elsif check_status_i = '1' then
        s_ctrl_word <= x"C1FFFFFF";
        
      else
        s_ctrl_word <= (others => '1');
      end if;
    end if;
  end process CTRL_WORDS;
  
  CTRL_o  <= s_ctrl_word when st_sending = Allowed else (others => '1');
  
-------------------------------------------------------------------------------
-- Fill memory with 245 Dil words: (48 channels + end-event) * 5 Dilogics
-------------------------------------------------------------------------------
  FILL_MEMORY: process (CLK10, arst) is
  begin
    if arst = '1' then
      s_dil_id  <= "000";
      s_channel <= "000000";
      s_value   <= x"0da";
      s_cnt     <= 0;
      dil_data  <= (others => (others => '0'));
    elsif rising_edge(CLK10) then
      if s_channel = 48 then
        dil_data(s_cnt) <= x"0A800030";
      else
        dil_data(s_cnt) <= x"0A" & "0" & "00" & std_logic_vector(s_dil_id) & std_logic_vector(s_channel) & s_value;
      end if;
      if s_cnt < 250 then
        s_cnt           <= s_cnt + 1;
      end if;
      if s_channel < 48 then
        s_channel   <= s_channel + 1;
      else
        s_channel   <= "000000";
        if s_dil_id < 4 then
          s_dil_id  <= s_dil_id + 1;
        else
          s_dil_id  <= "000";
        end if;
      end if;
    end if;
  end process FILL_MEMORY;

-------------------------------------------------------------------------------
-- FSM to read data from memory on trigger
-------------------------------------------------------------------------------
  GENERATE_DATA: process (CLK10, arst) is
  
  begin
    if arst = '1' then
      s_data          <= (others => '0');
      s_data_rdy      <= '0';
      s_data_rdy_reg  <= '0';
      s_word_cnt      <= 0;
      s_idle_cnt      <= 0;
      GEN_ST          <= Idle;
    elsif rising_edge(CLK10) then
    
      s_data_rdy_reg  <= s_data_rdy;
        
      case GEN_ST is
        when Idle =>
          s_data        <= (others => '0');
          s_word_cnt    <= 0;
          s_idle_cnt    <= 0;
          if accept_data_i = '1' then
            GEN_ST      <= Wait_start;
          end if;
          
        when Wait_start =>
          s_data        <= (others => '0');
          s_data_rdy    <= '0';
          if s_idle_cnt < 8 then
            s_idle_cnt  <= s_idle_cnt + 1;
            GEN_ST      <= Wait_start;
          else
            s_idle_cnt  <= 0;
            GEN_ST      <= Send_data;
          end if;
          
        when Send_data =>
          s_data        <= dil_data(s_word_cnt);
          s_word_cnt    <= s_word_cnt + 1;
          s_data_rdy    <= '1';
          if s_word_cnt = 244 then
            GEN_ST      <= Wait_stop;
          end if;
          
        when Wait_stop =>
          s_data        <= (others => '0');
          s_data_rdy    <= '0';
          s_word_cnt    <= 0;
          if s_idle_cnt < 8 then
            s_idle_cnt  <= s_idle_cnt + 1;
            GEN_ST      <= Wait_stop;
          else
            s_idle_cnt  <= 0;
            GEN_ST      <= Stop_pulse;
          end if;
          
        when Stop_pulse =>
          s_data        <= (others => '0');
          s_data_rdy    <= '0';
          GEN_ST        <= Idle;
          
        when others =>
          null;
      end case;
    end if;
  end process GENERATE_DATA;
  
-------------------------------------------------------------------------------
-- Fill data for 4 cards and fill card ID
-------------------------------------------------------------------------------
  DIL_DATA_GEN : for i in 0 to 3 generate
    
    DIL_DATA_OUT: process (CLK10, arst)
    
    begin
      if arst = '1' then
        DATAOUT_o(32*i+31 downto 32*i)  <= (others => '0');
        DATA_RDY_o(i)                   <= '0';
      elsif rising_edge(CLK10) then
      
        if s_data_rdy_reg = '1' and s_data_rdy = '1' then
          DATA_RDY_o(i) <= '1';
        else
          DATA_RDY_o(i) <= '0';
        end if;
        
        if s_data_rdy_reg = '1' then
          DATAOUT_o(32*i+31 downto 32*i)  <= 
            s_data(31 downto 23) &
            c_card_id(2*i+1 downto 2*i) & 
            s_data(20 downto 0);
        else
          DATAOUT_o(32*i+31 downto 32*i)  <= (others => '0');
        end if;
        
      end if;
    end process;
  
  end generate DIL_DATA_GEN;
  
end architecture structural;
