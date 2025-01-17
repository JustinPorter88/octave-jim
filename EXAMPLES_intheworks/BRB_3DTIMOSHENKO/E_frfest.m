% clc
% clear all

addpath('../../ROUTINES/')
addpath('../../ROUTINES/SOLVERS/')
addpath('../../ROUTINES/HARMONIC/')
addpath('../../ROUTINES/FEM/')
addpath('../../ROUTINES/FEM/BEAMS/')
addpath('../../ROUTINES/export_fig/')

Nein = 8;  % Number of Elements in the Bolt Area
load(sprintf('./MATS/%dIN_MATS.mat',Nein), 'M', 'K', 'Fbolt', 'L1', ...
     'L2', 'SensorLocs', 'RECOV', 'R1', 'R2', 'BM1', 'IN1', 'Beam1', ...
     'BM2', 'IN2', 'Beam2', 'pars', 'parsint', 'Nebb', 'Nein', ...
     'wdt', 'nu', 'int1nds', 'int2nds', 'remnds', ...
     'i1s', 'i2s', 'Vrbms');

Lrbms = null(full(Vrbms'*M));
Lrbms(abs(Lrbms)<eps) = 0;
Lrbms = sparse(Lrbms);


LML = Lrbms'*M*Lrbms;
LKL = Lrbms'*K*Lrbms;
LFb = Lrbms'*Fbolt;

% Truncate sparse
LML(abs(LML)<eps) = 0;
LKL(abs(LKL)<eps) = 0;

Prestress = 12e3;
%% Set up Quadrature
No = 2;

Les = diff(IN1.X);
Wys = IN1.WY(1:end-1);
Zs  = 0-IN1.Z(1:end-1);
[Q1, T1] = TM3D_ND2QP(Les, Wys, Zs, No);

Les = diff(IN2.X);
Wys = IN2.WY(1:end-1);
Zs  = 0-IN2.Z(1:end-1);
[Q2, T2] = TM3D_ND2QP(Les, Wys, Zs, No);

Qrel = zeros(Nein*No^2*3, (Nebb+Nein+1)*2*6);
Trel = zeros((Nebb+Nein+1)*2*6, Nein*No^2*3);

Qrel(:, i1s) = Q1;
Qrel(:, i2s) = -Q2;

Trel(i1s, :) = T1;
Trel(i2s, :) = -T2;

LTrel = Lrbms'*Trel;
QrelL = Qrel*Lrbms;

% Truncate for Storage Efficiency
% LTrel(abs(LTrel)<1e-10) = 0;
% QrelL(abs(QrelL)<1e-10) = 0;

LTrel = sparse(LTrel);
QrelL = sparse(QrelL);

%% Contact Model
Aint = sum(sum(T1(1:6:end, :)));

Pint = Prestress/Aint;
sint = 1e-6;
chi  = 2.0;
ktkn = chi*(1-nu)/(2-nu);
kt   = 4*(1-nu)*Pint/(sqrt(pi)*(2-nu)*sint);
kn   = kt/ktkn;

kn = 1e10;
% kt = kn*ktkn;

%% Linear Dissipation
tstiff = kron(ones(Nein*No^2,1), [kt;kt;kn]);
Ks = LTrel*diag(tstiff)*QrelL;

[Vs, Ws] = eigs(LKL+Ks, LML, 10, 'SM');
[Ws, si] = sort(sqrt(diag(Ws)));
Vs = Vs(:, si);
Vs = Vs./sqrt(diag(Vs'*LML*Vs))';

zetas = [0.1; 0.2]*1e-2;  % 0.1%, 0.2%
ab = [1./(2*Ws(1:length(zetas))) Ws(1:length(zetas))/2]\zetas;

LCL = ab(1)*LML + ab(2)*(LKL+Ks);

%% Setup Class Object
MDL = MDOFGEN(LML, LKL, LCL, Lrbms);

mu   = 0.25;
% mu = 1e6;
gap  = 0;

fnl = @(t, u, varargin) ELDRYFRICT3D(t, u, kt, kt, kn, mu, gap, varargin{:});
% fnl = @(t, u, varargin) LIN3D(t, u, kt, kt, kn, mu, gap, varargin{:});
MDL = MDL.SETNLFUN(2+5, QrelL, fnl, LTrel);
% MDL = MDL.SETNLFUN(2+5, QrelL, fnl, QrelL');

%% Static Prestress Analysis
U0 = (LKL+Ks)\(LFb*Prestress);
% [R, J] = MDL.STATRESFUN(U0, LFb*Prestress);

opts = struct('reletol', 1e-6, 'Display', true);
[Ustat, ~, ~, ~, J0] = NSOLVE(@(U) MDL.STATRESFUN(U, LFb*Prestress), U0, opts);

[V, Ws] = eig(full(J0), full(LML));
[Ws, si] = sort(sqrt(diag(Ws)));
V = V(:, si);
disp(max(Ws/2/pi))

%% Excitation
fsamp = 2^17;  % Sampling frequency (2^18)
T0 = 0;  T1 = 2^14/fsamp;  dt = 1/fsamp;

rng(1);  % Random seed
type = 'WGN';  reps = 2;  bw = -1;% 'WGN', 'IMP'
% type = 'IMP';  reps = 1;  bw = 1000; 

configs = {6, 'Z';
    8, 'Y';
    1, 'X'};

% looping configs --------------------------------------------------
for ci=1:size(configs, 1)
% looping configs --------------------------------------------------
    ldof = configs{ci, 1};
    DOF = configs{ci, 2};
    
    % looping amplitudes --------------------------------------------------
    for famp = [0.1 0.5 2.5 12.5] % *100
    % looping amplitudes --------------------------------------------------
        switch (type)
            case 'WGN'   % White Gaussian Noise
                fext = wgn(length(T0:dt:T1), reps, 40+20*log10(famp));
                fex = @(t, r) interp1(T0:dt:T1, fext(:, r), t);
                FEX = @(t, r) Lrbms'*RECOV(ldof,:)'*fex(t, r)+LFb*Prestress;
            case 'IMP'   % Haversine Impulse
                fex = @(t) sin(2*pi*bw*t).^2.*(t<=1.0/(2*bw))*famp;
                fext = fex(T0:dt:T1);
                FEX = @(t, r) Lrbms'*RECOV(ldof,:)'*fex(t)+LFb*Prestress;
        end

        %% Solution
        opts = struct('Display', 'waitbar');
        uresps = zeros(size(RECOV,1), length(T0:dt:T1), reps);
        udresps = zeros(size(RECOV,1), length(T0:dt:T1), reps);
        uddresps = zeros(size(RECOV,1), length(T0:dt:T1), reps);

        for r=1:reps
            [Thh, Uhh, Udhh, Uddhh, ~] = MDL.HHTAMARCH(T0, T1, dt, Ustat, ...
                Ustat*0, @(t) FEX(t, r), opts);

            uresps(:, :, r) = RECOV*Lrbms*Uhh;
            udresps(:, :, r) = RECOV*Lrbms*Udhh;
            uddresps(:, :, r) = RECOV*Lrbms*Uddhh;
            fprintf('Done %d\n', r);
        end

        save(sprintf('./DATA/%s_%s%d_F%.2f.mat', type, DOF, ldof, famp), ...
            'Thh', 'uresps', 'udresps', 'uddresps', 'fext');

        fprintf('Done ci: %d famp: %f\n', ci, famp)
        
    % looping amplitudes --------------------------------------------------
    end
    % looping amplitudes --------------------------------------------------
% looping configs --------------------------------------------------
end
% looping configs --------------------------------------------------

%% Plot FRF
ci = 3;

ldof = configs{ci, 1};
DOF = configs{ci, 2};
odof = ldof;
zpdx = 4;  % Amount of zero padding

famps = [0.1 0.5 2.5 12.5];
famp = 0.1;
load(sprintf('./DATA/%s_%s%d_F%.2f.mat', type, DOF, ldof, famp), 'Thh', 'uddresps', 'fext');

ures = squeeze(uddresps(odof, :, :));

Nt = length(Thh);
reps = size(uddresps, 3);

% wndw = ones(size(Thh'));  % Rectangular
wndw = hanning(length(Thh), 'periodic');
t = repmat(Thh(:), [zpdx+1, 1]) + kron((0:zpdx)'*(Thh(end)+Thh(2)), ones(Nt,1));

[freqs, Ffs] = FFTFUN(t, [fext.*wndw; zeros(Nt*zpdx, reps)]);
[~, Ufs] = FFTFUN(t, [ures.*wndw; zeros(Nt*zpdx, reps)]);

% % Hanning window in frequency domain directly
% [freqs, Ffs] = FFTFUN(Thh(:), fext);
% [~, Ufs] = FFTFUN(Thh(:), ures);
% 
% freqs = freqs(1:end-1)+0.5*freqs(2);
% Ffs = diff(Ffs);
% Ufs = diff(Ufs);

uresA = zeros(length(freqs), 1)*1j;
parfor i=1:length(freqs)
    uresA(i) = (1j*2*pi*freqs(i))^2*(RECOV(odof,:)*Lrbms*((LML*(1j*2*pi*freqs(i))^2+LCL*(1j*2*pi*freqs(i))+J0)\Lrbms')*RECOV(ldof,:)');
    fprintf('%d/%d\n', i, length(freqs));
end

% %%
figure(1)
clf()
set(gcf, 'color', 'white')
aa = gobjects(length(famps)+1, 1);

aa(1) = semilogy(freqs, abs(uresA), 'k--'); hold on
legend(aa(1), 'Linearized FRF');

figure(2)
clf()
set(gcf, 'color', 'white')
plot(freqs, -rad2deg(angle(uresA)), 'k--'); hold on
for fi = 1:length(famps)
    famp = famps(fi);
    load(sprintf('./DATA/%s_%s%d_F%.2f.mat', type, DOF, ldof, famp), 'Thh', 'uddresps', 'fext');

    ures = squeeze(uddresps(odof, :, :));
    Nt = length(Thh);
    reps = size(uddresps, 3);
    
    wndw = hanning(length(Thh), 'periodic');
    t = repmat(Thh(:), [zpdx+1, 1]) + kron((0:zpdx)'*(Thh(end)+Thh(2)), ones(Nt,1));

    [freqs, Ffs] = FFTFUN(t, [fext.*wndw; zeros(Nt*zpdx, reps)]);
    [~, Ufs] = FFTFUN(t, [ures.*wndw; zeros(Nt*zpdx, reps)]);
    
    
    % semilogy(freqs, abs(Ufs./Ffs), '.'); hold on
    % semilogy(freqs, mean(abs(Ufs./Ffs), 2), '.'); hold on

    figure(1)
    aa(fi+1) = semilogy(freqs, abs(mean(Ufs.*conj(Ffs), 2)./mean(Ffs.*conj(Ffs), 2)), '.-'); hold on
    legend(aa(fi+1), sprintf('F=%.2f N', famp))
    
    figure(2)
    plot(freqs, -rad2deg(angle(mean(Ufs.*conj(Ffs), 2)./mean(Ffs.*conj(Ffs), 2))), '.-'); hold on
end

figure(1)
ll = legend(aa(1:end), 'Location', 'best')
xlim([0 1e4])
xlabel('Frequency (Hz)')
ylabel('FRF Amplitude (m s^{-2}/N)')
export_fig(sprintf('./FIGS/FRFA_%s_%s%d.eps', type, DOF, ldof), '-depsc')
savefig(sprintf('./FIGS/FRFA_%s_%s%d.fig', type, DOF, ldof))

figure(1)
xlim([0 1800])
ll.Visible = false;
savefig(sprintf('./FIGS/FRFA_%s_%s%d_zoom.fig', type, DOF, ldof))

figure(2)
xlim([0 1e4])
ylim([-180 0])
set(gca, 'YTick', -180:45:0)
xlabel('Frequency (Hz)')
ylabel('Phase (degs)')
export_fig(sprintf('./FIGS/FRFP_%s_%s%d.eps', type, DOF, ldof), '-depsc')
savefig(sprintf('./FIGS/FRFP_%s_%s%d.fig', type, DOF, ldof))

figure(2)
xlim([0 1800])
savefig(sprintf('./FIGS/FRFP_%s_%s%d_zoom.fig', type, DOF, ldof))