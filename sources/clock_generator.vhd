-------------------------------------------------------------------------------
-- Title      : Clock generator
-- Project    :
-------------------------------------------------------------------------------
-- File       : clock_generator.vhd
-- Author     : Artem Shangaraev  <artem.shangaraev@cern.ch>
-- Company    : CERN
-- Created    : 2020-02-14
-- Last update: 2020-02-14
-- Platform   : Cyclone V GX
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: PLL with all necessary clocks for the design.
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CERN
-------------------------------------------------------------------------------
-- Revisions  :
-- Date         Version   Author    Description
-- 2020-02-14   1.0       ashangar  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity clock_generator is
  port (
    EXT_RST_i : in  std_logic;
		RST_o     : out std_logic;
    CLK_i     : in  std_logic;
		CLK_o     : out std_logic
  );
end entity;

architecture rtl of clock_generator is

-------------------------------------------------------------------------------
------ Component declaration --------------------------------------------------
-------------------------------------------------------------------------------
------ Intel IP ---------------------------------------------------------------

	component main_pll is
		port (
			refclk   : in  std_logic;
			rst      : in  std_logic;
			outclk_0 : out std_logic;
			locked   : out std_logic
		);
	end component main_pll;

-------------------------------------------------------------------------------
------ Signal declaration -----------------------------------------------------

  signal s_rst              : std_logic := '1';
  signal s_pll_locked       : std_logic := '0';
  signal s_pwrup_cnt        : unsigned (3 downto 0) := x"0";
  
-------------------------------------------------------------------------------
------ Architecture begin -----------------------------------------------------

begin

-------------------------------------------------------------------------------
------ Powerup reset ----------------------------------------------------------

  RST_o <= s_rst;

  PWRUP_RST: process(CLK_i)
  begin
    if rising_edge(CLK_i) then
      if s_pll_locked = '1' then
        if s_pwrup_cnt < x"F" then
          s_pwrup_cnt <= s_pwrup_cnt + 1;
          s_rst       <= '1';
        else
          s_rst       <= '0';
        end if;
      else
        s_pwrup_cnt   <= x"0";
        s_rst         <= '1';
      end if;
    end if;
  end process;

-------------------------------------------------------------------------------
------ Project clock ----------------------------------------------------------

  INST_MAIN_PLL : main_pll
    port map(
      refclk    => CLK_i,   -- clock from external oscillator
      rst       => EXT_RST_i,
      outclk_0  => CLK_o,           -- 10 MHz
      locked    => s_pll_locked
    );

end architecture rtl;