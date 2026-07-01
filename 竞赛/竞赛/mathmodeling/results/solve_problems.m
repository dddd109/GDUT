%% 2025 CUMCM A题：烟幕干扰弹的投放策略 - 求解程序
% MATLAB solution
clear; clc;

%% Global parameters
g = 9.8;          % gravity (m/s^2)
Rc = 10;          % smoke cloud effective radius (m)
vs = 3;           % cloud sink speed (m/s)
Teff = 20;        % cloud effective duration (s)
vm = 300;         % missile speed (m/s)
dt = 0.01;        % time step (s)

% Target points
O_decoy = [0, 0, 0];                    % decoy target (missile aim point)
T_real_base = [0, 200, 0];              % real target base center
T_real_r = 7; T_real_h = 10;            % real target radius & height

% Missile initial positions [x, y, z] and speed
M0 = [20000, 0,    2000;   % M1
      19000, 600,  2100;   % M2
      18000, -600, 1900];  % M3

% UAV initial positions [x, y, z]
F0 = [17800, 0,    1800;   % FY1
      12000, 1400, 1400;   % FY2
      6000,  -3000,700;    % FY3
      11000, 2000, 1800;   % FY4
      13000, -2000,1300];  % FY5

n_missiles = 3;
n_uavs = 5;

% Compute missile direction unit vectors and arrival times
mdir = zeros(n_missiles, 3);
T_arr = zeros(n_missiles, 1);
for i = 1:n_missiles
    dist = norm(M0(i,:));
    mdir(i,:) = -M0(i,:) / dist;
    T_arr(i) = dist / vm;
end

fprintf('Missile arrival times: M1=%.2f M2=%.2f M3=%.2f\n\n', T_arr);

%% ====================================================================
%% Problem 1: Fixed parameters, compute jamming duration for M1
%% ====================================================================
fprintf('========== Problem 1 ==========\n');

% Given: FY1 v=120m/s, heading toward decoy (theta=180deg),
% deploy at t=1.5s, detonate 3.6s after deployment
v1 = 120; theta1 = 180;  % speed (m/s), angle (deg)
td1 = 1.5;               % deployment time
tb_rel1 = 3.6;            % detonation delay

% Compute positions
dir1 = [cosd(theta1), sind(theta1), 0];  % heading toward origin = (-1, 0, 0)
Fdep1 = F0(1,:) + v1 * td1 * dir1;
vel_dep1 = v1 * dir1;
Pb1 = Fdep1 + vel_dep1 * tb_rel1 + 0.5 * [0, 0, -g] * tb_rel1^2;
tb_abs1 = td1 + tb_rel1;

fprintf('  Deploy: (%.1f, %.1f, %.1f) at t=%.1fs\n', Fdep1, td1);
fprintf('  Burst:  (%.1f, %.1f, %.1f) at t=%.1fs\n', Pb1, tb_abs1);

% Compute jamming duration
M1_arr = T_arr(1);
t_start = max(tb_abs1, 0);
t_end_jam = min(tb_abs1 + Teff, M1_arr);
t_jam = t_start:dt:t_end_jam;

jam_count = 0;
for idx = 1:length(t_jam)
    t = t_jam(idx);
    Mpos = M0(1,:) + vm * t * mdir(1,:);
    Cpos = Pb1 + [0, 0, -vs * (t - tb_abs1)];
    if check_jam(Mpos, O_decoy, Cpos, Rc)
        jam_count = jam_count + 1;
    end
end
Tj1 = jam_count * dt;
fprintf('  Effective jamming: %.4f s\n\n', Tj1);

%% ====================================================================
%% Problem 2: Single UAV, single round, optimize for M1
%% ====================================================================
fprintf('========== Problem 2 ==========\n');

% Grid search + fmincon refinement
v_range = [70, 140];
theta_range = [0, 360];
td_range = [0, 30];
tb_rel_range = [0.5, 20];

% Coarse grid search
n_grid = 15;
best_obj2 = 0;
best_x2 = [120, 180, 1.5, 3.6];

for iv = 1:n_grid
    v_try = v_range(1) + (iv-1)*(v_range(2)-v_range(1))/(n_grid-1);
    for it = 1:n_grid
        theta_try = theta_range(1) + (it-1)*(theta_range(2)-theta_range(1))/(n_grid-1);
        for itd = 1:n_grid
            td_try = td_range(1) + (itd-1)*(td_range(2)-td_range(1))/(n_grid-1);
            for itb = 1:n_grid
                tb_rel_try = tb_rel_range(1) + (itb-1)*(tb_rel_range(2)-tb_rel_range(1))/(n_grid-1);

                obj_val = compute_jam(F0(1,:), v_try, theta_try, td_try, ...
                    tb_rel_try, M0(1,:), mdir(1,:), T_arr(1), vm, vs, Rc, Teff, g, dt, O_decoy);

                if obj_val > best_obj2
                    best_obj2 = obj_val;
                    best_x2 = [v_try, theta_try, td_try, tb_rel_try];
                end
            end
        end
    end
end

% Local refinement with fmincon
options = optimoptions('fmincon', 'Display', 'off', 'Algorithm', 'sqp', ...
    'MaxFunctionEvaluations', 3000);
[x_opt2, J_opt2_neg] = fmincon(@(x) -compute_jam(F0(1,:), x(1), x(2), x(3), x(4), ...
    M0(1,:), mdir(1,:), T_arr(1), vm, vs, Rc, Teff, g, dt, O_decoy), ...
    best_x2, [], [], [], [], ...
    [v_range(1), theta_range(1), td_range(1), tb_rel_range(1)], ...
    [v_range(2), theta_range(2), td_range(2), tb_rel_range(2)], [], options);
J_opt2 = -J_opt2_neg;

v_opt2 = x_opt2(1); theta_opt2 = x_opt2(2);
td_opt2 = x_opt2(3); tb_rel_opt2 = x_opt2(4);

fprintf('  v=%.2f m/s, theta=%.1f deg, td=%.2f s, tb_rel=%.2f s\n', ...
    v_opt2, theta_opt2, td_opt2, tb_rel_opt2);
fprintf('  Max jamming: %.4f s (grid: %.4f s)\n\n', J_opt2, best_obj2);

% Compute deployment and burst positions
dir_opt2 = [cosd(theta_opt2), sind(theta_opt2), 0];
Fdep2 = F0(1,:) + v_opt2 * td_opt2 * dir_opt2;
Pb2 = Fdep2 + v_opt2 * dir_opt2 * tb_rel_opt2 + 0.5 * [0, 0, -g] * tb_rel_opt2^2;
fprintf('  Deploy: (%.1f, %.1f, %.1f), Burst: (%.1f, %.1f, %.1f)\n\n', Fdep2, Pb2);

%% ====================================================================
%% Problem 3: Single UAV (FY1), 3 rounds, optimize for M1
%% ====================================================================
fprintf('========== Problem 3 ==========\n');

% PSO for 3 rounds: [v, theta, td1, tb_rel1, td2, tb_rel2, td3, tb_rel3]
n_var3 = 8;
n_part3 = 50;
n_iter3 = 150;

lb3 = [70, 0, 0, 0.5, 1, 0.5, 2, 0.5];
ub3 = [140, 360, 25, 15, 26, 15, 27, 15];

best_x3 = [];
best_J3 = 0;

% Multiple PSO runs
for run_i = 1:5
    [x3, J3] = run_pso(n_var3, n_part3, n_iter3, lb3, ub3, ...
        @(x) eval_Nrounds(x, 3, 1, F0, M0, mdir, T_arr, vm, vs, Rc, Teff, g, dt, O_decoy));
    if J3 > best_J3
        best_J3 = J3;
        best_x3 = x3;
    end
end

v3 = best_x3(1); theta3 = best_x3(2);
td3 = best_x3([3,5,7]); tb_rel3 = best_x3([4,6,8]);

fprintf('  v=%.2f, theta=%.1f deg, total jam=%.4f s\n', v3, theta3, best_J3);

dir3 = [cosd(theta3), sind(theta3), 0];
for k = 1:3
    Fdep = F0(1,:) + v3 * td3(k) * dir3;
    Pb = Fdep + v3 * dir3 * tb_rel3(k) + 0.5 * [0, 0, -g] * tb_rel3(k)^2;

    % Individual round jamming
    Jk = compute_single_round_jam(F0(1,:), v3, theta3, td3(k), tb_rel3(k), ...
        M0(1,:), mdir(1,:), T_arr(1), vm, vs, Rc, Teff, g, dt, O_decoy);

    fprintf('  Round %d: td=%.2f, tb_rel=%.2f, Deploy(%.1f,%.1f,%.1f), Burst(%.1f,%.1f,%.1f), Jam=%.4f\n', ...
        k, td3(k), tb_rel3(k), Fdep, Pb, Jk);
end

%% ====================================================================
%% Problem 4: Three UAVs (FY1,FY2,FY3), one round each, jam M1
%% ====================================================================
fprintf('\n========== Problem 4 ==========\n');

% [v1, theta1, td1, tb_rel1, v2, theta2, td2, tb_rel2, v3, theta3, td3, tb_rel3]
n_var4 = 12;
n_part4 = 60;
n_iter4 = 150;

lb4 = repmat([70, 0, 0, 0.5], 1, 3);
ub4 = repmat([140, 360, 30, 15], 1, 3);

best_x4 = []; best_J4 = 0;

for run_i = 1:5
    [x4, J4] = run_pso(n_var4, n_part4, n_iter4, lb4, ub4, ...
        @(x) eval_multiUAV_1target(x, [1,2,3], 1, F0, M0, mdir, T_arr, vm, vs, Rc, Teff, g, dt, O_decoy));
    if J4 > best_J4
        best_J4 = J4;
        best_x4 = x4;
    end
end

fprintf('  Total jam: %.4f s\n', best_J4);
for j = 1:3
    idx = (j-1)*4 + 1;
    vj = best_x4(idx); thetaj = best_x4(idx+1);
    tdj = best_x4(idx+2); tb_relj = best_x4(idx+3);
    dirj = [cosd(thetaj), sind(thetaj), 0];
    Fdep = F0(j,:) + vj * tdj * dirj;
    Pb = Fdep + vj * dirj * tb_relj + 0.5 * [0,0,-g] * tb_relj^2;
    Jj = compute_single_round_jam(F0(j,:), vj, thetaj, tdj, tb_relj, ...
        M0(1,:), mdir(1,:), T_arr(1), vm, vs, Rc, Teff, g, dt, O_decoy);
    fprintf('  FY%d: v=%.1f, theta=%.1f, Deploy(%.0f,%.0f,%.0f), Burst(%.0f,%.0f,%.0f), Jam=%.4f\n', ...
        j, vj, thetaj, Fdep, Pb, Jj);
end

%% ====================================================================
%% Problem 5: Five UAVs, up to 3 rounds each, jam M1/M2/M3
%% ====================================================================
fprintf('\n========== Problem 5 ==========\n');

% Target assignment: force balanced distribution
% FY1,FY4 -> M1, FY2,FY5 -> M2, FY3,FYx -> M3 (add FY2 to cross-cover M2&M3)
uav_to_missile = [1; 2; 3; 1; 3];  % FY1->M1, FY2->M2, FY3->M3, FY4->M1, FY5->M3
fprintf('  Assignment: ');
for j = 1:5
    fprintf('FY%d->M%d  ', j, uav_to_missile(j));
end
fprintf('\n');

% Optimize each missile group separately
total_J5 = 0;
result5 = cell(3, 3);  % {x_opt, J_opt, uav_indices} for each missile

for mi = 1:3
    uavs_for_mi = find(uav_to_missile == mi);
    n_uav = length(uavs_for_mi);

    if n_uav == 0
        continue;
    end

    fprintf('\n  --- Missile M%d: %d UAVs ---\n', mi, n_uav);

    % Each UAV can deploy up to 3 rounds
    % Variables: [v_j, theta_j, td1_j, tb_rel1_j, td2_j, tb_rel2_j, td3_j, tb_rel3_j] for each UAV
    n_var5 = n_uav * 8;
    lb5 = [];
    ub5 = [];
    for u = 1:n_uav
        lb5 = [lb5, 70, 0, 0, 0.5, 1, 0.5, 2, 0.5];
        ub5 = [ub5, 140, 360, 25, 15, 26, 15, 27, 15];
    end

    n_part5 = min(40, 15 * n_uav);
    n_iter5 = 100;

    best_x5 = []; best_J5i = 0;

    for run_i = 1:3
        [x5, J5i] = run_pso(n_var5, n_part5, n_iter5, lb5, ub5, ...
            @(x) eval_UAVcluster(x, uavs_for_mi, mi, F0, M0, mdir, T_arr, vm, vs, Rc, Teff, g, dt, O_decoy));
        if J5i > best_J5i
            best_J5i = J5i;
            best_x5 = x5;
        end
    end

    total_J5 = total_J5 + best_J5i;
    result5{mi, 1} = best_x5;
    result5{mi, 2} = best_J5i;
    result5{mi, 3} = uavs_for_mi;

    fprintf('  M%d jam: %.4f s\n', mi, best_J5i);

    % Print details (only if > 0)
    if best_J5i > 0 && ~isempty(best_x5) && length(best_x5) >= n_uav * 8
        for u = 1:n_uav
            uav_idx = uavs_for_mi(u);
            base = (u-1)*8 + 1;
            if base + 7 > length(best_x5), break; end
            vu = best_x5(base); thetau = best_x5(base+1);
        diru = [cosd(thetau), sind(thetau), 0];
        for k = 1:3
            tdk = best_x5(base+2+(k-1)*2);
            tbrk = best_x5(base+3+(k-1)*2);
            Fdep = F0(uav_idx,:) + vu * tdk * diru;
            Pb = Fdep + vu * diru * tbrk + 0.5*[0,0,-g]*tbrk^2;
            fprintf('    FY%d round%d: td=%.2f tb_rel=%.2f Dep(%.0f,%.0f,%.0f) Bur(%.0f,%.0f,%.0f)\n', ...
                uav_idx, k, tdk, tbrk, Fdep, Pb);
            end
        end
    end
end

fprintf('\n  Total jamming (all missiles): %.4f s\n', total_J5);

%% ====================================================================
%% Save results to Excel
%% ====================================================================
out_dir = 'D:/GDUT/竞赛/mathmodeling/results/';

% --- result1.xlsx (Problem 3) ---
fprintf('\n--- Saving result1.xlsx ---\n');
dir3v = [cosd(theta3), sind(theta3), 0];
res1_data = zeros(3, 9);  % [RoundNo, td, tb_rel, DepX, DepY, DepZ, BurX, BurY, BurZ]
for k = 1:3
    Fdep = F0(1,:) + v3 * td3(k) * dir3v;
    Pb = Fdep + v3 * dir3v * tb_rel3(k) + 0.5 * [0,0,-g] * tb_rel3(k)^2;
    res1_data(k,:) = [k, td3(k), tb_rel3(k), Fdep, Pb];
end
T1 = array2table(rd(res1_data), 'VariableNames', ...
    {'RoundNo','DeployTime_s','BurstDelay_s','DepX_m','DepY_m','DepZ_m','BurX_m','BurY_m','BurZ_m'});
writetable(T1, [out_dir 'result1.xlsx']);
fprintf('  result1.xlsx saved.\n');

% --- result2.xlsx (Problem 4) ---
fprintf('--- Saving result2.xlsx ---\n');
uav_names = {'FY1','FY2','FY3'}';
v_list = zeros(3,1); theta_list = zeros(3,1);
depX = zeros(3,1); depY = zeros(3,1); depZ = zeros(3,1);
burX = zeros(3,1); burY = zeros(3,1); burZ = zeros(3,1);
jam_list = zeros(3,1);
for j = 1:3
    idx = (j-1)*4+1;
    v_list(j) = best_x4(idx); theta_list(j) = best_x4(idx+1);
    td_j = best_x4(idx+2); tb_j = best_x4(idx+3);
    d_j = [cosd(theta_list(j)), sind(theta_list(j)), 0];
    Fdep = F0(j,:) + v_list(j) * td_j * d_j;
    Pb = Fdep + v_list(j) * d_j * tb_j + 0.5*[0,0,-g]*tb_j^2;
    depX(j) = Fdep(1); depY(j) = Fdep(2); depZ(j) = Fdep(3);
    burX(j) = Pb(1); burY(j) = Pb(2); burZ(j) = Pb(3);
    jam_list(j) = compute_single_round_jam(F0(j,:), v_list(j), theta_list(j), td_j, tb_j, ...
        M0(1,:), mdir(1,:), T_arr(1), vm, vs, Rc, Teff, g, dt, O_decoy);
end
T2 = table(uav_names, rd(theta_list), rd(v_list), rd(depX), rd(depY), rd(depZ), ...
    rd(burX), rd(burY), rd(burZ), rd(jam_list), ...
    'VariableNames', {'UAV','Direction_deg','Speed_ms','DepX','DepY','DepZ','BurX','BurY','BurZ','Jam_s'});
writetable(T2, [out_dir 'result2.xlsx']);
fprintf('  result2.xlsx saved.\n');

% --- result3.xlsx (Problem 5) ---
fprintf('--- Saving result3.xlsx ---\n');
r3_data = {};
for mi = 1:3
    if isempty(result5{mi,1}) || result5{mi,2} <= 0
        continue;
    end
    x_mi = result5{mi,1};
    uav_ids = result5{mi,3};
    n_u = length(uav_ids);
    if length(x_mi) < n_u * 8, continue; end
    for u = 1:n_u
        base = (u-1)*8+1;
        uav_idx = uav_ids(u);
        vu = x_mi(base); thetau = x_mi(base+1);
        du = [cosd(thetau), sind(thetau), 0];
        for k = 1:3
            tdk = x_mi(base+2+(k-1)*2);
            tbrk = x_mi(base+3+(k-1)*2);
            Fdep = F0(uav_idx,:) + vu * tdk * du;
            Pb = Fdep + vu * du * tbrk + 0.5*[0,0,-g]*tbrk^2;
            r3_data = [r3_data; {sprintf('FY%d',uav_idx), rd(thetau), rd(vu), k, ...
                rd(Fdep(1)), rd(Fdep(2)), rd(Fdep(3)), rd(Pb(1)), rd(Pb(2)), rd(Pb(3)), ...
                sprintf('M%d',mi)}];
        end
    end
end
T3 = cell2table(r3_data, 'VariableNames', {'UAV','Direction_deg','Speed_ms','RoundNo',...
    'DepX','DepY','DepZ','BurX','BurY','BurZ','TargetMissile'});
writetable(T3, [out_dir 'result3.xlsx']);
fprintf('  result3.xlsx saved.\n');

%% ====================================================================
%% Generate visualizations
%% ====================================================================
fprintf('\n--- Generating figures ---\n');

% Figure 1: 3D scene overview
fig1 = figure('Position', [100, 100, 1000, 700], 'Visible', 'off');
hold on; grid on;
xlabel('x (m) East'); ylabel('y (m) South'); zlabel('z (m) Up');
title('3D Scene: Missile Threat & UAV Deployment');
axis equal; view(40, 25);

% Axes
plot3([0 5000], [0 0], [0 0], 'k-', 'LineWidth', 0.5);
plot3([0 0], [0 5000], [0 0], 'k-', 'LineWidth', 0.5);
plot3([0 0], [0 0], [0 3000], 'k-', 'LineWidth', 0.5);

% Real target cylinder
[Xc, Yc, Zc] = cylinder(T_real_r, 30);
Zc = Zc * T_real_h;
surf(Xc, Yc+200, Zc, 'FaceColor', [0.2 0.8 0.2], 'FaceAlpha', 0.3, 'EdgeColor', 'none');

% Decoy target
plot3(0, 0, 0, 'rx', 'MarkerSize', 15, 'LineWidth', 3);
text(0, 0, 100, 'Decoy Target (Origin)', 'FontSize', 9);

% Missile trajectories
colors = lines(3);
for i = 1:3
    t_traj = linspace(0, T_arr(i), 100);
    M_traj = M0(i,:) + vm * t_traj' * mdir(i,:);
    plot3(M_traj(:,1), M_traj(:,2), M_traj(:,3), '-', 'Color', colors(i,:), 'LineWidth', 1.5);
    plot3(M0(i,1), M0(i,2), M0(i,3), 'o', 'Color', colors(i,:), 'MarkerSize', 8, 'MarkerFaceColor', colors(i,:));
    text(M0(i,1), M0(i,2), M0(i,3)+150, sprintf('M%d', i), 'FontSize', 10);
end

% UAV positions
for j = 1:5
    plot3(F0(j,1), F0(j,2), F0(j,3), 's', 'Color', [0.8 0.4 0], 'MarkerSize', 8, 'MarkerFaceColor', [1 0.6 0]);
    text(F0(j,1), F0(j,2), F0(j,3)+120, sprintf('FY%d', j), 'FontSize', 9);
end

legend({'Axes', '', '', 'Real Target', 'Decoy Target', 'M1 traj', 'M1 start', ...
    'M2 traj', 'M2 start', 'M3 traj', 'M3 start', 'UAVs'}, 'Location', 'eastoutside');
saveas(fig1, [out_dir 'figure1_scene.png']);
close(fig1);
fprintf('  figure1_scene.png saved.\n');

% Figure 2: Jamming timeline (Problem 1)
fig2 = figure('Position', [100, 100, 900, 500], 'Visible', 'off');
t_plot = 0:dt:T_arr(1);
jam_state = zeros(size(t_plot));
for idx = 1:length(t_plot)
    t = t_plot(idx);
    Mpos = M0(1,:) + vm * t * mdir(1,:);
    if t >= tb_abs1 && t <= tb_abs1 + Teff
        Cpos = Pb1 + [0, 0, -vs * (t - tb_abs1)];
        jam_state(idx) = check_jam(Mpos, O_decoy, Cpos, Rc);
    end
end

subplot(2,1,1);
plot(t_plot, M0(1,3) + vm * t_plot * mdir(1,3), 'b-', 'LineWidth', 1.5);
hold on;
yline(Pb1(3), 'r--', 'LineWidth', 1);
xlabel('Time (s)'); ylabel('Height (m)');
title('Problem 1: Missile Height vs Time');
legend('Missile z', 'Cloud burst z');

subplot(2,1,2);
area(t_plot, jam_state, 'FaceColor', [0.3 0.7 0.3], 'EdgeColor', 'none');
xlabel('Time (s)'); ylabel('Jamming');
title(sprintf('Jamming State (Total: %.2f s)', Tj1));
ylim([0, 1.2]); xlim([0, T_arr(1)]);

saveas(fig2, [out_dir 'figure2_problem1_timeline.png']);
close(fig2);
fprintf('  figure2_problem1_timeline.png saved.\n');

% Figure 3: Comparison of all problems
fig3 = figure('Position', [100, 100, 800, 500], 'Visible', 'off');
jam_values = [Tj1, J_opt2, best_J3, best_J4, total_J5];
bar(jam_values, 'FaceColor', [0.2 0.4 0.7]);
xlabel('Problem'); ylabel('Effective Jamming Duration (s)');
title('Comparison of Optimal Jamming Duration Across Problems');
set(gca, 'XTickLabel', {'P1 (fixed)', 'P2 (1UAV-1rd)', 'P3 (1UAV-3rd)', 'P4 (3UAV-3rd)', 'P5 (5UAV-9rd)'});
grid on;
for i = 1:5
    text(i, jam_values(i) + 0.5, sprintf('%.2f s', jam_values(i)), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 11);
end
saveas(fig3, [out_dir 'figure3_comparison.png']);
close(fig3);
fprintf('  figure3_comparison.png saved.\n');

% Figure 4: Problem 5 target assignment (top-down view)
fig4 = figure('Position', [100, 100, 800, 600], 'Visible', 'off');
hold on; grid on; axis equal;
xlabel('x (m) East'); ylabel('y (m) South');
title('Problem 5: UAV-Missile Assignment (Top-down View)');

for i = 1:3
    plot(M0(i,1), M0(i,2), '^', 'Color', colors(i,:), 'MarkerSize', 12, 'MarkerFaceColor', colors(i,:));
    text(M0(i,1), M0(i,2)+300, sprintf('M%d', i), 'FontSize', 11, 'Color', colors(i,:));
end
for j = 1:5
    plot(F0(j,1), F0(j,2), 's', 'Color', colors(uav_to_missile(j),:), ...
        'MarkerSize', 10, 'MarkerFaceColor', colors(uav_to_missile(j),:));
    text(F0(j,1), F0(j,2)+300, sprintf('FY%d', j), 'FontSize', 10);
end
legend({'M1', 'M2', 'M3', 'UAVs (color = assigned missile)'}, 'Location', 'best');
saveas(fig4, [out_dir 'figure4_assignment.png']);
close(fig4);
fprintf('  figure4_assignment.png saved.\n');

fprintf('\n===== All problems solved =====\n');
fprintf('Results saved to: %s\n', out_dir);

%% ====================================================================
%% Helper Functions
%% ====================================================================

function ok = check_jam(M, O, C, R)
    % Check if line segment M->O intersects sphere (C, R)
    d = O - M;
    L = norm(d);
    if L < 1e-10
        ok = norm(C - M) <= R;
        return;
    end
    d = d / L;
    v = C - M;
    s = dot(v, d);
    if s < 0 || s > L
        ok = false;
        return;
    end
    Pc = M + s * d;
    ok = norm(Pc - C) <= R;
end

function J = compute_jam(F0_j, v, theta, td, tb_rel, M0_i, mdir_i, T_arr, vm, vs, Rc, Teff, g, dt, O)
    % Compute jamming duration for a single round
    theta_rad = deg2rad(theta);
    dir_vec = [cos(theta_rad), sin(theta_rad), 0];
    Fdep = F0_j + v * td * dir_vec;
    Pb = Fdep + v * dir_vec * tb_rel + 0.5 * [0, 0, -g] * tb_rel^2;
    tb_abs = td + tb_rel;

    if tb_abs >= T_arr
        J = 0;
        return;
    end

    t_end = min(tb_abs + Teff, T_arr);
    t_vec = tb_abs:dt:t_end;
    count = 0;
    for idx = 1:length(t_vec)
        t_i = t_vec(idx);
        Mpos = M0_i + vm * t_i * mdir_i;
        Cpos = Pb + [0, 0, -vs * (t_i - tb_abs)];
        if check_jam(Mpos, O, Cpos, Rc)
            count = count + 1;
        end
    end
    J = count * dt;
end

function Js = compute_single_round_jam(F0_j, v, theta, td, tb_rel, M0_i, mdir_i, T_arr, vm, vs, Rc, Teff, g, dt, O)
    % Wrapper for single round jam computation
    Js = compute_jam(F0_j, v, theta, td, tb_rel, M0_i, mdir_i, T_arr, vm, vs, Rc, Teff, g, dt, O);
end

function J = eval_Nrounds(x, N, mi, F0, M0, mdir, T_arr, vm, vs, Rc, Teff, g, dt, O)
    % Evaluate total jamming duration for N rounds from 1 UAV
    v = x(1); theta = x(2);
    jam_array = false(1, ceil(T_arr(mi)/dt) + 1);
    t_vec = (0:dt:T_arr(mi))';

    for k = 1:N
        tdk = x(2 + 2*k - 1); tb_relk = x(2 + 2*k);
        if tdk + tb_relk >= T_arr(mi)
            continue;
        end
        Fdep = F0(1,:) + v * tdk * [cosd(theta), sind(theta), 0];
        Pb = Fdep + v * [cosd(theta), sind(theta), 0] * tb_relk + 0.5 * [0, 0, -g] * tb_relk^2;
        tb_abs = tdk + tb_relk;

        i_s = max(1, ceil(tb_abs/dt));
        i_e = min(length(t_vec), ceil((tb_abs + Teff)/dt));

        for i = i_s:i_e
            t_i = t_vec(i);
            Mpos = M0(mi,:) + vm * t_i * mdir(mi,:);
            Cpos = Pb + [0, 0, -vs * (t_i - tb_abs)];
            jam_array(i) = jam_array(i) || check_jam(Mpos, O, Cpos, Rc);
        end
    end
    J = sum(jam_array) * dt;
end

function J = eval_multiUAV_1target(x, uav_ids, mi, F0, M0, mdir, T_arr, vm, vs, Rc, Teff, g, dt, O)
    % Evaluate cooperative jamming from multiple UAVs for 1 target missile
    jam_array = false(1, ceil(T_arr(mi)/dt) + 1);
    t_vec = (0:dt:T_arr(mi))';

    for j = 1:length(uav_ids)
        uav_idx = uav_ids(j);
        idx = (j-1)*4 + 1;
        vj = x(idx); thetaj = x(idx+1);
        tdj = x(idx+2); tb_relj = x(idx+3);

        if tdj + tb_relj >= T_arr(mi)
            continue;
        end

        dirj = [cosd(thetaj), sind(thetaj), 0];
        Fdep = F0(uav_idx,:) + vj * tdj * dirj;
        Pb = Fdep + vj * dirj * tb_relj + 0.5 * [0, 0, -g] * tb_relj^2;
        tb_abs = tdj + tb_relj;

        i_s = max(1, ceil(tb_abs/dt));
        i_e = min(length(t_vec), ceil((tb_abs + Teff)/dt));

        for i = i_s:i_e
            t_i = t_vec(i);
            Mpos = M0(mi,:) + vm * t_i * mdir(mi,:);
            Cpos = Pb + [0, 0, -vs * (t_i - tb_abs)];
            jam_array(i) = jam_array(i) || check_jam(Mpos, O, Cpos, Rc);
        end
    end
    J = sum(jam_array) * dt;
end

function J = eval_UAVcluster(x, uav_ids, mi, F0, M0, mdir, T_arr, vm, vs, Rc, Teff, g, dt, O)
    % Evaluate cluster of UAVs with multiple rounds for 1 target missile
    jam_array = false(1, ceil(T_arr(mi)/dt) + 1);
    t_vec = (0:dt:T_arr(mi))';

    for u = 1:length(uav_ids)
        uav_idx = uav_ids(u);
        base = (u-1)*8 + 1;
        vu = x(base); thetau = x(base+1);
        diru = [cosd(thetau), sind(thetau), 0];

        for k = 1:3
            tdk = x(base + 2 + (k-1)*2);
            tbrk = x(base + 3 + (k-1)*2);

            if tdk + tbrk >= T_arr(mi)
                continue;
            end

            Fdep = F0(uav_idx,:) + vu * tdk * diru;
            Pb = Fdep + vu * diru * tbrk + 0.5 * [0, 0, -g] * tbrk^2;
            tb_abs = tdk + tbrk;

            i_s = max(1, ceil(tb_abs/dt));
            i_e = min(length(t_vec), ceil((tb_abs + Teff)/dt));

            for i = i_s:i_e
                t_i = t_vec(i);
                Mpos = M0(mi,:) + vm * t_i * mdir(mi,:);
                Cpos = Pb + [0, 0, -vs * (t_i - tb_abs)];
                jam_array(i) = jam_array(i) || check_jam(Mpos, O, Cpos, Rc);
            end
        end
    end
    J = sum(jam_array) * dt;
end

function [best_x, best_J] = run_pso(n_var, n_part, n_iter, lb, ub, obj_fun)
    % Particle Swarm Optimization
    pos = lb + rand(n_part, n_var) .* (ub - lb);
    vel = zeros(n_part, n_var);

    pbest_pos = pos;
    pbest_val = -inf(n_part, 1);
    gbest_val = -inf;
    gbest_pos = pos(1,:);

    for iter = 1:n_iter
        w = 0.9 - 0.5 * iter / n_iter;  % Inertia decay

        for i = 1:n_part
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

        for i = 1:n_part
            r1 = rand(1, n_var); r2 = rand(1, n_var);
            vel(i,:) = w * vel(i,:) + 1.5 * r1 .* (pbest_pos(i,:) - pos(i,:)) ...
                                    + 1.5 * r2 .* (gbest_pos - pos(i,:));
            rng = ub - lb;
            vel(i,:) = min(max(vel(i,:), -0.15*rng), 0.15*rng);
            pos(i,:) = pos(i,:) + vel(i,:);
            pos(i,:) = min(max(pos(i,:), lb), ub);
        end
    end

    best_x = gbest_pos;
    best_J = gbest_val;
end

function v = rd(x)
    % Round to 2 decimal places
    v = round(x * 100) / 100;
end
