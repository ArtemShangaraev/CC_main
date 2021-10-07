-------------------------------------------------------------------------------
-- Title      : LVDS wrapper
-- Project    : Column Controller CPV
-------------------------------------------------------------------------------
-- File       : lvds_wrapper.vhd
-- Author     : Clive Seguna  <clive.seguna@cern.ch>
-- Company    : University of Malta
-- Created    : 2018-01-01
-- Last update: 2020-03-04
-- Platform   : Quartus Prime 18.1.0
-- Target     : Cyclone V GX
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: LVDS RX wrapper. TX has an output and can be used if needed.
--              Provides convertion of input bitstream to 4-bit words.
--              Align words.
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CERN
-------------------------------------------------------------------------------
--  Revisions  :
--  Date          Version   Author    Description
--  2018-01-01    1.0       cseguna   Created
--  2020-02-15    1.1       ashangar  Recreated from LVDSCtrl
--  2020-02-23    1.1       ashangar  Removed commented and not used code
-------------------------------------------------------------------------------


Library IEEE;
Use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity lvds_wrapper IS
  port (
    arst        : in  std_logic;
    lvds_data_i : in  std_logic_vector (0 downto 0);  -- serial in
    lvds_clk_i  : in  std_logic;                      -- 160M in clk
    lvds_data_o : out std_logic_vector (3 downto 0);  -- parallel out
    lvds_clk_o  : out std_logic;                      -- 40M out clk
    aligned_o   : out std_logic                       -- LVDS status
  );
end entity;


architecture beh of lvds_wrapper  is

-------------------------------------------------------------------------------
-- Component declaration ------------------------------------------------------

  component LVDS_RX is
    port (
      pll_areset            : in  std_logic;
      rx_channel_data_align : in  std_logic_vector (0 downto 0);
      rx_in                 : in  std_logic_vector (0 downto 0);
      rx_inclock            : in  std_logic;
      rx_locked             : out std_logic;
      rx_out                : out std_logic_vector (3 downto 0);
      rx_outclock           : out std_logic 
    );
  end component LVDS_RX;
  
-------------------------------------------------------------------------------
-- Signal declaration ---------------------------------------------------------

  type   t_bitslip_lvds is (
    Reset,
    Check1,
    Check2,
    Bitslip_on,
    Bitslip_off,
    Wait1,
    Wait2,
    Wait3,
    Ready,
    Realign1,
    Realign2,
    Realign3
  );
  signal BS :t_bitslip_lvds := Reset;

  signal s_pll_arst               : std_logic := '1';
  signal s_rx_channel_data_align  : std_logic_vector(0 downto 0) := "0";
  signal s_lvds_reg               : std_logic_vector(3 downto 0) := x"0";
  signal s_lvds_word              : std_logic_vector(3 downto 0) := x"0";
  signal s_lvds_clk               : std_logic := '0';
  signal s_rx_locked              : std_logic := '0';

-------------------------------------------------------------------------------
------ Architecture begin -----------------------------------------------------
begin

-------------------------------------------------------------------------------
------ LVDS IP entity ---------------------------------------------------------

  s_pll_arst <= arst;
  lvds_clk_o <= s_lvds_clk;
  aligned_o   <= '1' when BS <= Ready else '0';

  RX_LVDS : LVDS_RX 
  port map (
    pll_areset            => s_pll_arst,
    rx_channel_data_align => s_rx_channel_data_align, -- bit slip procedure
    rx_in                 => lvds_data_i,             -- incoming bitstream
    rx_inclock            => lvds_clk_i,              -- 200M serial clock
    rx_out                => s_lvds_word,             -- 4-bit word
    rx_outclock           => s_lvds_clk,              -- clock out 50M
    rx_locked             => s_rx_locked
  );

-------------------------------------------------------------------------------
------------- LVDS calibration process: bitslip and check ---------------------

  process(s_lvds_clk, arst)
  begin
    if arst = '1' then
      BS <= Reset;
    elsif rising_edge(s_lvds_clk) then
      case BS is
        when Reset =>
          if s_rx_locked = '1' then
            BS <= Check1;
          end if;
        when Check1 =>
          if s_lvds_word = x"2" then
            BS <= Check2;
          else
            BS <= Bitslip_on;
          end if;
        when Check2 =>
          if s_lvds_word = x"2" then
            BS <= Ready;
          else
            BS <= Bitslip_on;
          end if;
        when Bitslip_on  =>
          s_rx_channel_data_align <= "1";
          BS <= Bitslip_off;
        when Bitslip_off =>
          s_rx_channel_data_align <= "0";
          BS <= Wait1;
        when Wait1 =>
          BS <= Wait2;
        when Wait2 =>
          BS <= Wait3;
        when Wait3 =>
          BS <= Check1;      -- Data available on the 3rd parallel cycle
        when Ready =>
          if s_lvds_word = x"F" then
            BS <= Realign1;
          else
            BS <= Ready;
          end if;
        when Realign1 =>
          if s_lvds_word = x"F" then
            BS <= Realign2;
          else
            BS <= Ready;
          end if;
        when Realign2 =>
          if s_lvds_word = x"F" then
            BS <= Realign3;
          else
            BS <= Ready;
          end if;
        when Realign3 =>
          if s_lvds_word = x"F" then
            BS <= Reset;
          else
            BS <= Ready;
          end if;
        when others => 
          null;
      end case;
    end if;
  end process;

-------------------------------------------------------------------------------
---------- Register output data -----------------------------------------------

  lvds_data_o <= s_lvds_reg;
  
  process (s_lvds_clk, arst)
  begin
    if arst = '1' then
      s_lvds_reg <= x"0";
    elsif rising_edge(s_lvds_clk) then
      if BS = Ready or 
         BS = Realign1 or
         BS = Realign2 or
         BS = Realign3 then
        s_lvds_reg <= s_lvds_word;
      else
        s_lvds_reg <= x"0";
      end if;
    end if;
  end process;

end architecture;
