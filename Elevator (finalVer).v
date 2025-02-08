`timescale 1ns / 1ps

module Elevator
(
    input   wire            clk,    //100MHz
    input   wire            rst,    //复位 (绑定开关，打开开关为复位)
    input   wire            key1,   //1楼按键
    input   wire            key2,   //2楼按键
    input   wire            key3,   //3楼按键
    input   wire            key4,   //4楼按键
    input   wire            key5,   //5楼按键
    output  wire    [4:0]   led,    //各楼层请求的LED灯
    output  wire    [3:0]   AN,     //数码管位选
    output  wire    [7:0]   seg     //数码管段选
);

    localparam STATE_STOP           =       3'b000;
    localparam STATE_UPWARD         =       3'b001;    
    localparam STATE_UPWARD_STOP    =       3'b010;
    localparam STATE_DOWNWARD       =       3'b011;
    localparam STATE_DOWNWARD_STOP  =       3'b100;

    reg [2:0]   state_q; 
    reg [2:0]   next_state;   

    reg [25:0]  counter_1s_q;
    reg         clk_1s_q;
    reg [25:0]  counter_05s_q;
    reg         clk_05s_q;

    reg [1:0]   cnt_3s_q;

    reg         key1_sync;
    reg         key1_last;
    wire        key1_detected;

    reg         key2_sync;
    reg         key2_last;
    wire        key2_detected;

    reg         key3_sync;
    reg         key3_last;
    wire        key3_detected;

    reg         key4_sync;
    reg         key4_last;
    wire        key4_detected;

    reg         key5_sync;
    reg         key5_last;
    wire        key5_detected;

    reg [2:0]   current_floor_q;

    reg [16:0]  clk_an_count_q;
    reg [3:0]   an_select;
    reg [7:0]   display;

    //向上楼层检测 (基于当前楼层)
    reg detected_upper_floor;
    //向下楼层检测 (基于当前楼层)
    reg detected_lower_floor;

    reg [2:0] current_floor_dly1_q;

    //1s clock
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter_1s_q <= 0;
            clk_1s_q <= 0;
        end 
        else begin
            //100MHz to 1Hz
            if (counter_1s_q == (26'd50_000_000-26'd1)) begin
                counter_1s_q <= 0;
                clk_1s_q <= ~clk_1s_q; 
            end 
            else begin
                counter_1s_q <= counter_1s_q + 1;
            end
        end
    end

    //0.5s clock
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter_05s_q <= 0;
            clk_05s_q <= 0;
        end 
        else begin
            //100MHz to 1Hz
            if (counter_05s_q == (26'd25_000_000-26'd1)) begin
                counter_05s_q <= 0;
                clk_05s_q <= ~clk_05s_q; 
            end 
            else begin
                counter_05s_q <= counter_05s_q + 1;
            end
        end
    end

    //stop time
    always @(posedge clk_1s_q or posedge rst) begin
        if (rst) begin
            cnt_3s_q <= 0;
        end 
        else begin
            if (cnt_3s_q == 2'd3) begin
                cnt_3s_q <= 0;
            end 
            else if ((state_q==STATE_DOWNWARD_STOP) | (state_q==STATE_UPWARD_STOP))begin
                cnt_3s_q <= cnt_3s_q + 1;
            end
        end
    end

//按键检测
always @(posedge clk_05s_q or posedge rst) begin
    if (rst) 
    begin
        key1_sync <= 1'b0;
        key1_last <= 1'b0;
    end 
    else 
    begin
        key1_last <= key1_sync;
        key1_sync <= key1;
    end
end
assign key1_detected = (~key1_last & key1_sync);

always @(posedge clk_05s_q or posedge rst) begin
    if (rst) 
    begin
        key2_sync <= 1'b0;
        key2_last <= 1'b0;
    end 
    else 
    begin
        key2_last <= key2_sync;
        key2_sync <= key2;
    end
end
assign key2_detected = (~key2_last & key2_sync);

always @(posedge clk_05s_q or posedge rst) begin
    if (rst) 
    begin
        key3_sync <= 1'b0;
        key3_last <= 1'b0;
    end 
    else 
    begin
        key3_last <= key3_sync;
        key3_sync <= key3;
    end
end
assign key3_detected = (~key3_last & key3_sync);

always @(posedge clk_05s_q or posedge rst) begin
    if (rst) 
    begin
        key4_sync <= 1'b0;
        key4_last <= 1'b0;
    end 
    else 
    begin
        key4_last <= key4_sync;
        key4_sync <= key4;
    end
end
assign key4_detected = (~key4_last & key4_sync);

always @(posedge clk_05s_q or posedge rst) begin
    if (rst) 
    begin
        key5_sync <= 1'b0;
        key5_last <= 1'b0;
    end 
    else 
    begin
        key5_last <= key5_sync;
        key5_sync <= key5;
    end
end
assign key5_detected = (~key5_last & key5_sync);

    always @(posedge clk_05s_q or posedge rst) begin
        if (rst) begin
            current_floor_q <= 3'd1;
        end 
        else if ((current_floor_q!=3'd5) & (state_q==STATE_UPWARD) & detected_upper_floor) begin
                current_floor_q <= current_floor_q+1;
        end 
        else if ((current_floor_q!=3'd1) & (state_q==STATE_DOWNWARD) & detected_lower_floor)begin
                current_floor_q <= current_floor_q-1;
        end
    end

    always @(posedge clk_05s_q or posedge rst) begin
        if (rst) begin
            current_floor_dly1_q <= 3'd1;
        end 
        else begin
            current_floor_dly1_q <= current_floor_q;
        end
    end

//数码管扫描
always @(posedge clk or posedge rst) begin
    if (rst) begin
        clk_an_count_q <= 17'b0;
    end
    else if (clk_an_count_q[16:15]==2'b11)
        clk_an_count_q <= 17'b0;
    else begin
        clk_an_count_q <= clk_an_count_q + 1;
    end
end

//扫描到的数码管对应的内容
always @ (*) begin
    case (clk_an_count_q[16:15])
        3'd0: begin an_select = 4'b1110; end
        3'd1: begin an_select = 4'b1101; end
        3'd2: begin an_select = 4'b1011; end
        3'd3: begin an_select = 4'b0111; end
        default: begin an_select = 4'b1111; end
    endcase
end

//把要显示的数字转换成数码管要点亮的段
always @ (*) begin
    case (current_floor_dly1_q)
        4'd0: display = 8'b11000000;
        4'd1: display = 8'b11111001;
        4'd2: display = 8'b10100100;
        4'd3: display = 8'b10110000;
        4'd4: display = 8'b10011001;
        4'd5: display = 8'b10010010;
        4'd6: display = 8'b10000010;
        4'd7: display = 8'b11111000;
        4'd8: display = 8'b10000000;
        4'd9: display = 8'b10010000;
        default: display = 8'b11000000; //0
    endcase
end

    //数码管输出
    assign seg = display[7:0];
    assign AN = an_select[3:0];

    reg [5:0]   detected_floor_q;
    always @(posedge clk_05s_q or posedge rst) begin
        if (rst) begin
            detected_floor_q[0] <= 0;
        end 
        else begin
            detected_floor_q[0] <= 0;
        end
    end

    always @(posedge clk_05s_q or posedge rst) begin
        if (rst) begin
            detected_floor_q[1] <= 0;
        end 
        else if (((state_q==STATE_UPWARD) | (state_q==STATE_DOWNWARD)) & (current_floor_q==3'd1)) begin
            detected_floor_q[1] <= 0;
        end
        else if (key1_detected==1'b1) begin
            detected_floor_q[1] <= 1;
        end
    end

    always @(posedge clk_05s_q or posedge rst) begin
        if (rst) begin
            detected_floor_q[2] <= 0;
        end 
        else if (((state_q==STATE_UPWARD) | (state_q==STATE_DOWNWARD)) & (current_floor_q==3'd2)) begin
            detected_floor_q[2] <= 0;
        end
        else if (key2_detected==1'b1) begin
            detected_floor_q[2] <= 1;
        end
    end

    always @(posedge clk_05s_q or posedge rst) begin
        if (rst) begin
            detected_floor_q[3] <= 0;
        end 
        else if (((state_q==STATE_UPWARD) | (state_q==STATE_DOWNWARD)) & (current_floor_q==3'd3)) begin
            detected_floor_q[3] <= 0;
        end
        else if (key3_detected==1'b1) begin
            detected_floor_q[3] <= 1;
        end
    end

    always @(posedge clk_05s_q or posedge rst) begin
        if (rst) begin
            detected_floor_q[4] <= 0;
        end 
        else if (((state_q==STATE_UPWARD) | (state_q==STATE_DOWNWARD)) & (current_floor_q==3'd4)) begin
            detected_floor_q[4] <= 0;
        end
        else if (key4_detected==1'b1) begin
            detected_floor_q[4] <= 1;
        end
    end

    always @(posedge clk_05s_q or posedge rst) begin
        if (rst) begin
            detected_floor_q[5] <= 0;
        end 
        else if (((state_q==STATE_UPWARD) | (state_q==STATE_DOWNWARD)) & (current_floor_q==3'd5)) begin
            detected_floor_q[5] <= 0;
        end
        else if (key5_detected==1'b1) begin
            detected_floor_q[5] <= 1;
        end
    end

    //led输出
    assign led = detected_floor_q[5:1];

    always @ (*) begin
    case (current_floor_q)
        3'd1: detected_upper_floor = |(detected_floor_q[5:2]);
        3'd2: detected_upper_floor = |(detected_floor_q[5:3]);
        3'd3: detected_upper_floor = |(detected_floor_q[5:4]);
        3'd4: detected_upper_floor = |(detected_floor_q[5]);
        3'd5: detected_upper_floor = 1'b0;
        default: detected_upper_floor = 1'b0; //0
    endcase
    end

    always @ (*) begin
    case (current_floor_q)
        3'd1: detected_lower_floor = 1'b0;
        3'd2: detected_lower_floor = |(detected_floor_q[1]);
        3'd3: detected_lower_floor = |(detected_floor_q[2:1]);
        3'd4: detected_lower_floor = |(detected_floor_q[3:1]);
        3'd5: detected_lower_floor = |(detected_floor_q[4:1]);
        default: detected_lower_floor = 1'b0; //0
    endcase
    end

    //状态机
    always @ (posedge clk_05s_q or posedge rst)
    begin
        if (rst) begin
            state_q <= STATE_STOP;
        end
        else begin
            state_q <= next_state;
        end
    end    

    always @ (*) 
    begin
        case(state_q)
            STATE_STOP: begin
                //检测到上面楼层有人按键
                if ((current_floor_q!=3'd5) & detected_upper_floor)
                    next_state = STATE_UPWARD;
                //检测到下面楼层有人按键
                else if ((current_floor_q!=3'd1) & detected_lower_floor)
                    next_state = STATE_DOWNWARD;
                else
                    next_state = STATE_STOP;
            end
            STATE_UPWARD:begin
                //当前楼层有人按键，则停下3秒
                if (detected_floor_q[current_floor_q]==1'b1)
                    next_state = STATE_UPWARD_STOP;
                //否则，当上面楼层还有人按键时，每秒上升一层
                else if (detected_upper_floor)
                    next_state = STATE_UPWARD;
                //否则跳转回停止状态
                else
                    next_state = STATE_STOP;
            end
            STATE_UPWARD_STOP:begin
                //3秒中后回到STATE_UPWARD
                if (cnt_3s_q == 2'd3)
                    next_state = STATE_UPWARD;
            end
            STATE_DOWNWARD:begin
                //当前楼层有人按键，则停下3秒
                if (detected_floor_q[current_floor_q]==1'b1)
                    next_state = STATE_DOWNWARD_STOP;
                //否则，当下面楼层还有人按键时，每秒下降一层    
                else if (detected_lower_floor)
                    next_state = STATE_DOWNWARD;
                //否则跳转回停止状态
                else
                    next_state = STATE_STOP;
            end
            STATE_DOWNWARD_STOP:begin
                //3秒中后回到STATE_DOWNWARD
                if (cnt_3s_q == 2'd3)
                    next_state = STATE_DOWNWARD;
            end
            default: begin next_state = state_q; end
        endcase
    end     
endmodule
