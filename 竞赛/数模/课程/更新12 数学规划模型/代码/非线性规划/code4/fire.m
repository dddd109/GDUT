tic

clear; clc

%% 参数初始化
narvs = 3; % 变量个数
T0 = 100;   % 初始温度
T = T0; % 迭代中温度会发生改变，第一次迭代时温度就是T0
maxgen = 200;  % 最大迭代次数
Lk = 100;  % 每个温度下的迭代次数
alfa = 0.95;  % 温度衰减系数

%% 随机生成一个初始解 (限定为0或1)
x0 = randi([0, 1], 1, narvs);  % 随机生成0或1的初始解
while ~((x0(1)-x0(2)+x0(3)<=20)&&(3*x0(1)+2*x0(2)+4*x0(3)<=42)&&(3*x0(1)+2*x0(2)<=30))
    x0 = randi([0, 1], 1, narvs);  % 如果不满足约束条件，则重新生成
end
y0 = -5*x0(1) - 4*x0(2) - 6*x0(3); % 计算当前解的函数值

%% 定义一些保存中间过程的量，方便输出结果和画图
min_y = y0;     % 初始化找到的最佳解对应的函数值为y0
MINY = zeros(maxgen, 1); % 记录每次外层循环结束后找到的min_y (方便画图）

%% 模拟退火过程
for iter = 1 : maxgen  % 外循环
    for i = 1 : Lk  % 内循环，在每个温度下开始迭代
        % 生成0或1的新解
        x_new = randi([0, 1], 1, narvs);
        
        % 检查新解是否满足约束条件
        if ((x_new(1)-x_new(2)+x_new(3)<=20) && (3*x_new(1)+2*x_new(2)+4*x_new(3)<=42) && (3*x_new(1)+2*x_new(2)<=30))
            disp('当前解：');
            disp(x_new);
            
            y1 = -5*x_new(1) - 4*x_new(2) - 6*x_new(3);  % 计算新解的函数值
            if y1 < y0    % 如果新解函数值小于当前解的函数值
                x0 = x_new; % 更新当前解为新解
                y0 = y1;
            else
                p = exp(-(y1 - y0) / T); % 根据Metropolis准则计算一个概率
                if rand(1) < p   % 生成一个随机数并与概率比较
                    x0 = x_new;  % 更新当前解为新解
                    y0 = y1;
                end
            end
            
            % 判断是否要更新找到的最佳解
            if y0 < min_y  % 如果当前解更好，则对其进行更新
                min_y = y0;  % 更新最小的y
                best_x = x0;  % 更新找到的最好的x
            end
        end
    end
    MINY(iter) = min_y; % 保存每次外循环的最小y
    T = alfa * T;   % 温度下降
end

disp('最佳的位置是：'); disp(best_x)
disp('此时最优值是：'); disp(min_y)

%% 画出每次迭代后找到的最小y的图形
figure
plot(1:maxgen, MINY, 'b-');
xlabel('迭代次数');
ylabel('y的值');
title('模拟退火优化过程中的最小y值变化')

toc
