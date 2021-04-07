/******************************************************************************
 * SE-VGA
 * Primitives
 * techav
 * 2021-04-06
 ******************************************************************************
 * Basic modules to be used elsewhere
 *****************************************************************************/

// basic d-flipflop
module dff (
    input wire nReset,
    input wire clk,
    input wire d,
    output reg q
);
    always @(posedge clock or negedge nReset) begin
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
    always_comb begin
        out <= in[select];
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
    dff u0(nReset,clk,muxOuts[0],muxIns[1]);
    dff u1(nReset,clk,muxOuts[1],muxIns[2]);
    dff u2(nReset,clk,muxOuts[2],muxIns[3]);
    dff u3(nReset,clk,muxOuts[3],muxIns[4]);
    dff u4(nReset,clk,muxOuts[4],muxIns[5]);
    dff u5(nReset,clk,muxOuts[5],muxIns[6]);
    dff u6(nReset,clk,muxOuts[6],muxIns[7]);
    dff u7(nReset,clk,muxOuts[7],muxIns[0]);

    out <= muxIns[0];
endmodule