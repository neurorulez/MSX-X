/*

   Copyright (c) 2017-2020 - Victor Trucco

	Ported to Neptuno by NeuroRulez
	
   All rights reserved

   Redistribution and use in source and synthezised forms, with or without
   modification, are permitted provided that the following conditions are met:

   Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.

   Redistributions in synthesized form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

   Neither the name of the author nor the names of other contributors may
   be used to endorse or promote products derived from this software without
   specific prior written permission.

   THIS CODE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
   AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
   THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
   PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
   LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
   CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
   SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
   INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
   ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
   POSSIBILITY OF SUCH DAMAGE.

   You are responsible for any legal issues arising from your use of this code.

*///============================================================================
//  MSX top level for MiST
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================
//
//============================================================================
//
//  Multicore 2+ Top by Victor Trucco
//
//============================================================================

`default_nettype none

module MSX_X
(
    // Clocks
    input wire  CLOCK_50,

    // SDRAM (W9825G6KH-6)
    output [12:0] SDRAM_A,
    output  [1:0] SDRAM_BA,
    inout  [15:0] SDRAM_DQ,
    output        SDRAM_DQMH,
    output        SDRAM_DQML,
    output        SDRAM_CKE,
    output        SDRAM_nCS,
    output        SDRAM_nWE,
    output        SDRAM_nRAS,
    output        SDRAM_nCAS,
    output        SDRAM_CLK,

    // PS2
    inout wire  ps2_clk,
    inout wire  ps2_data,
    inout wire  ps2_mouse_clk,
    inout wire  ps2_mouse_data,

    // SD Card
    output wire sd_cs_n_o,
    output wire sd_sclk_o,
    output wire sd_mosi_o,
    input wire  sd_miso_i,

    // Joysticks
`ifndef JOYDC	 
    output wire JOY_CLK,
    output wire JOY_LOAD,
    input  wire JOY_DATA,
`else
	input	wire [5:0]joystick1,
	input	wire [5:0]joystick2,
`endif	
    output wire JOY_SELECT,

    // Audio
    output      AUDIO_L,
    output      AUDIO_R,
    input wire  EAR,

	 //AUDIO I2S
	 output wire	MCLK,
	 output wire	SCLK,
	 output wire	LRCLK,
	 output wire	SDIN,
	 
    // VGA
    output  [4:0] VGA_R,
    output  [4:0] VGA_G,
    output  [4:0] VGA_B,
    output        VGA_HS,
    output        VGA_VS,

	 
	 output wire VGA_BLANK, //Reloaded
	 output wire VGA_CLOCK, //Reloaded
	 
    //STM32
    output wire STM_RST,

    output LED

);


//---------------------------------------------------------
assign STM_RST = 1'b0;
assign VGA_BLANK = 1'b1;
assign VGA_CLOCK = clk_sys;


//-----------------------------------------------------------------

assign LED  = ~leds[0];
//assign LED  = mouse_strobe;

`include "build_id.v"
parameter CONF_STR = {
    "D,disable STM SD;",
    "OAB,Scanlines,Off,25%,50%,75%;",
    "OC,Blend,Off,On;",
    "O2,CPU Clock,Normal,Turbo;",
    "O3,Slot1,MegaSCC+ 1MB,Empty;",
    "O45,Slot2,MegaSCC+ 2MB,Empty,MegaRAM 2MB,MegaRAM 1MB;",
    "O6,RAM,2048kB,4096kB;",
    "OD,Slot 0,Expanded,Primary;",
    "O7,OPL3 sound,Yes,No;",
    "O9,Tape sound,Off,On;",
    "O1,Scandoubler,On,Off;",
    "OEF,Keymap,BR,EN,ES,FR;",
    "T0,Reset;",
    "V,v1.0.",`BUILD_DATE
};


////////////////////   CLOCKS   ///////////////////

wire pll_locked;
wire clk_sys;
wire memclk;

pll pll
(
    .inclk0(CLOCK_50),
    .c0(clk_sys),
    .c1(memclk),
    .c2(SDRAM_CLK),
    .locked(pll_locked)
);

//assign SDRAM_CLK = memclk;

//////////////////   MiST I/O   ///////////////////
wire  [1:0] buttons;
wire [31:0] status;
wire        ypbpr;

reg  [31:0] sd_lba;
reg         sd_rd = 0;
reg         sd_wr = 0;
wire        sd_conf;
wire        sd_ack;
wire        sd_ack_conf;
wire        sd_sdhc;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [31:0] img_size;

wire  [8:0] mouse_x;
wire  [8:0] mouse_y;
wire  [7:0] mouse_flags;
wire        mouse_strobe;

wire [63:0] rtc;

wire [5:0] audio_li;
wire [5:0] audio_ri;
wire [5:0] audio_l;
wire [5:0] audio_r;
wire [15:0] dac_out;

`ifndef JOYDC
wire [5:0] joya;
wire [5:0] joyb;
`else
wire [5:0] joya = ~joystick1;
wire [5:0] joyb = ~joystick2;
`endif

wire [5:0] msx_joya;
wire [5:0] msx_joyb;
wire       msx_stra;
wire       msx_strb;

wire       Sd_Ck;
wire       Sd_Cm;
wire [3:0] Sd_Dt;

reg  [7:0] dipsw;
wire [7:0] leds;

reg reset;
wire resetW = status[0];

reg [5:0] clock_div_q;

always @(posedge clk_sys) begin // Bit1: 0=VGA/1=RGB
    reset <= resetW;
    dipsw <= {1'b0,1'b0,2'b00,1'b0,1'b0,1'b0,1'b1};//{1'b0, ~status[6], ~status[5], status[4], status[3], ~status[1] & status[8], status[1], ~status[2]};
    audio_li <= audio_l;
    if (status[9]) begin
        audio_ri <= audio_r;
    end
        else audio_ri<= audio_l;

    if (reset)
        clock_div_q <= 6'd0;
    else
        clock_div_q <= clock_div_q + 6'd1;

end

wire [7:0]R_OSD,G_OSD,B_OSD;
wire host_scandoubler_disable;

data_io data_io
(
	.clk(clk_sys),
	.CLOCK_50(CLOCK_50), //Para modulos de I2s y Joystick
	
	.debug(),
	
	.reset_n(pll_locked),

	.vga_hsync(~HSync),
	.vga_vsync(~VSync),
	
	.red_i({R_O,2'b00}),
	.green_i({G_O,2'b00}),
	.blue_i({B_O,2'b00}),
	.red_o(R_OSD),
	.green_o(G_OSD),
	.blue_o(B_OSD),
	
	.ps2k_clk_in(ps2_clk),
	.ps2k_dat_in(ps2_data),
	
`ifndef JOYDC
	.JOY_CLK(JOY_CLK),
	.JOY_LOAD(JOY_LOAD),
	.JOY_DATA(JOY_DATA),
	.JOY_SELECT(JOY_SELECT),
	.joy1(joya),
	.joy2(joyb),
`endif
	.dac_MCLK(MCLK),
	.dac_LRCK(LRCLK),
	.dac_SCLK(SCLK),
	.dac_SDIN(SDIN),
	.L_data(dac_out),
	.R_data(dac_out),
	
	.status(status),

);
assign msx_joya = mouse_en ? /*(mouse ? 1'bZ : mouse)*/ mouse : (~joya & ~msx_stra ? joya : 1'bZ);
assign msx_joyb =                                     (~joyb & ~msx_strb ? joyb : 1'bZ);

//reg        mouse_en = 0;
wire       mouse_en;
reg  [5:0] mouse;
    
    
ps2mouse mousectrl
(
    .clk        ( clock_div_q[5] ),      //-- need a slower clock to avoid loosing data
    .reset      ( reset ), //-- slow reset signal
 
    .ps2mdat    ( ps2_mouse_data ), //  -- mouse PS/2 data
    .ps2mclk    ( ps2_mouse_clk ),  //      -- mouse PS/2 clk
 
    .xcount     ( mouse_x ),       //    -- mouse X counter      
    .ycount     ( mouse_y ),       //    -- mouse Y counter
    .zcount     (   ),   //-- mouse Z counter
    .mleft      ( mouse_flags[0] ),  //-- left mouse button output
    .mright     ( mouse_flags[1] ),  //-- right mouse button output
    .mthird     (                ),  //-- third(middle) mouse button output
   
    .sof        ( 1'b0 ),             //    -- mouse joystick emulation enable bit
    .mou_emu    ( 0 ),   //-- mouse with joystick input
    
    .test_load  ( 1'b0 ),            //        -- load test value to mouse counter
    .test_data  ( 0 ),  //  -- mouse counter test value
    .mouse_data_out ( mouse_strobe ) //-- mouse has data top present
);

always @(posedge clk_sys) begin

    reg        stra_d;
    reg  [7:0] mouse_x_latch;
    reg  [7:0] mouse_y_latch;
    reg  [1:0] mouse_state;
    reg [17:0] mouse_timeout;

    if (reset) begin
        mouse_en <= 0;
        mouse_state <= 0;
    end
    else if (mouse_strobe) mouse_en <= 1;
    else if (~&joya) mouse_en <= 0;

    if (mouse_strobe) begin
        mouse_x_latch <= mouse_x; //~mouse_x + 1'd1; //2nd complement of x
        mouse_y_latch <= mouse_y;
    end

    mouse[5:4] <= mouse_flags[1:0];
    if (mouse_en) begin
        if (mouse_timeout) begin
            mouse_timeout <= mouse_timeout - 1'd1;
            if (mouse_timeout == 1) mouse_state <= 0;
        end

        stra_d <= msx_stra;
        if (stra_d ^ msx_stra) begin
            mouse_timeout <= 18'd100000;
            mouse_state <= mouse_state + 1'd1;
            case (mouse_state)
            2'b00: mouse[3:0] <= {mouse_x_latch[4],mouse_x_latch[5],mouse_x_latch[6],mouse_x_latch[7]};
            2'b01: mouse[3:0] <= {mouse_x_latch[0],mouse_x_latch[1],mouse_x_latch[2],mouse_x_latch[3]};
            2'b10: mouse[3:0] <= {mouse_y_latch[4],mouse_y_latch[5],mouse_y_latch[6],mouse_y_latch[7]};
            2'b11:
            begin
                mouse[3:0] <= {mouse_y_latch[0],mouse_y_latch[1],mouse_y_latch[2],mouse_y_latch[3]};
                mouse_x_latch <= 0;
                mouse_y_latch <= 0;
            end
            endcase
        end
    end
end

emsx_top emsx
(
//        -- Clock, Reset ports
        .clk21m     (clk_sys),
        .memclk     (memclk),
        .pSltRst_n  (~reset),

//        -- SD-RAM ports
        .pMemAdr   ( SDRAM_A ),
        .pMemDat   ( SDRAM_DQ ),
        .pMemLdq   ( SDRAM_DQML ),
        .pMemUdq   ( SDRAM_DQMH ),
        .pMemWe_n  ( SDRAM_nWE ),
        .pMemCas_n ( SDRAM_nCAS ),
        .pMemRas_n ( SDRAM_nRAS ),
        .pMemCs_n  ( SDRAM_nCS ),
        .pMemBa0   ( SDRAM_BA[0] ),
        .pMemBa1   ( SDRAM_BA[1] ),
        .pMemCke   ( SDRAM_CKE ),

//        -- PS/2 keyboard ports
        .pPs2Clk   (ps2_clk),
        .pPs2Dat   (ps2_data),

//        -- Joystick ports (Port_A, Port_B)
        .pJoyA      ( {msx_joya[5:4], msx_joya[0], msx_joya[1], msx_joya[2], msx_joya[3]} ),
        .pStra      ( msx_stra ),
        .pJoyB      ( {msx_joyb[5:4], msx_joyb[0], msx_joyb[1], msx_joyb[2], msx_joyb[3]} ),
        .pStrb      ( msx_strb ),

//        -- SD/MMC slot ports
        .pSd_Ck     (sd_sclk_o), // (Sd_Ck),
        .pSd_Cm     (sd_mosi_o), // (Sd_Cm),
        .pSd_Dt     ({sd_cs_n_o,2'bZZ,sd_miso_i}), // (Sd_Dt),

//        -- DIP switch, Lamp ports
        .pDip       (dipsw),
        .pLed       (leds),

//        -- Video, Audio/CMT ports
        .pDac_VR    (R_O),      // RGB_Red / Svideo_C
        .pDac_VG    (G_O),      // RGB_Grn / Svideo_Y
        .pDac_VB    (B_O),      // RGB_Blu / CompositeVideo
        .pVideoHS_n (HSync),    // HSync(RGB15K, VGA31K)
        .pVideoVS_n (VSync),    // VSync(RGB15K, VGA31K)

        .CmtIn      (EAR),
        .pDac_SL    (audio_l),
        .pDac_SR    (audio_r),

        .osd_o      (),
		  .dac_out    (dac_out),
        .opl3_enabled ( ~status[7] ),
        .slot0_exp  ( ~status[13] ),
        .kbd_layout ( {status[14], status[15]} )
);

//////////////////   VIDEO   //////////////////
wire  [5:0] R_O;
wire  [5:0] G_O;
wire  [5:0] B_O;
wire        HSync, VSync, CSync;

wire [5:0] osd_r_o, osd_g_o, osd_b_o;

     mist_video #( .OSD_COLOR ( 3'b001 )) mist_video_inst
     (
         .clk_sys     ( memclk ), //clk_sys ),
         .scanlines   ( status[11:10] ),
         .rotate      ( 2'b00 ),
         .scandoubler_disable  ( 1'b1 ),
         .ce_divider  ( 1'b0 ), //1 para clk_sys ou 0 com clksdram para usar blend
         .blend       ( status[12] ),
         .no_csync    ( 1'b1 ),

         .SPI_SCK     ( 0 ),
         .SPI_SS3     ( 0 ),
         .SPI_DI      ( 0 ),

         .HSync       ( HSync ),
         .VSync       ( VSync ),
         .R           ( R_OSD[7:2] ), //R_O ),
         .G           ( G_OSD[7:2] ), //G_O ),
         .B           ( B_OSD[7:2] ), //B_O ),

         .VGA_HS      ( VGA_HS ),
         .VGA_VS      ( VGA_VS ),
         .VGA_R       ( VGA_R ),
         .VGA_G       ( VGA_G ),
         .VGA_B       ( VGA_B ),

         .osd_enable  ( )
     );

assign AUDIO_L = audio_li[0];
assign AUDIO_R = audio_ri[0];
/*
//////////////////   AUDIO   //////////////////
dac #(6) dac_l
(
    .clk_i(clk_sys),
    .res_n_i(1'b1),
    .dac_i(audio_li),
    .dac_o(AUDIO_L)
);

dac #(6) dac_r
(
    .clk_i(clk_sys),
    .res_n_i(1'b1),
    .dac_i(audio_ri),
    .dac_o(AUDIO_R)
);
*/
endmodule
