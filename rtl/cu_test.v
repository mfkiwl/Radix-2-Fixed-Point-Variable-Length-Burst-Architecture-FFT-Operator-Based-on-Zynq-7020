`timescale 1ns / 1ps


module cu_test
(
    input  wire        i_clk,            // 外部时钟信号
    input  wire        i_rst_n,            // 外部复位信号
    input  wire [4:0]  i_n_cfg,           // FFT配置信号输入，至多为2^31，远大于P_NMAX=8192点的设计需求
    input  wire        i_n_cfg_valid,     // FFT配置信号有效输入
    
    input  wire        i_data_in_valid,  // 外部数据输入有效信号,一直拉高
    input  wire        i_store_end,       // store完成信号,from ram
    input  wire        i_cal_end,       // calculation完成信号,from ram
    input  wire        i_output_end,       // output完成信号,from ram
    output wire [4:0]  o_current_n_cfg,   //当前FFT点数, to ram

    output reg  [1:0]  o_ram1_ctrl,  //控制pingpong_ram1的读写,默认00,read=01,write=10,to pingpongram
    output reg  [1:0]  o_ram2_ctrl,  //控制pingpong_ram2的读写,默认00,read=01,write=10,to pingpongram

    output reg         o_store_valid,    //输入阶段地址有效信号,to ram
    output reg  [15:0] o_store_addr,     //输入阶段的地址信号,to ram

    output reg  [15:0] o_di_1_addr,      // 数据1地址,to ram
    output reg  [15:0] o_di_2_addr,      // 数据2地址,to ram
    output reg         o_di_valid,       // 运算阶段数据有效信号,to ram
           

    output reg  [15:0] o_wc_addr,         // 放缩后的旋转因子地址,to ram
    output reg         o_wc_out_valid,    // 运算阶段旋转因子有效信号,to ram

    output reg         o_d_out_valid,    // 输出阶段有效信号,to ram
    output reg  [15:0] o_d_out_addr,     // 输出数据地址,to ram
    output reg         o_idle_out        // 空闲状态有效信号,to 外部
    );
    

    // 状态定义
    localparam S_IDLE      = 3'd0;
    localparam S_STORE     = 3'd1;
    localparam S_COLUMN    = 3'd2;
    localparam S_GROUP     = 3'd3;
    localparam S_INTERNAL  = 3'd4;
    localparam S_DELAY     = 3'd5;
    localparam S_OUTPUT    = 3'd6;

    localparam P_NMAX = 8192;  //最大支持8192点，可以再改
    

    reg [2:0] current_state;
    reg [2:0] next_state;
    reg [4:0] n_cfg_reg; //用于储存这一轮计算和输入的点数

    //----------------Sort_Unit signals----------------
    reg sort_end;
    reg [16:0] cur_rev; // input count to be reversed, 2^i_n_cfg-1(i_n_cfg=5) = 16, maximum 16 bit = 65536 points FFT;

    //reg [15:0] store_cnt; 
    //reg [15:0] store_cnt_reg; //用于打拍进行延迟,if needed
    //reg [15:0] store_cnt_max; 
    

    // 计数器
    reg [15:0] column_cnt;       // 用于计算阶段的计数
    reg [15:0] group_cnt;        // 用于计算阶段的计数
    reg [15:0] internal_cnt;     // 用于计算阶段的计数
    reg [15:0] output_cnt;       // 用于输出阶段的计数
    reg [15:0] column_cnt_reg;   // 用于储存上一个计数
    reg [15:0] group_cnt_reg;    // 用于储存上一个计数
    reg [15:0] internal_cnt_reg; // 用于储存上一个计数
    //reg [15:0] output_cnt_reg;   // 用于储存上一个计数*/
    reg [15:0] column_cnt_max;   // 用于计算阶段的计数
    reg [15:0] group_cnt_max;    // 用于计算阶段的计数
    reg [15:0] internal_cnt_max; // 用于计算阶段的计数
    reg [15:0] output_cnt_max;   // 用于输出阶段的计数
    
    reg store_end_reg;
    reg cal_end_reg;
    reg output_end_reg;
    integer i;
    


    always @(posedge i_clk or negedge i_rst_n) begin //打拍
    if (!i_rst_n) begin
        n_cfg_reg <= 'd0;       
        column_cnt_max <= 'd0;
        output_cnt_max <= 'd0;
        store_end_reg <= 0;
        cal_end_reg <= 0;
        output_end_reg <= 0;
    end else begin
        store_end_reg <= 0;
        cal_end_reg <= 0;
        output_end_reg <= 0;
        if (i_n_cfg_valid) begin
            n_cfg_reg <= i_n_cfg;
            column_cnt_max <= i_n_cfg -1; 
            output_cnt_max <= (1 << i_n_cfg) - 1; // 2^i_n_cfg - 1
        end
        if (i_store_end) begin
           store_end_reg <= i_store_end;
        end
        if (i_cal_end) begin
           cal_end_reg <= i_cal_end;
        end
        if (i_output_end) begin
           output_end_reg <= i_output_end;
        end
    end
end

    assign o_current_n_cfg = n_cfg_reg;//输出current_n_cfg供其他模块使用

    

    
    

// 第一段（时序逻辑，用于描述状态寄存器)
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            current_state <= S_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

// 第二段（组合逻辑，用于状态转移条件判断）
always @(*) begin
    next_state = current_state;
    case (current_state)
        S_IDLE: begin
            if (i_data_in_valid) begin
                next_state = S_STORE;
            end
            else next_state = S_IDLE;
        end

        S_STORE: begin
            if (sort_end) begin
                next_state = S_DELAY;
            end
            else next_state = S_STORE;
        end

        S_COLUMN: begin
            if (column_cnt_reg != column_cnt_max ) begin
                next_state = S_GROUP; //代表要进行下一列的计算
            end else begin
                next_state = S_DELAY; //代表最后一列计算也完成了
            end
        end

        S_GROUP: begin
            if (group_cnt_max == 0) begin 
//这种情况比较特殊，以8点的为例，当col=2(最后一层)时,group_cnt_max=0,此时正好group_cnt_reg也是0
//在判断时，会误以为该group已经算完，跳回到COLUMN,因此，要引入internal_cnt_reg != internal_cnt_max的判断来证明该group还没算完
                 if (internal_cnt_reg != internal_cnt_max) begin
                 next_state = S_INTERNAL; //代表列内计算还没完成
                 end
                 else begin
                 next_state = S_COLUMN;
                 end         
            end    
            else if (group_cnt_reg != group_cnt_max) begin
                next_state = S_INTERNAL; //代表列内计算还没完成
            end else begin
                next_state = S_COLUMN; //代表列内计算已经完成
            end
        end
        

        S_INTERNAL: begin
            
            if (internal_cnt != internal_cnt_max) begin
                next_state = S_INTERNAL; //代表组内计算还没完成
            end else begin
                next_state = S_GROUP; //代表组内计算已经完成
            end
        end

        S_DELAY: begin
            if (i_store_end || store_end_reg) begin
              next_state = S_COLUMN; //计算完成，进入输出状态
            end
            else if (i_cal_end || cal_end_reg) begin
              next_state = S_OUTPUT;//存储完成，进入计算状态
            end
            else if (i_output_end || output_end_reg) begin
              next_state = S_IDLE;  //输出完成，进入空闲状态
            end
            else begin
              next_state = S_DELAY; //默认状态就是延迟
            end
            
        end

        S_OUTPUT: begin
            
            if (output_cnt != output_cnt_max) begin
                next_state = S_OUTPUT; //没输出完就继续输出
            end
            else next_state = S_DELAY; //内部output地址输出完了，等待外部的输出完成信号
        end

        default : begin
                next_state = S_IDLE; 
        end    
            
    endcase
end


// 第三段（时序逻辑，用于描述内部信号更新逻辑和输出）
    
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        column_cnt <= 'd0; //内部信号置零
        group_cnt <= 'd0;
        internal_cnt <= 'd0;
        output_cnt <= 'd0;
        column_cnt_reg <= 'd0;
        group_cnt_reg <= 'd0;
        internal_cnt_reg <= 'd0;
        group_cnt_max <= 'd0;
        internal_cnt_max <= 'd0;
        o_store_valid <= 0; //输出信号置零
        o_store_addr <= 'd0;
        o_di_1_addr <= 0;
        o_di_2_addr <= 0;
        o_di_valid <= 0;
        o_ram1_ctrl <= 2'b00;
        o_ram2_ctrl <= 2'b00;
        o_wc_addr <= 0;
        o_wc_out_valid <= 0;
        o_d_out_valid <= 0;
        o_d_out_addr <= 0;
        o_idle_out <= 0;
        // new initializations for Sort_Unit segment
        sort_end <= 1'b0;
        cur_rev        <= {17{1'b1}}; // i.e. 1111_1111_1111_1111
    end else begin
        case (current_state)
            S_IDLE: begin
                column_cnt <= 'd0; //内部信号置零
                group_cnt <= 'd0;
                internal_cnt <= 'd0;
                output_cnt <= 'd0;
                column_cnt_reg <= 'd0;
                group_cnt_reg <= 'd0;
                internal_cnt_reg <= 'd0;
                group_cnt_max <= 'd0;
                internal_cnt_max <= 'd0;
                o_store_valid <= 0; //输出信号置零
                o_store_addr <= 'd0;
                o_di_1_addr <= 0;
                o_di_2_addr <= 0;
                o_di_valid <= 0;
                o_ram1_ctrl <= 0;
                o_ram2_ctrl <= 0;
                o_wc_addr <= 0;
                o_wc_out_valid <= 0;
                o_d_out_valid <= 0;
                o_d_out_addr <= 0;
                o_idle_out <= 1;//只有这个是1
                sort_end <= 1'b0;
                cur_rev        <= {17{1'b1}}; // i.e. 1111_1111_1111_1111
            end

            S_STORE: begin
                column_cnt <= 0; //内部信号置零
                group_cnt <= 0;
                internal_cnt <= 0;
                output_cnt <= 'd0;
                column_cnt_reg <= 0;
                group_cnt_reg <= 0;
                internal_cnt_reg <= 0;
                group_cnt_max <= 0;
                internal_cnt_max <= 0;
                o_di_1_addr <= 0;//输出信号置零
                o_di_2_addr <= 0;
                o_di_valid <= 0;
                o_ram1_ctrl <= 2'b00; 
                o_ram2_ctrl <= 2'b00;
                o_wc_addr <= 0;
                o_wc_out_valid <= 0;
                o_d_out_valid <= 0;
                o_d_out_addr <= 0;
                o_idle_out <= 0;
                o_store_valid <= 0; //default cases
                o_store_addr <= 'd0;
           /*----------------o_store_addr generate logic---------------*/
                if (cur_rev==(1<<n_cfg_reg)-1) begin //
                    sort_end <= 1'b1;
                    cur_rev <= {17{1'b1}};
                end
                else  begin //
                    cur_rev <= cur_rev + 1;
                    sort_end <= 1'b0;
                end
                // Bit reversal & Output logic 倒位序算法
                o_store_valid <= cur_rev!={17{1'b1}};
                o_ram1_ctrl <= cur_rev!={17{1'b1}}? 2'b10: 2'b00 ;
                for(i=0;i<n_cfg_reg;i=i+1) begin
                        o_store_addr[n_cfg_reg-1-i] <= cur_rev[i];
                    end
            end

            S_COLUMN: begin
                o_store_valid <= 0;//进入计算状态
                //o_di_1_addr <= 0;
                //o_di_2_addr <= 0;
                o_di_valid <= 0;
                o_ram1_ctrl <= 2'b00;
                o_ram2_ctrl <= 2'b00;
                //o_wc_addr <= 0;
                o_wc_out_valid <= 0;
                column_cnt_reg <= column_cnt;
                group_cnt_reg <= 0; //new
                internal_cnt_reg <= 0; //new
                //这里不能用阻塞赋值，因为师兄不让我用lol -->改成非阻塞赋值了
                //不然下次进入S_COLUMN的时候internal_cnt_max和group_cnt_max还是拿上次的column_cnt算的
                //-->改成直接用这一次的column_cnt计算internal_cnt_max,group_cnt_max，不用column_cnt_reg了
                o_idle_out <= 0;
                internal_cnt_max <= (1 << column_cnt) -1;    //计算internal_cnt_max,group_cnt_max      
                group_cnt_max <= (1 << (n_cfg_reg - 1 - column_cnt)) -1;
                if (column_cnt != column_cnt_max && column_cnt_reg != column_cnt_max) begin
                    column_cnt <= column_cnt + 1;
                end
                else begin
                    column_cnt <= 0;
                end
                
                
            end
            

            S_GROUP: begin
                //o_di_1_addr <= 0;
                //o_di_2_addr <= 0;
                o_ram1_ctrl <= 2'b00;
                o_ram2_ctrl <= 2'b00;
                o_di_valid <= 0;
                //o_wc_addr <= 0;
                o_wc_out_valid <= 0;
                group_cnt_reg <= group_cnt;
                o_store_valid <= 0;//计算状态
                o_idle_out <= 0;
                internal_cnt_reg <= 0; //new
                if (group_cnt != group_cnt_max && group_cnt_reg != group_cnt_max) begin
                    group_cnt <= group_cnt + 1;
                    
                end
                else begin
                    group_cnt <= 0;
                end
            end

            S_INTERNAL: begin
                internal_cnt_reg <= internal_cnt;
                if (column_cnt_reg[0] == 1'b0) begin //代表当前列是偶数,读pingpongram_1,写pingpongram_2
                    o_ram1_ctrl <= 2'b01;
                    o_ram2_ctrl <= 2'b10;
                end
                else begin //代表当前列是奇数,读pingpongram_2,写pingpongram_1
                    o_ram1_ctrl <= 2'b10;
                    o_ram2_ctrl <= 2'b01;
                end
                o_di_valid <= 1;
                o_di_1_addr <= (group_cnt_reg * (1 << (column_cnt_reg + 1)) + internal_cnt) ;
                o_di_2_addr <= (group_cnt_reg * (1 << (column_cnt_reg + 1)) + internal_cnt + (1 << column_cnt_reg)) ;
                o_wc_out_valid <= 1;
                o_wc_addr <=  (internal_cnt * (P_NMAX/(1 << (column_cnt_reg)))/2) ;
                if (internal_cnt != internal_cnt_max) begin
                    internal_cnt <= internal_cnt + 1;
                end
                else begin
                    internal_cnt <= 0;
                end
                
            end
            

            S_DELAY: begin
                column_cnt <= 'd0; //内部信号置零
                group_cnt <= 'd0;
                internal_cnt <= 'd0;
                output_cnt <= 'd0;
                column_cnt_reg <= 'd0;
                group_cnt_reg <= 'd0;
                internal_cnt_reg <= 'd0;
                group_cnt_max <= 'd0;
                internal_cnt_max <= 'd0;
                o_store_valid <= 0; //输出信号置零
                o_store_addr <= 'd0;
                o_di_1_addr <= 0;
                o_di_2_addr <= 0;
                o_di_valid <= 0;
                o_ram1_ctrl <= 2'b00;
                o_ram2_ctrl <= 2'b00;
                o_wc_addr <= 0;
                o_wc_out_valid <= 0;
                o_d_out_valid <= 0;
                o_d_out_addr <= 0;
                o_idle_out <= 0;
                // new initializations for Sort_Unit segment
                //sort_end       <= 1'b0;
                sort_end <= 1'b0;
                cur_rev        <= {17{1'b1}}; // i.e. 1111_1111_1111_1111
            end

            S_OUTPUT: begin
                if (column_cnt_max[0] == 1'b0) begin //代表最后结果存在ram2中,读pingpongram_2
                    o_ram1_ctrl <= 2'b00;
                    o_ram2_ctrl <= 2'b01;
                end
                else begin //代表最后结果存在ram1中,读pingpongram_1
                    o_ram1_ctrl <= 2'b01;
                    o_ram2_ctrl <= 2'b00;
                end
                o_d_out_valid <= 1;
                o_d_out_addr <= output_cnt;
                if (output_cnt != output_cnt_max) begin
                    output_cnt <= output_cnt + 1;
                end
                else begin
                    output_cnt <= 0;
                end

                
            end

            default: begin
                 
            end 
        endcase
    end
end

endmodule
