`define WORD		[15:0]
`define OPCODE		[3:0]
`define IMMED12		[11:0]
`define STATE		[4:0]
`define PRE		[3:0]
`define REGSIZE		[511:0]	//from provided
`define HALFWORD	[7:0]	//
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


`define NOOP    6'b111111

module decode(opin, src, dst, opout, sp, spOut, pre);
input wire `WORD opin;
output reg `WORD src;
output reg `WORD dst;
output reg `WORD opout;
output reg `HALFWORD spOut;
input wire `HALFWORD sp;
output reg `PRE pre;


always@(opin) begin

   case (opin[15:12])
      `NOARG: begin

       case(opin[3:0]) 
          `OPdup: begin  
               opout = opin[3:0];
               dst = sp +1;
               src = sp;
               spOut = sp+1;
               pre = 0;
           end
           `OPload: begin opout =  opin[3:0]; dst = sp; src = `NOOP; spOut = sp; pre = 0; end
           `OPret: begin opout =  opin[3:0]; src = sp; spOut = sp -1; dst = `NOOP; pre = 0; end
           `OPtest: begin opout = opin[3:0]; src = sp; spOut = sp -1; dst = `NOOP; pre = 0; end
           default: begin  
               opout = opin[3:0];
               dst = sp-1;
               src = sp;
               spOut = sp-1;
               pre = 0;
               end
       endcase
       end

       `OPcall: begin
               opout = opin[15:12];
               dst = sp+1;
               src = `NOOP;
               spOut = sp+1;
               pre = 0;
        end

        `OPget: begin
               opout = opin[15:12];
               dst = sp+1;
               src = sp-opin[11:0];
               spOut = sp+1;
               pre = 0;
        end

       //sets sp to 0 if the immediate is greater than sp.
        `OPpop: begin
               opout = opin[15:12];
               dst = `NOOP;
               src = `NOOP;
               if(sp < opin[11:0]) begin
               spOut = sp-opin[11:0];
               end
               else begin spOut = 0; end
               pre = 0;
        end

        `OPpre: begin
                opout = opin[15:12];
                dst =`NOOP;
                src = `NOOP;
                spOut = sp;
                pre = opin[3:0];
        end

        `OPpush: begin
               opout = opin[3:0];
               dst = sp+1;
               src = `NOOP;
               spOut = sp+1;
        end     

               
      default: begin opout = `NOOP; src = `NOOP; dst= `NOOP; spOut = sp; end
    endcase
  end

endmodule

module alu(opin, in1, in2, out, torf);
	output reg `WORD out;
	input wire `OPCODE opin;
	input wire `WORD in1, in2;
        output reg torf;

	always@(opin, in1, in2) begin
		case (opin)
			`OPadd: begin out = in1 + in2; torf = 0; end
			`OPand: begin out = in1 & in2; torf = 0; end
			`OPor: begin out = in1 | in2; torf = 0; end
			`OPxor: begin out = in1 ^ in2; torf = 0; end
			`OPsub: begin out = in1 - in2; torf = 0; end
                        `OPtest: begin out = `NOOP; torf = (in1 != 0); end
			default: begin out = in1; torf = 0; end
		endcase
       end

endmodule

module pipelined(halt, reset, clk);
input reset, clk;

output reg halt;

reg torf1;
reg torf2;

reg halt1;
reg halt2;

reg loaded=0;


reg `PRE preload1=0;
reg `PRE preload2=0;

reg `WORD pc1 = 0;
reg `WORD pc2 = 0;
reg `WORD pc =0;
reg `HALFWORD sp1 = -1;
reg `HALFWORD sp2 = -1;

reg `WORD regfile `REGSIZE;
reg `WORD memory `MEMSIZE;
reg `WORD curOP1;
reg `WORD curOP2;
wire `WORD opo;

reg `WORD s1op;
reg `WORD s2op;

reg `IMMED12 immed12;
	
reg `WORD srcval;
reg `WORD destval;

wire `WORD s1value;
wire `WORD d1value;
	
reg checkNOOP;

reg `PRE preReg;

wire `PRE preOut;
wire `WORD res;
	
reg thread_id;

//for whatever torf we are checking
wire torfIP;

reg `WORD counter= 0;
wire `HALFWORD spin =-1;
wire `HALFWORD spout = -1;
	always @(reset) begin
		halt = 0;
                halt1 = 0;
                halt2 = 0;
		pc1 = 0;
                pc2 = 1;
                curOP1 = `NOOP;
                curOP2 = `NOOP;
                s1op = 0;
                s2op = 0;
		$readmemh0(memory);
		$readmemh1(regfile);
	end
 

        //Instruction fetching!
	always@(posedge clk) begin 
              if (!halt1 && !halt2) begin 
              curOP1 <= memory[pc1]; curOP2 <= memory[pc2]; pc1 <= pc1 +2; pc2 <= pc2 + 2;  end
        end

        always@(posedge clk) begin if (!halt1 && !halt2) begin
             if(((counter % 2) === 0) && !halt1) begin
                 s1op <= curOP1;
                 pc <= pc1;  
		 thread_id = 0;
             end
             else if (!halt2) begin
                 s1op <= curOP2;
                 pc <= pc2;
		 thread_id = 1;
             end
           end
           counter <= counter + 1;
        end

        decode dd(s1op, s1value, d1value, opo, spin, spout, preOut);

        always@(s1op) begin
          if(preOut != 0 ) begin loaded = 1; end
          case(s1op)
                   //adapted from Sick.v at aggregate.org
                  `OPjump: begin pc={(loaded ? preOut : s1op[15:12]), s1op `IMMED12}; loaded=0; end
                  `OPjumpf: begin if (!torfIP) pc={(loaded ? preOut : s1op[15:12]), s1op `IMMED12}; loaded=0;  end
                  `OPjumpt: begin if (torfIP) pc={(loaded ? preOut : s1op[15:12]), s1op `IMMED12}; loaded=0;  end
                  default: begin pc <= pc; end
          endcase
        end


        alu aa(opo[3:0], regfile[{thread_id, s1value}], regfile[{thread_id, d1value}], res, torfIP);

	//set the source as the result. Otherwise, move forward for module 4.
	always@(*) begin if (s1value != 6'b111111) srcval = res;
		else srcval = s1value;
	end 

        //write the to the register.
	always@(*) begin if (d1value != 6'b111111) regfile[{thread_id, destval}] =res ;
		else destval = d1value;
	end
        
       //set the preload
        always@(*) begin if( preOut != 0) begin preReg = preOut; preload1 = 1; end else begin preload1 = 0; end  end
		
       //memory writing
	always @(posedge clk) if (!halt) begin
		if (destval != 0) regfile[{thread_id,destval}] <= srcval;
		end

	always @(posedge clk) begin
           if(halt1 && halt2) begin
               halt <=1;
           end
	end

endmodule

module testbench;
reg reset = 0;
reg clk = 0;
wire halted;
integer i = 0;
pipelined PE(halted, reset, clk);
initial begin
    $dumpfile;
    $dumpvars(0, PE);
    #10 reset = 1;
    #10 reset = 0;
    while (!halted && (i < 200)) begin
        #10 clk = 1;
        #10 clk = 0;
        i=i+1;
    end
    $finish;
end
endmodule
