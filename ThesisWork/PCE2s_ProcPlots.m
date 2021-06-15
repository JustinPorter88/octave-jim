clc
clear all
addpath('../ROUTINES/')
addpath('../ROUTINES/QUADRATURE/')
addpath('../ROUTINES/export_fig/')

set(0,'defaultAxesTickLabelInterpreter', 'default');
set(0,'defaultTextInterpreter','latex'); 
set(0, 'DefaultLegendInterpreter', 'latex'); 
set(0,'defaultAxesFontSize',13)

%%
% rqnm_exprsurf_mupce();
% rqnm_exprsurf_gappce();
% rqnm_exprsurf_mscpce();
% rqnm_exprsurf_prespce();

%%
% Experimental Data
exp(1) = load('./MATFILES/Mode1_Low.mat', 'AMP_avg', 'FRE_avg', 'DAM_avg');
exp(2) = load('./MATFILES/Mode1_Med.mat', 'AMP_avg', 'FRE_avg', 'DAM_avg');
exp(3) = load('./MATFILES/Mode1_High.mat', 'AMP_avg', 'FRE_avg', 'DAM_avg');

% ps = [0.05 0.50 0.99];
ps = [0.25 0.05];
ecs = colormap(lines(length(ps)));
% ecs = {'red', 'yellow', 'green'};
fcs = kron(ps(:)/2, [1 1 1]);
falph = 0.2;

parms = {'mu', 'msc', 'gap', 'pres', 'rot'};
pdists = {makedist('exp'), makedist('normal'), makedist('normal'), makedist('normal'), gmdistribution([0 0],[1 1])};
lims = [[0 inf]; repmat([-inf inf], 4, 1)];
Nsamps = [0; 10000; 0; 10000; 10000];
ttls = {'Coefficient of Friction', 'Mean Asperity Height', ...
    'Meso-Scale Topology', 'Prestress', 'Stage Rotation'};
lbls = {'$\mu\sim Exp(\cdot)$', '$\lambda\sim \mathcal{N}(\cdot,\cdot)$', ...
    '$gap\sim \mathcal{N}(\cdot, \cdot)$', '$P\sim \mathcal{N}(\cdot, \cdot)$', '$\theta_{X,Y}\sim \mathcal{N}^2(\cdot, \cdot)$'};
Nqps = 10;
for i=1:length(parms)
%     if strcmp(parms{i}, 'pres')
%         fname = sprintf('./%sPCE_25/%spce_N%d_cofs.mat', upper(parms{i}), parms{i}, Nqps);
%     else
        fname = sprintf('./%sPCE/%spce_N%d_cofs.mat', upper(parms{i}), parms{i}, Nqps);
%     end

    if ~strcmp(parms{i}, 'rot')
        load(fname, 'Qs', 'Rcofs', 'Wcofs', 'Zcofs', 'rxps', 'wxps', 'zxps', 'Integs')
    else
        load(fname, 'Qs', 'Rcofs', 'Wcofs', 'Zcofs', 'Wstatcofs', 'IJs', 'Integs')
    end
    
    % Variances
    Rvar = (Rcofs(:, 2:end).^2)*Integs(2:end);
    Wvar = (Wcofs(:, 2:end).^2)*Integs(2:end);
    Zvar = (Zcofs(:, 2:end).^2)*Integs(2:end);
    
    % Percentile Contours
    Nq = length(Qs);
    WCIs = zeros(Nq, 2, length(ps));
    ZCIs = zeros(Nq, 2, length(ps));
    if ~strcmp(parms{i}, 'rot')
        for j=1:length(ps)
            [WCIs(:, 1, j), WCIs(:, 2, j)] = PCE1_PCONTOURS(wxps, ps(j), pdists{i}, lims(i,:), Nsamps(i));
            [ZCIs(:, 1, j), ZCIs(:, 2, j)] = PCE1_PCONTOURS(zxps, ps(j), pdists{i}, lims(i,:), Nsamps(i));
        end
    else
        Samps = random(pdists{i}, Nsamps(i));
        Psis = PHERM(IJs(:,1), Samps(:,1)).*PHERM(IJs(:,2), Samps(:,2));
        Wsamps = Wcofs*Psis';
        Zsamps = Zcofs*Psis';
        for j=1:2
            WCIs(:, 1:2, j) = prctile(Wsamps, [ps(j) 1-ps(j)]*100, 2);
            ZCIs(:, 1:2, j) = prctile(Zsamps, [ps(j) 1-ps(j)]*100, 2);
        end
    end

    figure((i-1)*2+10)
    clf();
    set(gcf, 'Color', 'white')
    aa = gobjects(length(ps)+2, 1);
    for j=1:length(ps)
        aa(j) = fill(Rcofs([1:end end:-1:1],1)/9.81, [WCIs(:,1,j); WCIs(end:-1:1,2,j)]/2/pi, fcs(j,:), 'EdgeColor', ecs(j,:), 'FaceAlpha', falph); hold on
        legend(aa(j), sprintf('$%d^{th}-%d^{th}$ Percentiles', ps(j)*100, (1-ps(j))*100));
    end
    aa(length(ps)+1) = semilogx(Rcofs(:,1)/9.81, Wcofs(:,1)/2/pi, 'b-', 'LineWidth', 1);
    legend(aa(length(ps)+1), 'PCE Mean')
    for j=1:length(exp)
        aa(length(ps)+2) = semilogx(exp(j).AMP_avg, exp(j).FRE_avg, 'k-', 'LineWidth', 2);
    end
    legend(aa(length(ps)+2), 'Experimental Data')
    
    set(gca, 'xscale', 'log')
    xlim(10.^[-0.5 2.5])

    xlabel('Response Amplitude (g)')
    ylabel('Natural Frequency (Hz)')
    title(ttls{i})
    legend(aa(1:end), 'Location', 'southwest')
    
%     if strcmp(parms{i}, 'pres')
%         savefig(sprintf('./%sPCE/%spce_WBB_25.fig', upper(parms{i}), parms{i}));
%         savefig(sprintf('./SEND/%spce_WBB_25.fig', parms{i}));
%     else
        savefig(sprintf('./%sPCE/%spce_WBB.fig', upper(parms{i}), parms{i}));
        savefig(sprintf('./SEND/%spce_WBB.fig', parms{i}));
        export_fig(sprintf('./%sPCE/%spce_WBB.png', upper(parms{i}), parms{i}), '-dpng');
%     end
    figure((i-1)*2+20)
    clf();
    set(gcf, 'Color', 'white')
%     zeta0 = 4.0733e-5;
%     zeta0 = 5.5e-5;
    zeta0 = 1.3841e-4;
    for j=1:length(ps)
        fill(Rcofs([1:end end:-1:1],1)/9.81, [ZCIs(:,1,j); ZCIs(end:-1:1,2,j)]*100+zeta0*100, fcs(j,:), 'EdgeColor', ecs(j,:), 'FaceAlpha', falph); hold on
%         fill(Rcofs([1:end end:-1:1],1)/9.81, max([ZCIs(:,1,j); ZCIs(end:-1:1,2,j)]*100+zeta0*100,zeta0*100), fcs(j,:), 'EdgeColor', ecs(j,:), 'FaceAlpha', falph); hold on
    end
    semilogx(Rcofs(:,1)/9.81, Zcofs(:,1)*100+zeta0*100, 'b-', 'LineWidth', 1);
    for j=1:length(exp)
        semilogx(exp(j).AMP_avg, exp(j).DAM_avg*100, 'k-', 'LineWidth', 2)
    end
    set(gca, 'xscale', 'log')
%     set(gca, 'yscale', 'log')
    xlim(10.^[-0.5 2.5])
	title(ttls{i})

    xlabel('Response Amplitude (g)')
    ylabel('Damping Factor (\%)')
    
%     if strcmp(parms{i}, 'pres')
%         savefig(sprintf('./%sPCE/%spce_ZBB_25.fig', upper(parms{i}), parms{i}));
%         savefig(sprintf('./SEND/%spce_ZBB_25.fig', parms{i}));
%     else
        savefig(sprintf('./%sPCE/%spce_ZBB.fig', upper(parms{i}), parms{i}));
        savefig(sprintf('./SEND/%spce_ZBB.fig', parms{i}));
        export_fig(sprintf('./%sPCE/%spce_ZBB.png', upper(parms{i}), parms{i}), '-dpng');
%     end
end

%% Sobol Indices
for i=5
    fname = sprintf('./%sPCE/%spce_N%d_cofs.mat', upper(parms{i}), parms{i}, Nqps);
    load(fname, 'Qs', 'Rcofs', 'Wcofs', 'Zcofs', 'Wstatcofs', 'IJs', 'Integs')
    
    % Variances
    Rvar = (Rcofs(:, 2:end).^2)*Integs(2:end);
    Wvar = (Wcofs(:, 2:end).^2)*Integs(2:end);
    Zvar = (Zcofs(:, 2:end).^2)*Integs(2:end);
    
    % First Order Sobol Indices
    i1s = [find(IJs(2:end,2)==0) find(IJs(2:end,1)==0)]+1;
    W_S1 = [(Wcofs(:, i1s(:,1)).^2)*Integs(i1s(:,1)) (Wcofs(:, i1s(:,2)).^2)*Integs(i1s(:,2))]./Wvar;
    Z_S1 = [(Zcofs(:, i1s(:,1)).^2)*Integs(i1s(:,1)) (Zcofs(:, i1s(:,2)).^2)*Integs(i1s(:,2))]./Zvar;
    
    % Second Order Sobol Indices
    i2s = setdiff(2:size(IJs,1), i1s(:));
    W_S2 = ((Wcofs(:, i2s).^2)*Integs(i2s))./Wvar;
    Z_S2 = ((Zcofs(:, i2s).^2)*Integs(i2s))./Zvar;
    
    % Plots
    figure((i-1)*2+11)
    clf()
    set(gcf, 'Color', 'white')
    aa = gobjects(3,1);
    aa(1) = semilogx(Rcofs(:,1)/9.81, Wcofs(:,1)/2/pi, 'b-', 'LineWidth', 1); hold on
%     legend(aa(1), 'PCE Mean')
    for j=1:length(exp)
        aa(2) = semilogx(exp(j).AMP_avg, exp(j).FRE_avg, 'k-', 'LineWidth', 2);
    end
%     legend(aa(2), 'Experimental Data')
    
    set(gca, 'xscale', 'log')
    xlim(10.^[-0.5 2.5])
    xlabel('Response Amplitude (g)')
    ylabel('Natural Frequency (Hz)')
    
    yyaxis right;
    aa(1) = plot(Rcofs(:,1)/9.81, W_S1(:,1), 'r.-');
    aa(2) = plot(Rcofs(:,1)/9.81, W_S1(:,2), 'g*-');
    aa(3) = plot(Rcofs(:,1)/9.81, W_S2, 'm.-');
    ylim([-0.1 1.1])
    
    legend(aa, '$S_{\theta_{X}}$', '$S_{\theta_{Y}}$', '$S_{\theta_{X}, \theta_{Y}}$', 'Location', 'west')
    
    ylabel('Sobol Indices')
    
    figure((i-1)*2+21)
    clf()
    set(gcf, 'Color', 'white')
    aa = gobjects(3,1);
    aa(1) = semilogx(Rcofs(:,1)/9.81, Zcofs(:,1)*100, 'b-', 'LineWidth', 1); hold on
%     legend(aa(1), 'PCE Mean')
    for j=1:length(exp)
        aa(2) = semilogx(exp(j).AMP_avg, exp(j).DAM_avg*100, 'k-', 'LineWidth', 2);
    end
%     legend(aa(2), 'Experimental Data')
    
    set(gca, 'xscale', 'log')
    xlim(10.^[-0.5 2.5])
    xlabel('Response Amplitude (g)')
    ylabel('Natural Frequency (Hz)')
    
    yyaxis right;
    plot(Rcofs(:,1)/9.81, Z_S1(:,1), 'r.-');
    plot(Rcofs(:,1)/9.81, Z_S1(:,2), 'g*-');
    plot(Rcofs(:,1)/9.81, Z_S2*100, 'm.-');
    ylim([-0.1 1.1])
    
    ylabel('Sobol Indices')
end
%% Static Natural Frequencies
Wsex = zeros(3,1);  Zsex = zeros(3,1);
for i=1:3
    exp(1) = load(sprintf('./MATFILES/Mode%d_Low.mat',i), 'AMP_avg', 'FRE_avg', 'DAM_avg');
    exp(2) = load(sprintf('./MATFILES/Mode%d_Med.mat',i), 'AMP_avg', 'FRE_avg', 'DAM_avg');
    exp(3) = load(sprintf('./MATFILES/Mode%d_High.mat',i), 'AMP_avg', 'FRE_avg', 'DAM_avg');

    fav = robustfit([exp(1).AMP_avg; exp(2).AMP_avg; exp(3).AMP_avg], ...
                    [exp(1).FRE_avg; exp(2).FRE_avg; exp(3).FRE_avg]);
    zav = robustfit([exp(1).AMP_avg; exp(2).AMP_avg; exp(3).AMP_avg], ...
                    [exp(1).DAM_avg; exp(2).DAM_avg; exp(3).DAM_avg]);
    Wsex(i) = fav(1)*2*pi;
    Zsex(i) = zav(1);
end

Nsamps = 100000;
i = 1;
mdis = [1 3 5];  % modes of interest
Wstatsamps = zeros(length(mdis), Nsamps, length(parms));
Wstatvars = zeros(length(mdis), length(parms));
for i=1:length(parms)
%     if strcmp(parms{i}, 'pres')
%         fname = sprintf('./%sPCE_25/%spce_N%d_cofs.mat', upper(parms{i}), parms{i}, Nqps);
%     else
        fname = sprintf('./%sPCE/%spce_N%d_cofs.mat', upper(parms{i}), parms{i}, Nqps);
%     end

    if ~strcmp(parms{i}, 'rot')
        load(fname, 'Qs', 'Wstatcofs', 'wsxps', 'Integs')
    else
        load(fname, 'Qs', 'Wstatcofs', 'Integs', 'IJs')
    end
    Wstatvars(:, i) = (Wstatcofs(mdis, 2:end).^2)*Integs(2:end);
    
    % Confidence Intervals
    Nq = length(Qs);
    WSCIs = zeros(size(wsxps,1), 2, length(ps));

    if ~strcmp(parms{i}, 'rot')
        for j=1:length(ps)
            [WSCIs(:, 1, j), WSCIs(:, 2, j), rWstat] = PCE1_PCONTOURS(wsxps, ps(j), pdists{i}, lims(i,:), Nsamps);
        end
        Wstatsamps(:, :, i) = rWstat(mdis, :);
    else
        Samps = random(pdists{i}, Nsamps);
        Psis = PHERM(IJs(:,1), Samps(:,1)).*PHERM(IJs(:,2), Samps(:,2));
        Wstatsamps(:, :, i) = Wstatcofs(mdis,:)*Psis';
    end
end

Labels = {'$\mu$', '$\lambda$', '$gap$', '$P$', '$\theta_{X,Y}$'};
Labels = {'[Fric-Coef.]', '[Asp-Hgts.]', ...
    '[Top.]', '[Prest.]', '[Rotn. (X,Y)]'};
nplot = 5;
for i=1:length(mdis)
    figure(i*1000)
    clf()
    boxplot(squeeze(Wstatsamps(i, :, 1:nplot))/2/pi, 'Labels', Labels(1:nplot), 'Whisker', 3*max(Wstatvars(i, :))/2/pi);
    bp = gca;
    bp.XAxis.TickLabelInterpreter = 'latex';
    hold on
    plot(xlim, Wsex(i)*[1 1]/2/pi, 'k--', 'LineWidth', 2)
    yl = ylim;
    
%     ylim([min(Wsex(i)/2/pi-0.5,yl(1)) yl(2)])
    ylim([(Wsex(i)/2/pi-1) yl(2)])
    
    ylabel('Natural Frequency (Hz)')
    xlabel('Factors')
    grid on
    savefig(sprintf('./SEND/Mode%d_W.fig',i));
    export_fig(sprintf('./FIGS/Boxplot_Mode%d_W.png',i), '-dpng');
end
