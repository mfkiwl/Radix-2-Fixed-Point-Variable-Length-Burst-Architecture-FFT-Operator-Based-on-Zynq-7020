module data_fifo (
    input wire         i_clk,            // 外部时钟信号
    input wire         i_rst_n,          // 外部复位信号，低电平有效
    input wire [31:0]  i_data_in,        // 外部输入数据: [31:16] 实部, [15:0] 虚部
    input wire         i_data_in_valid,  // 外部输入数据有效信号，用作写使能
    input wire         i_store_valid,    // 来自CU的存储有效信号,用作读使能
    output wire [31:0] o_store_data      // 输出到 RAM 的数据
);

    wire full;
    wire empty;

    // FIFO IP 核实例化
    fifo_before_ram fifo_inst (
        .clk(i_clk),            // 时钟信号
        .srst(~i_rst_n),         // 异步复位信号，高电平有效
        .din(i_data_in),        // 输入数据
        .wr_en(i_data_in_valid),// 写使能
        .rd_en(i_store_valid),  // 读使能
        .dout(o_store_data),    // FIFO输出数据
        .full(full),
        .empty(empty)
    );

endmodule
