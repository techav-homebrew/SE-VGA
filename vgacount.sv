/******************************************************************************
 * SE-VGA
 * VGA signal counter
 * techav
 * 2021-04-06
 ******************************************************************************
 * Low-level VGA signal counter
 *****************************************************************************/

`ifndef VGACOUNT
    `define VGACOUNT

module vgacount (
    input wire              nReset,         // system reset signal
    input wire              clock,          // counter increment clock
    output logic [9:0]      count,          // count output
    output wire             nSync,          // sync pulse
    output wire             activeVid,      // active video signal
    output wire             activeSE        // secondary active video signal (SE)
);

parameter   COUNTMAX=800,       // Total dot count per line or line count per frame
            SYNCBEGIN=592,      // Dot/Line count where sync pulse begins
            SYNCEND=688,        // Dot/Line count +1 where sync pulse ends
            ACTBEGIN=576,       // Dot/Line count where VGA active video begins
            ACTEND=736,         // Dot/Line count +1 where VGA active video ends
            SEACTBEGIN=512;     // Dot/Line count +1 where SE video window ends

logic [9:0] counter;

// primary counter
always @(negedge clock or negedge nReset) begin
    if(nReset == 1'b0) begin
        counter <= 10'h0;
    end else begin
        if (counter < COUNTMAX) begin
            counter <= counter + 10'h1;
        end else begin
            counter <= 10'h0;
        end
    end
end


// combinatorial logic derived from the counters
always_comb begin
    // output the count signals
    count <= counter;

    // Sync pulse
    if(count >= SYNCBEGIN && count < SYNCEND) begin
        nSync <= 1'b0;
    end else begin
        nSync <= 1'b1;
    end

    // VGA active video range
    if(count >= ACTBEGIN && count < ACTEND) begin
        activeVid <= 1'b0;
    end else begin
        activeVid <= 1'b1;
    end

    // SE active video window within VGA active video range
    if(count >= SEACTBEGIN) begin
        activeSE <= 1'b0;
    end else begin
        activeSE <= 1'b1;
    end
end

endmodule

`endif