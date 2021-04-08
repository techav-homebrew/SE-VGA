/******************************************************************************
 * SE-VGA
 * VGA video output
 * techav
 * 2021-04-06
 ******************************************************************************
 * Fetches video data from VRAM and shifts out
 *****************************************************************************/

`include "primitives.sv"

module vgaout (
    input wire          pixClock,
    input wire          nReset,
    input logic [9:0]   hCount,
    input logic [9:0]   vCount,
    input wire          hSEActive,
    input wire          vSEActive,
    inout logic [7:0]   vramData,
    output logic [12:0] vramAddr,
    output wire         nvramOE,
    output wire         vidOut
);

reg [7:0] rVid;
wire vidMuxOut;
wire vidActive; // combined active video signal
wire vidMuxClk; // latch mux output just before updating rVid

// select bits 0..7 from the vram data in rVid, and latch if
// vidMuxClk goes high
mux8x1latch vidOutMux(rVid,hCount[2:0],vidMuxClk,nReset,vidMuxOut);

// vidMuxClk should be low during sequence 0..6, and high for 7
// this may lead to a race condition trying to change the mux
// before the output is latched. The alternative is to latch on
// the rising edge of pixClock during sequence 7, but then we may
// have a race condition with the data coming in from VRAM.
// What we really need is a half clock delay :-/
always_comb begin
    if(hCount[2:0] == 3'd7) begin
        vidMuxClk <= 1'b1;
    end else begin
        vidMuxClk <= 1'b0;
    end
end

// latch incoming vram data on rising clock and sequence 7
always @(posedge pixClock or negedge nReset) begin
    if(nReset == 1'b0) begin
        rVid <= 8'h0;
    end else begin
        if(hCount[2:0] == 3'b7) begin
            rVid <= vramData;
        end
    end
end

always_comb begin
    // combined video active signal
    if(hSEActive == 1'b1 && vSEActive == 1'b1) begin
        vidActive <= 1'b1;
    end else begin
        vidActive <= 1'b0;
    end

    // video data output
    if(vidActive == 1'b1) begin
        vidOut <= vidMuxOut;
    end else begin
        vidOut <= 1'b0;
    end

    // vram read signal
    if(vidActive == 1'b1 && hCount[2:0] == 3'b7) begin
        nvramOE <= 1'b0;
    end else begin
        nvramOE <= 1'b1;
    end

    // vram address signals
    // these will be mux'd with cpu addresses externally
    vramAddr[12:6] <= vCount[6:0];
    vramAddr[5:0]  <= hCount[8:3];
end
    
endmodule