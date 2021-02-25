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
  
*/
module i2c
(
   input        CLK,

   input        START,
   input [23:0] I2C_DATA,
   output reg   END = 1,
   output reg   ACK = 0,

   //I2C bus
   output       I2C_SCL,
   inout        I2C_SDA
);

// Clock Setting
parameter CLK_Freq = 50_000_000; // 50 MHz
parameter I2C_Freq = 400_000;    // 400 KHz

reg I2C_CLOCK;
always@(negedge CLK) begin
   integer mI2C_CLK_DIV = 0;
   if(mI2C_CLK_DIV < (CLK_Freq/I2C_Freq)) begin
      mI2C_CLK_DIV <= mI2C_CLK_DIV + 1;
   end else begin
      mI2C_CLK_DIV <= 0;
      I2C_CLOCK    <= ~I2C_CLOCK;
   end
end

assign I2C_SCL = SCLK | I2C_CLOCK;
assign I2C_SDA = SDO  ? 1'bz : 1'b0;

reg SCLK = 1, SDO = 1;

always @(posedge CLK) begin
   reg old_clk;
   reg old_st;

   reg  [5:0] SD_COUNTER = 'b111111;
   reg [0:31] SD;

   old_clk <= I2C_CLOCK;
   old_st  <= START;

   if(~old_st && START) begin
      SCLK <= 1;
      SDO  <= 1;
      ACK  <= 0;
      END  <= 0;
      SD   <= {2'b10, I2C_DATA[23:16], 1'b1, I2C_DATA[15:8], 1'b1, I2C_DATA[7:0], 4'b1011};
      SD_COUNTER <= 0;
   end else begin
      if(~old_clk && I2C_CLOCK && ~&SD_COUNTER) begin
         SD_COUNTER <= SD_COUNTER + 6'd1;
         case(SD_COUNTER)
                  01: SCLK <= 0;
            10,19,28: ACK  <= ACK | I2C_SDA;
                  29: SCLK <= 1;
                  32: END  <= 1;
         endcase
      end

      if(old_clk && ~I2C_CLOCK && ~SD_COUNTER[5]) SDO <= SD[SD_COUNTER[4:0]];
   end
end

endmodule
