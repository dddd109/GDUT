clear;clc;
c = [1; 1; 1; 1];             % 目标函数系数
intcon = [1, 2, 3, 4];        % 指定哪些变量需要是整数
A = [-2, -1, 0, 0;            % 等式约束系数矩阵
       0, -1, -2, -3;
       -1, -1, -2, 0];
b = [-100; -100; -100];        % 等式约束右侧向量
Aeq = [];                       % 不等式约束系数矩阵（没有不等式约束）
beq = [];                       % 不等式约束右侧向量（没有不等式约束）
lb = zeros(4, 1);             % 变量下界
ub = [+inf; +inf; +inf; +inf];% 变量上界

% 设置算法选项
options = optimoptions('intlinprog', 'Display', 'final', 'ConstraintTolerance', 1e-4);

% 求解
[x, fval, exitflag, output] = intlinprog(c, intcon, A, b, Aeq, beq, lb, ub, options);

% 输出结果
disp(x);
disp(fval);
disp(exitflag);
disp(output);