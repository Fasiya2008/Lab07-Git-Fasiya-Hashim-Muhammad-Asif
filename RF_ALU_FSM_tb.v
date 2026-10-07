`timescale 1ns/1ps
module RF_ALU_FSM_tb;
    reg  clk, rst;
    wire [2:0]  state;
    wire [4:0]  rs1, rs2, rd;
    wire [31:0] WriteData;
    wire        WriteEnable;
    wire [3:0]  ALUControl;
    wire [31:0] ALUResult;
    wire        Zero;
    wire [2:0]  op_idx;

    RF_ALU_FSM dut (
        .clk(clk), .rst(rst), .state(state),
        .rs1(rs1), .rs2(rs2), .rd(rd),
        .WriteData(WriteData), .WriteEnable(WriteEnable),
        .ALUControl(ALUControl), .ALUResult(ALUResult), .Zero(Zero),
        .op_idx(op_idx)
    );

    always #5 clk = ~clk;

    localparam WRITE_REGISTERS = 3'd6;

    // Expected result for each of the 8 operations
    // (A = x1 = 0x10101010, B = x2 = 0x01010101)
    reg [31:0]  expected [0:7];
    reg [127:0] opname   [0:7];
    initial begin
        expected[0] = 32'h11111111; opname[0] = "ADD";
        expected[1] = 32'h0F0F0F0F; opname[1] = "SUB";
        expected[2] = 32'h00000000; opname[2] = "AND";
        expected[3] = 32'h11111111; opname[3] = "OR";
        expected[4] = 32'h11111111; opname[4] = "XOR";
        expected[5] = 32'h20202020; opname[5] = "SLL";
        expected[6] = 32'h08080808; opname[6] = "SRL";
        expected[7] = 32'h00000000; opname[7] = "BEQ-flag"; // x1 != x2, so flag = 0
    end

    reg [2:0] prev_state;
    reg [2:0] check_idx;
    integer   pass_count, fail_count, i;

    initial begin
        $dumpfile("rf_alu_fsm_tb.vcd");
        $dumpvars(0, RF_ALU_FSM_tb);

        clk = 0; rst = 1; pass_count = 0; fail_count = 0; check_idx = 0; prev_state = 0;
        @(negedge clk);
        rst = 0;

        // Full pass = 4 init cycles + 8 ops x 3 cycles each = 28 edges
        for (i = 0; i < 28; i = i + 1) begin
            @(posedge clk);
            #1; // let registered outputs settle
            if (prev_state == WRITE_REGISTERS && state != WRITE_REGISTERS && check_idx <= 7) begin
                if (WriteData === expected[check_idx]) begin
                    $display("PASS %-10s rd=x%0d WriteData=%h", opname[check_idx], rd, WriteData);
                    pass_count = pass_count + 1;
                end else begin
                    $display("FAIL %-10s rd=x%0d WriteData=%h (expected %h)",
                               opname[check_idx], rd, WriteData, expected[check_idx]);
                    fail_count = fail_count + 1;
                end
                check_idx = check_idx + 1;
            end
            prev_state = state;
        end

        $display("---------------------------------------------");
        $display("RF+ALU+FSM integration: %0d PASS, %0d FAIL (of 8)", pass_count, fail_count);

        #10 $finish;
    end
endmodule