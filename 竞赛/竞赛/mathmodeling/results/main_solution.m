%% 2025 CUMCM A题：烟幕干扰弹的投放策略
% 主求解程序
clear; clc; close all;

%% ==== 全局参数 ====
g = 9.8;          % 重力加速度 (m/s^2)
R_cloud = 10;      % 烟幕云团有效半径 (m)
v_sink = 3;        % 云团下沉速度 (m/s)
T_eff = 20;        % 云团有效时间 (s)
v_missile = 300;   % 导弹速度 (m/s)
v_range = [70, 140]; % 无人机速度范围
dt = 0.01;         % 时间步长 (s)

% 原点（假目标）
O = [0, 0, 0];

% 导弹初始位置 [x, y, z]
M0 = [
    20000, 0,     2000;   % M1
    19000, 600,   2100;   % M2
    18000, -600,  1900    % M3
];

% 无人机初始位置 [x, y, z]
F0 = [
    17800, 0,     1800;   % FY1
    12000, 1400,  1400;   % FY2
    6000,  -3000, 700;    % FY3
    11000, 2000,  1800;   % FY4
    13000, -2000, 1300    % FY5
];

% 计算导弹方向单位向量和到达时间
n_missiles = size(M0, 1);
missile_dir = zeros(n_missiles, 3);
missile_T_arrive = zeros(n_missiles, 1);
for i = 1:n_missiles
    dist = norm(M0(i,:) - O);
    missile_dir(i,:) = (O - M0(i,:)) / dist;
    missile_T_arrive(i) = dist / v_missile;
end

fprintf('导弹到达原点时间: M1=%.2fs, M2=%.2fs, M3=%.2fs\n', missile_T_arrive);

%% ========================================================================
%% 问题1：固定参数计算有效遮蔽时长
%% ========================================================================
fprintf('\n===== 问题1 =====\n');

% 给定参数
v1 = 120;            % 无人机速度 (m/s)
theta1 = 180;         % 飞行方向角（度），朝向假目标即-x方向
t_d = 1.5;            % 投放时刻 (s)
t_b_rel = 3.6;        % 相对于投放的起爆时间 (s)

% 末端无人机的投放位置
F_start = F0(1,:);
dir_vec = [cosd(theta1), sind(theta1), 0];
F_deploy = F_start + v1 * t_d * dir_vec;

% 起爆位置（考虑重力下落）
dt_fall = t_b_rel;
vel_deploy = v1 * dir_vec;
P_b1 = F_deploy + vel_deploy * dt_fall + 0.5 * [0, 0, -g] * dt_fall^2;
t_b_abs = t_d + t_b_rel;  % 绝对起爆时刻

fprintf('投放点: (%.2f, %.2f, %.2f)\n', F_deploy);
fprintf('起爆点: (%.2f, %.2f, %.2f)\n', P_b1);
fprintf('起爆时刻: %.2f s\n', t_b_abs);

% 计算遮蔽时长
T_end = min(t_b_abs + T_eff, missile_T_arrive(1));
t_vec = t_b_abs:dt:T_end;
is_jammed = false(size(t_vec));

for idx = 1:length(t_vec)
    t = t_vec(idx);
    M_pos = M0(1,:) + v_missile * t * missile_dir(1,:);
    % 云团中心位置（考虑下沉）
    C_pos = P_b1 + [0, 0, -v_sink * (t - t_b_abs)];
    is_jammed(idx) = line_sphere_intersect(M_pos, O, C_pos, R_cloud);
end

T_jam1 = sum(is_jammed) * dt;
fprintf('有效遮蔽时长: %.4f s\n', T_jam1);

%% ========================================================================
%% 问题2：单机单弹优化
%% ========================================================================
fprintf('\n===== 问题2 =====\n');

% 优化变量: [v, theta(rad), t_d, t_b_rel]
% 使用 fmincon 进行优化

% 初始猜测
x0 = [120, pi, 1.5, 3.6];
lb = [v_range(1), 0, 0, 0.1];
ub = [v_range(2), 2*pi, 30, 20];

% 使用全局搜索+局部优化
options = optimoptions('fmincon', 'Display', 'off', 'Algorithm', 'sqp', ...
    'MaxFunctionEvaluations', 5000);

% 多次随机初始点搜索
n_trials = 20;
best_x = x0;
best_J = -inf;
all_results = zeros(n_trials, 5);

for trial = 1:n_trials
    if trial == 1
        x_init = x0;
    else
        x_init = [lb(1) + rand*(ub(1)-lb(1)), ...
                  lb(2) + rand*(ub(2)-lb(2)), ...
                  lb(3) + rand*(ub(3)-lb(3)), ...
                  lb(4) + rand*(ub(4)-lb(4))];
    end
    try
        [x_opt, J_opt] = fmincon(@(x) -obj_jam_duration(x, M0(1,:), missile_dir(1,:), ...
            F0(1,:), v_missile, missile_T_arrive(1), g, v_sink, R_cloud, T_eff, dt), ...
            x_init, [], [], [], [], lb, ub, [], options);
        J_opt = -J_opt;
        all_results(trial,:) = [x_opt, J_opt];
        if J_opt > best_J
            best_J = J_opt;
            best_x = x_opt;
        end
    catch
        all_results(trial,:) = [x_init, 0];
    end
end

fprintf('最优速度: %.2f m/s\n', best_x(1));
fprintf('最优方向角: %.2f 度\n', rad2deg(best_x(2)));
fprintf('最优投放时刻: %.2f s\n', best_x(3));
fprintf('最优起爆延时: %.2f s\n', best_x(4));
fprintf('最大遮蔽时长: %.4f s\n', best_J);

%% ========================================================================
%% 问题3：单机三弹优化
%% ========================================================================
fprintf('\n===== 问题3 =====\n');

% 优化变量: [v, theta(rad), t_d1, t_b_rel1, t_d2, t_b_rel2, t_d3, t_b_rel3]
% 约束: t_d2 >= t_d1 + 1, t_d3 >= t_d2 + 1
% 使用 PSO 求解

n_vars = 8;
n_particles = 40;
n_iterations = 100;
w = 0.7; c1 = 1.5; c2 = 1.5;  % PSO 参数

lb3 = [v_range(1), 0, 0, 0.1, 1, 0.1, 2, 0.1];
ub3 = [v_range(2), 2*pi, 25, 15, 26, 15, 27, 15];

% 初始化粒子群
pos = zeros(n_particles, n_vars);
vel = zeros(n_particles, n_vars);
for i = 1:n_particles
    pos(i,:) = lb3 + rand(1, n_vars) .* (ub3 - lb3);
    % 确保投放间隔约束
    pos(i,5) = max(pos(i,5), pos(i,3) + 1);
    pos(i,7) = max(pos(i,7), pos(i,5) + 1);
end

pbest_pos = pos;
pbest_val = -inf(n_particles, 1);
gbest_val = -inf;
gbest_pos = pos(1,:);

for iter = 1:n_iterations
    for i = 1:n_particles
        % 修正约束
        pos(i,5) = max(pos(i,5), pos(i,3) + 1);
        pos(i,7) = max(pos(i,7), pos(i,5) + 1);

        % 评估适应度
        f_val = eval_3_rounds(pos(i,:), M0(1,:), missile_dir(1,:), F0(1,:), ...
            v_missile, missile_T_arrive(1), g, v_sink, R_cloud, T_eff, dt);

        if f_val > pbest_val(i)
            pbest_val(i) = f_val;
            pbest_pos(i,:) = pos(i,:);
        end
        if f_val > gbest_val
            gbest_val = f_val;
            gbest_pos = pos(i,:);
        end
    end

    % 更新速度和位置
    for i = 1:n_particles
        r1 = rand(1, n_vars); r2 = rand(1, n_vars);
        vel(i,:) = w * vel(i,:) + c1 * r1 .* (pbest_pos(i,:) - pos(i,:)) ...
                                + c2 * r2 .* (gbest_pos - pos(i,:));
        vel(i,:) = min(max(vel(i,:), -0.1*(ub3-lb3)), 0.1*(ub3-lb3));
        pos(i,:) = pos(i,:) + vel(i,:);
        pos(i,:) = min(max(pos(i,:), lb3), ub3);
    end
end

fprintf('最优速度: %.2f m/s\n', gbest_pos(1));
fprintf('最优方向角: %.2f 度\n', rad2deg(gbest_pos(2)));
fprintf('最大总遮蔽时长: %.4f s\n', gbest_val);

% 提取三枚弹的投放策略
result3 = extract_3round_result(gbest_pos, F0(1,:), g);
fprintf('\n弹1: 投放(%.2f,%.2f,%.2f) 起爆(%.2f,%.2f,%.2f) 遮蔽%.4fs\n', result3(1,:));
fprintf('弹2: 投放(%.2f,%.2f,%.2f) 起爆(%.2f,%.2f,%.2f) 遮蔽%.4fs\n', result3(2,:));
fprintf('弹3: 投放(%.2f,%.2f,%.2f) 起爆(%.2f,%.2f,%.2f) 遮蔽%.4fs\n', result3(3,:));

% 写入 result1.xlsx
write_result1(gbest_pos, result3, F0(1,:), g);

%% ========================================================================
%% 问题4：三机协同干扰单枚导弹
%% ========================================================================
fprintf('\n===== 问题4 =====\n');

% FY1, FY2, FY3 各投1枚干扰弹协同干扰 M1
% 每架无人机优化: [v, theta, t_d, t_b_rel]
n_vars4 = 12;  % 3 UAVs * 4 params
n_particles4 = 50;
n_iterations4 = 150;

lb4 = repmat([v_range(1), 0, 0, 0.1], 1, 3);
ub4 = repmat([v_range(2), 2*pi, 30, 15], 1, 3);

% PSO 优化
[pos4, gbest_pos4, gbest_val4] = pso_optimizer(n_vars4, n_particles4, n_iterations4, ...
    lb4, ub4, @(x) eval_multi_uav(x, 3, 1, M0, missile_dir, F0, ...
    v_missile, missile_T_arrive, g, v_sink, R_cloud, T_eff, dt));

fprintf('最优总遮蔽时长: %.4f s\n', gbest_val4);

result4 = zeros(3, 8);
for j = 1:3
    idx = (j-1)*4 + 1;
    v_j = gbest_pos4(idx);
    theta_j = gbest_pos4(idx+1);
    t_d_j = gbest_pos4(idx+2);
    t_b_rel_j = gbest_pos4(idx+3);

    dir_j = [cos(theta_j), sin(theta_j), 0];
    F_d = F0(j,:) + v_j * t_d_j * dir_j;
    vel_d = v_j * dir_j;
    P_b = F_d + vel_d * t_b_rel_j + 0.5 * [0, 0, -g] * t_b_rel_j^2;

    % 计算单弹遮蔽时长
    jam_t = compute_single_jam(F0(j,:), v_j, theta_j, t_d_j, t_b_rel_j, ...
        M0(1,:), missile_dir(1,:), v_missile, g, v_sink, R_cloud, T_eff, missile_T_arrive(1), dt);

    result4(j,:) = [v_j, rad2deg(theta_j), F_d, P_b, jam_t];
    fprintf('FY%d: v=%.1f θ=%.1f° 投放(%.0f,%.0f,%.0f) 起爆(%.0f,%.0f,%.0f) 遮蔽%.4fs\n', ...
        j, result4(j,1), result4(j,2), result4(j,3), result4(j,4), result4(j,5), ...
        result4(j,6), result4(j,7), result4(j,8), jam_t);
end

write_result2(result4);

%% ========================================================================
%% 问题5：五机三目标协同优化
%% ========================================================================
fprintf('\n===== 问题5 =====\n');

% 第一阶段：目标分配 —— 基于初始位置最近原则
UAV_to_missile = assign_targets(F0, M0);

% 第二阶段：对每枚导弹分别优化分配给它的无人机
% M1: FY1, FY4 （最近的两架）
% M2: FY2, FY5
% M3: FY3

fprintf('\n目标分配方案:\n');
for j = 1:5
    fprintf('  FY%d -> M%d\n', j, UAV_to_missile(j));
end

% 对每个目标分别优化
all_results5 = cell(3, 1);
total_jam5 = 0;

for mi = 1:3
    assigned_uavs = find(UAV_to_missile == mi);
    n_uav = length(assigned_uavs);
    fprintf('\n--- 优化 M%d (分配%d架无人机) ---\n', mi, n_uav);

    % 每架无人机3枚弹
    % 变量: [v_j, theta_j, t_d1_j, tb_rel1_j, t_d2_j, tb_rel2_j, t_d3_j, tb_rel3_j] × n_uav
    n_vars5 = n_uav * 8;
    lb5 = repmat([v_range(1), 0, 0, 0.1, 1, 0.1, 2, 0.1], 1, n_uav);
    ub5 = repmat([v_range(2), 2*pi, 25, 15, 26, 15, 27, 15], 1, n_uav);

    [pos5, gbest_pos5, gbest_val5] = pso_optimizer(n_vars5, 30, 80, lb5, ub5, ...
        @(x) eval_cluster(x, n_uav, mi, assigned_uavs, M0, missile_dir, F0, ...
        v_missile, missile_T_arrive, g, v_sink, R_cloud, T_eff, dt));

    total_jam5 = total_jam5 + gbest_val5;
    all_results5{mi} = {gbest_pos5, gbest_val5, assigned_uavs};
    fprintf('  M%d 最优遮蔽时长: %.4f s\n', mi, gbest_val5);
end

fprintf('\n总有效遮蔽时长: %.4f s\n', total_jam5);

write_result3(all_results5, F0, g);

%% ========================================================================
%% 可视化
%% ========================================================================
fprintf('\n===== 生成可视化图表 =====\n');

% 图1：三维场景图
figure('Position', [100, 100, 900, 700]);
hold on; grid on; axis equal;

% 绘制坐标系
plot3([0 5000], [0 0], [0 0], 'k-', 'LineWidth', 1);
plot3([0 0], [0 5000], [0 0], 'k-', 'LineWidth', 1);
plot3([0 0], [0 0], [0 3000], 'k-', 'LineWidth', 1);
text(5000, 0, 0, 'x(E)', 'FontSize', 10);
text(0, 5000, 0, 'y(S)', 'FontSize', 10);
text(0, 0, 3000, 'z(Up)', 'FontSize', 10);

% 真目标和假目标
[X_cyl, Y_cyl, Z_cyl] = cylinder(7, 20);
Z_cyl = Z_cyl * 10;
surf(X_cyl, Y_cyl + 200, Z_cyl, 'FaceColor', 'g', 'FaceAlpha', 0.4, 'EdgeColor', 'none');
plot3(0, 0, 0, 'rx', 'MarkerSize', 12, 'LineWidth', 3);
text(0, 0, 50, '假目标(原点)', 'FontSize', 10);
text(0, 200, 10, '真目标', 'FontSize', 10);

% 导弹初始位置和轨迹
colors_m = {'r', 'b', 'm'};
for i = 1:3
    plot3(M0(i,1), M0(i,2), M0(i,3), 'o', 'Color', colors_m{i}, ...
        'MarkerSize', 8, 'MarkerFaceColor', colors_m{i});
    % 导弹轨迹
    T_i = missile_T_arrive(i);
    t_traj = 0:1:T_i;
    M_traj = zeros(length(t_traj), 3);
    for k = 1:length(t_traj)
        M_traj(k,:) = M0(i,:) + v_missile * t_traj(k) * missile_dir(i,:);
    end
    plot3(M_traj(:,1), M_traj(:,2), M_traj(:,3), '--', 'Color', colors_m{i}, 'LineWidth', 1);
    text(M0(i,1), M0(i,2), M0(i,3)+100, sprintf('M%d', i), 'FontSize', 10);
end

% 无人机初始位置
for j = 1:5
    plot3(F0(j,1), F0(j,2), F0(j,3), 's', 'Color', [0 0.5 0], ...
        'MarkerSize', 8, 'MarkerFaceColor', [0 0.5 0]);
    text(F0(j,1), F0(j,2), F0(j,3)+100, sprintf('FY%d', j), 'FontSize', 10);
end

xlabel('x (m) East'); ylabel('y (m) South'); zlabel('z (m) Up');
title('三维场景：导弹来袭态势与无人机部署');
legend({'坐标轴', '', '', '', '真目标', '假目标', ...
    '导弹M1', 'M1轨迹', '导弹M2', 'M2轨迹', '导弹M3', 'M3轨迹', '无人机'}, ...
    'Location', 'bestoutside');
view(45, 30);
saveas(gcf, 'D:/GDUT/竞赛/mathmodeling/results/figure1_scene.png');

% 图2：问题1遮蔽时间线
figure('Position', [100, 100, 900, 400]);
t_plot = 0:dt:missile_T_arrive(1);
M1_z = zeros(size(t_plot));
cloud_z = zeros(size(t_plot));
is_jammed_plot = zeros(size(t_plot));
for idx = 1:length(t_plot)
    t = t_plot(idx);
    M1_pos = M0(1,:) + v_missile * t * missile_dir(1,:);
    M1_z(idx) = M1_pos(3);
    if t >= t_d + t_b_rel && t <= t_d + t_b_rel + T_eff
        cloud_z(idx) = P_b1(3) - v_sink * (t - t_d - t_b_rel);
        C_pos = [P_b1(1:2), cloud_z(idx)];
        is_jammed_plot(idx) = line_sphere_intersect(M1_pos, O, C_pos, R_cloud);
    else
        cloud_z(idx) = NaN;
    end
end

subplot(2,1,1);
yyaxis left;
plot(t_plot, M1_z, 'b-', 'LineWidth', 1.5); ylabel('M1高度 (m)');
yyaxis right;
plot(t_plot, cloud_z, 'r-', 'LineWidth', 1.5); ylabel('云团高度 (m)');
xlabel('时间 (s)'); title('问题1：导弹与云团高度变化');
legend('M1高度', '云团中心高度');

subplot(2,1,2);
plot(t_plot, is_jammed_plot, 'k-', 'LineWidth', 2);
xlabel('时间 (s)'); ylabel('遮蔽状态');
title(sprintf('遮蔽状态 (1=有效遮蔽), 总时长=%.2fs', T_jam1));
ylim([-0.1, 1.1]);

saveas(gcf, 'D:/GDUT/竞赛/mathmodeling/results/figure2_problem1.png');

% 图3：优化结果对比
figure('Position', [100, 100, 800, 500]);
problem_labels = {'问题1', '问题2', '问题3', '问题4', '问题5'};
jam_times = [T_jam1, best_J, gbest_val, gbest_val4, total_jam5];
bar(jam_times, 'FaceColor', [0.2 0.4 0.8]);
xlabel('问题编号'); ylabel('有效遮蔽时长 (s)');
title('各问题最优遮蔽时长对比');
xticklabels(problem_labels);
grid on;
for i = 1:5
    text(i, jam_times(i) + 0.5, sprintf('%.2f s', jam_times(i)), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold');
end
saveas(gcf, 'D:/GDUT/竞赛/mathmodeling/results/figure3_comparison.png');

fprintf('可视化完成。图表已保存到 results/ 目录。\n');

%% ========================================================================
%% 辅助函数定义
%% ========================================================================

function intersect = line_sphere_intersect(P_start, P_end, C, R)
    % 判断线段 P_start -> P_end 是否与球 (C, R) 相交
    d = P_end - P_start;
    len = norm(d);
    if len < 1e-10
        intersect = norm(P_start - C) <= R;
        return;
    end
    d = d / len;
    v = C - P_start;
    s = dot(v, d);

    if s < 0 || s > len
        intersect = false;
        return;
    end

    P_close = P_start + s * d;
    intersect = norm(P_close - C) <= R;
end

function J = obj_jam_duration(x, M0_i, missile_dir_i, F0_i, v_m, T_arrive, ...
    g, v_sink, R_cloud, T_eff, dt)
    % 目标函数：计算给定参数下的有效遮蔽时长
    v = x(1); theta = x(2); t_d = x(3); t_b_rel = x(4);

    dir_vec = [cos(theta), sin(theta), 0];
    F_deploy = F0_i + v * t_d * dir_vec;
    vel_deploy = v * dir_vec;
    P_b = F_deploy + vel_deploy * t_b_rel + 0.5 * [0, 0, -g] * t_b_rel^2;
    t_b_abs = t_d + t_b_rel;

    if t_b_abs >= T_arrive
        J = 0;
        return;
    end

    T_end = min(t_b_abs + T_eff, T_arrive);
    t_vec = t_b_abs:dt:T_end;

    jam_count = 0;
    for idx = 1:length(t_vec)
        t_i = t_vec(idx);
        M_pos = M0_i + v_m * t_i * missile_dir_i;
        C_pos = P_b + [0, 0, -v_sink * (t_i - t_b_abs)];
        if line_sphere_intersect(M_pos, [0 0 0], C_pos, R_cloud)
            jam_count = jam_count + 1;
        end
    end
    J = jam_count * dt;
end

function J = eval_3_rounds(x, M0_i, missile_dir_i, F0_i, v_m, T_arrive, ...
    g, v_sink, R_cloud, T_eff, dt)
    % 评估三枚弹的总遮蔽时长（不含重叠）
    v = x(1); theta = x(2);
    t_d = x([3, 5, 7]);
    t_b_rel = x([4, 6, 8]);

    T_end = T_arrive;
    t_vec = 0:dt:T_end;
    is_jammed = false(size(t_vec));

    for k = 1:3
        if t_d(k) + t_b_rel(k) >= T_arrive
            continue;
        end
        dir_vec = [cos(theta), sin(theta), 0];
        F_d = F0_i + v * t_d(k) * dir_vec;
        vel_d = v * dir_vec;
        P_b = F_d + vel_d * t_b_rel(k) + 0.5 * [0, 0, -g] * t_b_rel(k)^2;
        t_b_abs = t_d(k) + t_b_rel(k);

        idx_start = max(1, round((t_b_abs)/dt) + 1);
        idx_end = min(length(t_vec), round((t_b_abs + T_eff)/dt) + 1);

        for idx = idx_start:idx_end
            t_i = t_vec(idx);
            M_pos = M0_i + v_m * t_i * missile_dir_i;
            C_pos = P_b + [0, 0, -v_sink * (t_i - t_b_abs)];
            is_jammed(idx) = is_jammed(idx) || ...
                line_sphere_intersect(M_pos, [0 0 0], C_pos, R_cloud);
        end
    end

    J = sum(is_jammed) * dt;
end

function result = extract_3round_result(x, F0_i, g)
    v = x(1); theta = x(2);
    t_d = x([3, 5, 7]);
    t_b_rel = x([4, 6, 8]);
    result = zeros(3, 8);

    for k = 1:3
        dir_vec = [cos(theta), sin(theta), 0];
        F_d = F0_i + v * t_d(k) * dir_vec;
        vel_d = v * dir_vec;
        P_b = F_d + vel_d * t_b_rel(k) + 0.5 * [0, 0, -g] * t_b_rel(k)^2;
        result(k,:) = [F_d, P_b, t_d(k), t_b_rel(k)];
    end
end

function J = eval_multi_uav(x, n_uav, mi, M0, missile_dir, F0, ...
    v_m, T_arrive, g, v_sink, R_cloud, T_eff, dt)
    % 评估多机协同的遮蔽时长
    T_end = T_arrive(mi);
    t_vec = 0:dt:T_end;
    is_jammed = false(size(t_vec));

    for j = 1:n_uav
        idx = (j-1)*4 + 1;
        v_j = x(idx); theta_j = x(idx+1);
        t_d_j = x(idx+2); t_b_rel_j = x(idx+3);

        if t_d_j + t_b_rel_j >= T_end
            continue;
        end

        dir_j = [cos(theta_j), sin(theta_j), 0];
        F_d = F0(j,:) + v_j * t_d_j * dir_j;
        vel_d = v_j * dir_j;
        P_b = F_d + vel_d * t_b_rel_j + 0.5 * [0, 0, -g] * t_b_rel_j^2;
        t_b_abs = t_d_j + t_b_rel_j;

        idx_s = max(1, round(t_b_abs/dt) + 1);
        idx_e = min(length(t_vec), round((t_b_abs + T_eff)/dt) + 1);

        for i_t = idx_s:idx_e
            t_i = t_vec(i_t);
            M_pos = M0(mi,:) + v_m * t_i * missile_dir(mi,:);
            C_pos = P_b + [0, 0, -v_sink * (t_i - t_b_abs)];
            is_jammed(i_t) = is_jammed(i_t) || ...
                line_sphere_intersect(M_pos, [0 0 0], C_pos, R_cloud);
        end
    end

    J = sum(is_jammed) * dt;
end

function J = eval_cluster(x, n_uav, mi, uav_ids, M0, missile_dir, F0, ...
    v_m, T_arrive, g, v_sink, R_cloud, T_eff, dt)
    % 评估多机多弹集群的遮蔽时长
    T_end = T_arrive(mi);
    t_vec = 0:dt:T_end;
    is_jammed = false(size(t_vec));

    for u = 1:n_uav
        uav_idx = uav_ids(u);
        base_idx = (u-1)*8 + 1;
        v_u = x(base_idx); theta_u = x(base_idx+1);
        dir_u = [cos(theta_u), sin(theta_u), 0];

        for k = 1:3
            t_d_k = x(base_idx + 2 + (k-1)*2);
            t_b_rel_k = x(base_idx + 3 + (k-1)*2);

            if t_d_k + t_b_rel_k >= T_end
                continue;
            end

            F_d = F0(uav_idx,:) + v_u * t_d_k * dir_u;
            vel_d = v_u * dir_u;
            P_b = F_d + vel_d * t_b_rel_k + 0.5 * [0, 0, -g] * t_b_rel_k^2;
            t_b_abs = t_d_k + t_b_rel_k;

            idx_s = max(1, round(t_b_abs/dt) + 1);
            idx_e = min(length(t_vec), round((t_b_abs + T_eff)/dt) + 1);

            for i_t = idx_s:idx_e
                t_i = t_vec(i_t);
                M_pos = M0(mi,:) + v_m * t_i * missile_dir(mi,:);
                C_pos = P_b + [0, 0, -v_sink * (t_i - t_b_abs)];
                is_jammed(i_t) = is_jammed(i_t) || ...
                    line_sphere_intersect(M_pos, [0 0 0], C_pos, R_cloud);
            end
        end
    end

    J = sum(is_jammed) * dt;
end

function [pos, gbest_pos, gbest_val] = pso_optimizer(n_vars, n_particles, ...
    n_iter, lb, ub, obj_fun)
    % 通用 PSO 优化器
    pos = zeros(n_particles, n_vars);
    vel = zeros(n_particles, n_vars);

    for i = 1:n_particles
        pos(i,:) = lb + rand(1, n_vars) .* (ub - lb);
    end

    pbest_pos = pos;
    pbest_val = -inf(n_particles, 1);
    gbest_val = -inf;
    gbest_pos = pos(1,:);

    w_start = 0.9; w_end = 0.4;

    for iter = 1:n_iter
        w = w_start - (w_start - w_end) * iter / n_iter;

        for i = 1:n_particles
            f_val = obj_fun(pos(i,:));

            if f_val > pbest_val(i)
                pbest_val(i) = f_val;
                pbest_pos(i,:) = pos(i,:);
            end
            if f_val > gbest_val
                gbest_val = f_val;
                gbest_pos = pos(i,:);
            end
        end

        for i = 1:n_particles
            r1 = rand(1, n_vars); r2 = rand(1, n_vars);
            vel(i,:) = w * vel(i,:) + 1.5 * r1 .* (pbest_pos(i,:) - pos(i,:)) ...
                                    + 1.5 * r2 .* (gbest_pos - pos(i,:));
            range = ub - lb;
            vel(i,:) = min(max(vel(i,:), -0.15*range), 0.15*range);
            pos(i,:) = pos(i,:) + vel(i,:);
            pos(i,:) = min(max(pos(i,:), lb), ub);
        end
    end
end

function jam_t = compute_single_jam(F0_j, v, theta, t_d, t_b_rel, ...
    M0_i, missile_dir_i, v_m, g, v_sink, R_cloud, T_eff, T_arrive, dt)
    % 计算单枚弹的有效遮蔽时长
    dir_vec = [cos(theta), sin(theta), 0];
    F_d = F0_j + v * t_d * dir_vec;
    vel_d = v * dir_vec;
    P_b = F_d + vel_d * t_b_rel + 0.5 * [0, 0, -g] * t_b_rel^2;
    t_b_abs = t_d + t_b_rel;

    if t_b_abs >= T_arrive
        jam_t = 0;
        return;
    end

    T_end = min(t_b_abs + T_eff, T_arrive);
    t_vec = t_b_abs:dt:T_end;
    jam_count = 0;

    for idx = 1:length(t_vec)
        t_i = t_vec(idx);
        M_pos = M0_i + v_m * t_i * missile_dir_i;
        C_pos = P_b + [0, 0, -v_sink * (t_i - t_b_abs)];
        if line_sphere_intersect(M_pos, [0 0 0], C_pos, R_cloud)
            jam_count = jam_count + 1;
        end
    end
    jam_t = jam_count * dt;
end

function assignment = assign_targets(F_pos, M_pos)
    % 基于距离的目标分配（贪心算法）
    n_uavs = size(F_pos, 1);
    n_missiles = size(M_pos, 1);
    distances = zeros(n_uavs, n_missiles);

    for j = 1:n_uavs
        for i = 1:n_missiles
            distances(j,i) = norm(F_pos(j,:) - M_pos(i,:));
        end
    end

    % 贪心分配：每架无人机分配给最近的导弹
    assignment = zeros(n_uavs, 1);
    for j = 1:n_uavs
        [~, assignment(j)] = min(distances(j,:));
    end
end

function write_result1(x, result3, F0_1, g)
    % 写入 result1.xlsx
    v = x(1); theta_deg = rad2deg(x(2));

    data = cell(4, 10);
    data{1,1} = '无人机运动方向'; data{1,2} = '无人机运动速度(m/s)';
    data{1,3} = '烟幕干扰弹编号'; data{1,4} = '投放点x(m)'; data{1,5} = '投放点y(m)';
    data{1,6} = '投放点z(m)'; data{1,7} = '起爆点x(m)'; data{1,8} = '起爆点y(m)';
    data{1,9} = '起爆点z(m)'; data{1,10} = '有效干扰时长(s)';

    data{2,1} = theta_deg; data{2,2} = v;

    for k = 1:3
        data{1+k, 3} = k;
        data{1+k, 4} = round(result3(k,1), 2);
        data{1+k, 5} = round(result3(k,2), 2);
        data{1+k, 6} = round(result3(k,3), 2);
        data{1+k, 7} = round(result3(k,4), 2);
        data{1+k, 8} = round(result3(k,5), 2);
        data{1+k, 9} = round(result3(k,6), 2);
    end

    T = cell2table(data(2:end,:), 'VariableNames', data(1,:));
    writetable(T, 'D:/GDUT/竞赛/mathmodeling/results/result1.xlsx');
    fprintf('result1.xlsx saved.\n');
end

function write_result2(result4)
    % 写入 result2.xlsx
    data = cell(4, 10);
    data{1,1} = '无人机编号'; data{1,2} = '无人机运动方向';
    data{1,3} = '无人机运动速度(m/s)'; data{1,4} = '投放点x(m)';
    data{1,5} = '投放点y(m)'; data{1,6} = '投放点z(m)';
    data{1,7} = '起爆点x(m)'; data{1,8} = '起爆点y(m)';
    data{1,9} = '起爆点z(m)'; data{1,10} = '有效干扰时长(s)';

    uav_names = {'FY1', 'FY2', 'FY3'};
    for j = 1:3
        data{j+1, 1} = uav_names{j};
        data{j+1, 2} = round(result4(j,2), 1);
        data{j+1, 3} = round(result4(j,1), 1);
        data{j+1, 4} = round(result4(j,3), 2);
        data{j+1, 5} = round(result4(j,4), 2);
        data{j+1, 6} = round(result4(j,5), 2);
        data{j+1, 7} = round(result4(j,6), 2);
        data{j+1, 8} = round(result4(j,7), 2);
        data{j+1, 9} = round(result4(j,8), 2);
    end

    T = cell2table(data(2:end,:), 'VariableNames', data(1,:));
    writetable(T, 'D:/GDUT/竞赛/mathmodeling/results/result2.xlsx');
    fprintf('result2.xlsx saved.\n');
end

function write_result3(all_results5, F0, g)
    % 写入 result3.xlsx
    data = cell(16, 12);
    data{1,1} = '无人机编号'; data{1,2} = '无人机运动方向'; data{1,3} = '无人机运动速度(m/s)';
    data{1,4} = '烟幕干扰弹编号'; data{1,5} = '投放点x(m)'; data{1,6} = '投放点y(m)';
    data{1,7} = '投放点z(m)'; data{1,8} = '起爆点x(m)'; data{1,9} = '起爆点y(m)';
    data{1,10} = '起爆点z(m)'; data{1,11} = '有效干扰时长(s)'; data{1,12} = '干扰的导弹编号';

    uav_names = {'FY1', 'FY2', 'FY3', 'FY4', 'FY5'};
    row = 2;

    for mi = 1:3
        if isempty(all_results5{mi})
            continue;
        end
        gbest_pos = all_results5{mi}{1};
        uav_ids = all_results5{mi}{3};
        n_uav = length(uav_ids);

        for u = 1:n_uav
            uav_idx = uav_ids(u);
            base_idx = (u-1)*8 + 1;
            v_u = gbest_pos(base_idx);
            theta_u = rad2deg(gbest_pos(base_idx+1));
            dir_u = [cosd(theta_u), sind(theta_u), 0];

            for k = 1:3
                t_d_k = gbest_pos(base_idx + 2 + (k-1)*2);
                t_b_rel_k = gbest_pos(base_idx + 3 + (k-1)*2);

                F_d = F0(uav_idx,:) + v_u * t_d_k * dir_u;
                vel_d = v_u * dir_u;
                P_b = F_d + vel_d * t_b_rel_k + 0.5 * [0, 0, -g] * t_b_rel_k^2;

                data{row, 1} = uav_names{uav_idx};
                data{row, 2} = round(theta_u, 1);
                data{row, 3} = round(v_u, 1);
                data{row, 4} = k;
                data{row, 5} = round(F_d(1), 2);
                data{row, 6} = round(F_d(2), 2);
                data{row, 7} = round(F_d(3), 2);
                data{row, 8} = round(P_b(1), 2);
                data{row, 9} = round(P_b(2), 2);
                data{row, 10} = round(P_b(3), 2);
                data{row, 12} = sprintf('M%d', mi);
                row = row + 1;
            end
        end
    end

    T = cell2table(data(2:row-1,:), 'VariableNames', data(1,:));
    writetable(T, 'D:/GDUT/竞赛/mathmodeling/results/result3.xlsx');
    fprintf('result3.xlsx saved.\n');
end
