`timescale 1ns/1ps
module RegisterFile_tb;
    reg  clk, rst, WriteEnable;
    reg  [4:0]  rs1, rs2, rd;
    reg  [31:0] WriteData;
    wire [31:0] ReadData1, ReadData2;

    RegisterFile dut (
        .clk(clk), .rst(rst), .WriteEnable(WriteEnable),
        .rs1(rs1), .rs2(rs2), .rd(rd), .WriteData(WriteData),
        .ReadData1(ReadData1), .ReadData2(ReadData2)
    );

    // Free-running clock
    always #5 clk = ~clk;

    // -- Write one register, waiting for the clock edge to land it --
    task write_reg(input [4:0] addr, input [31:0] data);
        begin
            @(negedge clk);
            rd = addr; WriteData = data; WriteEnable = 1'b1;
            @(posedge clk);
            @(negedge clk);
            WriteEnable = 1'b0;
        end
    endtask

    // -- Read both ports and print a pass/fail check --
    task check_read(input [4:0] addr1, input [31:0] expected1,
                     input [4:0] addr2, input [31:0] expected2,
                     input [127:0] name);
        begin
            rs1 = addr1; rs2 = addr2;
            #1; // let combinational reads settle
            if (ReadData1 === expected1 && ReadData2 === expected2)
                $display("PASS %-20s RD1=%h RD2=%h", name, ReadData1, ReadData2);
            else
                $display("FAIL %-20s RD1=%h (exp %h) RD2=%h (exp %h)",
                           name, ReadData1, expected1, ReadData2, expected2);
        end
    endtask

    initial begin
        $dumpfile("regfile_tb.vcd");
        $dumpvars(0, RegisterFile_tb);

        clk = 0; rst = 1; WriteEnable = 0; rs1 = 0; rs2 = 0; rd = 0; WriteData = 0;
        @(negedge clk); // apply reset for one clock edge
        rst = 0;

        // Test 1: write then read back
        write_reg(5, 32'hDEADBEEF);
        check_read(5, 32'hDEADBEEF, 0, 32'd0, "write-then-read");

        // Test 2: x0 stays zero
        write_reg(0, 32'hFFFFFFFF);
        check_read(0, 32'd0, 0, 32'd0, "x0-write-ignored");

        // Test 3: two simultaneous reads
        write_reg(6, 32'h11111111);
        check_read(5, 32'hDEADBEEF, 6, 32'h11111111, "dual-read-ports");

        // Test 4: overwrite
        write_reg(5, 32'hCAFEBABE);
        check_read(5, 32'hCAFEBABE, 0, 32'd0, "overwrite");

        // Test 5: reset clears everything
        rst = 1;
        @(negedge clk);
        rst = 0;
        check_read(5, 32'd0, 6, 32'd0, "reset-clears-all");

        #10 $finish;
    end
endmodule