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
		
--
-- wifiESP8266next.vhd
--   WiFi to Serial Module ESP2866 and UART to interface with it
--   Revision 1.02
--
-- 1.01 - Fixed reading of 06 and 07 not returning the real data but the previous latched data
--      - Fixed received 06 command not being executed until a next command was received
-- 1.02 - Added possibility of activating interrupts (CMD 21) and deactivating it (CMD 22)
--        Default is off as if no one services the interrupt, it won't clear and z80 will
--        lock executing the interrupt routine.xecuted until a next command was received
-- 1.03 - Changed Available Baud Rate List, adding 859372 BPS as 0 (maximum), 346520 BPS as 1
--        and 230400 as 2, removed 2400bps options. Removed interrupt support, not needed for
--        UNAPI ESP firmware, so let's not waste cells and use them for other hardware! :-)
--
-- Copyright (c) 2019 Oduvaldo Pavan Junior ( ducasp@ gmail.com )
-- Based on Victor Trucco Spectrum Next WiFi interface
-- All rights reserved.
--
-- Redistribution and use of this source code or any derivative works, are
-- permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice,
--    this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
-- 3. Redistributions may not be sold, nor may they be used in a commercial
--    product or activity without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
-- "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
-- TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
-- CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
-- EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
-- PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
-- OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
-- WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
-- OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
-- ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-- Address 0x07 send to tx uart buffer or read to get uart status
--
-- Address 0x06 send to set UART speed or read to get uart rx buffer
--
-- 0x06 Address Write commands:
--
-- 0 - UART 859372 bps
-- 1 - UART 346520 bps
-- 2 - UART 231014 bps
-- 3 - UART 115200 bps
-- 4 - UART 57600 bps
-- 5 - UART 38400 bps
-- 6 - UART 31250 bps
-- 7 - UART 19200 bps
-- 8 - UART 9600 bps
-- 9 - UART 4800 bps
-- 20 - Clear FIFO buffer
--
-- 0x07 Address Uart Status bits:
--
-- bit 0 - does fifo rx buffer have data?
-- bit 1 - is data transmission in progress?
-- bit 2 - is fifo rx buffer full?
-- bit 6 - 0 if in interrupt with 128 bytes of data or more, 1 if free (avoid open bus confusion)
-- bit 7 - 0 if in interrupt, 1 if free (avoid open bus confusion)

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.std_logic_unsigned.all;
    use ieee.numeric_std.ALL;

entity wifi is
    port(
        clk_i       : in    std_logic;
        wait_o      : out   std_logic := '1';
        reset_i     : in    std_logic;
        iorq_i      : in    std_logic;
        wrt_i       : in    std_logic;
        rd_i        : in    std_logic;
        tx_i        : in    std_logic;
        rx_o        : out   std_logic;
        adr_i       : in    std_logic_vector( 15 downto 0 );
        db_i        : in    std_logic_vector(  7 downto 0 );
        db_o        : out   std_logic_vector(  7 downto 0 ) := (others => 'Z')
    );
end wifi;

architecture Behavior of wifi is

-- TYPES for state machine of each part of the design
type    tx_states   is (STATE_TX_IDLE, STATE_TX_DATA, STATE_TX_FINISH);
type    cmd_states  is (STATE_CMD_IDLE, STATE_CMD_DATA, STATE_CMD_FINISH);
type    rx_states   is (STATE_RX_IDLE, STATE_RX_DATA, STATE_RX_WAITDATA, STATE_RX_FINISH);

-- UART TX operations
signal  my_tx_state         : tx_states := STATE_TX_IDLE;
signal  uart_tx_o           : std_logic := '0';
signal  uart_tx_active_i    : std_logic;
signal  out_tx_data         : std_logic_vector(7 downto 0) := (others => '0');

-- UART RX operations
signal  my_rx_state         : rx_states := STATE_RX_IDLE;
signal  rx_byte_finished    : std_logic;
signal  in_rx_data          : std_logic_vector(7 downto 0) := (others => '0');

-- I/O CMD Port -> WR
signal  my_cmd_state        : cmd_states := STATE_CMD_IDLE;
signal  out_uart_status     : std_logic_vector(7 downto 0) := (others => '0');

-- FIFO operations
signal  reset_fifo          : std_logic := '0';
signal  fifo_empty          : std_logic;
signal  fifo_full_status    : std_logic;
signal  fifo_read           : std_logic := '0';
signal  fifo_data_out       : std_logic_vector (7 downto 0);
signal  fifo_we             : std_logic := '0';
signal  fifo_data_in        : std_logic_vector (7 downto 0);

-- I/O port selection
signal  address_06          : STD_LOGIC := '1';
signal  address_07          : STD_LOGIC := '1';
signal  select_06w          : STD_LOGIC := '1';
signal  select_06r          : STD_LOGIC := '1';
signal  select_07w          : STD_LOGIC := '1';
signal  select_07r          : STD_LOGIC := '1';

-- ticks_per_bit_i = (clock)/(bauds)
-- 21484300 / 115200 = 186.49   =  115200 bps
-- 21484300 / 231014 = 92.99    =  231014 bps
-- 21484300 / 346520 = 62.00    =  346520 bps
-- 21484300 / 596786 = 36.00    =  596786 bps
-- 21484300 / 859372 = 25.00    =  859372 bps

signal  prescaler_i_s       : std_logic_vector(13 downto 0) := std_logic_vector( to_unsigned(25, 14) );

begin

    U1 : work.UART
    port map
    (
        uart_prescaler_i    => prescaler_i_s,
        TX_start_i          => uart_tx_o,
        TX_byte_i           => out_tx_data,
        TX_active_o         => uart_tx_active_i,
        RX_byte_finished_o  => rx_byte_finished,
        RX_byte_o           => in_rx_data,
        TX_out_o            => rx_o,
        RX_in_i             => tx_i,
        clock_i             => clk_i
    );

    U2 : work.FIFO
    generic map
    (
        FIFO_DEPTH          => 2080
    )
    port map
    (
        clock_i             => clk_i,
        fifo_empty_o        => fifo_empty,
        fifo_read_i         => fifo_read,
        fifo_data_o         => fifo_data_out,
        fifo_data_i         => fifo_data_in,
        fifo_we_i           => fifo_we,
        fifo_full_o         => fifo_full_status,
        reset_i             => reset_fifo
    );

    address_06  <= '0' when adr_i (7 downto 0) = x"06" else '1';
    address_07  <= '0' when adr_i (7 downto 0) = x"07" else '1';
    select_06w  <= ( address_06 or ( wrt_i ) or ( iorq_i ) );
    select_06r  <= ( address_06 or ( rd_i ) or ( iorq_i ) );
    select_07w  <= ( address_07 or ( wrt_i ) or ( iorq_i ) );
    select_07r  <= ( address_07 or ( rd_i ) or ( iorq_i ) );

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            -- RESET of cartridge
            if (reset_i = '0') then
                fifo_we         <= '0';
                my_tx_state     <= STATE_TX_IDLE;
                my_rx_state     <= STATE_RX_IDLE;
                my_cmd_state    <= STATE_CMD_IDLE;
                reset_fifo      <= '1';
                out_uart_status(6) <= '1';
                out_uart_status(7) <= '1';
            else
                -- If not in RESET, make sure to release FIFO reset
                reset_fifo <= '0';

                -- If UART received a byte, let's push it into the FIFO
                if (rx_byte_finished = '1') then
                    -- UART received a byte, let's push it to the FIFO
                    fifo_data_in <= in_rx_data;
                    fifo_we <= '1';
                else
                    -- Otherwise just clear the WE so it doesn't push it again
                    fifo_we <= '0';
                end if;

                -- Z80 I/O write Cycle
                -- IORQ goes low as well as WR, Data is available in the Data BUS for at least the next two Z80 clock ticks
                -- Device can assert WAIT to 0 while it is not done and data will still be available
                -- After WAIT goes back to 1, IORQ will go to high during next clock cycle and transfer is done

                -- &H07 -> WR (data being pushed to the UART)
                -- What we are doing:
                --  - Receive data and copy it to a signal linked to the UART TX input, signal UART to transfer, assert WAIT
                --  - Wait UART to signal starting to send data, clear the UART signal to transfer (no longer needed)
                --  - Once transfer is no longer in progress, put WAIT back in open state and stay put until the IORQ
                --    or WR or Address 07 is taken out of the bus, then go back to IDLE (avoid re-sending the same byte)

                if (select_07w = '0') then
                    case my_tx_state is
                        -- First step: get the data that should be sent
                        when STATE_TX_IDLE =>
                            -- Assert wait until uart TX is done
                            wait_o <= '0';
                            if ( uart_tx_active_i = '0' ) then
                                -- Copy the data to the UART tx Data signal
                                out_tx_data <= db_i;
                                -- Signal UART that it should start transferring data
                                uart_tx_o <= '1';
                                -- Ready for the next state
                                my_tx_state <= STATE_TX_DATA;
                            end if;
                        -- Second step, guarantee UART get our command, wait one clock
                        when STATE_TX_DATA =>
                                -- UART got our command, Ready for the next state
                                my_tx_state <= STATE_TX_FINISH;

                        -- Final step:
                        when STATE_TX_FINISH =>
                            uart_tx_o <= '0';
                            wait_o <= '1';
                            -- We will get out of here as Z80 will set IORQ/WR indicating it is done, leaving the select 07w set to 1

                        when others =>
                                -- Real bad, stop everything
                                my_tx_state <= STATE_TX_IDLE;
                                wait_o <= '1';
                                uart_tx_o <= '0';

                    end case;

                -- Z80 I/O write Cycle
                -- IORQ goes low as well as WR, Data is available in the Data BUS for at least the next two Z80 clock ticks
                -- Device can assert WAIT to 0 while it is not done and data will still be available
                -- After WAIT goes back to 1, IORQ will go to high during next clock cycle and transfer is done
                -- &H06 -> WR (command being pushed to the cartridge)

                elsif (select_06w = '0') then
                    case my_cmd_state is
                        -- First step - check a received command
                        when STATE_CMD_IDLE =>
                            -- Assert wait just in case Z80 is faster than us (shouldn't really be anyway)
                            wait_o <= '0';

                            -- If command is 0 (859372BPS)
                            if ( unsigned(db_i) = 0 ) then
                                -- 21484300 / 859372 = 25.00
                                -- set prescaler
                                prescaler_i_s <= std_logic_vector( to_unsigned(25, prescaler_i_s'length) );
                                -- Nothing else to do
                                my_cmd_state <= STATE_CMD_FINISH;

                            -- If command is 1 (346520BPS)
                            elsif ( unsigned(db_i) = 1 ) then
                                -- 21484300 / 346520 = 62.00
                                -- set prescaler
                                prescaler_i_s <= std_logic_vector( to_unsigned(62, prescaler_i_s'length) );
                                -- Nothing else to do
                                my_cmd_state <= STATE_CMD_FINISH;

                            -- If command is 2 (231014BPS)
                            elsif ( unsigned(db_i) = 2 ) then
                                -- 21484300 / 231014 = 92.99
                                -- set prescaler
                                prescaler_i_s <= std_logic_vector( to_unsigned(93, prescaler_i_s'length) );
                                -- Nothing else to do
                                my_cmd_state <= STATE_CMD_FINISH;


                            -- If command is 3 (115200BPS)
                            elsif ( unsigned(db_i) = 3 ) then
                                -- 21484300 / 115200 = 186.49    =  115200 bps
                                -- set prescaler
                                prescaler_i_s <= std_logic_vector( to_unsigned(186, prescaler_i_s'length) );
                                -- Nothing else to do
                                my_cmd_state <= STATE_CMD_FINISH;

                            -- If command is 4 (57600BPS)
                            elsif ( unsigned(db_i) = 4 ) then
                                -- 21484300 / 57600 = 372.99    =  57600 bps
                                -- set prescaler
                                prescaler_i_s <= std_logic_vector( to_unsigned(373, prescaler_i_s'length) );
                                -- Nothing else to do
                                my_cmd_state <= STATE_CMD_FINISH;

                            -- If command is 5 (38400BPS)
                            elsif ( unsigned(db_i) = 5 ) then
                                -- 21484300 / 38400 = 559.48    =  38400 bps
                                -- set prescaler
                                prescaler_i_s <= std_logic_vector( to_unsigned(559, prescaler_i_s'length) );
                                -- Nothing else to do
                                my_cmd_state <= STATE_CMD_FINISH;

                            -- If command is 6 (31250BPS)
                            elsif ( unsigned(db_i) = 6 ) then
                                -- 21484300 / 31250 = 687.49    =  31250 bps
                                -- set prescaler
                                prescaler_i_s <= std_logic_vector( to_unsigned(688, prescaler_i_s'length) );
                                -- Nothing else to do
                                my_cmd_state <= STATE_CMD_FINISH;

                            -- If command is 7 (19200BPS)
                            elsif ( unsigned(db_i) = 7 ) then
                                -- 21484300 / 19200 = 1118.97    =  19200 bps
                                -- set prescaler
                                prescaler_i_s <= std_logic_vector( to_unsigned(1119, prescaler_i_s'length) );
                                -- Nothing else to do
                                my_cmd_state <= STATE_CMD_FINISH;

                            -- If command is 8 (9600BPS)
                            elsif ( unsigned(db_i) = 8 ) then
                                -- 21484300 / 9600 = 2237.94    =  9600 bps
                                -- set prescaler
                                prescaler_i_s <= std_logic_vector( to_unsigned(2238, prescaler_i_s'length) );
                                -- Nothing else to do
                                my_cmd_state <= STATE_CMD_FINISH;

                            -- If command is 9 (4800BPS)
                            elsif ( unsigned(db_i) = 9 ) then
                                -- 21484300 / 4800 = 4475.89    =  4800 bps
                                -- set prescaler
                                prescaler_i_s <= std_logic_vector( to_unsigned(4476, prescaler_i_s'length) );
                                -- Nothing else to do
                                my_cmd_state <= STATE_CMD_FINISH;

                            -- If command is 20 (clear buffer)
                            elsif ( unsigned(db_i) = 20 ) then
                                -- Reset FIFO
                                reset_fifo <= '1';
                                -- Nothing else to do
                                my_cmd_state <= STATE_CMD_FINISH;

                            -- Other command
                            else
                                -- Ignore any other command, nothing else to do
                                my_cmd_state <= STATE_CMD_FINISH;
                            end if;

                        -- Just wait the I/O write cycle finish
                        when STATE_CMD_FINISH =>
                            -- Done, so Z80 is clear to run
                            wait_o <= '1';
                            -- We will get out of here as Z80 will set IORQ/WR indicating it is done, leaving the select 06 set to 1

                        when others =>
                                -- Real bad, stop everything
                                my_tx_state <= STATE_TX_IDLE;
                                reset_fifo <= '0';
                                wait_o <= '1';

                    end case;

                -- Z80 I/O read Cycle
                -- IORQ goes low as well as RD, Data must be available in the Data BUS after two Z80 clock ticks
                -- and until RD goes back to high.
                -- Device can assert WAIT to 0 while it has not put the data in the data bus.
                -- After WAIT goes back to 1, IORQ and RD will go to high during next cpu clock cycle and transfer is done
                --
                -- Get FIFO/UART status

                elsif (select_07r = '0') then
                    case my_rx_state is
                        -- First step: get the data that should be sent
                        when STATE_RX_IDLE =>
                            wait_o <= '0';
                            -- bit 0 - fifo empty?
                            if ( fifo_empty = '1' ) then
                                out_uart_status(0) <= '0';
                            else
                                out_uart_status(0) <= '1';
                            end if;

                            -- bit 1 - tx in progress?
                            if ( uart_tx_active_i = '0' ) then
                                out_uart_status(1) <= '0';
                            else
                                out_uart_status(1) <= '1';
                            end if;

                            -- bit 2 - fifo full?
                            if ( fifo_full_status = '0' ) then
                                out_uart_status(2) <= '0';
                            else
                                out_uart_status(2) <= '1';
                            end if;

                            -- Nothing else to do
                            my_rx_state <= STATE_RX_FINISH;

                        when STATE_RX_FINISH =>
                            -- move the uart status to the bus
                            db_o <= out_uart_status;
                            -- Done, so Z80 is clear to run
                            wait_o <= '1';
                            -- We will get out of here as Z80 will set IORQ/RD indicating it is done, leaving the select 07r set to 1

                        when others =>
                            -- Real bad, stop everything
                            my_rx_state <= STATE_RX_IDLE;
                            wait_o <= '1';
                    end case;

                -- Z80 I/O read Cycle
                -- IORQ goes low as well as RD, Data must be available in the Data BUS after two Z80 clock ticks
                -- and until RD goes back to high.
                -- Device can assert WAIT to 0 while it has not put the data in the data bus.
                -- After WAIT goes back to 1, IORQ and RD will go to high during next cpu clock cycle and transfer is done
                --
                -- Get a byte out of fifo

                elsif (select_06r = '0') then
                    case my_rx_state is
                        -- First step: get the data that should be sent
                        when STATE_RX_IDLE =>
                            -- Assert wait just in case Z80 is faster than us (shouldn't really be anyway)
                            wait_o <= '0';
                            if ( fifo_empty = '1' ) then
                                -- What? No fifo data, let's just return FF
                                db_o <= "11111111";
                                -- Nothing else to do
                                my_rx_state <= STATE_RX_FINISH;
                            else
                                -- Ok, need to pop a byte out of FIFO
                                fifo_read <= '1';
                                -- Next step: wait FIFO data and move to the bus
                                my_rx_state <= STATE_RX_WAITDATA;
                            end if;

                        -- This clock cycle FIFO will get our command, so the next one the data will be there
                        when STATE_RX_WAITDATA =>
                            my_rx_state <= STATE_RX_DATA;

                        -- Get the data and clear the command
                        when STATE_RX_DATA =>
                            -- Let's clear this so FIFO won't POP data again
                            fifo_read <= '0';
                            -- Nothing else to do
                            my_rx_state <= STATE_RX_FINISH;

                        when STATE_RX_FINISH =>
                            -- Move the data from FIFO to data bus
                            db_o <= fifo_data_out;
                            -- Done, so Z80 is clear to run
                            wait_o <= '1';
                            -- We will get out of here as Z80 will set IORQ/RD indicating it is done, leaving the select 07r set to 1

                        when others =>
                            -- Real bad, stop everything
                            my_rx_state <= STATE_RX_IDLE;
                            wait_o <= '1';
                            fifo_read <= '0';
                    end case;

                else -- idling, or, end of I/O, be it read or write, will alway access this condition
                    my_tx_state <= STATE_TX_IDLE;
                    my_rx_state <= STATE_RX_IDLE;
                    my_cmd_state <= STATE_CMD_IDLE;
                    wait_o <= '1';
                end if;
            end if;
        end if;
    end process;

end Behavior;
