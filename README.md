# Pipelining A SIK Machine
# Implementor’s notes

Robert Conway, Ted Ferguson, Katie Long

Abstract — pipelining and hyperthreading to implement a multi cycle processor design.

# I.	Introduction

For this project the SIK design was to be altered to include pipelining done with multiple stages. The advantage comes when alternating between two stacks. The four stages run simultaneously and need to be broken up into independent parts. Any two stages should avoid interfering with each other. 

The two instruction files are inputted through VMEM0 and VMEM1 after being assembled. Just like in the previous design, the opcodes are stored in a memory array. The four stages are:

1: Get operation and increment PC

2: Decode the operation

3: Get the source and destination for the register files

4: Data memory and ALU

After reset the values are initialized and the processor begins with the instruction fetching and program counter incrementing. A counter bit controls which thread is being processed in the decode stage. Within the decode module the source value and destination relative to the stack pointer is determined, along with the opcode field. These are latched and then used in stage 3 within the main pipelined module. One difficulty is that the operations are no longer all happening in the same place. Each stage needs it’s own case statement for the instructions that are relevant. This makes debugging difficult as a problem could be in different places and the stages need to properly cycle before the testbench can check the register values. 

# II.	Verilog		

Now there are two of: PC, Registers, Halt, Reset, Torf and Stack pointers. The previous SIK design used had two stages and no ALU. The new design effectively doubles the previous implementation. The first stage is fetching the current operation for both stacks. The curOP1 and curOP2 denote the operations for the different threads, that will be assigned later in the selection.

curOP1 <= memory[pc1]; curOP2 <= memory[pc2]; pc1 <= pc1 +2; pc2 <= pc2 + 2;

We then use a counter bit which selects the thread to decode. The s1op register is the opcode that is passed to the next stage. The selection logic is shown below:

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

Upon selection, the counter, which denotes the number of the opcode we are on, is incremented. Upon selection, instantiating the decode module is instantiated:
  decode dd(s1op, s1value, d1value, opo, spin, spout, preOut);

As well as the ALU module:

alu aa(opo[3:0], regfile[s1value], regfile[d1value], res, torfIP);

The different modules and always blocks need to not interfere with each other by trying to change the same registers. The values should be latched once, however they could be read any number of times. The latching is done using always blocks that assign the wire value from the alu and decode modules to a register that can then be used for the next stages. The register write stage then uses the latched value to write to or read from the necessary location. Otherwise, the value is forwarded to the last stage where the latched values are used to read and write from memory.

# III.	Errata

In the first stage, our system increments both program counters for each thread, and then selects the appropriate program counter to be moved to the decode stage. However, the value of this thread fails for be added to other thread dependent structures. The most important of these is begin the true or false register. As a result of the failure, the address we wish to jump to fails to be associated with the proper thread. This also applies to the pre instruction. This implementation is able to recognize a pre instruction and load the appropriate bottom four bits to the pre register, but once again fails to associate this to the proper thread.

Additionally, the value forwarding is incorrect. This relates to the multithreading, as the given attempt to value forward is not independent for each thread. The original attempt for value forwarding was a condition statement that checked for a nop code output in the source and destination registers. Upon seeing the noop, it should forward the value to the next stage. However, this does not account for data dependencies, and cannot be solved by the multithreading as it isn’t implemented correctly for this stage. Logic needs to be added such that it checks the destination values from stage 3 to stage 4 and uses a mux to select whether the values are forwarded or not.

# IV. 	Conclusion	

Despite the issues with multithreading and value forwarding, much of the processor works as expected. The project was a good exposure to pipelining and hyperthreading, even with an imperfect execution exhibited in this implementation.

# REFERENCES:

In sik.v: the memory writing stage (stage 4) was provided by the TA and adapted to fit the implementation.
In sik.v:  The jump decoding that is present in the decode stage is adapted from the logic found at http://aggregate.org/EE480/Sick.v
In sik.v: The implementation of the processor was heavily influenced by the code found at http://aggregate.org/EE480/pipe.v . Specifically, the always@(*) blocks were adapted to fit this implementation.
In sik.aik: The aik spec comes from the Assignment 2 specification created by Katie Long, Natsagdorj Baljinnyam, Stephanie McCormick.
