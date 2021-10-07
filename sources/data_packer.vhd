-------------------------------------------------------------------------------
-- Title      : Data packer
-- Project    : Column Controller CPV
-------------------------------------------------------------------------------
-- File       : data_packer.vhd
-- Author     : Artem Shangaraev  <artem.shangaraev@cern.ch>
-- Company    : CERN
-- Created    : 2020-02-13
-- Last update: 2021-04-14
-- Platform   : Quartus Prime 18.1.0
-- Target     : Cyclone V GX
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Multiplexer to send data from 4 Dilogic cards to XCVR.
--              There is a FIFO for each card with different read/write clock.
--              Round-robin reading of FIFOs with instant reading, 
--              registering data and valid-acknowledge handshake process.
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CERN
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity data_packager is
  port (
    arst        : in  std_logic;
    
    -- 10M clock domain
    CLK_DIL     : in  std_logic;
    DATA_i      : in  std_logic_vector(127 downto 0);
    DATA_RDY_i  : in  std_logic_vector(3 downto 0);
    CTRL_i      : in  std_logic_vector(31 downto 0);
    
    -- XCVR interface, GTX parallel clock domain
    CLK_XCVR    : in  std_logic;
    DATA_o      : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of data_packager is

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
  
  signal s_ctrl_in      : std_logic_vector (31 downto 0)  := (others => '1');
  signal s_ctrl_reg     : std_logic_vector (31 downto 0)  := (others => '1');
  signal s_ctrl_out     : std_logic_vector (31 downto 0)  := (others => '1');
  
  signal s_data_in      : std_logic_vector (127 downto 0) := (others => '0');
  signal s_wrreq        : std_logic_vector (3 downto 0)   := x"0";
  signal s_wrfull       : std_logic_vector (3 downto 0)   := x"0";
  
  signal s_rdempty      : std_logic_vector (3 downto 0)   := x"0";
  signal s_rdreq        : std_logic_vector (3 downto 0)   := x"0";
  signal s_fifo_out     : std_logic_vector (127 downto 0) := (others => '0');
  signal s_data_valid   : std_logic_vector (3 downto 0)   := x"0";
  signal s_valid_ack    : std_logic_vector (3 downto 0)   := x"0";
  signal s_data_reg     : std_logic_vector (127 downto 0) := (others => '0');
  signal s_data_out     : std_logic_vector (31 downto 0)  := (others => '0');
  
  signal s_fifo_num     : natural range 0 to 3 := 0;

-------------------------------------------------------------------------------
------ Architecture begin -----------------------------------------------------
begin

  s_data_in <= DATA_i;
  DATA_o    <= s_data_out;

-------------------------------------------------------------------------------
------ CDC fo control words ---------------------------------------------------

  CDC_CTRL_INST: process(CLK_XCVR, arst)
  begin
    if arst = '1' then
      s_ctrl_in     <= (others => '1');
      s_ctrl_reg    <= (others => '1');
      s_ctrl_out    <= (others => '1');
    elsif rising_edge(CLK_XCVR) then
      s_ctrl_in     <= CTRL_i;
      s_ctrl_reg    <= s_ctrl_in;
      if s_ctrl_reg /= s_ctrl_in then
        s_ctrl_out  <= s_ctrl_in;
      else
        s_ctrl_out  <= (others => '1');
      end if;
    end if;
  end process CDC_CTRL_INST;
  
-------------------------------------------------------------------------------
------ Generate 4 FIFO for datapath -------------------------------------------

  INST_DATAPATH_FIFO_GEN : for i in 0 to 3 generate
  
    s_wrreq(i) <= DATA_RDY_i(i) and not s_wrfull(i);
    
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
        s_data_valid(i)                 <= '0';
        s_rdreq(i)                      <= '0';
        s_data_reg(32*i+31 downto 32*i) <= (others => '0');
      elsif falling_edge(CLK_XCVR) then
        s_rdreq(i)                      <= not s_rdempty(i);
        s_data_reg(32*i+31 downto 32*i) <= s_fifo_out(32*i+31 downto 32*i);
        
        if s_rdreq(i) = '1' then
          s_data_valid(i)               <= '1';
        elsif s_valid_ack(i) = '1' then
          s_data_valid(i)               <= '0';
        end if;
        
      end if;
    end process;
  
  end generate INST_DATAPATH_FIFO_GEN;
  
-------------------------------------------------------------------------------
------ Choose FIFO to read from -----------------------------------------------

  DATA_MUX: process(CLK_XCVR, arst) 
  begin
    if (arst = '1') then
      s_fifo_num      <= 0;
      s_valid_ack     <= (others => '0');
      s_data_out      <= (others => '0');
    elsif rising_edge(CLK_XCVR) then
    
      -- Control word has a priority
      if s_ctrl_out /= x"FFFFFFFF" then
        s_data_out    <= s_ctrl_out;
        s_valid_ack   <= (others => '0');
      else
        -- reset unused ACK signals
        s_valid_ack   <= (others => '0');
      
        if s_data_valid(s_fifo_num) = '1' then
          if s_fifo_num < 3 then
            s_fifo_num  <= s_fifo_num + 1;
          else
            s_fifo_num  <= 0;
          end if;
          s_valid_ack(s_fifo_num) <= '1';
          s_data_out              <= s_data_reg(32*s_fifo_num+31 downto 32*s_fifo_num);
          
        elsif s_data_valid /= "0000" then
          if s_fifo_num < 3 then
            s_fifo_num  <= s_fifo_num + 1;
          else
            s_fifo_num  <= 0;
          end if;
          s_data_out              <= x"C5C5C5BC";
          
        else
          s_data_out              <= x"C5C5C5BC";
        end if;
      end if;
    end if;
  end process;

end architecture;
