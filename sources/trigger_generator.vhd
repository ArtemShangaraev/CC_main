-------------------------------------------------------------------------------
-- Title      : Trigger_generator
-- Project    : Column Controller CPV
-------------------------------------------------------------------------------
-- File       : trigger_generator.vhd
-- Author     : Artem Shangaraev <artem.shangaraev@cern.ch>
-- Company    : CERN / IHEP, Protvino
-- Created    : 2019-07-18
-- Last update: 2019-07-18
-- Platform   : Quartus Prime 18.1.0
-- Target     : Cyclone V GX
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Generate pulses with constant frequency (1 kHz).
--              Optional entity for debug while LVDS doesn't work.
-------------------------------------------------------------------------------
-- Copyright (c) 2019 CERN
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2019-07-18  1.0      ashangar  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity trigger_generator is
  port (
    CLK       : in  std_logic;    -- 10 MHz
    ARST      : in  std_logic;

    TRIGGER_o : out std_logic
    );
end entity trigger_generator;

architecture rtl of trigger_generator is

  signal s_cnt    : integer range 0 to 16000 := 0;
  
  constant c_1k   : integer := 9999;
  
begin
  
  process(ARST, CLK) is
  begin
    if falling_edge(CLK) then
      if ARST = '1' then
        TRIGGER_o   <= '0';
      else
        if s_cnt = c_1k then
          s_cnt     <= 0;
          TRIGGER_o <= '1';
        else
          s_cnt     <= s_cnt + 1;
          TRIGGER_o <= '0';
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
