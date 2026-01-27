// NeoGeo logic definition
// Copyright (C) 2018 Sean Gonsalves
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// Everything here was verified on a MV4 board
// Todo: Check phase relations between 12M, 68KCLK and 68KCLKB
// Todo: Check cycle right after nRESETP goes high, real hw might have an important delay added

module clocks_sync(
	input CLK,
	input [1:0] TURBO_SPEED,
	input CLK_EN_24M_P,
	input CLK_EN_24M_N,
	input nRESETP,
	output CLK_24M,
	output CLK_12M,
	output reg CLK_68KCLK,
	output CLK_68KCLKB,
	output CLK_EN_68K_P,
	output CLK_EN_68K_N,
	output CLK_6MB,
	output reg CLK_1HB,
	output CLK_EN_12M,
	output CLK_EN_12M_N,
	output CLK_EN_6MB,
	output CLK_EN_1HB
);

	reg [2:0] CLK_DIV;
	reg [7:0] phase_acc;      // Phase accumulator for fractional divider
	reg [7:0] phase_inc;      // How much to add each cycle
	wire CLK_3M;
	// Select phase increment based on turbo speed
	// 0 = Off (12MHz):  increment 128 -> toggle at 24MHz rate -> 12MHz 68K
	// 1 = 14MHz:        increment 149 -> toggle at ~28MHz rate -> ~14MHz 68K
	// 2 = 18MHz:        increment 192 -> toggle at ~36MHz rate -> ~18MHz 68K
	always @(*) begin
    	case (TURBO_SPEED)
        	2'b01:   phase_inc = 8'd149;  // ~14MHz
        	2'b10:   phase_inc = 8'd192;  // ~18MHz
        	default: phase_inc = 8'd128;  // 12MHz (normal)
    	endcase
	end
	
	//assign CLK_68KCLKB = ~CLK_68KCLK;
	assign CLK_68KCLKB = CLK_EN_68K_N;
	
	// Phase accumulator and 68K clock generation
	reg phase_overflow;
	always @(posedge CLK or negedge nRESETP)
	begin
    	if (!nRESETP) begin
        	CLK_68KCLK <= 1'b0;
        	phase_acc <= 8'd0;
        	phase_overflow <= 1'b0;
    	end
    	else begin
        	if (TURBO_SPEED == 2'b00 || TURBO_SPEED == 2'b11) begin
            	// Normal mode (12MHz): use original 24MHz enable
            	phase_overflow <= CLK_EN_24M_P;
            	if (CLK_EN_24M_P)
                	CLK_68KCLK <= ~CLK_68KCLK;
        	end
        	else begin
            	// Fractional modes (14MHz, 18MHz): use phase accumulator
            	{phase_overflow, phase_acc} <= phase_acc + phase_inc;
            	if (phase_acc + phase_inc >= 256)
                	CLK_68KCLK <= ~CLK_68KCLK;
        	end
    	end
	end
	assign CLK_EN_68K_P = ~CLK_68KCLK & phase_overflow;
	assign CLK_EN_68K_N =  CLK_68KCLK & phase_overflow;
	
	always @(posedge CLK, negedge nRESETP)
	begin
		if (!nRESETP)
			CLK_DIV <= 3'b100;
		else if (CLK_EN_24M_N)
			CLK_DIV <= CLK_DIV + 1'b1;
	end
	
	assign CLK_24M = CLK_EN_24M_N;
	assign CLK_12M = CLK_DIV[0];
	assign CLK_EN_12M   = CLK_EN_24M_N & ~CLK_DIV[0];
	assign CLK_EN_12M_N = CLK_EN_24M_N &  CLK_DIV[0];
	assign CLK_6MB = ~CLK_DIV[1];
	assign CLK_3M = CLK_DIV[2];
	
	// MV4 C4:B
	always @(posedge CLK)
		if (CLK_EN_12M) CLK_1HB <= ~CLK_3M;

	assign CLK_EN_6MB = CLK_EN_24M_N & CLK_DIV[1:0] == 3;
	assign CLK_EN_1HB = CLK_EN_24M_N & CLK_DIV == 0;
	
endmodule