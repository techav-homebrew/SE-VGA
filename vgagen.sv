/******************************************************************************
 * SE-VGA
 * VGA timing generator
 * techav
 * 2021-04-06
 ******************************************************************************
 * Generates VGA timing signals & counters
 *****************************************************************************/

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

endmodule