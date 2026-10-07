module top_rf_alu #(
    parameter TICK_MAX = 27'd99_999_999   
) (
    input  wire        clk,
    input  wire        pbin,
    input  wire [15:0] physical_sw,
    output wire [15:0] physical_leds,
    output wire [6:0]  seg,
    output wire [3:0]  an
);

    wire rst_clean;
    debouncer rst_db (
        .clk  (clk),
        .pbin (pbin),
        .pbout(rst_clean)
    );

    wire [31:0] switch_data;
    leds switch_reader (
        .clk(clk), .rst(rst_clean),
        .btns(16'd0), .writeData(32'd0), .writeEnable(1'b0),
        .readEnable(1'b1), .memAddress(30'd0),
        .switches(physical_sw), .readData(switch_data)
    );

    reg [31:0] led_write_data = 32'd0;
    switches led_writer (
        .clk(clk), .rst(rst_clean),
        .writeData(led_write_data), .writeEnable(1'b1),
        .readEnable(1'b0), .memAddress(30'd0),
        .readData(), .leds(physical_leds)
    );

    // -- Mode / manual-control switches --
    wire       mode        = switch_data[10];      // 0=AUTO, 1=MANUAL
    wire [3:0] manual_ctrl = switch_data[3:0];
    wire [4:0] manual_rd   = switch_data[8:4];
    wire       manual_we   = switch_data[9];

    // -- Register file + ALU (single shared instance of each) --
    wire [4:0]  rs1, rs2, final_rd;
    wire [31:0] WriteData_final;
    wire        WriteEnable_final;
    wire [3:0]  ALUControl_final;
    wire [31:0] ReadData1, ReadData2, ALUResult;
    wire        Zero;

    RegisterFile u_rf (
        .clk(clk), .rst(rst_clean), .WriteEnable(WriteEnable_final),
        .rs1(rs1), .rs2(rs2), .rd(final_rd), .WriteData(WriteData_final),
        .ReadData1(ReadData1), .ReadData2(ReadData2)
    );

    ALU_top u_alu (
        .A(ReadData1), .B(ReadData2),
        .ALUControl(ALUControl_final),
        .ALUResult(ALUResult), .Zero(Zero)
    );

    reg [26:0] cnt = 0;
    wire tick = (cnt == TICK_MAX);
    always @(posedge clk or posedge rst_clean) begin
        if (rst_clean)  cnt <= 0;
        else if (tick)  cnt <= 0;
        else            cnt <= cnt + 1'b1;
    end
    localparam IDLE = 3'd0, INIT_X1 = 3'd1, INIT_X2 = 3'd2, INIT_X3 = 3'd3,
               READ_REGISTERS = 3'd4, ALU_OPERATION = 3'd5, WRITE_REGISTERS = 3'd6;

    reg [2:0]  auto_state;
    reg [4:0]  auto_rd;
    reg [31:0] auto_WriteData;
    reg        auto_WE;
    reg [3:0]  auto_ALUControl;
    reg [2:0]  op_idx;

    reg [3:0] op_code  [0:7];
    reg [4:0] dest_reg [0:7];
    initial begin
        op_code[0]=4'b0000; dest_reg[0]=5'd4;  op_code[1]=4'b0001; dest_reg[1]=5'd5;
        op_code[2]=4'b0010; dest_reg[2]=5'd6;  op_code[3]=4'b0011; dest_reg[3]=5'd7;
        op_code[4]=4'b0100; dest_reg[4]=5'd8;  op_code[5]=4'b0101; dest_reg[5]=5'd9;
        op_code[6]=4'b0110; dest_reg[6]=5'd10; op_code[7]=4'b0111; dest_reg[7]=5'd11;
    end

    assign rs1 = 5'd1;
    assign rs2 = 5'd2;

    always @(posedge clk or posedge rst_clean) begin
        if (rst_clean) begin
            auto_state <= IDLE; auto_rd <= 0; auto_WriteData <= 0;
            auto_WE <= 0; auto_ALUControl <= 0; op_idx <= 0;
        end else if (tick) begin
            case (auto_state)
                IDLE: begin auto_WE <= 0; auto_state <= INIT_X1; end
                INIT_X1: begin auto_rd<=5'd1; auto_WriteData<=32'h10101010; auto_WE<=1; auto_state<=INIT_X2; end
                INIT_X2: begin auto_rd<=5'd2; auto_WriteData<=32'h01010101; auto_WE<=1; auto_state<=INIT_X3; end
                INIT_X3: begin auto_rd<=5'd3; auto_WriteData<=32'h00000005; auto_WE<=1; op_idx<=0; auto_state<=READ_REGISTERS; end
                READ_REGISTERS: begin auto_WE<=0; auto_state<=ALU_OPERATION; end
                ALU_OPERATION: begin auto_ALUControl<=op_code[op_idx]; auto_state<=WRITE_REGISTERS; end
                WRITE_REGISTERS: begin
                    auto_rd <= dest_reg[op_idx];
                    auto_WriteData <= (op_idx==3'd7) ? {31'd0,Zero} : ALUResult;
                    auto_WE <= 1;
                    if (op_idx==3'd7) begin op_idx<=0; auto_state<=IDLE; end
                    else begin op_idx<=op_idx+1'b1; auto_state<=READ_REGISTERS; end
                end
                default: auto_state <= IDLE;
            endcase
        end
    end

    assign ALUControl_final = mode ? manual_ctrl : auto_ALUControl;
    assign final_rd         = mode ? manual_rd   : auto_rd;
    assign WriteEnable_final = mode ? manual_we  : auto_WE;
    assign WriteData_final  = mode ? ALUResult   : auto_WriteData;


    always @(posedge clk) begin
        led_write_data <= {16'd0, (mode ? 3'b000 : auto_state), 3'b000, ALUResult[9:0]};
    end

   
    reg [4:0] disp_rd = 0;
    always @(posedge clk or posedge rst_clean) begin
        if (rst_clean)              disp_rd <= 0;
        else if (WriteEnable_final) disp_rd <= final_rd;
    end

    seg7_driver u_seg (
        .clk(clk),
        .rd(disp_rd),
        .seg(seg),
        .an(an)
    );

endmodule