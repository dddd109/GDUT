% =========================================================================
% 实验四：FIR数字滤波器的设计
% =========================================================================
clc; clear; close all;

%% 1. 生成含噪信号 (模拟xtg函数)
N = 1000; Fs = 1000;
T = 1/Fs; Tp = N*T;
t = 0:T:(N-1)*T;
k = 0:N-1; f = k/Tp;

% 生成信号 st (100Hz载波，10Hz调制 -> 包含90Hz和110Hz分量)
fc = Fs/10; f0 = fc/10;
mt = cos(2*pi*f0*t);
ct = cos(2*pi*fc*t);
st = mt .* ct;

% 产生高频噪声 (使用firpmord和firpm替代旧版remezord和remez)
nt = 2*rand(1, N) - 1; % 随机噪声
fp_n = 150; fs_n = 200; Rp_n = 0.1; As_n = 70;
dev_n = [10^(-As_n/20), (10^(Rp_n/20)-1)/(10^(Rp_n/20)+1)];
[n_ord, fo, mo, w_weight] = firpmord([fp_n, fs_n], [0, 1], dev_n, Fs); % 设计高通滤波器生成噪声
hn_noise = firpm(n_ord, fo, mo, w_weight);
nht = filter(hn_noise, 1, 10*nt); % 生成含有高频成分的噪声

xt = st + nht; % 含噪混合信号
fxt = fft(xt, N);

figure('Name', '实验四：含噪声信号');
subplot(2,1,1); plot(t, xt); grid on;
xlabel('t/s'); ylabel('x(t)'); title('(a) 信号加噪声波形'); axis([0 0.5 min(xt) max(xt)]);
subplot(2,1,2); plot(f(1:N/2), abs(fxt(1:N/2))/max(abs(fxt))); grid on;
xlabel('f/Hz'); ylabel('幅度'); title('(b) 信号加噪声的频谱'); axis([0 500 0 1.2]);

%% 2. 窗函数法设计FIR低通滤波器
% 信号频率最高110Hz，噪声最低150Hz。设定通带截止120Hz，阻带截止150Hz。
fp = 120; fs_stop = 150; 
As = 60; % 要求阻带衰减60dB，需选择黑斯曼窗(Blackman)或凯撒窗。此处选用Blackman窗。
delta_f = fs_stop - fp;
Wn = (fp + fs_stop) / 2 / (Fs/2); % 归一化截止频率

% 计算Blackman窗所需的阶数，N ≈ 5.5 * Fs / delta_f
M = ceil(5.5 * Fs / delta_f); % 滤波器阶数M
if mod(M,2)==1 % 确保为偶数阶(Type I)，避免在Nyquist处增益为0的限制(虽然低通影响不大)
    M = M + 1;
end
win = blackman(M+1);
hn = fir1(M, Wn, 'low', win);

%% 3. 使用fftfilt进行滤波
yt = fftfilt(hn, xt);

%% 4. 绘图
figure('Name', '实验四：滤波器特性与输出');
[H, w] = freqz(hn, 1, 512);
subplot(2,1,1); plot(w/pi * (Fs/2), 20*log10(abs(H))); grid on; % X轴转换为Hz方便观察
title('(a) 窗函数法设计的低通滤波器幅频特性'); xlabel('f/Hz'); ylabel('幅度(dB)'); axis([0 500 -120 10]);
subplot(2,1,2); plot(t, yt); grid on;
title('(b) 窗函数法设计的滤波器滤除噪声后的信号波形'); xlabel('t/s'); ylabel('y_t(t)'); axis([0 0.5 -1 1]);