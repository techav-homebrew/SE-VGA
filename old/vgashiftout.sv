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
    input wire nReset, clk, nLoad,
    input logic [7:0] parIn,
    output wire out
);

reg [8:0] shiftReg;

always @(negedge clk or negedge nReset) begin
    if(!nReset) shiftReg <= 0;
    else begin
        if(!nLoad) begin
            shiftReg[8] <= shiftReg[7];
            shiftReg[7:0] <= parIn;
        end else begin
            shiftReg[8:1] <= shiftReg[7:0];
            shiftReg[0] <= 0;
        end
    end
end

assign out = shiftReg[8];

endmodule

/*
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

    // load data into first stage register on rising edge of pixel clock
    // if nLoad1 is asserted
    always @(posedge clk or negedge nReset) begin
        if(!nReset) inReg <= 0;
        else if(!nLoad1) inReg <= parIn;
    end

    // load data into second stage register on falling edge of pixel clock
    // if nLoad2 is asserted, otherwise if shiftEn is asserted, then shift
    // video data out. Shift in 0 to fill empty registers
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

    // high-order bit of the shift register (second stage) is the serial output
    assign out = outReg[7];
endmodule
*/

`endif