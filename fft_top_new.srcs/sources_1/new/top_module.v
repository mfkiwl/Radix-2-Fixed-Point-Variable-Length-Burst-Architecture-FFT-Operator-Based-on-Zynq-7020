module top_module (  
    input wire i_clk,              // 时钟输入  
    input wire i_rst_n,            // 异步复位信号，低有效  
    input wire i_btn              // 按钮输入  
    //output wire [31:0] o_data_out, // FFT 输出数据  
    //output wire o_data_out_valid,   // FFT 输出有效信号  
    //output wire o_idle_out          // FFT 空闲状态信号  
);  

    // 中间信号定义  
    wire [31:0] fft_initdata;      // 从 stimulate_module 输出的数据  
    wire fft_initdata_valid;       // stimulate_module 的数据有效信号  
    wire [4:0] n_cfg;              // 配置信号  
    wire n_cfg_valid;              // 配置有效信号  

    // 实例化 stimulate_module  
    stimulate_module stim_mod (  
        .i_clk(i_clk),  
        .i_rst_n(i_rst_n),  
        .i_btn(i_btn),  
        .o_fft_initdata(fft_initdata),  
        .o_fft_initdata_valid(fft_initdata_valid),  
        .o_n_cfg(n_cfg),  
        .o_n_cfg_valid(n_cfg_valid)  
    );  

    // 实例化 fft_top_new  
    fft_top_new fft_mod (  
        .i_clk(i_clk),  
        .i_rst_n(i_rst_n),  
        .i_n_cfg_valid(n_cfg_valid),  
        .i_n_cfg(n_cfg),  
        .i_data_in_valid(fft_initdata_valid),  
        .i_data_in(fft_initdata),  
        .o_data_out(o_data_out),  
        .o_data_out_valid(o_data_out_valid),  
        .o_idle_out(o_idle_out)  
    );  

endmodule