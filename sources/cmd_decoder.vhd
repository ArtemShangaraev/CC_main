-------------------------------------------------------------------------------
-- Title      : Command decoder
-- Project    :
-------------------------------------------------------------------------------
-- File       : cmd_decoder.vhd
-- Author     : Artem Shangaraev
-- Company    : NRC "Kurchatov institute" - IHEP
-- Created    : 2018-01-01
-- Last update: 2020-02-15
-- Platform   : Cyclone V GX
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: System control decodes incoming LVDS commands.
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CERN
-------------------------------------------------------------------------------
--  Revisions  :
--  Date          Version   Author    Description
--  2020-02-16    1.0       ashangar  Created
-------------------------------------------------------------------------------

Library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cmd_decoder is
  port (
    arst          : in std_logic;
    clk           : in std_logic;
    
    lvds_cmd_i    : in std_logic_vector(3 downto 0);
    lvds_cmd_o    : out std_logic_vector(3 downto 0);
    is_cmd20_o    : out std_logic;
    analog_trg_o  : out std_logic;
    stop_rd_o     : out std_logic;
    is_data_o     : out std_logic;
    data_o        : out std_logic_vector(8 downto 0)
  );
end entity;

architecture beh of cmd_decoder is

-------------------------------------------------------------------------------
-- Component declaration ------------------------------------------------------

-------------------------------------------------------------------------------
------ Signal declaration -----------------------------------------------------

  type  t_cmd_fsm is (
    Reset,
    Aligned,
    Idle,
    ZS_on,
    ZS_off,
    Trigger,
    Load_threshold,
    Read_threshold,
    Start_of_frame,
    End_of_frame,
    Data1,
    Data2,
    Data3,
    Break,
    Wait_100ns,
    Done
  );
  signal st_cmd      : t_cmd_fsm := Reset;
  
  signal s_lvds_cmd   : std_logic_vector(3 downto 0) := x"0";
  signal s_data       : std_logic_vector(8 downto 0) := (others => '0');
  signal s_pulse_hold : unsigned (2 downto 0) := b"000";

-------------------------------------------------------------------------------
------ Architecture begin -----------------------------------------------------
begin

-------------------------------------------------------------------------------
------ FSM to decode command --------------------------------------------------

  CMD_DECODE: process(clk, arst) 
  begin
    if arst = '1' then
      data_o        <= (others => '0');
      is_data_o     <= '0';
      is_cmd20_o    <= '0';
      analog_trg_o  <= '0';
      lvds_cmd_o    <= x"0";
      s_pulse_hold  <= b"000";
      st_cmd        <= Reset;
    elsif rising_edge(clk) then
      s_lvds_cmd <= lvds_cmd_i;            -- Just buffering incoming command
      case st_cmd is
        when Reset =>
          data_o      <= (others => '0');
          is_data_o   <= '0';
          is_cmd20_o  <= '0';
          lvds_cmd_o  <= x"0";
          if lvds_cmd_i = x"2" then
            st_cmd    <= Aligned;
          end if;
          
        when Aligned =>
          is_cmd20_o  <= '0';
          lvds_cmd_o  <= s_lvds_cmd;
          st_cmd      <= Idle;
          
        when Idle =>
          s_pulse_hold  <= b"000";
          analog_trg_o  <= '0';
          stop_rd_o     <= '0';
          is_cmd20_o    <= '0';
          lvds_cmd_o    <= x"0";
          case lvds_cmd_i is
            when x"1" =>
              st_cmd   <= Load_threshold;
            when x"2" =>
              st_cmd   <= Idle;
            when x"3" =>
              st_cmd   <= Start_of_frame;
            when x"4" =>
              st_cmd   <= Read_threshold; -- Read thresholds
            when x"5" =>
              st_cmd   <= ZS_off;
            when x"6" =>
              st_cmd   <= ZS_on;
            when x"7" =>
              st_cmd   <= Trigger;
            when x"8" =>
              st_cmd   <= Break;
            when others =>
              null;
          end case;
        
        when ZS_on =>
          is_cmd20_o  <= '0';
          lvds_cmd_o  <= s_lvds_cmd;
          st_cmd      <= Done;
          
        when ZS_off =>
          is_cmd20_o  <= '0';
          lvds_cmd_o  <= s_lvds_cmd;
          st_cmd      <= Done;
          
        when Trigger =>
          analog_trg_o  <= '1';
          is_cmd20_o    <= '1';
          lvds_cmd_o    <= s_lvds_cmd;
          st_cmd        <= Wait_100ns;
          
        when Break =>
          stop_rd_o     <= '1';
          is_cmd20_o    <= '1';
          lvds_cmd_o    <= s_lvds_cmd;
          st_cmd        <= Wait_100ns;
          
        -- Provide 100 ns pulse for 10 MHz clock domain
        when Wait_100ns =>
          is_cmd20_o    <= '0';
          if s_pulse_hold < 4 then
            s_pulse_hold  <= s_pulse_hold + 1;
          else
            st_cmd        <= Idle;
          end if;
          
        when Start_of_frame =>
          data_o      <= (others => '0');
          is_data_o   <= '0';
          is_cmd20_o  <= '1';
          lvds_cmd_o  <= s_lvds_cmd;
          st_cmd      <= Data1;
          
        when Data1 =>
          s_data(8)   <= s_lvds_cmd(0);
          is_cmd20_o  <= '0';
          st_cmd      <= Data2;
          
        when Data2 =>
          s_data(7 downto 4) <= s_lvds_cmd;
          is_cmd20_o  <= '0';
          st_cmd      <= Data3;
          
        when Data3 =>
          s_data(3 downto 0) <= s_lvds_cmd;
          is_cmd20_o  <= '0';
          st_cmd      <= End_of_frame;
          
        when End_of_frame =>
          data_o      <= s_data;
          is_data_o   <= '1';
          is_cmd20_o  <= '0';
          if lvds_cmd_i = x"3" then
            st_cmd    <= Start_of_frame;
          else
            st_cmd    <= Done;
          end if;
          
        when Done =>
          data_o      <= (others => '0');
          is_data_o   <= '0';
          is_cmd20_o  <= '0';
          st_cmd      <= Idle;
          
        when others =>
          st_cmd      <= Idle;
--          null;
      end case;
    end if;
  end process;

end architecture;