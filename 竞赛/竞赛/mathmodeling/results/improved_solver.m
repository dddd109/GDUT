%% Improved solver for 2025 CUMCM A题
% Key improvements:
% 1. Heuristic-guided PSO initialization
% 2. Better target assignment for Problem 5
% 3. Staged optimization (coarse -> fine)
% 4. Cross-UAV coordination for Problems 4-5
clear; clc;

%% Global parameters
g = 9.8; Rc = 10; vs = 3; Teff = 20; vm = 300; dt = 0.01;
O = [0, 0, 0];

M0 = [20000, 0, 2000; 19000, 600, 2100; 18000, -600, 1900];
F0 = [17800, 0, 1800; 12000, 1400, 1400; 6000, -3000, 700; 11000, 2000, 1800; 13000, -2000, 1300];

n_m = 3; n_f = 5;
mdir = zeros(n_m, 3); T_arr = zeros(n_m, 1);
for i = 1:n_m
    d = norm(M0(i,:));
    mdir(i,:) = -M0(i,:) / d;
    T_arr(i) = d / vm;
end

out_dir = 'D:/GDUT/竞赛/mathmodeling/results/';

%% ======== Problem 1: Fixed params ========
fprintf('===== Problem 1 =====\n');
v1 = 120; theta1 = 180; td1 = 1.5; tb_rel1 = 3.6;
[Tj1, Pb1, tb_abs1] = calc_jam_fixed(F0(1,:), v1, theta1, td1, tb_rel1, ...
    M0(1,:), mdir(1,:), T_arr(1), vm, vs, Rc, Teff, g, dt, O);
fprintf('  Jam: %.4f s\n', Tj1);

%% ======== Problem 2: Single UAV, single round, optimize ========
fprintf('\n===== Problem 2: Improved =====\n');

% Heuristic: cloud should be on missile's LOS.
% Missile LOS: z = (M_z0/M_x0)*x = k_m * x in xz-plane
% For M1: k_m = 2000/20000 = 0.1
% Best cloud x should be as close to origin as possible (small x)
% while still being between missile and origin for long duration.
% M_x(t) = M_x0 - v_m*t*|d_x|, so missile passes x at t = (M_x0-x)/(v_m*|d_x|)
% Cloud at x_c: jamming from t_start to min(t_pass, t_b+20)
% where t_pass = (M_x0 - x_c)/(v_m*|d_x|)

% Grid search (finer)
v_vals = linspace(70, 140, 30);
theta_vals = linspace(0, 359, 72);  % 5 deg steps
td_vals = [0, 0.5, 1:30];
tb_rel_vals = [0.5, 1:2:20];

best_J2 = 0; best_x2 = [120, 180, 1.5, 3.6];

% Smart grid: focus on promising regions
for vi = 1:5:length(v_vals)
    v_t = v_vals(vi);
    for ti = 1:4:length(theta_vals)
        th_t = theta_vals(ti);
        for tdi = 1:3:length(td_vals)
            td_t = td_vals(tdi);
            for tbi = 1:3:length(tb_rel_vals)
                tb_t = tb_rel_vals(tbi);
                J = calc_jam(F0(1,:), v_t, th_t, td_t, tb_t, ...
                    M0(1,:), mdir(1,:), T_arr(1), vm, vs, Rc, Teff, g, dt, O);
                if J > best_J2
                    best_J2 = J; best_x2 = [v_t, th_t, td_t, tb_t];
                end
            end
        end
    end
end

% SQP refinement (multiple starts)
options = optimoptions('fmincon', 'Display', 'off', 'Algorithm', 'sqp', 'MaxFunctionEvaluations', 3000);
for restart = 1:5
    x0_r = best_x2 + [20*(rand-0.5), 30*(rand-0.5), 5*(rand-0.5), 5*(rand-0.5)];
    x0_r = max(min(x0_r, [140, 359, 30, 20]), [70, 0, 0, 0.5]);
    [x_opt, J_neg] = fmincon(@(x) -calc_jam(F0(1,:), x(1), x(2), x(3), x(4), ...
        M0(1,:), mdir(1,:), T_arr(1), vm, vs, Rc, Teff, g, dt, O), ...
        x0_r, [], [], [], [], [70,0,0,0.5], [140,359,30,20], [], options);
    if -J_neg > best_J2
        best_J2 = -J_neg; best_x2 = x_opt;
    end
end

v2 = best_x2(1); th2 = best_x2(2); td2 = best_x2(3); tb2 = best_x2(4);
fprintf('  v=%.2f, theta=%.1f, td=%.2f, tb_rel=%.2f, Jam=%.4f\n', v2, th2, td2, tb2, best_J2);

%% ======== Problem 3: Single UAV, 3 rounds ========
fprintf('\n===== Problem 3: Improved PSO =====\n');

n_var3 = 8; n_pop3 = 60; n_iter3 = 200;
lb3 = [70, 0, 0, 0.5, 1, 0.5, 2, 0.5];
ub3 = [140, 360, 28, 15, 29, 15, 30, 15];

% Heuristic init: successive rounds
init_pop3 = lhsdesign(n_pop3, n_var3);  % Latin Hypercube for better coverage
pos3 = lb3 + init_pop3 .* (ub3 - lb3);
% Enforce td sequence
pos3(:,5) = max(pos3(:,5), pos3(:,3) + 1);
pos3(:,7) = max(pos3(:,7), pos3(:,5) + 1);

[best_x3, best_J3] = pso_improved(n_var3, n_pop3, n_iter3, lb3, ub3, pos3, ...
    @(x) eval_N_rounds(x, 3, M0(1,:), mdir(1,:), T_arr(1), F0(1,:), vm, vs, Rc, Teff, g, dt, O), 5);

v3 = best_x3(1); th3 = best_x3(2);
fprintf('  v=%.2f, theta=%.1f, Total Jam=%.4f\n', v3, th3, best_J3);
for k = 1:3
    Jk = calc_jam(F0(1,:), v3, th3, best_x3(2+2*k-1), best_x3(2+2*k), ...
        M0(1,:), mdir(1,:), T_arr(1), vm, vs, Rc, Teff, g, dt, O);
    fprintf('  R%d: td=%.2f tb_rel=%.2f Jam=%.4f\n', k, best_x3(2+2*k-1), best_x3(2+2*k), Jk);
end

%% ======== Problem 4: 3 UAVs, 1 round each ========
fprintf('\n===== Problem 4: Improved Co-op =====\n');

% Each UAV optimized to contribute non-overlapping coverage
n_var4 = 12; n_pop4 = 80; n_iter4 = 250;
lb4 = repmat([70, 0, 0, 0.5], 1, 3);
ub4 = repmat([140, 360, 30, 15], 1, 3);

% Intelligent initialization: each UAV targets different phase of missile flight
init4 = lhsdesign(n_pop4, n_var4);
pos4 = lb4 + init4 .* (ub4 - lb4);
% Bias FY1 toward early phase, FY2 toward mid, FY3 toward late
pos4(:,3) = pos4(:,3) * 0.3;           % FY1: early deployment
pos4(:,7) = 5 + pos4(:,7) * 0.3;       % FY2: mid deployment
pos4(:,11) = 10 + pos4(:,11) * 0.3;    % FY3: late deployment

[best_x4, best_J4] = pso_improved(n_var4, n_pop4, n_iter4, lb4, ub4, pos4, ...
    @(x) eval_multi_uav_coop(x, [1,2,3], M0(1,:), mdir(1,:), T_arr(1), F0, vm, vs, Rc, Teff, g, dt, O), 5);

fprintf('  Total Coop Jam: %.4f s\n', best_J4);
for j = 1:3
    idx = (j-1)*4+1;
    vj = best_x4(idx); thj = best_x4(idx+1);
    tdj = best_x4(idx+2); tbj = best_x4(idx+3);
    Jj = calc_jam(F0(j,:), vj, thj, tdj, tbj, ...
        M0(1,:), mdir(1,:), T_arr(1), vm, vs, Rc, Teff, g, dt, O);
    fprintf('  FY%d: v=%.1f th=%.1f td=%.2f tb=%.2f Jam=%.4f\n', j, vj, thj, tdj, tbj, Jj);
end

%% ======== Problem 5: Full scenario ========
fprintf('\n===== Problem 5: Full Scenario =====\n');

% Optimal target assignment via greedy heuristic
% Assign each UAV to the missile whose LOS passes closest to the UAV
uav_assign = zeros(5, 1);
for j = 1:5
    best_dist = inf;
    for mi = 1:3
        % Distance from UAV to missile trajectory line (in xy projection)
        d = dist_point_to_line_2d(F0(j,1:2), M0(mi,1:2), [0,0]);
        if d < best_dist
            best_dist = d;
            uav_assign(j) = mi;
        end
    end
end

% Ensure coverage: at least 1 UAV per missile
coverage = histcounts(uav_assign, 0.5:1:3.5);
for mi = 1:3
    if coverage(mi) == 0
        % Reassign the UAV farthest from its current missile
        [~, far_uav] = max(arrayfun(@(j) dist_point_to_line_2d(F0(j,1:2), M0(uav_assign(j),1:2), [0,0]), 1:5));
        uav_assign(far_uav) = mi;
        coverage = histcounts(uav_assign, 0.5:1:3.5);
    end
end

fprintf('  Assignment: ');
for j = 1:5, fprintf('FY%d->M%d  ', j, uav_assign(j)); end
fprintf('\n');

total_J5 = 0;
result5 = cell(3, 3);

for mi = 1:3
    uavs = find(uav_assign == mi);
    n_u = length(uavs);
    fprintf('\n  M%d: %d UAVs\n', mi, n_u);

    n_var = n_u * 8;
    lb_i = []; ub_i = [];
    for u = 1:n_u
        lb_i = [lb_i, 70, 0, 0, 0.5, 1, 0.5, 2, 0.5];
        ub_i = [ub_i, 140, 360, 25, 15, 26, 15, 27, 15];
    end

    n_pop = min(60, 20 * n_u);
    n_iter = 150;

    init_i = lhsdesign(n_pop, n_var);
    pos_i = lb_i + init_i .* (ub_i - lb_i);

    [x_i, J_i] = pso_improved(n_var, n_pop, n_iter, lb_i, ub_i, pos_i, ...
        @(x) eval_cluster_jam(x, uavs, M0(mi,:), mdir(mi,:), T_arr(mi), F0, vm, vs, Rc, Teff, g, dt, O), 3);

    total_J5 = total_J5 + J_i;
    result5{mi,1} = x_i; result5{mi,2} = J_i; result5{mi,3} = uavs;
    fprintf('  M%d Jam: %.4f s\n', mi, J_i);

    if J_i > 0 && ~isempty(x_i) && length(x_i) >= n_u * 8
        for u = 1:n_u
            uid = uavs(u); base = (u-1)*8+1;
            if base+7 > length(x_i), break; end
            vu = x_i(base); thu = x_i(base+1);
            for k = 1:3
                tdk = x_i(base+2+(k-1)*2);
                tbk = x_i(base+3+(k-1)*2);
                Jk = calc_jam(F0(uid,:), vu, thu, tdk, tbk, ...
                    M0(mi,:), mdir(mi,:), T_arr(mi), vm, vs, Rc, Teff, g, dt, O);
                fprintf('    FY%d R%d: td=%.2f tb=%.2f Jam=%.4f\n', uid, k, tdk, tbk, Jk);
            end
        end
    end
end

fprintf('\n  TOTAL JAMMING: %.4f s\n', total_J5);

%% ======== Save Results ========
fprintf('\n===== Saving Excel Files =====\n');
save_all_results(best_x3, best_x4, result5, F0, M0, mdir, T_arr, vm, vs, Rc, Teff, g, dt, O, out_dir);

%% ======== Generate Visualizations ========
fprintf('\n===== Generating Figures =====\n');
generate_improved_figures(F0, M0, mdir, T_arr, vm, vs, Rc, Teff, g, dt, O, ...
    Tj1, best_J2, best_J3, best_J4, total_J5, uav_assign, out_dir);

%% Final Summary
fprintf('\n========================================\n');
fprintf('FINAL RESULTS SUMMARY\n');
fprintf('========================================\n');
fprintf('Problem 1: %.4f s (baseline)\n', Tj1);
fprintf('Problem 2: %.4f s (+%.1f%%)\n', best_J2, (best_J2/Tj1-1)*100);
fprintf('Problem 3: %.4f s (+%.1f%% over P2)\n', best_J3, (best_J3/best_J2-1)*100);
fprintf('Problem 4: %.4f s\n', best_J4);
fprintf('Problem 5: %.4f s (M1+M2+M3)\n', total_J5);
fprintf('All results saved to: %s\n', out_dir);

%% ================== HELPER FUNCTIONS ==================

function J = calc_jam(F0_j, v, theta, td, tb_rel, M0_i, mdir_i, T_arr, vm, vs, Rc, Teff, g, dt, O)
    th = deg2rad(theta);
    dir_v = [cos(th), sin(th), 0];
    Fdep = F0_j + v * td * dir_v;
    Pb = Fdep + v * dir_v * tb_rel + 0.5 * [0,0,-g] * tb_rel^2;
    tb_abs = td + tb_rel;
    if tb_abs >= T_arr, J = 0; return; end
    t_end = min(tb_abs + Teff, T_arr);
    t_vec = tb_abs:dt:t_end;
    cnt = 0;
    for i = 1:length(t_vec)
        t = t_vec(i);
        Mpos = M0_i + vm * t * mdir_i;
        Cpos = Pb + [0, 0, -vs*(t-tb_abs)];
        if check_jam(Mpos, O, Cpos, Rc), cnt = cnt+1; end
    end
    J = cnt * dt;
end

function [J, Pb, tb_abs] = calc_jam_fixed(F0_j, v, theta, td, tb_rel, M0_i, mdir_i, T_arr, vm, vs, Rc, Teff, g, dt, O)
    th = deg2rad(theta);
    dir_v = [cos(th), sin(th), 0];
    Fdep = F0_j + v * td * dir_v;
    Pb = Fdep + v * dir_v * tb_rel + 0.5 * [0,0,-g] * tb_rel^2;
    tb_abs = td + tb_rel;
    if tb_abs >= T_arr, J = 0; return; end
    t_end = min(tb_abs + Teff, T_arr);
    t_vec = tb_abs:dt:t_end;
    cnt = 0;
    for i = 1:length(t_vec)
        t = t_vec(i);
        Mpos = M0_i + vm * t * mdir_i;
        Cpos = Pb + [0, 0, -vs*(t-tb_abs)];
        if check_jam(Mpos, O, Cpos, Rc), cnt = cnt+1; end
    end
    J = cnt * dt;
end

function ok = check_jam(M, O, C, R)
    d = O - M; L = norm(d);
    if L < 1e-10, ok = norm(C-M) <= R; return; end
    d = d/L;
    v = C - M; s = dot(v,d);
    if s < 0 || s > L, ok = false; return; end
    ok = norm(M + s*d - C) <= R;
end

function J = eval_N_rounds(x, N, M0_i, mdir_i, T_arr, F0_i, vm, vs, Rc, Teff, g, dt, O)
    v = x(1); theta = x(2);
    jam = false(1, ceil(T_arr/dt)+1);
    t_vec = 0:dt:T_arr;
    for k = 1:N
        tdk = x(2+2*k-1); tbk = x(2+2*k);
        if tdk+tbk >= T_arr, continue; end
        dir_v = [cosd(theta), sind(theta), 0];
        Fdep = F0_i + v*tdk*dir_v;
        Pb = Fdep + v*dir_v*tbk + 0.5*[0,0,-g]*tbk^2;
        tb = tdk+tbk;
        is_ = max(1,ceil(tb/dt)); ie = min(length(t_vec),ceil((tb+Teff)/dt));
        for i = is_:ie
            t = t_vec(i);
            Mpos = M0_i + vm*t*mdir_i;
            Cpos = Pb + [0,0,-vs*(t-tb)];
            jam(i) = jam(i) || check_jam(Mpos, O, Cpos, Rc);
        end
    end
    J = sum(jam)*dt;
end

function J = eval_multi_uav_coop(x, uav_ids, M0_i, mdir_i, T_arr, F0, vm, vs, Rc, Teff, g, dt, O)
    jam = false(1, ceil(T_arr/dt)+1);
    t_vec = 0:dt:T_arr;
    for j = 1:length(uav_ids)
        uid = uav_ids(j); idx = (j-1)*4+1;
        vj = x(idx); thj = x(idx+1); tdj = x(idx+2); tbj = x(idx+3);
        if tdj+tbj >= T_arr, continue; end
        dir_v = [cosd(thj), sind(thj), 0];
        Fdep = F0(uid,:) + vj*tdj*dir_v;
        Pb = Fdep + vj*dir_v*tbj + 0.5*[0,0,-g]*tbj^2;
        tb = tdj+tbj;
        is_ = max(1,ceil(tb/dt)); ie = min(length(t_vec),ceil((tb+Teff)/dt));
        for i = is_:ie
            t = t_vec(i);
            Mpos = M0_i + vm*t*mdir_i;
            Cpos = Pb + [0,0,-vs*(t-tb)];
            jam(i) = jam(i) || check_jam(Mpos, O, Cpos, Rc);
        end
    end
    J = sum(jam)*dt;
end

function J = eval_cluster_jam(x, uav_ids, M0_i, mdir_i, T_arr, F0, vm, vs, Rc, Teff, g, dt, O)
    jam = false(1, ceil(T_arr/dt)+1);
    t_vec = 0:dt:T_arr;
    for u = 1:length(uav_ids)
        uid = uav_ids(u); base = (u-1)*8+1;
        if base+7 > length(x), continue; end
        vu = x(base); thu = x(base+1);
        dir_v = [cosd(thu), sind(thu), 0];
        for k = 1:3
            tdk = x(base+2+(k-1)*2);
            tbk = x(base+3+(k-1)*2);
            if tdk+tbk >= T_arr, continue; end
            Fdep = F0(uid,:) + vu*tdk*dir_v;
            Pb = Fdep + vu*dir_v*tbk + 0.5*[0,0,-g]*tbk^2;
            tb = tdk+tbk;
            is_ = max(1,ceil(tb/dt)); ie = min(length(t_vec),ceil((tb+Teff)/dt));
            for i = is_:ie
                t = t_vec(i);
                Mpos = M0_i + vm*t*mdir_i;
                Cpos = Pb + [0,0,-vs*(t-tb)];
                jam(i) = jam(i) || check_jam(Mpos, O, Cpos, Rc);
            end
        end
    end
    J = sum(jam)*dt;
end

function [best_x, best_J] = pso_improved(n_var, n_pop, n_iter, lb, ub, pos_init, obj_fun, n_restarts)
    % PSO with Latin Hypercube init + restarts
    pos = pos_init;
    vel = zeros(n_pop, n_var);
    pbest_pos = pos; pbest_val = -inf(n_pop,1);
    gbest_val = -inf; gbest_pos = pos(1,:);

    for restart = 1:n_restarts
        if restart > 1
            pos = lb + lhsdesign(n_pop, n_var) .* (ub - lb);
            vel = zeros(n_pop, n_var);
            for i = 1:n_pop
                f = obj_fun(pos(i,:));
                if f > pbest_val(i), pbest_val(i) = f; pbest_pos(i,:) = pos(i,:); end
                if f > gbest_val, gbest_val = f; gbest_pos = pos(i,:); end
            end
        end

        for iter = 1:ceil(n_iter/n_restarts)
            w = 0.9 - 0.5*(iter-1)/ceil(n_iter/n_restarts);
            for i = 1:n_pop
                f = obj_fun(pos(i,:));
                if f > pbest_val(i), pbest_val(i) = f; pbest_pos(i,:) = pos(i,:); end
                if f > gbest_val, gbest_val = f; gbest_pos = pos(i,:); end
            end
            for i = 1:n_pop
                r1 = rand(1,n_var); r2 = rand(1,n_var);
                vel(i,:) = w*vel(i,:) + 1.8*r1.*(pbest_pos(i,:)-pos(i,:)) + 1.8*r2.*(gbest_pos-pos(i,:));
                rng = ub - lb;
                vel(i,:) = min(max(vel(i,:), -0.2*rng), 0.2*rng);
                pos(i,:) = pos(i,:) + vel(i,:);
                pos(i,:) = min(max(pos(i,:), lb), ub);
            end
        end
    end
    best_x = gbest_pos; best_J = gbest_val;
end

function d = dist_point_to_line_2d(P, A, B)
    % Distance from point P to line AB in 2D
    AB = B - A; AP = P - A;
    d = abs(AB(1)*AP(2) - AB(2)*AP(1)) / norm(AB);
end

function save_all_results(x3, x4, r5, F0, M0, mdir, T_arr, vm, vs, Rc, Teff, g, dt, O, out_dir)
    % Save result1.xlsx (Problem 3)
    v3 = x3(1); th3 = x3(2);
    dir3 = [cosd(th3), sind(th3), 0];
    res1 = zeros(3, 10);
    for k = 1:3
        tdk = x3(2+2*k-1); tbk = x3(2+2*k);
        Fdep = F0(1,:) + v3*tdk*dir3;
        Pb = Fdep + v3*dir3*tbk + 0.5*[0,0,-g]*tbk^2;
        Jk = calc_jam(F0(1,:), v3, th3, tdk, tbk, M0(1,:), mdir(1,:), T_arr(1), vm, vs, Rc, Teff, g, dt, O);
        res1(k,:) = [k, th3, v3, tdk, tbk, Fdep, Pb, Jk];
    end
    T1 = array2table(round(res1,2), 'VariableNames', ...
        {'Round','Dir_deg','Speed_ms','Deploy_t','Burst_dt','DepX','DepY','DepZ','BurX','BurY','BurZ','Jam_s'});
    writetable(T1, [out_dir 'result1_improved.xlsx']);

    % Save result2.xlsx (Problem 4)
    res2 = zeros(3, 11);
    for j = 1:3
        idx = (j-1)*4+1;
        vj = x4(idx); thj = x4(idx+1); tdj = x4(idx+2); tbj = x4(idx+3);
        dirj = [cosd(thj), sind(thj), 0];
        Fdep = F0(j,:) + vj*tdj*dirj;
        Pb = Fdep + vj*dirj*tbj + 0.5*[0,0,-g]*tbj^2;
        Jj = calc_jam(F0(j,:), vj, thj, tdj, tbj, M0(1,:), mdir(1,:), T_arr(1), vm, vs, Rc, Teff, g, dt, O);
        res2(j,:) = [j, thj, vj, tdj, tbj, Fdep, Pb, Jj];
    end
    T2 = array2table(round(res2,2), 'VariableNames', ...
        {'UAV','Dir_deg','Speed_ms','Deploy_t','Burst_dt','DepX','DepY','DepZ','BurX','BurY','BurZ','Jam_s'});
    writetable(T2, [out_dir 'result2_improved.xlsx']);

    % Save result3.xlsx (Problem 5)
    r3data = [];
    uav_names = {'FY1','FY2','FY3','FY4','FY5'};
    for mi = 1:3
        if isempty(r5{mi,1}) || r5{mi,2} <= 0, continue; end
        xm = r5{mi,1}; uavs = r5{mi,3};
        if length(xm) < length(uavs)*8, continue; end
        for u = 1:length(uavs)
            uid = uavs(u); base = (u-1)*8+1;
            if base+7 > length(xm), break; end
            vu = xm(base); thu = xm(base+1);
            diru = [cosd(thu), sind(thu), 0];
            for k = 1:3
                tdk = xm(base+2+(k-1)*2); tbk = xm(base+3+(k-1)*2);
                Fdep = F0(uid,:) + vu*tdk*diru;
                Pb = Fdep + vu*diru*tbk + 0.5*[0,0,-g]*tbk^2;
                r3data = [r3data; {uav_names{uid}, thu, vu, k, ...
                    round(Fdep(1),2), round(Fdep(2),2), round(Fdep(3),2), ...
                    round(Pb(1),2), round(Pb(2),2), round(Pb(3),2), sprintf('M%d',mi)}];
            end
        end
    end
    if ~isempty(r3data)
        T3 = cell2table(r3data, 'VariableNames', ...
            {'UAV','Dir_deg','Speed_ms','Round','DepX','DepY','DepZ','BurX','BurY','BurZ','Target'});
        writetable(T3, [out_dir 'result3_improved.xlsx']);
    end
    fprintf('  All Excel files saved.\n');
end

function generate_improved_figures(F0, M0, mdir, T_arr, vm, vs, Rc, Teff, g, dt, O, ...
    Tj1, J2, J3, J4, J5, assign, out_dir)

    % Figure 1: 3D scene
    f1 = figure('Visible','off','Position',[100,100,1000,700]);
    hold on; grid on; axis equal; view(45,25);
    xlabel('x (m) East'); ylabel('y (m) South'); zlabel('z (m) Up');
    title('3D Battlespace: Missile Trajectories and UAV Positions');

    % Real target cylinder
    [Xc,Yc,Zc] = cylinder(7,30); Zc = Zc*10;
    surf(Xc, Yc+200, Zc, 'FaceColor',[0.2,0.8,0.2],'FaceAlpha',0.3,'EdgeColor','none');
    plot3(0,0,0,'rx','MarkerSize',15,'LineWidth',3);
    text(0,0,100,'Decoy (Origin)','FontSize',9);
    text(0,200,15,'Real Target','FontSize',9);

    colors = lines(3);
    for i = 1:3
        tt = linspace(0,T_arr(i),100);
        Mt = M0(i,:) + vm*tt'.*mdir(i,:);
        plot3(Mt(:,1),Mt(:,2),Mt(:,3),'-','Color',colors(i,:),'LineWidth',1.5);
        plot3(M0(i,1),M0(i,2),M0(i,3),'o','Color',colors(i,:),'MarkerSize',8,'MarkerFaceColor',colors(i,:));
        text(M0(i,1),M0(i,2),M0(i,3)+150,sprintf('M%d',i),'FontSize',10);
    end
    for j = 1:5
        plot3(F0(j,1),F0(j,2),F0(j,3),'s','Color',[0.8,0.4,0],'MarkerSize',8,'MarkerFaceColor',[1,0.6,0]);
        text(F0(j,1),F0(j,2),F0(j,3)+120,sprintf('FY%d',j),'FontSize',9);
    end
    legend({'Real Target','Decoy Target','M1','','M2','','M3','','UAVs'},'Location','eastoutside');
    saveas(f1, [out_dir 'fig1_3d_scene.png']); close(f1);

    % Figure 2: Jam duration comparison
    f3 = figure('Visible','off','Position',[100,100,800,500]);
    bar([Tj1, J2, J3, J4, J5], 'FaceColor', [0.2,0.4,0.8]);
    set(gca,'XTickLabel',{'P1:Fixed','P2:1UAV-1rd','P3:1UAV-3rd','P4:3UAV-Coop','P5:5UAV-Full'});
    ylabel('Effective Jamming (s)'); title('Jamming Duration Comparison');
    grid on;
    vals = [Tj1, J2, J3, J4, J5];
    for i = 1:5, text(i, vals(i)+0.3, sprintf('%.2f',vals(i)), 'HorizontalAlignment','center','FontWeight','bold'); end
    saveas(f3, [out_dir 'fig2_comparison.png']); close(f3);

    % Figure 3: Top-down target assignment
    f4 = figure('Visible','off','Position',[100,100,800,600]);
    hold on; grid on; axis equal;
    xlabel('x (m) East'); ylabel('y (m) South');
    title('Problem 5: UAV-Missile Assignment (Top-down)');
    for i = 1:3
        plot(M0(i,1),M0(i,2),'^','Color',colors(i,:),'MarkerSize',12,'MarkerFaceColor',colors(i,:));
        text(M0(i,1),M0(i,2)+300,sprintf('M%d',i),'FontSize',11);
    end
    for j = 1:5
        plot(F0(j,1),F0(j,2),'s','Color',colors(assign(j),:),'MarkerSize',10,'MarkerFaceColor',colors(assign(j),:));
        text(F0(j,1),F0(j,2)+300,sprintf('FY%d->M%d',j,assign(j)),'FontSize',9);
    end
    legend({'M1','M2','M3','UAVs (color=assigned missile)'},'Location','best');
    saveas(f4, [out_dir 'fig3_assignment.png']); close(f4);

    fprintf('  Figures saved.\n');
end
