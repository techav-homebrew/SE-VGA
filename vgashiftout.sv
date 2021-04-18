/******************************************************************************
 * SE-VGA
 * VGA Shift Out
 * techav
 * 2021-04-06
 ******************************************************************************
 * 2-stage shift register for storing & shifting out pixel data
 *****************************************************************************/

`ifndef VGASHIFTOUT
    `define VGASHIFTOUT

module vgaShiftOut (
    input wire nReset,
    input wire clk,
    input wire shiftEn,
    input wire nLoad1,
    input wire nLoad2,
    input logic [7:0] parIn,
    output wire out
);

    reg [7:0] inReg;
    reg [7:0] outReg;

    always @(posedge clk or negedge nReset) begin
        if(!nReset) inReg <= 0;
        else if(!nLoad1) inReg <= parIn;
    end

    always @(negedge clk or negedge nReset) begin
        if(!nReset) outReg <= 0;
        else begin
            if(!nLoad2) outReg <= inReg;
            else if(shiftEn) begin
                outReg[7] <= outReg[6];
                outReg[6] <= outReg[5];
                outReg[5] <= outReg[4];
                outReg[4] <= outReg[3];
                outReg[3] <= outReg[2];
                outReg[2] <= outReg[1];
                outReg[1] <= outReg[0];
                outReg[0] <= 0;
            end
        end
    end

    assign out = outReg[7];
endmodule

// module vgaShiftOut (
//     input wire nReset,
//     input wire clk,
//     input wire vidActive,
//     input logic [2:0] seq,
//     input logic [7:0] parIn,
//     output wire out
// );
//     /* Shift register functioning similar to a 74597, with 8-bit input latch
//      * and 8-bit PISO shift register output stage.
//      * In sequence 0 new data is loaded from VRAM into the input stage, and in
//      * sequence 1 the input stage is copied to the output stage to be shifted.
//      */
//     reg [7:0] inReg;
//     reg [7:0] outReg;

//     // to meet VRAM timing requirements, data from VRAM has to be clocked into
//     // our input register on the rising edge of the pixel clock
//     always @(posedge clk or negedge nReset) begin
//         if(nReset == 0) begin
//             inReg <= 0;
//         end else begin
//             if(seq == 0) begin
//                 inReg <= parIn;
//             end
//         end
//     end

//     // pixels are shifted out on the falling edge of the pixel clock
//     always @(negedge clk or negedge nReset) begin
//         if(nReset == 1'b0) begin
//             //inReg <= 0;
//             outReg <= 0;
//         end else begin
//             if(vidActive == 1'b1) begin
//                 if(seq == 0) begin
//                     outReg <= inReg;
//                 end else begin
//                     outReg[7] <= outReg[6];
//                     outReg[6] <= outReg[5];
//                     outReg[5] <= outReg[4];
//                     outReg[4] <= outReg[3];
//                     outReg[3] <= outReg[2];
//                     outReg[2] <= outReg[1];
//                     outReg[1] <= outReg[0];
//                     outReg[0] <= 1'b0;
//                 end
//             end
//         end
//     end
//     assign out = outReg[7];
// endmodule

`endif