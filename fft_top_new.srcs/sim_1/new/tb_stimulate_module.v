`timescale 1ns / 1ps  

module tb_stimulate_module;  

    // 测试bench信号定义  
    reg i_clk;                  // 时钟信号  
    reg i_rst_n;                // 异步复位信号，低有效  
    reg i_btn;                  // 按钮输入  
    wire [31:0] o_fft_initdata;    // 输出数据  
    wire o_fft_initdata_valid;         // 数据有效信号  
    wire [4:0] o_n_cfg;      // 配置信号  
    wire o_n_cfg_valid;      // 配置有效信号  

    // 实例化被测试模块  
    stimulate_module uut (  
        .i_clk(i_clk),  
        .i_rst_n(i_rst_n),  
        .i_btn(i_btn),  
        .o_fft_initdata(o_fft_initdata),  
        .o_fft_initdata_valid(o_fft_initdata_valid),  
        .o_n_cfg(o_n_cfg),  
        .o_n_cfg_valid(o_n_cfg_valid)  
    );  

    // 时钟生成  
    initial begin  
        i_clk = 0;  
        forever #5 i_clk = ~i_clk; // 每5个时间单位翻转一次  
    end  

    // 测试过程  
    initial begin  
        // 初始化信号  
        i_rst_n = 0; // 先拉低复位信号  
        i_btn = 0;  

        // 等待一段时间以确保模块初始化  
        #10;  
        i_rst_n = 1; // 释放复位信号  

        // 等待一段时间  
        #10;  

        // 按下按钮以开始读取  
        i_btn = 1;  
        #10; // 按钮保持高电平一段时间  

        // 释放按钮  
        i_btn = 0;  
        #10; // 等待一段时间  

        // 继续观察输出  
        #200; // 观察一段时间以查看数据输出  

        
        // 结束测试  
        $finish;  
    end  

    // 监视输出信号  
    initial begin  
        $monitor("Time: %0t | i_rst_n: %b | i_btn: %b | o_fft_initdata: %h | o_fft_initdata_valid: %b | o_n_cfg: %b | o_n_cfg_valid: %b",  
                 $time, i_rst_n, i_btn, o_fft_initdata, o_fft_initdata_valid, o_n_cfg, o_n_cfg_valid);  
    end  

endmodule