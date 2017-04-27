//Assignment 3
//EE480 Spring 2017
//Angelo Stekardis, Matt Crosby, Zach Kahleifeh

// standard sizes
`define STATE [7:0]
`define WORD	[15:0]
`define REGSIZE [511:0]   
`define MEMSIZE [131071:0] //Double the normal amount (each thread gets half the total memory)
`define Opcode [15:12]
`define Immed [11:0]
`define NUMREGS [7:0]

// initial state
`define Start	8'b11110000

// opcode values/ state numbers
`define NOimmed 8'b00000000
`define OPget 8'b00010000
`define OPpop 8'b00100000
`define OPput 8'b00110000
`define OPcall 8'b 01000000
`define OPjumpf 8'b01010000
`define OPjump 8'b01100000
`define OPjumpt 8'b01110000
`define OPpre 8'b10000000
`define OPpush 8'b10010000

// secondary opcode field values
`define OPadd 8'h01
`define OPand 8'h02
`define OPdup 8'h03
`define OPload 8'h04
`define OPlt 8'h05
`define OPor 8'h06
`define OPret 8'h07
`define OPstore 8'h08
`define OPsub 8'h09
`define OPsys 8'h0A
`define OPtest 8'h0B
`define OPxor 8'h0C


module processor (halt, reset, clk); // operator input removed
output reg [1:0] halt; //2 bits to keep track of hault on each thread
input clk, reset;

reg `WORD regfile `REGSIZE;
reg `WORD mainmem `MEMSIZE;

reg `NUMREGS sp [1:0];
reg `WORD pc [1:0];
reg [3:0] prefix [1:0]; 
reg [1:0] preEmpty; // Register describing the state of pre (loaded = 0, not loaded = 1)
reg `WORD ir [1:0];   	// Register that holds instruction spec code
reg [1:0] torf;       	// True or false register (2 bits wide so that each thread has a torf value)
reg threadID = 1'b0;
reg currThreadID = 1'b0;
reg [1:0] threadStall = 2'b00;

//Need source and destination registers for each stage:
//reg `NUMREGS stage1Dest;
//reg `NUMREGS stage2Dest;
reg `NUMREGS stage3Dest;
reg `NUMREGS stage4Dest;
//reg `NUMREGS stage1Source;
//reg `NUMREGS stage2Source;
reg `NUMREGS stage3Source;
reg `NUMREGS stage4Source;

//Need a register for the source and dest vals to carry between stage 3 and 4
reg `NUMREGS setDest;
reg `NUMREGS setSource;
//Need register to hold immediate values when goinf from stage 3 to 4 
reg `WORD holdImmedVal;

//Need to store PC when a jump is used, and need one for each thread
reg `WORD pcJumpStore [1:0];
//Need to set flags for when PC will be used across stages (such as when a call instruction is used)
reg [1:0] pcFlag = 0;

reg `STATE stage2 = `Start;
reg `STATE stage3 = `Start;
reg `STATE stage4 = `Start;

always @ (reset) begin
	//Initialize PC's for each thread to 0
  pc[0] <= 0;
  pc[1] <= 0;
  //Initialize SP's for each thread to 0
  sp[0] <= 0;
  sp[1] <= 0;
  //Initialize stages
	stage2 <= `Start;
	stage3 <= `Start;
  stage4 <= `Start;
  //Initialize everything else
  ir[0] <= `Start;
  ir[1] <= `Start;
  threadID <= 0;
  halt <= 2'b00;
	torf <= 2'b00;
	preEmpty <= 2'b11;
  $readmemh0(regfile);
	$readmemh1(mainmem);
  $display("Reset");
end

always @(posedge clk) begin
  threadID <= !threadID; //Change threads after each clock cycle
end

//In stages 1 and 3 we will use threadID while in the other stages we will use !threadID so that both threads may be used at the same time

//Stage 1
always @(posedge clk) begin
  if(!threadStall[threadID]) begin //Only get next instruction if the thread is not stalled
    if(!pcFlag[threadID]) begin //If a jump is not being taken...
      pc[threadID] <= pc[threadID] + 1;
      ir[threadID] <= mainmem[{threadID, pc[threadID]}];
      //stage2 <= mainmem[{threadID, pc[threadID]}]`Opcode; 
      stage2 <= {(mainmem[{threadID,pc[threadID]}]`Opcode),((mainmem[{threadID,pc[threadID]}]`Opcode == 0) ? mainmem[{threadID, pc[threadID]}][3:0] : 4'b0)};
      //$display("stagenum: %b",stage2);
    end
    else begin
      pc[threadID] <= pcJumpStore[threadID] + 1;
      ir[threadID] <= mainmem[{threadID, pcJumpStore[threadID]}];
      //stage2 <= mainmem[{threadID, pcJumpStore[threadID]}]`Opcode;
      stage2 <= {(mainmem[{threadID,pcJumpStore[threadID]}]`Opcode),((mainmem[{threadID,pcJumpStore[threadID]}]`Opcode == 0) ? mainmem[{threadID, pcJumpStore[threadID]}][3:0] : 4'b0)};
      //$display("stagenum: %b",stage2);
    end
  end
  else begin //If the current thread is stalled...
    ir[threadID] <= 16'hffff;
    //Will trigger a no-op
    stage2 <= `Start;
  end
end

//Stage 2 
always @(posedge clk) begin
  currThreadID = !threadID;
  //Reset pc flag and stall flag if either had been previously used 
  if(pcFlag[currThreadID]) begin
    pcFlag[currThreadID] <= 0;
  end
  if(threadStall[currThreadID]) begin
    threadStall[currThreadID] <= 0;
  end
  //Using the opcode found in stage 1 calculate the source and dest for the appropriate instruction
  case(stage2)
    `OPadd: begin
      stage3Dest <= sp[currThreadID] - 1;
      stage3Source <= sp[currThreadID];
      sp[currThreadID] <= sp[currThreadID] - 1;
      $display("Add executed on thread number %d",currThreadID);
    end
    `OPand: begin
      stage3Dest <= sp[currThreadID] - 1;
      stage3Source <= sp[currThreadID];
      sp[currThreadID] <= sp[currThreadID] - 1;
      $display("And executed on thread number %d",currThreadID);
    end
    `OPdup: begin
      stage3Dest <= sp[currThreadID] + 1;
      stage3Source <= sp[currThreadID];
      sp[currThreadID] <= sp[currThreadID] + 1;
      $display("Dup executed on thread number %d",currThreadID);
    end
    `OPload: begin
      stage3Dest <= sp[currThreadID];
      $display("Load executed on thread number %d",currThreadID);
    end
    `OPlt: begin
      stage3Dest <= sp[currThreadID] - 1;
      stage3Source <= sp[currThreadID];
      sp[currThreadID] <= sp[currThreadID] - 1;
      $display("LT executed on thread number %d",currThreadID);
    end
    `OPor: begin
      stage3Dest <= sp[currThreadID] - 1;
      stage3Source <= sp[currThreadID];
      sp[currThreadID] <= sp[currThreadID] - 1;
      $display("Or executed on thread number %d",currThreadID);
    end
    `OPret: begin
      stage3Source <= sp[currThreadID];
      sp[currThreadID] <= sp[currThreadID] - 1;
      pcFlag[currThreadID] <= 1;
      pcJumpStore[currThreadID] <= regfile[{currThreadID,sp[currThreadID]}];
      $display("Ret executed on thread number %d",currThreadID);
    end
    `OPstore: begin
      stage3Dest <= sp[currThreadID] - 1;
      stage3Source <= sp[currThreadID];
      sp[currThreadID] <= sp[currThreadID] - 1;
      $display("Store executed on thread number %d",currThreadID);
    end
    `OPsub: begin
      stage3Dest <= sp[currThreadID] - 1;
      stage3Source <= sp[currThreadID];
      sp[currThreadID] <= sp[currThreadID] - 1;
      $display("Sub executed on thread number %d",currThreadID);
    end
    `OPtest: begin
      stage3Source <= sp[currThreadID];
      sp[currThreadID] <= sp[currThreadID] - 1;
      threadStall[currThreadID] <= 1;
      $display("Test executed on thread number %d",currThreadID);
    end
    `OPxor: begin
      stage3Dest <= sp[currThreadID] - 1;
      stage3Source <= sp[currThreadID];
      sp[currThreadID] <= sp[currThreadID] - 1;
      $display("Xor executed on thread number %d",currThreadID);
    end
    `OPget: begin
      stage3Dest <= sp[currThreadID] + 1;
      stage3Source <= sp[currThreadID] - (ir[currThreadID]`NUMREGS);
      sp[currThreadID] <= sp[currThreadID] + 1;
      $display("Get executed on thread number %d",currThreadID);
    end
    `OPpop: begin
      sp[currThreadID] <= sp[currThreadID] - (ir[currThreadID]`NUMREGS);
      $display("Pop executed on thread number %d",currThreadID);
    end
    `OPput: begin 
      stage3Dest <= sp[currThreadID] - (ir[currThreadID]`NUMREGS);
      stage3Source <= sp[currThreadID] ;
      $display("Put executed on thread number %d",currThreadID);
    end
    `OPcall: begin
      stage3Dest <= sp[currThreadID] + 1;
      sp[currThreadID] <= sp[currThreadID] + 1;
      pcJumpStore[currThreadID] <= {(preEmpty[currThreadID] ? prefix[currThreadID] : pc[currThreadID][15:12]), ir[currThreadID]`Immed};
      pcFlag[currThreadID] <= 1;
      $display("Call executed on thread number %d",currThreadID);
    end
    `OPjumpf: begin
      //Only execute when torf == 0
      if (!torf[currThreadID]) begin
        pcJumpStore[currThreadID] <= {(preEmpty[currThreadID] ? prefix[currThreadID] : pc[currThreadID][15:12]), ir[currThreadID]`Immed};
        pcFlag[currThreadID] <= 1;
      end
      $display("Jump on false executed on thread number %d",currThreadID);
    end
    `OPjump: begin
        pcJumpStore[currThreadID] <= {(preEmpty[currThreadID] ? prefix[currThreadID] : pc[currThreadID][15:12]), ir[currThreadID]`Immed};
        pcFlag[currThreadID] <= 1;
        $display("Jump executed on thread number %d",currThreadID);
    end
    `OPjumpt: begin
      //Only execute when torf == 1
      if (torf[currThreadID]) begin
        pcJumpStore[currThreadID] <= {(preEmpty[currThreadID] ? prefix[currThreadID] : pc[currThreadID][15:12]), ir[currThreadID]`Immed};
        pcFlag[currThreadID] <= 1;
      end
      $display("Jump on true executed on thread number %d",currThreadID);
    end
    `OPpre: begin
      prefix[currThreadID] = ir[currThreadID][3:0];
      $display("Pre executed on thread number %d",currThreadID);
    end
    `OPpush: begin
      stage3Dest <= sp[currThreadID] + 1;
      sp[currThreadID] <= sp[currThreadID] + 1;
      $display("Push executed on thread number %d",currThreadID);
    end
    `Start: begin
      $display("NoOP on thread number %d since the thread was stalled",currThreadID);
    end
    default: begin
      //If a halt is called
      halt[currThreadID] <= 1;
    end
  endcase // stage2
  stage3 <= stage2;
end 

//Stage 3
always @(posedge clk) begin
  case(stage3)
    `OPadd: begin
      setDest <= regfile[{threadID, stage3Dest}];
      setSource <= regfile[{threadID, stage3Source}];
    end
    `OPand: begin
      setDest <= regfile[{threadID, stage3Dest}];
      setSource <= regfile[{threadID, stage3Source}];
    end
    `OPdup: begin
      setSource <= regfile[{threadID, stage3Source}];
    end  
    `OPload: begin
      setDest <= regfile[{threadID, stage3Dest}];
    end
    `OPlt: begin
      setDest <= regfile[{threadID, stage3Dest}];
      setSource <= regfile[{threadID, stage3Source}];
    end
    `OPor: begin
      setDest <= regfile[{threadID, stage3Dest}];
      setSource <= regfile[{threadID, stage3Source}];
    end
    `OPret: begin    end
    `OPstore: begin
      setDest <= regfile[{threadID, stage3Dest}];
      setSource <= regfile[{threadID, stage3Source}];
    end
    `OPsub: begin
      setDest <= regfile[{threadID, stage3Dest}];
      setSource <= regfile[{threadID, stage3Source}];
    end
    `OPtest: begin
      setSource <= regfile[{threadID, stage3Source}];
    end
    `OPxor: begin
      setDest <= regfile[{threadID, stage3Dest}];
      setSource <= regfile[{threadID, stage3Source}];
    end
    `OPget: begin
      setSource <= regfile[{threadID, stage3Source}];
    end
    `OPpop: begin    end
    `OPput: begin
      setSource <= regfile[{threadID, stage3Source}]; 
    end
    `OPcall: begin
     holdImmedVal <= pc[threadID];
    end
    `OPjumpf: begin    end

    `OPjump: begin    end

    `OPjumpt: begin    end
   
    `OPpre: begin    end

    `OPpush: begin
      holdImmedVal <= ir[threadID];
    end
    `Start: begin
      $display("NoOP on thread number %d since the thread was stalled",threadID);
    end
    //Case for halt:
    default: begin
      halt[threadID] <= 1;
    end
  endcase // stage3
  stage4 <= stage3;
  stage4Dest <= stage3Dest;
  stage4Source <= stage4Source;
end

//Stage 4
always @(posedge clk) begin
  currThreadID = !threadID;
  case(stage4)
    `OPadd: begin
      regfile[{currThreadID, stage4Dest}] <= setDest + setSource;
    end
    `OPand: begin
      regfile[{currThreadID, stage4Dest}] <= setDest & setSource;
    end
    `OPdup: begin
      regfile[{currThreadID, stage4Dest}] <= setSource;
    end
    `OPload: begin
      regfile[{currThreadID, stage4Dest}] <= mainmem[setDest]; 
    end
    `OPlt: begin
      regfile[{currThreadID, stage4Dest}] <= setDest < setSource;
    end
    `OPor: begin
      regfile[{currThreadID, stage4Dest}] <= setDest | setSource;
     end
    `OPret: begin     end
    `OPstore: begin
      mainmem[{currThreadID, setDest}] <= setSource;  
      regfile[{currThreadID, stage4Dest}] <= setSource;
    end
    `OPsub: begin
      regfile[{currThreadID, stage4Dest}] <= setDest - setSource;
    end
    `OPtest: begin
      torf[currThreadID] <= (setSource != 0);
    end
    `OPxor: begin
      regfile[{currThreadID, stage4Dest}] <= setDest ^ setSource ;
    end
    `OPget: begin
      regfile[{currThreadID, stage4Dest}] <= setSource;
    end
    `OPpop: begin     end
    `OPput: begin
      regfile[{currThreadID, stage4Dest}] <= setSource;
    end
    `OPcall: begin
      regfile[{currThreadID, stage4Dest}] <= holdImmedVal;
      preEmpty <= 0;
    end
    `OPjumpf: begin
      preEmpty <= 0;
    end
    `OPjump: begin
        preEmpty <= 0;
    end
    `OPjumpt: begin
      preEmpty <= 0;
    end
    `OPpre: begin
      preEmpty[currThreadID] <= 1;
    end
    `OPpush: begin
      regfile[{currThreadID, stage4Dest}] <= {preEmpty[currThreadID] ? prefix[currThreadID] : {4 { holdImmedVal[11]}},holdImmedVal`Immed};
      preEmpty <= 0;
    end
    `Start: begin
      $display("NoOP on thread number %d since the thread was stalled",currThreadID);
    end
    //Case for halt:
    default: begin
      halt[currThreadID] <= 1;
    end
  endcase
end

endmodule // processor

module testbench;
	reg reset = 0;
	reg clk = 0;
	wire [1:0] halted;
	processor PE(halted, reset, clk);
	initial begin
  	$dumpfile;
  	$dumpvars(0, PE);
  	#10 reset = 1;
  	#10 reset = 0;
  	while (halted != 2'b11) begin
    	#10 clk = 1;
   	#10 clk = 0;
 	end
  	$finish;
	end
endmodule


