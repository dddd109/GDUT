tic
clear; clc
%% 参数初始化
narvs = 3; % 变量个数
T0 = 100;   % 初始温度
T = T0; % 迭代中温度会发生改变，第一次迭代时温度就是T0
maxgen = 200;  % 最大迭代次数
Lk = 1000;  % 每个温度下的迭代次数
alfa = 0.95;  % 温度衰减系数
x_lb = [0 0 0]; % x的下界
x_ub = [1000 1000 1000]; % x的上界


%%  随机生成一个初始解
x0 = zeros(1,narvs);
for i = 1: narvs
    x0(i) = x_lb(i) + (x_ub(i)-x_lb(i))*rand(1);    
end
while ~((x0(1)-x0(2)+x0(3)<=20)&&(3*x0(1)+2*x0(2)+4*x0(3)<=42)&&(3*x0(1)+2*x0(2)<=30))
   for i = 1: narvs
    x0(i) = x_lb(i) + (x_ub(i)-x_lb(i))*rand(1);    
   end   
end
y0 = -5*x0(1) - 4*x0(2) - 6*x0(3); % 计算当前解的函数值

%% 定义一些保存中间过程的量，方便输出结果和画图
min_y = y0;     % 初始化找到的最佳的解对应的函数值为y0
MINY = zeros(maxgen,1); % 记录每一次外层循环结束后找到的min_y (方便画图）

%% 模拟退火过程
for iter = 1 : maxgen  % 外循环, 我这里采用的是指定最大迭代次数

    for i = 1 : Lk  % 内循环，在每个温度下开始迭代

        y = randn(1,narvs);  % 生成1行narvs列的N(0,1)随机数
        z = y / sqrt(sum(y.^2)); % 根据新解的产生规则计算z
        x_new = x0 + z*T; % 根据新解的产生规则计算x_new的值


        % 初步定义域判断（如果这个新解的位置超出了定义域，就对其进行调整）
        for j = 1: narvs
            if x_new(j) < x_lb(j)
                r = rand(1);
                x_new(j) = r*x_lb(j)+(1-r)*x0(j);
            elseif x_new(j) > x_ub(j)
                r = rand(1);
                x_new(j) = r*x_ub(j)+(1-r)*x0(j);
            end
        end
        
if ((x_new(1)-x_new(2)+x_new(3)<=20)&&(3*x_new(1)+2*x_new(2)+4*x_new(3)<=42)&&(3*x_new(1)+2*x_new(2)<=30))
disp('最佳的位置是：');
disp(x_new);
x1 = x_new; % 将调整后的x_new赋值给新解x1
y1 = -5*x1(1) - 4*x1(2) - 6*x1(3); % 计算新解的函数值
if y1 < y0 % 如果新解函数值小于当前解的函数值
x0 = x1; % 更新当前解为新解
y0 = y1;
else
p = exp(-(y1 - y0)/T); % 根据Metropolis准则计算一个概率
if rand(1) < p % 生成一个随机数和这个概率比较，如果该随机数小于这个概率
x0 = x1; % 更新当前解为新解
y0 = y1;
end
end
% 判断是否要更新找到的最佳的解
if y0 < min_y % 如果当前解更好，则对其进行更新
min_y = y0; % 更新最小的y
best_x = x0; % 更新找到的最好的x
end
end

        %最后确认定义域范围
        for j = 1: narvs
            if x_new(j) < x_lb(j)
                x_new(j) = x_lb(j);
            elseif x_new(j) > x_ub(j)
                x_new(j) = x_ub(j);
            end
        end

        x1 = x_new;    % 将调整后的x_new赋值给新解x1
        y1 = Obj_fun2(x1);  % 计算新解的函数值
        
        if y1 < y0    % 如果新解函数值小于当前解的函数值
            x0 = x1; % 更新当前解为新解
            y0 = y1;
        else
            p = exp(-(y1 - y0)/T); % 根据Metropolis准则计算一个概率
            if rand(1) < p   % 生成一个随机数和这个概率比较，如果该随机数小于这个概率
                x0 = x1;  % 更新当前解为新解
                y0 = y1;
            end
        end
        % 判断是否要更新找到的最佳的解

        if y0 < min_y  % 如果当前解更好，则对其进行更新
            min_y = y0;  % 更新最小的y
            best_x = x0;  % 更新找到的最好的x
        end
    end
    MINY(iter) = min_y; % 保存本轮外循环结束后找到的最小的y
    T = alfa*T;   % 温度下降

end


disp('最佳的位置是：'); disp(best_x)
disp('此时最优值是：'); disp(min_y)

toc
