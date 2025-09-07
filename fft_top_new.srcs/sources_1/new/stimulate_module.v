module stimulate_module (  
    input wire i_clk,              // 时钟输入  
    input wire i_rst_n,            // 异步复位信号，低有效  
    input wire i_btn,              // 按钮输入  
    output wire [31:0] o_fft_initdata,  // 输出数据到 fft_top  
    output reg o_fft_initdata_valid,       // 数据有效信号  
    output reg [4:0] o_n_cfg,    // 输出配置信号  
    output reg o_n_cfg_valid     // 输出配置有效信号  
);  

    // 状态机状态定义  
    reg [2:0] state;             // 状态寄存器  
    reg [15:0] addr;             // 地址寄存器  
    reg cfg_sent;                // 配置信号发送标志  
    reg rom_enable;              // ROM 使能信号  
    reg [15:0] addr_reg;
    // 状态定义  
    localparam IDLE = 3'b000,  
               READ = 3'b001,  
               DONE = 3'b010;  

      
    intl_datarom my_rom (  
        .clka(i_clk),              // 连接时钟信号  
        .ena(rom_enable),       // 使能信号  
        .addra(addr_reg),           // 地址输入  
        .douta(o_fft_initdata)        // 数据输出  
    );  

    // 状态机  
    always @(posedge i_clk or negedge i_rst_n) begin  
        if (!i_rst_n) begin  // 异步复位 
            addr_reg <= 0;
            state <= IDLE;  
            addr <= 0;       // 初始化地址  
            o_n_cfg <= 5'd0;      // 初始化配置信号  
            o_n_cfg_valid <= 1'b0; // 初始化配置有效信号  
            cfg_sent <= 1'b0;     // 重置配置发送标志   
            o_fft_initdata_valid <= 1'b0;    // 初始化数据有效信号  
            rom_enable <= 1'b0;   // 禁用 ROM  
        end else begin  
            case (state)  
                IDLE: begin  
                    if (i_btn) begin  
                        state <= READ;    // 转到读取状态  
                    end  
                end  

                READ: begin  
                    rom_enable <= 1'b1;    // 使能 ROM  
                    addr_reg  <= addr;
                    addr <= addr + 1;      // 地址加 1 
                    o_fft_initdata_valid <= rom_enable; // 数据有效信号等于 ROM 使能信号  

                    // 输出配置信号  
                    if (!cfg_sent) begin  
                        o_n_cfg <= 5'd13;   // 设置配置信号  
                        o_n_cfg_valid <= 1'b1; // 设置配置有效信号  
                        cfg_sent <= 1'b1;   // 标记配置信号已发送  
                    end else begin  
                        o_n_cfg_valid <= 1'b0; // 在下一个时钟周期清除有效信号   
                        o_n_cfg <= 5'd0;   // 设置配置信号   
                    end  

                    // 检查是否读取完所有数据  
                    if (addr_reg == 11'd8191) begin  
                        state <= DONE;      // 转到完成状态  
                    end  
                end  

                DONE: begin  
                    rom_enable <= 1'b0;    // 禁用 ROM  
                    o_fft_initdata_valid <= 1'b0; // 数据有效信号等于 ROM 使能信号  
                    o_n_cfg_valid <= 1'b0; // 清除配置有效信号  
                    if (!i_btn) begin  
                        state <= IDLE;    // 返回到空闲状态  
                    end  
                end  

                default: state <= IDLE; // 默认状态  
            endcase  
        end  
    end  

endmodule