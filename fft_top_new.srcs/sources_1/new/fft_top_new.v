module fft_top_new (
    input         i_clk,           // from outside: Clock signal
    input         i_rst_n,         // from outside: Active-low reset signal
    input         i_n_cfg_valid,   // from outside: FFT configuration valid signal
    input  [4:0]  i_n_cfg,         // from outside: FFT point size configuration (max 2048 points)
    input         i_data_in_valid, // from outside: Data input valid signal, needs to stay high
    input  [31:0] i_data_in,       // from outside: Data input [31:16] real, [15:0] imaginary

    output wire [31:0] o_data_out,      // to outside: Final FFT serial output data
    output wire       o_data_out_valid, // to outside: Final FFT serial output valid signal
    output wire       o_idle_out        // to outside: Idle state valid signal, indicating readiness for new FFT calculation
  );

// ILA 实例化  
  ila_0 ila_0_inst (  
    .clk(i_clk),                     // 连接时钟信号  
    .probe0(o_data_out),            // 捕获 FFT 输出数据  
    .probe1(o_data_out_valid),      // 捕获输出有效信号  
    .probe2(o_idle_out)             // 捕获空闲状态信号  
);  

  // Internal signals
  wire [31:0] fifo_to_ram_data;        // from data_fifo to pingpongram: Data output from FIFO to RAM

  wire [15:0] store_addr;              // from cu_new to ram: Store address
  wire [1:0]  ram1_ctrl;               // from cu_new to ram: ram1 read/write control
  wire [1:0]  ram2_ctrl;               // from cu_new to ram: ram2 read/write control
  wire [15:0] di_1_addr;               // from cu_new to ram: Data address 1
  wire [15:0] di_2_addr;               // from cu_new to ram: Data address 2
  wire [15:0] wc_addr;                 // from cu_new to ram: Twiddle factor address
  wire [15:0] d_out_addr;              // from cu_new to ram: Output data address

  wire [4:0]  current_n_cfg;           // from cu_new to ram_withip: Current FFT point size configuration

  wire        store_valid;             // from cu_new to ram_withip: Store valid signal
  wire        di_valid;                // from cu_new to ram_withip: Data valid signal
  wire        wc_out_valid;            // from cu_new to ram_withip: Twiddle factor valid signal
  wire        tran_valid;              // from cu_new to ram_withip: Transfer valid signal
  wire        d_out_valid;             // from cu_new to ram_withip: Output stage valid signal

  wire        store_end;               // from ram_withip to cu_new: Store stage completion signal
  wire        cal_end;                 // from ram_withip to cu_new: Calculation stage completion signal
  wire        output_end;              // from ram_withip to cu_new: Output stage completion signal

  wire        di_valid_to_bf;          // from ram_withip to butterfly_unit: Data valid signal
  wire        w_valid_to_bf;           // from ram_withip to butterfly_unit: Twiddle factor valid signal

  wire [31:0] di_1_to_bf;              // from ram_withip to butterfly_unit: Data 1
  wire [31:0] di_2_to_bf;              // from ram_withip to butterfly_unit: Data 2
  wire [31:0] w_to_bf;                 // from ram_withip to butterfly_unit: Twiddle factor

  wire [31:0] bf_result_1;             // from butterfly_unit to ram_withip: Butterfly unit result 1
  wire [31:0] bf_result_2;             // from butterfly_unit to ram_withip: Butterfly unit result 2
  wire        bf_result_valid;         // from butterfly_unit to ram_withip: Butterfly unit result valid signal


  // Control Unit
  cu_test cu_inst (
            .i_clk(i_clk),
            .i_rst_n(i_rst_n),
            .i_n_cfg(i_n_cfg),
            .i_n_cfg_valid(i_n_cfg_valid),
            .i_data_in_valid(i_data_in_valid),
            .i_store_end(store_end),
            .i_cal_end(cal_end),
            .i_output_end(output_end),
            .o_current_n_cfg(current_n_cfg),
            .o_ram1_ctrl(ram1_ctrl),
            .o_ram2_ctrl(ram2_ctrl),
            .o_store_valid(store_valid),
            .o_store_addr(store_addr),
            .o_di_1_addr(di_1_addr),
            .o_di_2_addr(di_2_addr),
            .o_di_valid(di_valid),
            .o_wc_addr(wc_addr),
            .o_wc_out_valid(wc_out_valid),
            .o_d_out_valid(d_out_valid),
            .o_d_out_addr(d_out_addr),
            .o_idle_out(o_idle_out)
          );

  // Ping-pong RAM
  pingpongram_test #(
                     .P_DEPTH(8192) // Depth of RAM, matches FFT size
                   ) pingpongram_inst (
                     .i_clk(i_clk),
                     .i_rst_n(i_rst_n),
                     .i_current_n_cfg(current_n_cfg),
                     .i_ram1_ctrl(ram1_ctrl),
                     .i_ram2_ctrl(ram2_ctrl),
                     .i_store_data(fifo_to_ram_data),
                     .i_store_valid(store_valid),
                     .i_store_addr(store_addr),
                     .i_do_1_bf(bf_result_1),
                     .i_do_2_bf(bf_result_2),
                     .i_do_bf_valid(bf_result_valid),
                     .i_di_1_addr(di_1_addr),
                     .i_di_2_addr(di_2_addr),
                     .i_di_valid(di_valid),
                     .i_w_addr(wc_addr),
                     .i_w_valid(wc_out_valid),
                     .o_di_1(di_1_to_bf),
                     .o_di_2(di_2_to_bf),
                     .o_di_valid(di_valid_to_bf),
                     .o_w(w_to_bf),
                     .o_w_valid(w_valid_to_bf),
                     .i_d_out_valid(d_out_valid),
                     .i_d_out_addr(d_out_addr),
                     .o_cal_end(cal_end),
                     .o_store_end(store_end),
                     .o_output_end(output_end),
                     .o_ram_data_out(o_data_out),
                     .o_ram_data_out_valid(o_data_out_valid)
                   );

  // FIFO for data buffering
  data_fifo data_fifo_inst (
              .i_clk(i_clk),
              .i_rst_n(i_rst_n),
              .i_data_in(i_data_in),
              .i_data_in_valid(i_data_in_valid),
              .i_store_valid(store_valid),
              .o_store_data(fifo_to_ram_data)
            );

  // Butterfly Unit
  butterfly_unit_test butterfly_unit_inst (
                        .i_di_valid(di_valid_to_bf),
                        .i_di_1(di_1_to_bf),
                        .i_di_2(di_2_to_bf),
                        .i_w_valid(w_valid_to_bf),
                        .i_w(w_to_bf),
                        .o_do_valid(bf_result_valid),
                        .o_do_1(bf_result_1),
                        .o_do_2(bf_result_2)
                      );

endmodule
