/******************************************************************************
 * SE-VGA
 * Primitives
 * techav
 * 2021-04-06
 ******************************************************************************
 * Basic modules to be used elsewhere
 *****************************************************************************/

`ifndef PRIMS
    `define PRIMS

// basic d-flipflop
module myDff (
    input wire nReset,
    input wire clk,
    input wire d,
    output reg q
);
    always @(posedge clk or negedge nReset) begin
        if(nReset == 1'b0) begin
            q <= 1'b0;
        end else begin
            q <= d;
        end
    end
endmodule

// basic 8-bit mux
module mux8 (
    input logic [7:0] inA,
    input logic [7:0] inB,
    input wire select,
    output logic [7:0] out
);
    always_comb begin
        if(select == 1'b0) begin
            out <= inA;
        end else begin
            out <= inB;
        end
    end
endmodule

// basic 8-to-1 mux
module mux8x1 (
    input logic[7:0] in,
    input logic[2:0] select,
    output wire out
);
    assign out = in[select];
endmodule

// basic 8-to-1 mux with transparent output latch
module mux8x1latch (
    input logic[7:0] in,
    input logic[2:0] select,
    input wire clock,
    input wire nReset,
    output reg out
);
    wire muxOut;
    mux8x1 mux (in,select,muxOut);

    // transparent latch -- when clock is low, output will
    // follow the output of the mux. When clock is high,
    // output will hold its last value.
    always @(clock or nReset or muxOut or out) begin
        if(nReset == 1'b0) begin
            out = 1'b0;
        end else if(clock == 1'b0) begin
            out = muxOut;
        end else begin
            out = out;
        end
    end
endmodule

// basic 8-bit PISO shift register
module piso8 (
    input wire nReset,
    input wire clk,
    input wire load,
    input logic [7:0] parIn,
    output wire out
);

    logic [7:0] muxIns;
    logic [7:0] muxOuts;

    mux8 loader(muxIns[7:0],parIn[7:0],load,muxOuts[7:0]);
    myDff u0(nReset,clk,muxOuts[0],muxIns[1]);
    myDff u1(nReset,clk,muxOuts[1],muxIns[2]);
    myDff u2(nReset,clk,muxOuts[2],muxIns[3]);
    myDff u3(nReset,clk,muxOuts[3],muxIns[4]);
    myDff u4(nReset,clk,muxOuts[4],muxIns[5]);
    myDff u5(nReset,clk,muxOuts[5],muxIns[6]);
    myDff u6(nReset,clk,muxOuts[6],muxIns[7]);
    myDff u7(nReset,clk,muxOuts[7],muxIns[0]);

    assign out = muxIns[0];
endmodule

`endif