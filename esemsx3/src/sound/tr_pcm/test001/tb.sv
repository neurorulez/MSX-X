/*
  
   Multicore 2 / Multicore 2+
  
   Copyright (c) 2017-2020 - Victor Trucco

  
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
  
*/module tb;
    localparam      CLK_BASE    = 1000000000/21480;
    reg             clk21m;
    reg             reset;
    reg             req;
    wire            ack;
    reg             wrt;
    reg             adr;                //  0:A4h, 1:A5h
    wire    [ 7:0]  dbi;
    reg     [ 7:0]  dbo;
    reg     [ 7:0]  wave_in;            //  -128...127 (two's complement)
    wire    [ 7:0]  wave_out;           //  -128...127 (two's complement)
    string          s_test_name;

    // -------------------------------------------------------------
    //  clock generator
    // -------------------------------------------------------------
    always #(CLK_BASE/2) begin
        clk21m  <= ~clk21m;
    end

    // -------------------------------------------------------------
    //  DUT
    // -------------------------------------------------------------
    tr_pcm u_dut (
        .clk21m     ( clk21m    ),
        .reset      ( reset     ),
        .req        ( req       ),
        .ack        ( ack       ),
        .wrt        ( wrt       ),
        .adr        ( adr       ),
        .dbi        ( dbi       ),
        .dbo        ( dbo       ),
        .wave_in    ( wave_in   ),
        .wave_out   ( wave_out  )
    );

    initial begin
        s_test_name     <= "Initialize";
        clk21m          <= 1'b0;
        reset           <= 1'b1;
        req             <= 1'b0;
        wrt             <= 1'b0;
        adr             <= 1'b0;
        dbo             <= 8'd0;
        wave_in         <= 8'd0;
        repeat( 10 ) @( posedge clk21m );

        reset           <= 1'b0;
        repeat( 10 ) @( posedge clk21m );

        req             <= 1'b0;
        wrt             <= 1'b0;
        adr             <= 1'b0;
        dbo             <= 8'd100;
        @( posedge clk21m );

        req             <= 1'b1;
        wrt             <= 1'b1;
        adr             <= 1'b0;
        dbo             <= 8'd100;
        @( posedge clk21m );

        req             <= 1'b0;
        wrt             <= 1'b0;
        adr             <= 1'b0;
        dbo             <= 8'd0;
        repeat( 1400 ) @( posedge clk21m );

        req             <= 1'b1;
        wrt             <= 1'b1;
        adr             <= 1'b0;
        dbo             <= 8'd200;
        @( posedge clk21m );

        req             <= 1'b0;
        wrt             <= 1'b0;
        adr             <= 1'b0;
        dbo             <= 8'd0;
        repeat( 1400 ) @( posedge clk21m );

        $finish;
    end
endmodule
