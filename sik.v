`define WORD		[15:0]
`define OPCODE		[3:0]
`define IMMED12		[11:0]
`define STATE		[6:0]
`define PRE		[3:0]
`define REGSIZE		[511:0]	//from provided
`define HALFWORD	[7;0]	//
`define MEMSIZE		[65535:0]//

//Normal curOPs
`define OPget       4'b0001
`define OPpop       4'b0010
`define OPput       4'b0011
`define OPcall      4'b0100
`define OPjumpf     4'b0101
`define OPjump      4'b0110
`define OPjumpt     4'b0111
`define OPpush      4'b1000
`define OPpre       4'b1111

//Extended curOPs
`define OPadd       4'b0001
`define OPlt        4'b0010
`define OPsub       4'b0011
`define OPand       4'b0100
`define OPor        4'b0101
`define OPxor       4'b0110
`define OPdup       4'b0111
`define OPret       4'b1000
`define OPsys       4'b1001
`define OPload      4'b1010
`define OPstore     4'b1011
`define OPtest      4'b1100

`define NOARG   4'b0000

`define Start   5'b11111
`define Start1  5'b11110


module pipelined(halt, reset, clk)
input reset, clk;

output reg halt;

reg torf1;
reg torf2;

reg loaded1=0;
reg loaded2=0;

reg `PRE preload1=0;
reg `PRE preload2=0;

reg `WORD pc1 = 0;
reg `WORD pc2 = 0;
reg `HALFWORD sp1 = -1;
reg `HALFWORD sp2 = -1;

reg `WORD regfile `REGSIZE;
reg `WORD memory `MEMSIZE;
reg `WORD curOP1;
reg `WORD curOP2;

reg `IMMED12 immed12;

reg `STATE s = `Start;

always @(reset) begin
	halt = 0;
	pc = 0;
	s <= `Start;
	$readmemh0(regfile);
	$readmemh1(memory);
end

endmodule
