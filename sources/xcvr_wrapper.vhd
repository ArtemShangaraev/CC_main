-------------------------------------------------------------------------------
-- Title      : XCVR wrapper
-- Project    : Column Controller CPV
-------------------------------------------------------------------------------
-- File       : xcvr_wrapper.vhd
-- Author     : Clive Seguna  <clive.seguna@cern.ch>
-- Company    : University of Malta
-- Created    : 2018-01-01
-- Last update: 2020-02-23
-- Platform   : Quartus Prime 18.1.0
-- Target     : Cyclone V GX
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: XCVR TX wrapper. RX has an input and can be used if needed.
--              Provides convertion of 32-bit words to serial bitstream.
--              Includes reconfiguration and reset.
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CERN
-------------------------------------------------------------------------------
--  Revisions  :
--  Date          Version   Author    Description
--  2018-01-01    1.0       cseguna   Created
--  2020-02-15    1.1       ashangar  Recreated to check compilation errors
--  2020-02-20    1.2       ashangar  Removed XCVR RX.
--                                    Reset and reconfiguration replaced by
--                                    native Intel IP cores.
--  2020-07-20    1.3       ashangar  Idle word and control bits changed to
--                                    provide 4-bytes alignment.
-------------------------------------------------------------------------------

Library IEEE;
Use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity XCVR_WRAPPER is
  port (
    ARST                    : in  std_logic;
    MGMT_CLK                : in  std_logic;                      -- 50 MHz
    REF_CLK                 : in  std_logic_vector (0 downto 0);  -- 156.25 MHz
    
    XCVR_TX_parallel_data_i : in  std_logic_vector (31 downto 0);
    XCVR_TX_serial_data_o   : out std_logic_vector (0 downto 0);
    XCVR_TX_parallel_clk_o  : out std_logic_vector (0 downto 0)   -- 78.125 MHz
  );
end entity XCVR_WRAPPER;

architecture structural of XCVR_WRAPPER is 

-------------------------------------------------------------------------------
------ Component declaration --------------------------------------------------

  component XCVR_TX is
    port (
      pll_powerdown           : in  std_logic_vector(0 downto 0);
      tx_analogreset          : in  std_logic_vector(0 downto 0);
      tx_digitalreset         : in  std_logic_vector(0 downto 0);
      tx_pll_refclk           : in  std_logic_vector(0 downto 0);
      tx_serial_data          : out std_logic_vector(0 downto 0);
      pll_locked              : out std_logic_vector(0 downto 0);
      tx_std_coreclkin        : in  std_logic_vector(0 downto 0);
      tx_std_clkout           : out std_logic_vector(0 downto 0);
      tx_cal_busy             : out std_logic_vector(0 downto 0);
      reconfig_to_xcvr        : in  std_logic_vector(139 downto 0);
      reconfig_from_xcvr      : out std_logic_vector(91 downto 0);
      tx_parallel_data        : in  std_logic_vector(31 downto 0);
      tx_datak                : in  std_logic_vector(3 downto 0);
      unused_tx_parallel_data : in  std_logic_vector(7 downto 0)
    );
  end component XCVR_TX;
  
  component XCVR_RST_CTRL is
    port (
      clock              : in  std_logic;
      reset              : in  std_logic;
      pll_powerdown      : out std_logic_vector(0 downto 0);
      tx_analogreset     : out std_logic_vector(0 downto 0);
      tx_digitalreset    : out std_logic_vector(0 downto 0);
      tx_ready           : out std_logic_vector(0 downto 0);
      pll_locked         : in  std_logic_vector(0 downto 0);
      pll_select         : in  std_logic_vector(0 downto 0);
      tx_cal_busy        : in  std_logic_vector(0 downto 0)
    );
  end component XCVR_RST_CTRL;

  component XCVR_RECFG_CTRL is
    port (
      reconfig_busy             : out std_logic;
      mgmt_clk_clk              : in  std_logic;
      mgmt_rst_reset            : in  std_logic;
      reconfig_mgmt_address     : in  std_logic_vector(6 downto 0);
      reconfig_mgmt_read        : in  std_logic;
      reconfig_mgmt_readdata    : out std_logic_vector(31 downto 0);
      reconfig_mgmt_waitrequest : out std_logic;
      reconfig_mgmt_write       : in  std_logic;
      reconfig_mgmt_writedata   : in  std_logic_vector(31 downto 0);
      reconfig_to_xcvr          : out std_logic_vector(139 downto 0);
      reconfig_from_xcvr        : in  std_logic_vector(91 downto 0)
    );
  end component XCVR_RECFG_CTRL;

-------------------------------------------------------------------------------
------ Signal declaration -----------------------------------------------------

  signal s_xcvr_rst           : std_logic :='0';
  signal s_scvr_rst_cnt       : unsigned (3 downto 0) := x"0";

  signal s_pll_powerdown      : std_logic_vector(0 downto 0)    := (others => '0');
  signal s_tx_analogreset     : std_logic_vector(0 downto 0)    := (others => '0');
  signal s_tx_digitalreset    : std_logic_vector(0 downto 0)    := (others => '0');
  signal s_tx_serial_data     : std_logic_vector(0 downto 0)    := (others => '0');
  signal s_pll_locked         : std_logic_vector(0 downto 0)    := (others => '0');
  signal s_tx_std_clk         : std_logic_vector(0 downto 0)    := (others => '0');
  signal s_tx_cal_busy        : std_logic_vector(0 downto 0)    := (others => '0');
  signal s_reconfig_to_xcvr   : std_logic_vector(139 downto 0)  := (others => '0');
  signal s_reconfig_from_xcvr : std_logic_vector(91 downto 0)   := (others => '0');
  signal s_tx_parallel_data   : std_logic_vector(31 downto 0)   := (others => '0');
  signal s_tx_datak           : std_logic_vector(3 downto 0)    := (others => '0');
  
-------------------------------------------------------------------------------
------ Architecture begin -----------------------------------------------------
begin

-------------------------------------------------------------------------------
------ XCVR TX entity ---------------------------------------------------------

  INST_XCVR_TX: XCVR_TX
    port map(
      pll_powerdown           => s_pll_powerdown,
      tx_analogreset          => s_tx_analogreset,
      tx_digitalreset         => s_tx_digitalreset,
      tx_pll_refclk           => REF_CLK,
      tx_serial_data          => XCVR_TX_serial_data_o,
      pll_locked              => s_pll_locked,
      tx_std_coreclkin        => s_tx_std_clk,
      tx_std_clkout           => s_tx_std_clk,
      tx_cal_busy             => s_tx_cal_busy,
      reconfig_to_xcvr        => s_reconfig_to_xcvr,
      reconfig_from_xcvr      => s_reconfig_from_xcvr,
      tx_parallel_data        => XCVR_TX_parallel_data_i,
      tx_datak                => s_tx_datak,
      unused_tx_parallel_data => (others => '0')
    );

-------------------------------------------------------------------------------
------ XCVR Reset control -----------------------------------------------------

  INST_RST_TX: XCVR_RST_CTRL
    port map (
      clock              => MGMT_CLK,
      reset              => s_xcvr_rst,
      pll_powerdown      => s_pll_powerdown,
      tx_analogreset     => s_tx_analogreset,
      tx_digitalreset    => s_tx_digitalreset,
      tx_ready           => open,
      pll_locked         => s_pll_locked,
      pll_select         => (others => '0'),
      tx_cal_busy        => s_tx_cal_busy              
    );

-------------------------------------------------------------------------------
------ XCVR reconfiguration control -------------------------------------------

  INST_RECFG_XCVR : XCVR_RECFG_CTRL
    port map (
      reconfig_busy             => open, 
      mgmt_clk_clk              => MGMT_CLK, 
      mgmt_rst_reset            => s_xcvr_rst, 
      reconfig_mgmt_address     => (others => '0'),
      reconfig_mgmt_read        => '0',
      reconfig_mgmt_readdata    => open, 
      reconfig_mgmt_waitrequest => open, 
      reconfig_mgmt_write       => '0', 
      reconfig_mgmt_writedata   => (others => '0'),
      reconfig_to_xcvr          => s_reconfig_to_xcvr,
      reconfig_from_xcvr        => s_reconfig_from_xcvr
    ); 

-------------------------------------------------------------------------------
------ Reset and other signals ------------------------------------------------

  process (MGMT_CLK, ARST)
  begin
    if ARST = '1' then
      s_scvr_rst_cnt <= x"0";
    elsif rising_edge(MGMT_CLK) then
      if s_scvr_rst_cnt < x"C" then
        s_scvr_rst_cnt <= s_scvr_rst_cnt  + 1;
      end if;
    end if;
  end process; 

  s_xcvr_rst  <= '1' when s_scvr_rst_cnt > x"5" and s_scvr_rst_cnt < x"9" else '0';

  XCVR_TX_parallel_clk_o  <= s_tx_std_clk; 

  s_tx_datak <= "0001" when XCVR_TX_parallel_data_i = X"C5C5C5BC" else "0000" ;

  -- s_tx_datak is data/control indicator of the byte sent. 
  -- "0" means data; "1" means control.
  -- x"C5BCC5BC" and "0101" for 2-bytes alignment
  -- x"C5C5C5BC" and "0001" for 4-bytes alignment

end architecture;
