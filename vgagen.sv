/******************************************************************************
 * SE-VGA
 * VGA timing generator
 * techav
 * 2021-04-06
 ******************************************************************************
 * Generates VGA timing signals & counters
 *****************************************************************************/

`ifndef VGAGEN
    `define VGAGEN

`include "vgacount.sv"

module vgagen (
    input wire             nReset,     // master reset signal
    input wire             pixClk,     // 25.175MHz pixel clock
    output logic [9:0]     hCount,     // horizontal pixel count
    output wire            hActive,    // horizontal VGA active video signal
    output wire            hSEActive,  // horizontal SE active video signal
    output wire            nhSync,     // horizontal sync pulse signal
    output logic [9:0]     vCount,     // vertical line count
    output wire            vActive,    // vertical VGA active video signal
    output wire            vSEActive,  // vertical SE active video signal
    output wire            nvSync      // vertical sync pulse signal
);

vgacount #(800,592,688,576,736,512) hoz(nReset,pixClk,hCount,nhSync,hActive,hSEActive);
vgacount #(525,421,423,411,456,342) ver(nReset,nhSync,vCount,nvSync,vActive,vSEActive);

/*
module vgacount (
    input wire              nReset,         // system reset signal
    input wire              clock,          // counter increment clock
    output logic [9:0]      count,          // count output
    output wire             nSync,          // sync pulse
    output wire             activeVid,      // active video signal
    output wire             activeSE        // secondary active video signal (SE)
);
parameter   COUNTMAX=800,
            SYNCBEGIN=592,
            SYNCEND=688,
            ACTBEGIN=576,
            ACTEND=736,
            SEACTBEGIN=512;
*/

endmodule

`endif