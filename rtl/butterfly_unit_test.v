`timescale 1ns / 1ps

`define SUB 1'b0
`define ADD 1'b1

module butterfly_unit_test(
    input i_di_valid,              // Data input valid signal from ram
    input signed [31:0] i_di_1,    // Data input 1 from ram, 高16位实部，低16位虚部
    input signed [31:0] i_di_2,    // Data input 2 from ram, 高16位实部，低16位虚部
    input i_w_valid,               // Twiddle factor input valid signal from ram
    input signed [31:0] i_w,       // Twiddle factor input from ram, 高16位实部，低16位虚部
    output reg o_do_valid,         // Data output valid signal to ram
    output reg signed [31:0] o_do_1, // Data output 1 to ram, 高16位实部，低16位虚部
    output reg signed [31:0] o_do_2  // Data output 2 to ram, 高16位实部，低16位虚部



  );
  //debugging ports
  reg signed [15:0] di_1_real, di_1_imag;
  reg signed [15:0] di_2_real, di_2_imag;
  reg signed [15:0] w_real, w_imag;
  reg signed [15:0] mult_real, mult_imag; //temp result for w * di_2
  reg signed [15:0] do_1_real, do_1_imag; //temp result for o_do_1
  reg signed [15:0] do_2_real, do_2_imag; //temp result for o_do_2


  always @(*)
  begin
    // 输入有效性判断
    if (i_di_valid && i_w_valid)
    begin
      // 输出有效信号
      o_do_valid = 1;
      // 提取实部和虚部
      di_1_real = i_di_1[31:16];
      di_1_imag = i_di_1[15:0];
      di_2_real = i_di_2[31:16];//a
      di_2_imag = i_di_2[15:0];//b
      w_real = i_w[31:16];//c
      w_imag = i_w[15:0];//d

      // 计算 i_w * i_di_2 (实部和虚部) (ac-bd)+(ad+bc)i 理论上是永远不会发生溢出
      mult_real =fixed_multiply(w_real, di_2_real)-fixed_multiply(w_imag, di_2_imag);//ac-bd
      mult_imag =fixed_multiply(w_real, di_2_imag)+fixed_multiply(w_imag, di_2_real);//ad+bc

      // 计算 o_do_1 = i_di_1 + mult_result
      do_1_real = fixed_add_sub_conv_round(di_1_real, mult_real, `ADD);
      do_1_imag = fixed_add_sub_conv_round(di_1_imag, mult_imag, `ADD);

      // 计算 o_do_2 = i_di_1 - mult_result
      do_2_real = fixed_add_sub_conv_round(di_1_real, mult_real, `SUB);
      do_2_imag = fixed_add_sub_conv_round(di_1_imag, mult_imag, `SUB);

      // 合并结果
      o_do_1 = {do_1_real, do_1_imag};
      o_do_2 = {do_2_real, do_2_imag};



    end
    else
    begin
      o_do_valid = 0;
      o_do_1 = 32'b0;
      o_do_2 = 32'b0;


    end
  end

  // Verilog function for fixed-point multiplication
  function signed [15:0] fixed_multiply (
      input signed [15:0] a,  // 输入第1个定点数
      input signed [15:0] b   // 输入第2个定点数,实际上这个数永远是Q0.15格式
    );
    // 中间结果为32bit
    reg signed [31:0] temp_result;
    reg signed [15:0] final_result;

    begin
      // 计算乘积
      temp_result = a * b;

      // 特殊情况处理
      if (a == 16'b1000_0000_0000_0000 && b == 16'b1000_0000_0000_0000)
      begin
        final_result = 16'b0111_1111_1111_1111; // 特殊情况
      end
      else
      begin
        final_result = temp_result[30:15]; // 截取[30:15]
      end

      // 返回结果
      fixed_multiply = final_result;
    end
  endfunction

  // Verilog function for fixed-point addition and subtraction with truncation
  //(两个数具有相同整数位数,例如都是Q0.15或是Q5.10)
  function signed [15:0] fixed_add_sub_trunc (
      input signed [15:0] a,          // 输入第1个定点数
      input signed [15:0] b,          // 输入第2个定点数
      input add_sub                   // 加减判断位，1 加法，0 减法
    );
    // 中间结果为 Q1.16 格式
    reg signed [16:0] temp_result;
    reg signed [15:0] final_result;

    begin
      // 根据加减判断位选择加法或减法
      temp_result = add_sub ? (a + b) : (a - b);

      // 对最低位直接截断
      final_result = temp_result[16:1]; // 舍去最低位

      // 返回结果
      fixed_add_sub_trunc = final_result;
    end
  endfunction

  // Verilog function for fixed-point addition and subtraction with rounding
// (两个数具有相同整数位数, 例如都是 Q0.15 或者 Q5.10)
function signed [15:0] fixed_add_sub_conv_round (
  input signed [15:0] a,          // 输入第1个定点数 (Q0.15)
  input signed [15:0] b,          // 输入第2个定点数 (Q0.15)
  input add_sub                    // 加减判断位，1 加法，0 减法
);
  // 中间结果为 Q1.16 格式
  reg signed [16:0] temp_result;
  reg signed [15:0] final_result;

  begin
      // 根据加减判断位选择加法或减法
      temp_result = add_sub ? (a + b) : (a - b);

      // 实现收敛舍入
      if (temp_result[0] & temp_result[1]) begin
          final_result = temp_result[16:1] + 1'b1; // 向上舍入
      end else begin
          final_result = temp_result[16:1]; // 保持不变
      end

      // 返回最终结果 (Q1.14)
      fixed_add_sub_conv_round = final_result;
  end
endfunction


  

endmodule
