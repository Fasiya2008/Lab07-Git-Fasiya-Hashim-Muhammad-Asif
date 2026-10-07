module seg7_driver (
    input  wire       clk,
    input  wire [4:0] rd,      // register number being written
    output reg  [6:0] seg,     // active low
    output reg  [3:0] an       // active low
);

    reg [16:0] refresh = 0;
    always @(posedge clk) refresh <= refresh + 1'b1;

    // Split into tens and ones (decimal)
    wire [3:0] rd_tens = (rd >= 30) ? 4'd3 :
                         (rd >= 20) ? 4'd2 :
                         (rd >= 10) ? 4'd1 : 4'd0;
    wire [4:0] rd_rem  = rd - (rd_tens * 5'd10);
    wire [3:0] rd_ones = rd_rem[3:0];

    // Two digits only (right side), the left two stay off
    reg [3:0] digit;
    always @(*) begin
        case (refresh[16])
            1'b0: begin an = 4'b1110; digit = rd_ones; end
            1'b1: begin an = 4'b1101; digit = rd_tens; end
        endcase
    end

    always @(*) begin
        case (digit)
            4'd0: seg = 7'b1000000;
            4'd1: seg = 7'b1111001;
            4'd2: seg = 7'b0100100;
            4'd3: seg = 7'b0110000;
            4'd4: seg = 7'b0011001;
            4'd5: seg = 7'b0010010;
            4'd6: seg = 7'b0000010;
            4'd7: seg = 7'b1111000;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0010000;
            default: seg = 7'b1111111;
        endcase
    end

endmodule