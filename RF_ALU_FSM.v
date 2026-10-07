module RF_ALU_FSM (
    input  wire  clk,
    input  wire        rst,
    output reg  [2:0]  state,
    output reg  [4:0]  rs1,
    output reg  [4:0]  rs2,
    output reg  [4:0]  rd,
    output reg  [31:0] WriteData,
    output reg         WriteEnable,
    output reg  [3:0]  ALUControl,
    output wire [31:0] ALUResult,
    output wire        Zero,
    output reg  [2:0]  op_idx
);
    // -- States --
    localparam IDLE            = 3'd0;
    localparam INIT_X1         = 3'd1;
    localparam INIT_X2         = 3'd2;
    localparam INIT_X3         = 3'd3;
    localparam READ_REGISTERS  = 3'd4;
    localparam ALU_OPERATION   = 3'd5;
    localparam WRITE_REGISTERS = 3'd6;

    // -- Operation table: ALUControl code + destination register per step --
    reg [3:0] op_code  [0:7];
    reg [4:0] dest_reg [0:7];
    initial begin
        op_code[0] = 4'b0000; dest_reg[0] = 5'd4;  // ADD -> x4
        op_code[1] = 4'b0001; dest_reg[1] = 5'd5;  // SUB -> x5
        op_code[2] = 4'b0010; dest_reg[2] = 5'd6;  // AND -> x6
        op_code[3] = 4'b0011; dest_reg[3] = 5'd7;  // OR  -> x7
        op_code[4] = 4'b0100; dest_reg[4] = 5'd8;  // XOR -> x8
        op_code[5] = 4'b0101; dest_reg[5] = 5'd9;  // SLL -> x9
        op_code[6] = 4'b0110; dest_reg[6] = 5'd10; // SRL -> x10
        op_code[7] = 4'b0111; dest_reg[7] = 5'd11; // BEQ -> x11 (flag)
    end

    // -- Register file and ALU --
    wire [31:0] ReadData1, ReadData2;

    RegisterFile u_rf (
        .clk(clk), .rst(rst), .WriteEnable(WriteEnable),
        .rs1(rs1), .rs2(rs2), .rd(rd), .WriteData(WriteData),
        .ReadData1(ReadData1), .ReadData2(ReadData2)
    );

    ALU_top u_alu (
        .A(ReadData1), .B(ReadData2),
        .ALUControl(ALUControl),
        .ALUResult(ALUResult), .Zero(Zero)
    );

    // -- FSM --
    always @(posedge clk) begin
    if (rst) begin
            state <= IDLE;
            rs1 <= 0; rs2 <= 0; rd <= 0; WriteData <= 0;
            WriteEnable <= 0; ALUControl <= 0; op_idx <= 0;
        end else begin
            case (state)
                IDLE: begin
                    WriteEnable <= 0;
                    state <= INIT_X1;
                end
                INIT_X1: begin
                    rd <= 5'd1; WriteData <= 32'h10101010; WriteEnable <= 1'b1;
                    state <= INIT_X2;
                end
                INIT_X2: begin
                    rd <= 5'd2; WriteData <= 32'h01010101; WriteEnable <= 1'b1;
                    state <= INIT_X3;
                end
                INIT_X3: begin
                    rd <= 5'd3; WriteData <= 32'h00000005; WriteEnable <= 1'b1;
                    op_idx <= 0;
                    state <= READ_REGISTERS;
                end
                READ_REGISTERS: begin
                    WriteEnable <= 0;
                    rs1 <= 5'd1; rs2 <= 5'd2;   // read x1, x2
                    state <= ALU_OPERATION;
                end
                ALU_OPERATION: begin
                    ALUControl <= op_code[op_idx]; // result settles combinationally
                    state <= WRITE_REGISTERS;
                end
                WRITE_REGISTERS: begin
                    rd <= dest_reg[op_idx];
                    WriteData <= (op_idx == 3'd7) ? {31'd0, Zero} : ALUResult;
                    WriteEnable <= 1'b1;
                    if (op_idx == 3'd7) begin
                        op_idx <= 0;
                        state  <= IDLE;              // all 8 ops done
                    end else begin
                        op_idx <= op_idx + 1'b1;
                        state  <= READ_REGISTERS;     // next operation
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule