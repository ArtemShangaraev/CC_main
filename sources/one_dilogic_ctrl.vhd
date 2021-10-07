-------------------------------------------------------------------------------
-- Title      : One Dilogic control
-- Project    : Column Controller CPV
-------------------------------------------------------------------------------
-- File       : one_dilogic_ctrl.vhd
-- Author     : Artem Shangaraev <artem.shangaraev@cern.ch>
-- Company    : NRC "Kurchatov institute" - IHEP
-- Created    : 2020-02-18
-- Last update: 2021-04-09
-- Platform   : Quartus Prime 18.1.0
-- Target     : Cyclone V GX
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Read FIFO of 5-Dilogic card.
--              Reset FIFO or daisy chain.
--              Load thresholds to the Dilogic memory or read it back.
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CERN
-------------------------------------------------------------------------------

Library IEEE;
Use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity one_dilogic_ctrl is
  port (
    ARST              : in  std_logic;
    
    -- 10M clock domain
    CLK               : in  std_logic;
    FCODE_i           : in  std_logic_vector(3 downto 0);
    RDY_o             : out std_logic;
    SYNC_i            : in  std_logic;
    TIMEOUT_i         : in  std_logic;
    
    -- Dilogic connection
    RST_o             : out std_logic;
    STRIN_o           : out std_logic;
    ENIN_N_o          : out std_logic;
    ENOUT_N_i         : in  std_logic_vector(4 downto 0);
    DIL_ID_o          : out std_logic_vector(2 downto 0);
    DATA_FROM_DIL_i   : in  std_logic_vector(17 downto 0);
    DATA_TO_DIL_o     : out std_logic_vector(17 downto 0);
    THR_TO_DIL_i      : in  std_logic_vector(17 downto 0);
    DATA_TO_FABRIC_o  : out std_logic_vector(17 downto 0);
    DATA_RDY_o        : out std_logic
  );
end entity;


architecture beh of one_dilogic_ctrl is

-------------------------------------------------------------------------------
------ Component declaration --------------------------------------------------

-------------------------------------------------------------------------------
------ Signal declaration -----------------------------------------------------

--  Reminder of FCODE:
--  TEST_MODE    = b"0000";
--  LOAD_ALMFULL = b"0001";
--  IDLE         = b"0010";
--  PATTERN_READ = b"1000";
--  PATTERN_DEL  = b"1001";
--  ANALOG_READ  = b"1010";
--  ANALOG_DEL   = b"1011";
--  RESET_FIFO   = b"1100";
--  RESET_CHAIN  = b"1101";
--  CONFIG_WRITE = b"1110";
--  CONFIG_READ  = b"1111";
  
  type t_dil_fsm is (
    Reset,
    Idle,
    Test_mode,
    Load_almfull,
    Pattern_del,
    Analog_del,
    Set_enin,
    Set_strin,
    Wait_5_enout,
    Process_end,
    Wait_sync,
    Rst_start,
    Rst_hold,
    Rst_end
  );
  signal st_dil: t_dil_fsm := Reset;

  signal s_clk_ena        : std_logic := '0';
  signal s_data_to_dil    : std_logic_vector (17 downto 0) := (others => '0');
  signal s_data_from_dil  : std_logic_vector (17 downto 0) := (others => '0');
  
  signal i_dil_cnt        : natural range 0 to 7 := 0;
  
-------------------------------------------------------------------------------
------ Architecture begin -----------------------------------------------------
begin

  DATA_TO_DIL_o     <= THR_TO_DIL_i;
  s_data_from_dil   <= DATA_FROM_DIL_i;
  DATA_TO_FABRIC_o  <= s_data_from_dil;

  ENIN_N_o          <= '0' when st_dil = Set_strin
                             or st_dil = Wait_5_enout
                             or st_dil = Process_end
                           else '1';
  STRIN_o           <= CLK when s_clk_ena = '1' else '1';
  RST_o             <= '1' when arst = '1' else '0';
  
  DIL_ID_o          <= std_logic_vector(to_unsigned(i_dil_cnt,3));
  
  DATA_RDY_o        <= ENOUT_N_i(4) when (st_dil = Wait_5_enout and FCODE_i /= x"E") else '0';
  
  RDY_o             <= '1' when  st_dil = Wait_sync else '0';
  
-------------------------------------------------------------------------------
------ Dilogic card FSM -------------------------------------------------------

  DILOGIC_FSM: process (CLK, arst)
  
  variable v_dil_cnt        : natural range 0 to 7 := 0;
  
  begin
    if arst = '1' then
      v_dil_cnt       := 0;
      st_dil          <= Reset;
      
    elsif rising_edge(CLK) then
      
      case st_dil is
        when Reset =>
          st_dil <= Idle;
          
        when Idle =>
          v_dil_cnt   := 0;
          case FCODE_i is
            when x"0" =>
              st_dil  <= Test_mode;
            when x"1" =>
              st_dil  <= Load_almfull;
            when x"8" =>
              st_dil  <= Set_enin;
            when x"9" =>
              st_dil  <= Pattern_del;
            when x"A" =>
              st_dil  <= Set_enin;
            when x"B" =>
              st_dil  <= Analog_del;
            when x"C" =>
              st_dil  <= Rst_start;
            when x"D" =>
              st_dil  <= Rst_start;
            when x"E" =>
              st_dil  <= Set_enin;
            when x"F" =>
              st_dil  <= Set_enin;
            when others =>
              null;
          end case;
          
-------------------------------------------------------------------------------
------ Analog read, Pattern read, Config read or Config write subFSM ----------
        
        when Set_enin =>
          st_dil      <= Set_strin;
        
        when Set_strin =>
          s_clk_ena   <= '1';
          st_dil      <= Wait_5_enout;
        
        when Wait_5_enout =>
          if TIMEOUT_i   = '1' then 
            st_dil      <= Process_end;
          elsif v_dil_cnt < 5 then
            if ENOUT_N_i(v_dil_cnt) = '0' then
              v_dil_cnt := v_dil_cnt + 1;
            end if;
          else
            v_dil_cnt   := 0;
            st_dil      <= Process_end;
          end if;
        
        when Process_end =>
          v_dil_cnt     := 0;
          s_clk_ena     <= '0';
          st_dil        <= Wait_sync;
        
        when Wait_sync =>
          if SYNC_i   = '1' then 
            st_dil      <= Idle;
          end if;
        
-------------------------------------------------------------------------------
------ Reset FIFO pointer or Reset daisy chain subFSM -------------------------
        
        when Rst_start =>
          s_clk_ena   <= '1';
          st_dil      <= Rst_hold;
        
        when Rst_hold =>
          s_clk_ena   <= '1';
          st_dil      <= Rst_end;
        
        when Rst_end =>
          s_clk_ena   <= '0';
          st_dil      <= Idle;
        
        when others =>
          st_dil      <= Idle;    -- return to idle from any unexpected state
      end case;
    end if;
    
    i_dil_cnt   <= v_dil_cnt;
    
  end process;
  
end architecture;
