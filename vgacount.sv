/******************************************************************************
 * SE-VGA
 * VGA signal counter
 * techav
 * 2021-04-06
 ******************************************************************************
 * Low-level VGA signal counter
 *****************************************************************************/

module vgacount (
    input wire              nReset,         // system reset signal
    input wire              clock,          // counter increment clock
    output logic [9:0]     count,          // count output
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
    if(hCount >= SYNCBEGIN && hCount < SYNCEND) begin
        nhSync <= 1'b0;
    end else begin
        nhSync <= 1'b1;
    end

    if(hCount >= ACTBEGIN && hCount < ACTEND) begin
        hActive <= 1'b0;
    end else begin
        hActive <= 1'b1;
    end

    if(hCount >= SEACTBEGIN) begin
        hSEActive <= 1'b0;
    end else begin
        hSEActive <= 1'b1;
    end
end

endmodule