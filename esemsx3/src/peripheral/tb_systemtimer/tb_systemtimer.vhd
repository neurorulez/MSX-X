--
-- Multicore 2 / Multicore 2+
--
-- Copyright (c) 2017-2020 - Victor Trucco
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS CODE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- You are responsible for any legal issues arising from your use of this code.
--
		
-- --------------------------------------------------------- --
--  system timer test bench                                  --
-- ========================================================= --
--  Copyright (c)2006 t.hara                                 --
-- --------------------------------------------------------- --

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.std_logic_unsigned.all;

entity tb is
end tb;

architecture behavior of tb is

    -- test target
    component system_timer
        port(
            clk21m  : in    std_logic;
            reset   : in    std_logic;
            req     : in    std_logic;
            ack     : out   std_logic;
            wrt     : in    std_logic;
            adr     : in    std_logic_vector( 15 downto 0 );
            dbi     : out   std_logic_vector(  7 downto 0 );
            dbo     : in    std_logic_vector(  7 downto 0 )
        );
    end component;

    constant CYCLE : time := 10 ns;

    signal  clk21m  : std_logic;
    signal  reset   : std_logic;
    signal  req     : std_logic;
    signal  ack     : std_logic;
    signal  wrt     : std_logic;
    signal  adr     : std_logic_vector(15 downto 0);
    signal  dbi     : std_logic_vector(7 downto 0);
    signal  dbo     : std_logic_vector(7 downto 0);

    signal  tb_end  : std_logic := '0';
begin

    --  instance
    u_target: system_timer
    port map(
        clk21m  => clk21m   ,
        reset   => reset    ,
        req     => req      ,
        ack     => ack      ,
        wrt     => wrt      ,
        adr     => adr      ,
        dbi     => dbi      ,
        dbo     => dbo
    );

    -- ----------------------------------------------------- --
    --  clock generator                                      --
    -- ----------------------------------------------------- --
    process
    begin
        if( tb_end = '1' )then
            wait;
        end if;
        clk21m <= '0';
        wait for 5 ns;
        clk21m <= '1';
        wait for 5 ns;
    end process;

    -- ----------------------------------------------------- --
    --  test bench                                           --
    -- ----------------------------------------------------- --
    process
    begin
        -- init
        req     <= '0';
        wrt     <= '0';
        adr     <= (others => '0');
        dbo     <= (others => '0');

        -- reset
        reset   <= '1';
        wait until( clk21m'event and clk21m = '1' );
        reset   <= '0';
        wait until( clk21m'event and clk21m = '1' );

        -- read E6h
        adr     <= "0000000011100110";
        req     <= '1';
        wrt     <= '0';
        wait until( clk21m'event and clk21m = '1' );

        req     <= '0';
        wrt     <= '0';
        wait until( clk21m'event and clk21m = '1' );

        -- read E7h
        adr     <= "0000000011100111";
        req     <= '1';
        wrt     <= '0';
        wait until( clk21m'event and clk21m = '1' );

        req     <= '0';
        wrt     <= '0';
        wait until( clk21m'event and clk21m = '1' );

        for i in 0 to 10 loop
            wait until( clk21m'event and clk21m = '1' );
        end loop;

        -- write E6h
        adr     <= "0000000011100110";
        req     <= '1';
        wrt     <= '1';
        dbo     <= "01010101";
        wait until( clk21m'event and clk21m = '1' );

        req     <= '0';
        wrt     <= '0';
        dbo     <= "00000000";
        wait until( clk21m'event and clk21m = '1' );

        for i in 0 to 10 loop
            wait until( clk21m'event and clk21m = '1' );
        end loop;

        -- write E7h
        adr     <= "0000000011100111";
        req     <= '1';
        wrt     <= '1';
        dbo     <= "00010010";
        wait until( clk21m'event and clk21m = '1' );

        req     <= '0';
        wrt     <= '0';
        dbo     <= "00000000";
        wait until( clk21m'event and clk21m = '1' );

        for i in 0 to 10 loop
            wait until( clk21m'event and clk21m = '1' );
        end loop;

        -- wait
        tb_end <= '1';
        wait;
    end process;

end behavior;
