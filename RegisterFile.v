module RegisterFile (
    input  wire clk,
    input  wire rst,
    input  wire WriteEnable,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    input  wire [4:0]  rd,
    input  wire [31:0] WriteData,
    output wire [31:0] ReadData1,
    output wire [31:0] ReadData2
);
    reg [31:0] regs [0:31]; 
    
    assign ReadData1 = (rs1 == 5'd0) ? 32'd0 : regs[rs1];
    assign ReadData2 = (rs2 == 5'd0) ? 32'd0 : regs[rs2];

    // -- Write: synchronous, x0 writes ignored --
    integer i;
   always @(posedge clk or posedge rst)
    if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end else if (WriteEnable && rd != 5'd0) begin
            regs[rd] <= WriteData;
        end

endmodule