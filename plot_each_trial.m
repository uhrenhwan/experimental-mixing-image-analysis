
clc; clear; close all;

%% 1. Input files and settings
files = {
    'exp1_1.xls', 
    'exp1_2.xls'
    'exp1_3.xls'
    'exp1_compiled.xlsx',
    
   
};

threshold = 0.025;
colors = lines(4);

options = optimset('Display','off', ...
    'MaxFunEvals',20000,'MaxIter',20000);

%% 2. Define models
single = @(p,x) ...
    exp(p(1))*exp(-exp(p(2))*x) + p(3);

double = @(p,x) ...
    exp(p(1))*exp(-exp(p(2))*x) + ...
    exp(p(3))*exp(-exp(p(4))*x) + p(5);

%% 3. Create figure
figure;

mixing_times = NaN(1,4);
for i = 1:4

    %% Import data
    data = readmatrix(files{i});

    t = data(:,1);
    y = data(:,2);

    valid = isfinite(t) & isfinite(y);
    t = t(valid);
    y = y(valid);

    % Sort and average duplicate time values
    [t,~,group] = unique(t);
    y = accumarray(group,y,[],@mean);

    % Shift time origin
    t0 = t(1);
    x = t-t0;
    n = length(y);

    if n <= 6
        error('Trial %d needs at least 7 unique time points.',i);
    end

    %% Initial estimates
    C0 = median(y(round(0.8*n):end));
    A0 = max(max(y)-C0,0.01);

    %% Fit single exponential
    p1_init = [log(A0),log(0.1),C0];

    p1 = fminsearch(@(p) ...
        sum((y-single(p,x)).^2),p1_init,options);

    %% Fit double exponential
    p2_init = [log(0.6*A0),log(0.3), ...
               log(0.4*A0),log(0.03),C0];

    p2 = fminsearch(@(p) ...
        sum((y-double(p,x)).^2),p2_init,options);

    %% Compare fits using AICc
    SSE1 = sum((y-single(p1,x)).^2);
    SSE2 = sum((y-double(p2,x)).^2);

    AICc1 = n*log(SSE1/n)+6+24/(n-4);
    AICc2 = n*log(SSE2/n)+10+60/(n-6);

    %% Select model and calculate gradient
    if AICc2 < AICc1-2

        model = 'Double exponential';

        A1 = exp(p2(1));
        k1 = exp(p2(2));
        A2 = exp(p2(3));
        k2 = exp(p2(4));
        C = p2(5);

        fit_fun = @(x) ...
            A1*exp(-k1*x)+A2*exp(-k2*x)+C;

        grad_fun = @(x) ...
            -A1*k1*exp(-k1*x)-A2*k2*exp(-k2*x);

        fprintf('\nTrial %d: %s\n',i,model);
        fprintf(['y = %.5f*exp(-%.5f*x) + ', ...
                 '%.5f*exp(-%.5f*x) + %.5f\n'], ...
                 A1,k1,A2,k2,C);

    else

        model = 'Single exponential';

        A = exp(p1(1));
        k = exp(p1(2));
        C = p1(3);

        fit_fun = @(x) A*exp(-k*x)+C;
        grad_fun = @(x) -A*k*exp(-k*x);

        fprintf('\nTrial %d: %s\n',i,model);
        fprintf('y = %.5f*exp(-%.5f*x) + %.5f\n', ...
            A,k,C);

    end

    %% Goodness of fit
    y_fit = fit_fun(x);

    R2 = 1-sum((y-y_fit).^2)/sum((y-mean(y)).^2);

    fprintf('R-squared = %.5f\n',R2);
    fprintf('AICc single = %.3f\n',AICc1);
    fprintf('AICc double = %.3f\n',AICc2);
    fprintf('Time origin t0 = %.4f s\n',t0);

    %% Generate smooth fitted curve
    t_plot = linspace(t(1),t(end),2000);
    x_plot = t_plot-t0;

    y_plot = fit_fun(x_plot);
    gradient_plot = grad_fun(x_plot);

    %% Find first gradient threshold crossing
    % Find exact crossing of fitted gradient

    if abs(grad_fun(0)) <= threshold

        mixing_time = t0;

    elseif abs(grad_fun(x(end))) <= threshold

        crossing_x = fzero(@(z) ...
            abs(grad_fun(z))-threshold,[0,x(end)]);

        mixing_time = crossing_x+t0;

    else

        mixing_time = NaN;

    end
    
    mixing_times(i) = mixing_time;
    %% Plot fitted curves and original data
    subplot(2,1,1);
    hold on;

    light_color = 0.65*colors(i,:)+0.35;

    plot(t,y,'.', ...
        'Color',light_color, ...
        'HandleVisibility','off');

    plot(t_plot,y_plot,'-', ...
        'Color',colors(i,:), ...
        'LineWidth',2, ...
        'DisplayName',sprintf('Trial %d',i));

    %% Plot gradients
    subplot(2,1,2);
    hold on;

    plot(t_plot,gradient_plot,'-', ...
        'Color',colors(i,:), ...
        'LineWidth',2, ...
        'DisplayName',sprintf('Trial %d',i));

    %% Mark mixing time
    if ~isnan(mixing_time)

        mixing_std = fit_fun(mixing_time-t0);
        mixing_grad = grad_fun(mixing_time-t0);

        fprintf('Mixing time = %.2f s\n',mixing_time);
        fprintf('Gradient = %.5f\n',mixing_grad);

        % Mark on fitted curve
        subplot(2,1,1);

        plot(mixing_time,mixing_std,'o', ...
            'MarkerFaceColor',colors(i,:), ...
            'MarkerEdgeColor','k', ...
            'MarkerSize',8, ...
            'HandleVisibility','off');

        xline(mixing_time, '--', ...
            sprintf('%.2f s', mixing_time), ...
            'Color', colors(i,:), ...
            'LabelVerticalAlignment', 'top', ...
            'LabelHorizontalAlignment', 'right', ...
            'FontSize', 10, ...
            'HandleVisibility', 'off');

        xlim([0 100]);

        % Mark on gradient graph
        subplot(2,1,2);

        plot(mixing_time,mixing_grad,'o', ...
            'MarkerFaceColor',colors(i,:), ...
            'MarkerEdgeColor','k', ...
            'MarkerSize',8, ...
            'HandleVisibility','off');

        xline(mixing_time,'--', ...
            'Color',colors(i,:), ...
            'HandleVisibility','off');

    else

        fprintf('Gradient threshold not reached.\n');

    end

end

trial1_time = mixing_times(1);
trial2_time = mixing_times(2);
trial3_time = mixing_times(3);
trial4_time = mixing_times(4);

fprintf('trial4_time: %.2f', trial4_time )

average_time = trial4_time;
sd = std([trial1_time    trial2_time     trial3_time]);
SEM = sd/sqrt(3);
SEM

sd_v2 = sqrt(((trial1_time-average_time)^2 + ...
              (trial2_time-average_time)^2 + ...
              (trial3_time-average_time)^2)/2);

SEM_v2 = sd_v2/sqrt(3);
SEM_v2


%% 4. Format fitted curve graph
subplot(2,1,1);

xlabel('Time (s)');
ylabel('Standard Deviation');
title('Mixing Time Analysis - Three Trials');
legend('Location','northeast');
grid on;
box on;

%% 5. Format gradient graph
subplot(2,1,2);

yline(-threshold,'k--', ...
    sprintf('Threshold = -%.3f',threshold), ...
    'HandleVisibility','off');

xlabel('Time (s)');
ylabel('d(Standard Deviation)/dt');
title('Gradient of Fitted Curves');
legend('Location','southeast');
grid on;
box on;

