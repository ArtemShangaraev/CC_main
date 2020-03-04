-------------------------------------------------------------------------------
-- Title      : Analog readout
-- Project    :
-------------------------------------------------------------------------------
-- File       : analog_read.vhd
-- Author     : Artem Shangaraev <artem.shangaraev@cern.ch>
-- Company    : NRC "Kurchatov institute" - IHEP
-- Created    : 2020-02-18
-- Last update: 2020-02-18
-- Platform   : Cyclone V GX
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Read Analog signals from Gassiplex to Dilogic FIFO.
--              Generates the full chain of signals for 3Gassiplex card.
--              To do: add stop-signal to break the readout and clear Dil FIFO.
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CERN
-------------------------------------------------------------------------------
--  Revisions  :
--  Date          Version   Author    Description
--  2020-02-18    1.0       ashangar  Created
-------------------------------------------------------------------------------

Library IEEE;
Use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity analog_read is
  port (
    arst          : in  std_logic;
    CLK           : in  std_logic;
    start_i       : in  std_logic;
    stop_i        : in  std_logic;
    done_o        : out std_logic;
    
    ------ Dilogic pins ------
    CLK_ADC_o     : out std_logic;
    CLKD_o        : out std_logic;
    CLR_D_o       : out std_logic;
    ADDR_GAS_N_o  : out std_logic_vector(5 downto 0);
    TRG_N_o       : out std_logic;
    
    ------ Gassiplex pins ------
    CLK_G_o       : out std_logic;
    CLR_G_o       : out std_logic;
    T_H_o         : out std_logic
  );
end entity;


architecture beh of analog_read is

-------------------------------------------------------------------------------
------ Component declaration --------------------------------------------------

-------------------------------------------------------------------------------
------ Signal declaration -----------------------------------------------------

  type t_readout_fsm is (
    Reset,
    Idle,
    Start_T_H,
    Start_CLK,
    Process_rd,
    End_T_H,
    Clear_delay_100ns,
    Clear_delay_200ns,
    Clear_set_100ns,
    Clear_set_200ns,
    Readout_done
  );
  signal s_rd_state: t_readout_fsm := Reset;

  signal s_addr_cnt   : unsigned (5 downto 0) := (others => '0');
  signal s_clk_ena    : std_logic := '0';
  signal s_clk_ena_d  : std_logic := '0';
  signal s_t_h        : std_logic := '0';
  signal s_trg        : std_logic := '0';
  
-------------------------------------------------------------------------------
------ Architecture begin -----------------------------------------------------
begin
  
  ADDR_GAS_N_o  <= std_logic_vector(not s_addr_cnt);
  
--  CLK_G_o       <= (not CLK) and s_clk_ena;
--  CLK_ADC_o     <= CLK and s_clk_ena;
--  CLKD_o        <= CLK and s_clk_ena_d;
  CLK_G_o       <= not CLK when s_clk_ena = '1'   else '1';
  CLK_ADC_o     <=     CLK when s_clk_ena = '1'   else '1';
  CLKD_o        <=     CLK when s_clk_ena_d = '1' else '1';
  
  CLR_D_o       <= arst;
  CLR_G_o       <= '0' when s_rd_state = Clear_set_100ns 
                         or s_rd_state = Clear_set_200ns else '1';
  
  T_H_o         <= not s_t_h;
  TRG_N_o       <= not s_trg;

  READOUT_FSM: process (CLK, arst)
  begin
    if arst = '1' then
      s_addr_cnt  <= (others => '0');
      s_trg       <= '0';
      s_t_h       <= '0';
      s_clk_ena   <= '0';
      s_clk_ena_d <= '0';
      s_rd_state  <= Reset;
      
    elsif rising_edge(CLK) then
      case s_rd_state is
        when Reset =>
          s_rd_state    <= Idle;
          
        when Idle =>
          s_clk_ena     <= '0';
          s_clk_ena_d   <= '0';
          done_o        <= '0';
          if start_i = '1' then
            s_trg       <= '1';
            s_t_h       <= '1';
            s_rd_state  <= Start_T_H;
          end if;
          
        when Start_T_H =>
          s_trg         <= '0';
          s_rd_state    <= Start_CLK;
          
        when Start_CLK =>
          s_addr_cnt    <= (others => '0');
          s_clk_ena     <= '1';
          s_clk_ena_d   <= '1';
          s_rd_state    <= Process_rd;
        
        when Process_rd =>
          if stop_i = '0' then
            if s_addr_cnt < 48 then
              s_addr_cnt  <= s_addr_cnt + 1;
            else
              s_addr_cnt  <= (others => '0');
              s_clk_ena   <= '0';
              s_clk_ena_d <= '1';
              s_rd_state  <= End_T_H;
            end if;
          else
            s_addr_cnt  <= (others => '0');
            s_clk_ena   <= '0';
            s_rd_state  <= End_T_H;
          end if;
        
        when End_T_H =>
          done_o        <= '1';
          s_t_h         <= '0';
          s_clk_ena_d   <= '0';
          s_rd_state    <= Clear_delay_100ns;
        
        when Clear_delay_100ns =>
          s_rd_state    <= Clear_delay_200ns;
        
        when Clear_delay_200ns =>
          s_rd_state    <= Clear_set_100ns;
        
        when Clear_set_100ns =>
          s_rd_state    <= Clear_set_200ns;
        
        when Clear_set_200ns =>
          s_rd_state    <= Readout_done;
        
        when Readout_done =>
          s_rd_state    <= Idle;
        
        when others =>
          null;
      end case;
    end if;
  end process;


end architecture;