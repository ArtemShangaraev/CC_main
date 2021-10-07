-------------------------------------------------------------------------------
-- Title      : Analog readout
-- Project    : Column Controller CPV
-------------------------------------------------------------------------------
-- File       : analog_read.vhd
-- Author     : Artem Shangaraev <artem.shangaraev@cern.ch>
-- Company    : NRC "Kurchatov institute" - IHEP
-- Created    : 2020-02-18
-- Last update: 2021-08-05
-- Platform   : Quartus Prime 18.1.0
-- Target     : Cyclone V GX
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Reading Analog signals from Gassiplex to Dilogic FIFO.
--              1. Generates the full chain of signals for 3Gassiplex card
--                  (T/H, CLK, CLR).
--              2. Generates clock for ADC.
--              3. Generates trigger pulse, clock and address to write data 
--                  to FIFO of Dilogic.
--              4. Provide pulse for other entities when process ends.
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CERN
-------------------------------------------------------------------------------

Library IEEE;
Use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity analog_read is
  port (
    ARST          : in  std_logic;
    CLK           : in  std_logic;
    START_i       : in  std_logic;
    DONE_o        : out std_logic;
    
    ------ Dilogic pins ------
    CLK_A_o       : out std_logic;                    -- ADC clock
    CLK_D_o       : out std_logic;
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

  signal s_clk_a_en : std_logic := '0';
  signal s_clk_d_en : std_logic := '0';
  signal s_clk_g_en : std_logic := '0';

  signal s_cnt      : unsigned (7 downto 0) := (others => '0');
  
-------------------------------------------------------------------------------
------ Architecture begin -----------------------------------------------------
begin

  DONE_o    <= '1' when s_cnt = x"3A" else '0';
  
  CLR_D_o   <= ARST;
  
  CLK_A_o   <= CLK when s_clk_a_en = '1' else '1';
  CLK_D_o   <= CLK when s_clk_d_en = '1' else '1';
  CLK_G_o   <= CLK when s_clk_g_en = '1' else '1';

-------------------------------------------------------------------------------
------ Counter of analog readout process --------------------------------------

  READOUT_CNT: process (CLK, ARST)
  
    variable v_cnt        : unsigned(7 downto 0) := x"00";
    
  begin
    if ARST = '1' then
      v_cnt     := x"00";
      
    elsif rising_edge(CLK) then
    
      if v_cnt > x"00" and
         v_cnt < x"3A" then
        v_cnt   := v_cnt + 1;
      else
        v_cnt   := x"00";
      end if;
      
      if START_i = '1' then
        v_cnt   := x"01";
      end if;
      
      s_cnt     <= v_cnt;
      
    end if;
  end process READOUT_CNT;
  
-------------------------------------------------------------------------------
------ Generating signals for 3Gassiplex card ---------------------------------
  
  GASSIPLEX_CONTROL: process (CLK, ARST)
  
    variable v_th       : std_logic := '0';
    variable v_clk_g_en : std_logic := '0';
    variable v_clr_g    : std_logic := '0';
    
    variable v_clk_a_en : std_logic := '0';
    variable v_clk_d_en : std_logic := '0';
    variable v_trg_d    : std_logic := '0';
    variable v_addr     : unsigned (5 downto 0) := (others => '0');
    
  begin
    if ARST = '1' then
      v_th          := '0';
      v_clk_g_en    := '1';
      v_clr_g       := '0';
      v_clk_a_en    := '0';
      v_clk_d_en    := '1';
      v_trg_d       := '0';
      v_addr        := (others => '0');
      
    elsif rising_edge(CLK) then
    
      if s_cnt > x"00" and
         s_cnt < x"35" then
        v_th        := '1';
      else
        v_th        := '0';
      end if;
    
      if s_cnt > x"02" and
         s_cnt < x"33" then
        v_clk_g_en  := '1';
      else
        v_clk_g_en  := '0';
      end if;
    
      if s_cnt = x"37" or
         s_cnt = x"38" then
        v_clr_g     := '1';
      else
        v_clr_g     := '0';
      end if;
    
      if s_cnt = x"01" then
        v_trg_d     := '1';
      else
        v_trg_d     := '0';
      end if;
    
      if s_cnt > x"00" then
        v_clk_a_en  := '1';
      else
        v_clk_a_en  := '0';
      end if;
    
      if s_cnt > x"06" and
         s_cnt < x"38" then
        v_clk_d_en  := '1';
      else
        v_clk_d_en  := '0';
      end if;
    
      if s_cnt > x"07" and
         s_cnt < x"37" then
        v_addr      := v_addr + 1;
      else
        v_addr      := (others => '0');
      end if;
    
      T_H_o         <= not v_th;
      CLR_G_o       <= not v_clr_g;
      s_clk_g_en    <= v_clk_g_en;
      
      TRG_N_o       <= not v_trg_d;
      s_clk_d_en    <= v_clk_d_en;
      s_clk_a_en    <= v_clk_a_en;
      ADDR_GAS_N_o  <= std_logic_vector(not v_addr);
      
    end if;
  end process GASSIPLEX_CONTROL;
  
end architecture;
