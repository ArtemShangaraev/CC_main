-------------------------------------------------------------------------------
-- Title      : Data packer
-- Project    : Column Controller CPV
-------------------------------------------------------------------------------
-- File       : data_packer.vhd
-- Author     : Artem Shangaraev  <artem.shangaraev@cern.ch>
-- Company    : CERN
-- Created    : 2020-02-13
-- Last update: 2020-03-04
-- Platform   : Quartus Prime 18.1.0
-- Target     : Cyclone V GX
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Multiplexer to send data from 4 Dilogic cards to XCVR.
--              There is a FIFO for each card.
--              Round-robin reading of FIFOs.
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CERN
-------------------------------------------------------------------------------
-- Revisions  :
-- Date         Version   Author    Description
-- 2020-02-13   1.0       ashangar  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity data_packer is
  port (
    arst        : in  std_logic;
    
    -- 10M clock domain
    CLK_DIL     : in  std_logic;
    DATA_i      : in  std_logic_vector(127 downto 0);
    DATA_RDY_i  : in  std_logic_vector(3 downto 0);
    
    -- XCVR interface, GTX parallel clock domain
    CLK_XCVR    : in  std_logic;
    DATA_o      : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of data_packer is

-------------------------------------------------------------------------------
---- Component declaration ----------------------------------------------------

  component fifo_32x256 is
    port (
      aclr    : in  std_logic;
      data    : in  std_logic_vector (31 downto 0);
      rdclk   : in  std_logic;
      rdreq   : in  std_logic;
      wrclk   : in  std_logic;
      wrreq   : in  std_logic;
      q       : out std_logic_vector (31 downto 0);
      rdempty : out std_logic;
      wrfull  : out std_logic
    );
  end component fifo_32x256;
  
-------------------------------------------------------------------------------
------ Signal declaration -----------------------------------------------------
  
  signal s_data_out     : std_logic_vector (31 downto 0)  := (others => '0');
  signal s_fifo_out     : std_logic_vector (127 downto 0) := (others => '0');
  signal s_data_in      : std_logic_vector (127 downto 0) := (others => '0');
  signal s_wrreq        : std_logic_vector (3 downto 0)   := x"0";
  signal s_wrfull       : std_logic_vector (3 downto 0)   := x"0";
  
  signal s_rdempty      : std_logic_vector (3 downto 0)   := x"0";
  signal s_rdreq        : std_logic_vector (3 downto 0)   := x"0";
  signal s_rdreq_hold_0 : std_logic_vector (3 downto 0)   := x"0";
  signal s_rdreq_hold_1 : std_logic_vector (3 downto 0)   := x"0";
  signal s_rdreq_hold_2 : std_logic_vector (3 downto 0)   := x"0";
  signal s_rdreq_hold_3 : std_logic_vector (3 downto 0)   := x"0";
  
  signal s_word_1       : std_logic_vector (15 downto 0)  := (others => '0');
  signal s_word_2       : std_logic_vector (15 downto 0)  := (others => '0');
  signal s_fifo_num     : natural range 0 to 3 := 0;

-------------------------------------------------------------------------------
------ Architecture begin -----------------------------------------------------
begin

  s_data_in <= DATA_i;
  DATA_o    <= s_data_out;

-------------------------------------------------------------------------------
------ Generate 4 FIFO for datapath -------------------------------------------

  INST_DATAPATH_FIFO_GEN : for i in 0 to 3 generate
  
    s_wrreq(i) <= data_rdy_i(i) and not s_wrfull(i);
    
    INST_xcvr_tx_fifo: fifo_32x256
      port map (
        aclr    => arst,
        wrclk   => CLK_DIL,
        wrreq   => s_wrreq(i),
        data    => s_data_in(32*i+31 downto 32*i),
        wrfull  => s_wrfull(i),
        rdclk   => CLK_XCVR,
        rdreq   => s_rdreq(i),
        q       => s_fifo_out(32*i+31 downto 32*i),
        rdempty => s_rdempty(i)
      );
      
    process (CLK_XCVR, arst)
    begin
      if (arst = '1') then
        s_rdreq_hold_0(i) <= '0';
        s_rdreq_hold_1(i) <= '0';
        s_rdreq_hold_2(i) <= '0';
        s_rdreq_hold_3(i) <= '0';
      elsif falling_edge(CLK_XCVR) then
        s_rdreq_hold_0(i) <= not s_rdempty(i);    -- real rdreq
        s_rdreq_hold_1(i) <= s_rdreq_hold_0(i);   -- Hold while reading 4 FIFO
        s_rdreq_hold_2(i) <= s_rdreq_hold_1(i);
        s_rdreq_hold_3(i) <= s_rdreq_hold_2(i);
      end if;
    end process;
  
    s_rdreq(i) <= s_rdreq_hold_0(i)
               or s_rdreq_hold_1(i)
               or s_rdreq_hold_2(i)
               or s_rdreq_hold_3(i);
  
  end generate INST_DATAPATH_FIFO_GEN;
  
-------------------------------------------------------------------------------
------ Assemble data to send out ----------------------------------------------
------ Send bits [15..0] first, then [31..16] ---------------------------------
------ This is a requirement of receiver side ---------------------------------

  s_data_out <= s_word_2 & s_word_1;

-------------------------------------------------------------------------------
------ Choose FIFO to read from -----------------------------------------------

  DATA_MUX: process(CLK_XCVR, arst) 
  begin
    if (arst = '1') then
      s_fifo_num    <= 0;
      s_word_1  <= x"0000";
      s_word_2  <= x"0000";
    elsif rising_edge(CLK_XCVR) then
      if s_fifo_num < 3 then
        s_fifo_num  <= s_fifo_num + 1;
      else
        s_fifo_num  <= 0;
      end if;
      if s_rdreq(s_fifo_num) = '1' then
        s_word_1  <= s_fifo_out(32*s_fifo_num+31 downto 32*s_fifo_num+16);
        s_word_2  <= s_fifo_out(32*s_fifo_num+15 downto 32*s_fifo_num);
      else
        s_word_1  <= x"C5BC";
        s_word_2  <= x"C5BC";
      end if;
    end if;
  end process;

end architecture;
