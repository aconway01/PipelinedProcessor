//processorTest.v
//CS 480
//Assignment 2
//Julian Wicker, Chelsea Kuball, and Andy Conway

//Various sizes of things
`define WORD		[15:0]
`define STACKPOINTER [7:0]
`define PRE			[3:0]
`define Opcode		[15:12]
`define SecondOpcode [11:8]
`define PreLocation	[11:8]
`define STATE		[1:0]
`define EXTSTATE	[3:0]
`define IMMED		[11:0]
`define REGSIZE		[255:0]
`define MEMSIZE		[65535:0]

//Opcode values
`define MoreOps		4'b0000
`define OPget		4'b0001
`define OPpop		4'b0010
`define OPpre		4'b0011
`define OPput		4'b0100
`define OPcall		4'b0101
`define OPjumpf		4'b0110
`define OPjump		4'b0111
`define OPjumpt		4'b1000
`define OPpush		4'b1001

//Extended Opcodes
`define OPaddsub	4'b0000
`define OPand		4'b0001
`define OPdup		4'b0010
`define OPload		4'b0011
`define OPlt		4'b0100
`define OPor		4'b0101
`define OPret		4'b0110
`define OPstore		4'b0111
`define OPsys		4'b1000
`define OPtest		4'b1001
`define OPxor		4'b1010

//State numbers
`define Start		2'b00
`define Start2		2'b01
`define NoExtendOP	2'b10
`define ExtendOP	2'b11

//The Processor
module processor(halt, reset, clk);
output reg halt; //If half == 1, the testbench needs to full stop.
input reset, clk;

reg `WORD regFile `REGSIZE;
reg `WORD mainMemory `MEMSIZE;
reg `WORD pc = 0;
reg `STACKPOINTER sp = 0;
reg `STACKPOINTER destination;
reg `STACKPOINTER source;
reg torf;
reg `PRE pre;
reg preLoaded = 0;
reg `WORD ir;
reg `STATE s = `Start;
reg `EXTSTATE opcode;
reg `IMMED immed;

//Whenever the testbench changes reset, reset the whole processor and re-read the input files.
always @(reset)
begin
	halt = 0;
	pc = 0;
	s = `Start;
	$readmemh0(regFile);
	$readmemh1(mainMemory);
end

always @(posedge clk)
begin
	case (s)
		`Start: begin ir <= mainMemory[pc]; s <= `Start2; end //Fetch the next instruction
		`Start2:							//Find the opcode
		begin
			pc <= pc + 1;					//Increment pc counter
			if (ir `Opcode == `MoreOps)		//If true, we are using an extended opcode
			begin
				s <= `ExtendOP;
				opcode <= ir `SecondOpcode;
			end
			else							//Otherwise, it's directly encoded in the top 4 bits
			begin
				s <= `NoExtendOP;
				opcode <= ir `Opcode;
				immed <= ir `IMMED;			//Every instruction but pre in this category needs an immediate.
			end
		end
		
		`ExtendOP:							//These are the instructions without an immediate.
		begin
$display("VALUEDB: %d", regFile[destination]);
			case(opcode)
				`OPaddsub:
				begin

					destination = sp - 1;
					source = sp;
					sp <= sp - 1;
$display("VALUEDB: %d", regFile[destination]);
					if (ir[7] == 0) //Addition
						regFile[destination] = regFile[destination] + regFile[source];

					else			//Subtraction
						regFile[destination] = regFile[destination] - regFile[source];
					s <= `Start;
				end

				`OPand: begin destination = sp - 1; source = sp; sp <= sp - 1; regFile[destination] = regFile[destination] & regFile[source]; s <= `Start; end
				`OPdup: begin destination = sp + 1; source = sp; sp <= sp + 1; regFile[destination] = regFile[source]; s <= `Start; end
				`OPload: begin destination = sp; regFile[destination] = mainMemory[regFile[destination]]; s <= `Start; end
				`OPlt: begin destination = sp - 1; source = sp; sp <= sp - 1; regFile[destination] = regFile[destination] < regFile[source]; s <= `Start; end
				`OPor: begin destination = sp - 1; source = sp; sp <= sp - 1; regFile[destination] = regFile[destination] | regFile[source]; s <= `Start; end
				`OPret: begin source = sp; sp <= sp - 1; pc = regFile[source]; s <= `Start; end
				`OPstore: begin destination = sp - 1; source = sp; sp <= sp - 1; mainMemory[regFile[destination]] = regFile[source]; regFile[destination] = regFile[source]; s <= 
`Start; end
				`OPtest: begin source = sp; sp <= sp - 1; torf = regFile[source] != 0; s <= `Start; end
				`OPxor: begin destination = sp - 1; source = sp; sp <= sp - 1; regFile[destination] = regFile[destination] ^ regFile[source]; s <= `Start; end
				
				default: halt = 1; //If something goes wrong or opcode == `OPsys
			endcase
$display("VALUEDA: %d", regFile[destination]);
		end
		
		`NoExtendOP:
		begin
			case(opcode)
				`OPget: begin destination = sp + 1; source = sp - immed; sp <= sp + 1; regFile[destination] = regFile[source]; s <= `Start; end
				`OPpop: begin if (immed > sp) sp = 0; else sp = sp - immed; s <= `Start; end
				`OPpre: begin pre = ir `PreLocation; preLoaded = 1; s <= `Start; end
				`OPput: begin if (immed > sp) destination = 0; else destination = sp - immed; source = sp; regFile[destination] = regFile[source]; s <= `Start; end
				`OPcall:
				begin
					destination = sp + 1;
					sp <= sp + 1;
					regFile[destination] = pc + 1;
					if (preLoaded == 1)				//If there is a pre, use it and set preLoaded to 0.
					begin
						pc = {pre, immed};
						preLoaded <= 0;
					end
					else							//Use top 4 bits of pc otherwise.
						pc = {(pc >> 12), immed};
					s <= `Start;
				end
				`OPjumpf:
				begin
					if (!torf)
					begin
						if (preLoaded == 1)			//If there is a pre, use it and set preLoaded to 0.
						begin
							pc = {pre, immed};
							preLoaded <= 0;
						end
						else
							pc = {(pc >> 12), immed}; //Use top 4 bits of pc otherwise.
					end
					s <= `Start;
				end
				`OPjump:
				begin
					if (preLoaded == 1)				//If there is a pre, use it and set preLoaded to 0.
					begin
						pc = {pre, immed};
						preLoaded <= 0;
					end
					else
						pc = {(pc >> 12), immed};	//Use top 4 bits of pc otherwise.
					s <= `Start;
				end
				`OPjumpt:
				begin
					if (torf)
					begin
						if (preLoaded == 1)			//If there is a pre, use it and set preLoaded to 0.
						begin
							pc = {pre, immed};
							preLoaded <= 0;
						end
						else
							pc = {(pc >> 12), immed}; //Use top 4 bits of pc otherwise.
					end
					s <= `Start;
				end
				`OPpush:
				begin
					destination = sp + 1;
					sp <= sp + 1;
					if (preLoaded == 1)				//If there is a pre, use it and set preLoaded to 0.
					begin
						regFile[destination] = {pre, immed};
						preLoaded <= 0;
					end
					else
						regFile[destination] = {{4{immed[11]}}, immed}; //Sign-extend the 11th bit of immed otherwise.
					s <= `Start;
				end
				
				default: halt = 1; //If something goes wrong
			endcase
                        $display("CONTENTS OF STACK ARE: \n0: %d \n1: %d \n2: %d \n3: %d \n4: %d \n5: %d \n6: %d \n7: %d",regFile[0], regFile[1], regFile[2],regFile[3], regFile[4], regFile[5], 
regFile[6], regFile[7]);
                        $display("CONTENTS OF MEMORY ARE: \n0: %d \n1: %d \n2: %d \n3: %d \n4: %d \n5: %d \n6: %d",mainMemory[0], mainMemory[1], mainMemory[2],mainMemory[3], mainMemory[4], 
mainMemory[5], mainMemory[6]);
		end
	endcase
end

endmodule

module testbench;
reg reset = 0;
reg clk = 0;
wire halted;
processor PE(halted, reset, clk);
initial begin
  $dumpfile;
  $dumpvars(0, PE);
  #10 reset = 1;
  #10 reset = 0;
  while (!halted) begin
    #10 clk = 1;
    #10 clk = 0;
  end
  $finish;
end
 
endmodule
