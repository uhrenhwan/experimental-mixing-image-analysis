%% MIXING ANALYSIS: VIDEO -> TRIAL FITS -> MEAN/SEM -> COMPARISON
% Combined from video_analysis_3_trials.m, plot_each_trial.m,
% and plot_comparison.m.
%
% HOW TO USE
% 1. Edit ONLY the USER INPUTS below (videos, crop rectangles and labels).
% 2. Select input_source = "videos" to process MOV files, or "excel" to
%    reuse the original three trial spreadsheets (e.g. exp1_1.xlsx, etc.).
% 3. Run this file. No manual Excel averaging or SEM entry is required.
% 4. Results appear in outputs/data/ and outputs/figures/.
%
% Each experiment/setup has THREE independent trials. For comparisons,
% add more entries to the experiments struct (see example below).
% Requires MATLAB with VideoReader and Image Processing Toolbox (for imcrop,
% rgb2gray and std2) when input_source is "videos".

clc; clear; close all;

%% =========================================================
%  =================== USER INPUTS =========================
%  =========================================================

input_source = "videos";    % "videos" or "excel"

% Folders. By default, place MOV or existing trial .xlsx files next to
% this MATLAB script. The script writes new data into outputs/data/.
project_folder = fileparts(mfilename('fullpath'));
video_folder   = project_folder;
excel_folder   = project_folder;
output_folder  = fullfile(project_folder, 'outputs');
data_folder    = fullfile(output_folder, 'data');
figure_folder  = fullfile(output_folder, 'figures');

% ---- Settings carried over from the original scripts ----
time2start = 1;      % First time to analyse (s)
time2end   = 120;    % Last time to analyse (s)
df         = 50;     % Read every df-th video frame
threshold  = 0.025; % |d(SD)/dt| threshold, grayscale-intensity units/s

options = optimset('Display','off', ...
    'MaxFunEvals',20000,'MaxIter',20000);

% ---- Experimental setups ----
% Current example uses the three exp13 videos and the original crop values.
experiments = struct([]);
experiments(1).id = 'exp13';
experiments(1).label = 'Experiment 13';
experiments(1).videos = {'exp13_1.MOV','exp13_2.MOV','exp13_3.MOV'};
experiments(1).crops = 1.0e+03 * [ ...
    0.2035  1.2415  0.7540  0.1120; ...
    0.1925  1.1905  0.7180  0.0940; ...
    0.1565  1.1795  0.7540  0.1050];

% TO COMPARE TWO SETUPS USING ALREADY EXPORTED EXCEL TRIAL FILES:
% Set input_source = "excel" and replace the block above with:
%
% experiments = struct([]);
% experiments(1).id = 'exp1';
% experiments(1).label = 'Coating';
% experiments(2).id = 'exp6';
% experiments(2).label = 'Non-coating';
%
% The script then reads exp1_1.xlsx, exp1_2.xlsx, exp1_3.xlsx,
% exp6_1.xlsx, exp6_2.xlsx, exp6_3.xlsx (also accepts .xls).
% No .videos or .crops values are needed in "excel" mode.
%
% TO PROCESS MORE THAN ONE SETUP FROM VIDEOS, instead add:
% experiments(2).id = 'exp6';
% experiments(2).label = 'Non-coating';
% experiments(2).videos = {'exp6_1.MOV','exp6_2.MOV','exp6_3.MOV'};
% experiments(2).crops = [x1 y1 w1 h1; x2 y2 w2 h2; x3 y3 w3 h3];
% Replace these placeholder crop coordinates with measured values.

%% =========================================================
%  ================== END OF USER INPUTS ===================
%  =========================================================

if ~ismember(input_source, ["videos", "excel"])
    error('input_source must be "videos" or "excel".');
end
if isempty(experiments)
    error('Configure at least one experiment in USER INPUTS.');
end
if ~exist(data_folder, 'dir'), mkdir(data_folder); end
if ~exist(figure_folder, 'dir'), mkdir(figure_folder); end

%% 1. Define models (unchanged from original fitting scripts)
single = @(p,x) ...
    exp(p(1))*exp(-exp(p(2))*x) + p(3);

double = @(p,x) ...
    exp(p(1))*exp(-exp(p(2))*x) + ...
    exp(p(3))*exp(-exp(p(4))*x) + p(5);

nExperiments = numel(experiments);
results = struct([]);

for e = 1:nExperiments
    exp_id = experiments(e).id;
    exp_label = experiments(e).label;
    fprintf('\n========== %s (%s) ==========\n', exp_label, exp_id);

    %% 2. Video analysis (or load pre-extracted trial Excel files)
    trial_data = cell(1,3);
    for trial = 1:3
        if input_source == "videos"
            if ~isfield(experiments, 'videos') || ...
                    ~isfield(experiments, 'crops') || ...
                    numel(experiments(e).videos) ~= 3 || ...
                    ~isequal(size(experiments(e).crops), [3,4])
                error(['Experiment %s must define three video filenames ' ...
                       'and a 3x4 array of crop coordinates.'], exp_id);
            end

            filename = fullfile(video_folder, experiments(e).videos{trial});
            if ~isfile(filename)
                error('Missing video: %s', filename);
            end

            % Original video_analysis_3_trials.m method:
            v = VideoReader(filename);
            framerate = v.FrameRate;
            firstframe = round(time2start*framerate) + 1;
            lastframe = min(round(time2end*framerate) + 1, v.NumFrames);
            if firstframe > lastframe
                error('Invalid video time range for %s.', filename);
            end
            frames = firstframe:df:lastframe;
            time = (frames-1)/framerate;
            stdeviation = zeros(size(frames));

            for k = 1:numel(frames)
                img = read(v, frames(k));
                if size(img,3) == 3
                    img = rgb2gray(img);
                end
                img = imcrop(img, experiments(e).crops(trial,:));
                if isempty(img)
                    error('Crop rectangle is outside video frame: %s', filename);
                end
                stdeviation(k) = std2(img);
            end
            data = [time(:), stdeviation(:)];
            data = clean_sd_data(data);

            % Preserve the original per-trial Excel output.
            trial_file = fullfile(data_folder, sprintf('%s_%d.xlsx',exp_id,trial));
            writematrix(data, trial_file);
            fprintf('Trial %d: extracted SD and saved %s\n',trial,trial_file);
        else
            % Reuse the Excel files already produced by the old workflow.
            trial_file = find_trial_excel(excel_folder, exp_id, trial);
            data = clean_sd_data(readmatrix(trial_file));
            fprintf('Trial %d: loaded %s\n',trial,trial_file);
        end
        trial_data{trial} = data;
    end

    % Raw SD curves (same information as video_analysis_3_trials.m plots)
    fig_raw = figure('Name',sprintf('%s - Raw SD',exp_label),'Color','w');
    hold on;
    trial_colors = lines(3);
    for trial = 1:3
        plot(trial_data{trial}(:,1), trial_data{trial}(:,2), ...
            'Color',trial_colors(trial,:),'LineWidth',1.5, ...
            'DisplayName',sprintf('Trial %d',trial));
    end
    hold off;
    title(sprintf('Standard Deviation - %s',exp_label));
    xlabel('Time (s)'); ylabel('Standard Deviation');
    grid on; legend('Location','best');
    save_plot(fig_raw,figure_folder,sprintf('%s_raw_sd.png',exp_id));

    %% 3. Plot each trial, fit exponential models and calculate mixing times
    % Same single/double exponential, AICc and |gradient| threshold logic
    % as the original plot_each_trial.m.
    trial_fits = cell(1,3);
    trial_times = NaN(1,3);

    fig_trials = figure('Name',sprintf('%s - Trial Fitting',exp_label), ...
                        'Color','w');
    for trial = 1:3
        data = trial_data{trial};
        fit = fit_sd_curve(data(:,1),data(:,2), ...
                           single,double,threshold,options);
        trial_fits{trial} = fit;
        trial_times(trial) = fit.mixing_time;

        fprintf('Trial %d: %s | R2=%.5f | mixing time=%.2f s\n', ...
            trial,fit.model,fit.R2,fit.mixing_time);

        t = data(:,1); y = data(:,2);
        t_plot = linspace(t(1),t(end),2000);
        x_plot = t_plot-fit.t0;
        fitted_sd = fit.fit_fun(x_plot);
        fitted_gradient = fit.grad_fun(x_plot);
        color = trial_colors(trial,:);

        subplot(2,1,1); hold on;
        light_color = 0.65*color + 0.35;
        plot(t,y,'.','Color',light_color,'HandleVisibility','off');
        plot(t_plot,fitted_sd,'-','Color',color,'LineWidth',2, ...
             'DisplayName',sprintf('Trial %d',trial));

        subplot(2,1,2); hold on;
        plot(t_plot,fitted_gradient,'-','Color',color,'LineWidth',2, ...
             'DisplayName',sprintf('Trial %d',trial));

        if isfinite(fit.mixing_time)
            mixing_sd = fit.fit_fun(fit.mixing_time-fit.t0);
            mixing_gradient = fit.grad_fun(fit.mixing_time-fit.t0);
            subplot(2,1,1);
            plot(fit.mixing_time,mixing_sd,'o', ...
                'MarkerFaceColor',color,'MarkerEdgeColor','k', ...
                'MarkerSize',8,'HandleVisibility','off');
            xline(fit.mixing_time,'--',sprintf('%.2f s',fit.mixing_time), ...
                'Color',color,'HandleVisibility','off');

            subplot(2,1,2);
            plot(fit.mixing_time,mixing_gradient,'o', ...
                'MarkerFaceColor',color,'MarkerEdgeColor','k', ...
                'MarkerSize',8,'HandleVisibility','off');
            xline(fit.mixing_time,'--','Color',color, ...
                'HandleVisibility','off');
        else
            warning('%s Trial %d did not cross the gradient threshold.',exp_id,trial);
        end
    end

    subplot(2,1,1);
    xlabel('Time (s)'); ylabel('Standard Deviation');
    title(sprintf('Mixing Time Analysis - %s (Three Trials)',exp_label));
    legend('Location','northeast'); grid on; box on;
    subplot(2,1,2);
    yline(-threshold,'k--',sprintf('Threshold = -%.3f',threshold), ...
          'HandleVisibility','off');
    xlabel('Time (s)'); ylabel('d(Standard Deviation)/dt');
    title('Gradient of Fitted Curves');
    legend('Location','southeast'); grid on; box on;
    % The fourth (averaged) SD curve is added below, after automatic compilation.

    % IMPORTANT: use the trial-based mean AND trial-based SEM together.
    valid_times = trial_times(isfinite(trial_times));
    if numel(valid_times) ~= 3
        warning('%s: only %d/3 trials had valid mixing times.', ...
                exp_id,numel(valid_times));
    end
    if isempty(valid_times)
        mean_time = NaN;
        SEM = NaN;
    else
        mean_time = mean(valid_times);
        if numel(valid_times) > 1
            SEM = std(valid_times,0)/sqrt(numel(valid_times));
        else
            SEM = NaN;
        end
    end
    fprintf('Mean mixing time = %.2f s | SEM = %.2f s (n=%d)\n', ...
            mean_time,SEM,numel(valid_times));

    %% 4. Compile Excel automatically: aligned, averaged SD curves
    % Use common trial-1 timestamps in the OVERLAPPING time interval.
    % Interpolate other trials where sample timestamps do not coincide.
    compiled = average_three_trials(trial_data);
    compiled_file = fullfile(data_folder,sprintf('%s_compiled.xlsx',exp_id));
    writematrix(compiled,compiled_file);
    fprintf('Compiled average SD: %s\n',compiled_file);

    % Fit averaged SD curve for VISUALISATION (not for bar-chart mean).
    avg_fit = fit_sd_curve(compiled(:,1),compiled(:,2), ...
                           single,double,threshold,options);

    % Add the averaged SD curve as the fourth trace on the original
    % plot_each_trial-style graph (the other three are individual trials).
    avg_t = compiled(:,1);
    avg_y = compiled(:,2);
    avg_t_plot = linspace(avg_t(1),avg_t(end),2000);
    avg_x_plot = avg_t_plot-avg_fit.t0;
    figure(fig_trials);
    subplot(2,1,1); hold on;
    plot(avg_t,avg_y,'.','Color',[0.6 0.6 0.6], ...
        'HandleVisibility','off');
    plot(avg_t_plot,avg_fit.fit_fun(avg_x_plot),'k--', ...
        'LineWidth',2,'DisplayName','Averaged SD');
    if isfinite(avg_fit.mixing_time)
        xline(avg_fit.mixing_time,'k:', ...
            'HandleVisibility','off');
    end
    legend('Location','northeast');
    subplot(2,1,2); hold on;
    plot(avg_t_plot,avg_fit.grad_fun(avg_x_plot),'k--', ...
        'LineWidth',2,'DisplayName','Averaged SD');
    if isfinite(avg_fit.mixing_time)
        xline(avg_fit.mixing_time,'k:', ...
            'HandleVisibility','off');
    end
    legend('Location','southeast');
    save_plot(fig_trials,figure_folder,sprintf('%s_trial_fits.png',exp_id));

    % Save per-trial values for traceability.
    trial_table = table((1:3)', trial_times', ...
        string(cellfun(@(f)f.model,trial_fits,'UniformOutput',false))', ...
        cellfun(@(f)f.R2,trial_fits)', ...
        'VariableNames',{'Trial','MixingTime_s','SelectedModel','R2'});
    writetable(trial_table,fullfile(data_folder, ...
               sprintf('%s_trial_results.xlsx',exp_id)));

    results(e).id = exp_id;
    results(e).label = exp_label;
    results(e).mean_time = mean_time;
    results(e).SEM = SEM;
    results(e).n_valid = numel(valid_times);
    results(e).trial_times = trial_times;
    results(e).compiled = compiled;
    results(e).avg_fit = avg_fit;
end

%% 5. Plot comparison between experimental setups (original layout)
nFiles = nExperiments;
colors = lines(nFiles);
legend_names = {results.label};
mixing_times = [results.mean_time];
horizontal_errors = [results.SEM]; % Automatically calculated; NO manual entry

fig_comparison = figure('Name','Mixing Comparison','Color','w');
for i = 1:nFiles
    data = results(i).compiled;
    t = data(:,1);
    y = data(:,2);
    fit = results(i).avg_fit;
    t0 = fit.t0;
    t_plot = linspace(t(1),t(end),2000);
    x_plot = t_plot-t0;
    y_plot = fit.fit_fun(x_plot);
    gradient_plot = fit.grad_fun(x_plot);

    % Average SD profiles and fitted curves
    subplot(2,1,1); hold on;
    light_color = 0.4*colors(i,:) + 0.6;
    plot(t,y,'.','Color',light_color,'HandleVisibility','off');
    plot(t_plot,y_plot,'-','Color',colors(i,:), ...
        'LineWidth',1.5,'DisplayName',legend_names{i});

    % Original gradient plot
    subplot(2,1,2); hold on;
    plot(t_plot,gradient_plot,'-','Color',colors(i,:), ...
        'LineWidth',2,'DisplayName',legend_names{i});

    if isfinite(mixing_times(i))
        % The central marker is the trial-based MEAN mixing time.
        % The underlying curve is the fit to the averaged SD profile.
        mixing_std = fit.fit_fun(mixing_times(i)-t0);
        mixing_grad = fit.grad_fun(mixing_times(i)-t0);

        subplot(2,1,1);
        if isfinite(horizontal_errors(i))
            h = errorbar(mixing_times(i),mixing_std, ...
                horizontal_errors(i),horizontal_errors(i), ...
                'horizontal','o', ...
                'Color','k','MarkerFaceColor',colors(i,:), ...
                'MarkerEdgeColor','k','MarkerSize',7, ...
                'LineWidth',1.5,'CapSize',15, ...
                'HandleVisibility','off');
            uistack(h,'top');
        else
            plot(mixing_times(i),mixing_std,'o', ...
                'MarkerFaceColor',colors(i,:), ...
                'MarkerEdgeColor','k','HandleVisibility','off');
        end
        xline(mixing_times(i),'--',sprintf('%.2f s',mixing_times(i)), ...
              'Color',colors(i,:),'HandleVisibility','off');

        subplot(2,1,2);
        plot(mixing_times(i),mixing_grad,'o', ...
            'MarkerFaceColor',colors(i,:), ...
            'MarkerEdgeColor','k','MarkerSize',8, ...
            'HandleVisibility','off');
        xline(mixing_times(i),'--','Color',colors(i,:), ...
            'HandleVisibility','off');
    end
end

subplot(2,1,1);
xlabel('Time (s)'); ylabel('Standard Deviation');
title('Comparison of Experimental Setups');
legend('Location','northeast'); grid on; box on;
subplot(2,1,2);
yline(-threshold,'k--',sprintf('Threshold = -%.3f',threshold), ...
      'HandleVisibility','off');
xlabel('Time (s)'); ylabel('d(Standard Deviation)/dt');
title('Gradient of Fitted Curves');
legend('Location','southeast'); grid on; box on;
save_plot(fig_comparison,figure_folder,'comparison_sd_curves.png');

%% 6. Bar chart: MEAN of three trial mixing times with SEM error bars
fig_bar = figure('Name','Mixing Time Comparison','Color','w');
hold on;
x_bar = 1:nFiles;
b = bar(x_bar,mixing_times,0.6);
b.FaceColor = 'flat';
b.CData = colors;

valid_SEM = isfinite(horizontal_errors) & isfinite(mixing_times);
if any(valid_SEM)
    errorbar(x_bar(valid_SEM),mixing_times(valid_SEM), ...
        horizontal_errors(valid_SEM), ...
        'k','LineStyle','none','LineWidth',1.5,'CapSize',12);
end
for i = 1:nFiles
    if isfinite(mixing_times(i))
        shift = 0;
        if isfinite(horizontal_errors(i)), shift = horizontal_errors(i); end
        text(x_bar(i),mixing_times(i)+shift+2, ...
            sprintf('%.2f s',mixing_times(i)), ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','bottom','FontSize',11, ...
            'FontWeight','bold');
    end
end
xticks(x_bar);
xticklabels(legend_names);
xlabel('Experimental Setup'); ylabel('Mean Mixing Time (s)');
title('Comparison of Mixing Times (Mean + SEM)');
xlim([0.5,nFiles+0.5]);
limits = mixing_times + horizontal_errors;
limits = limits(isfinite(limits));
if ~isempty(limits), ylim([0,max(limits)*1.25+2]); end
grid on; box on; hold off;
save_plot(fig_bar,figure_folder,'comparison_mixing_times.png');

%% 7. Save a single summary spreadsheet
summary = table(string({results.id})',string({results.label})', ...
    mixing_times',horizontal_errors',[results.n_valid]', ...
    'VariableNames',{'ExperimentID','Setup','MeanMixingTime_s','SEM_s','ValidTrials'});
writetable(summary,fullfile(data_folder,'mixing_summary.xlsx'));

disp(' ');
disp('========== FINAL SUMMARY ==========');
disp(summary);
fprintf('Output data:    %s\n',data_folder);
fprintf('Output figures: %s\n',figure_folder);

%% =========================================================
%  =================== LOCAL FUNCTIONS =====================
%  =========================================================

function data = clean_sd_data(data)
    if size(data,2) < 2
        error('Each trial dataset requires two columns: time and SD.');
    end
    data = data(:,1:2);
    data = data(all(isfinite(data),2),:);
    if isempty(data)
        error('Trial dataset has no valid numeric time/SD rows.');
    end
    [t,~,group] = unique(data(:,1)); % Sorted, removes duplicate timestamps
    y = accumarray(group,data(:,2),[],@mean);
    data = [t,y];
    if size(data,1) < 7
        error('Each trial requires at least seven distinct time points.');
    end
end

function filename = find_trial_excel(folder,exp_id,trial)
    base = fullfile(folder,sprintf('%s_%d',exp_id,trial));
    if isfile([base '.xlsx'])
        filename = [base '.xlsx'];
    elseif isfile([base '.xls'])
        filename = [base '.xls'];
    else
        error('Missing %s.xlsx or %s.xls',base,base);
    end
end

function averaged = average_three_trials(trial_data)
    % Align observations on trial 1 timestamps within the interval where
    % ALL three trials have data; avoid extrapolation beyond measurements.
    first_time = -Inf;
    last_time = Inf;
    for k = 1:3
        t = trial_data{k}(:,1);
        first_time = max(first_time,t(1));
        last_time = min(last_time,t(end));
    end
    t_common = trial_data{1}(:,1);
    t_common = t_common(t_common >= first_time & t_common <= last_time);
    if numel(t_common) < 7
        error('Trials have fewer than seven common-time observations.');
    end

    all_sd = zeros(numel(t_common),3);
    for k = 1:3
        t = trial_data{k}(:,1);
        sd = trial_data{k}(:,2);
        all_sd(:,k) = interp1(t,sd,t_common,'linear');
    end
    averaged = [t_common,mean(all_sd,2)];
end

function fit = fit_sd_curve(t,y,single,double,threshold,options)
    % Same exponential fits and AICc model-selection rule as original code.
    t = t(:); y = y(:);
    n = numel(y);
    if n <= 6
        error('Curve fitting requires at least seven time points.');
    end
    t0 = t(1);
    x = t-t0;

    C0 = median(y(round(0.8*n):end));
    A0 = max(max(y)-C0,0.01);

    p1_init = [log(A0),log(0.1),C0];
    p1 = fminsearch(@(p)sum((y-single(p,x)).^2),p1_init,options);

    p2_init = [log(0.6*A0),log(0.3), ...
               log(0.4*A0),log(0.03),C0];
    p2 = fminsearch(@(p)sum((y-double(p,x)).^2),p2_init,options);

    SSE1 = max(sum((y-single(p1,x)).^2),realmin);
    SSE2 = max(sum((y-double(p2,x)).^2),realmin);
    AICc1 = n*log(SSE1/n)+6+24/(n-4);
    AICc2 = n*log(SSE2/n)+10+60/(n-6);

    if AICc2 < AICc1-2
        model = 'Double exponential';
        A1 = exp(p2(1)); k1 = exp(p2(2));
        A2 = exp(p2(3)); k2 = exp(p2(4));
        C = p2(5);
        fit_fun = @(x)A1*exp(-k1*x)+A2*exp(-k2*x)+C;
        grad_fun = @(x)-A1*k1*exp(-k1*x)-A2*k2*exp(-k2*x);
    else
        model = 'Single exponential';
        A = exp(p1(1)); k = exp(p1(2)); C = p1(3);
        fit_fun = @(x)A*exp(-k*x)+C;
        grad_fun = @(x)-A*k*exp(-k*x);
    end

    y_fit = fit_fun(x);
    ss_tot = sum((y-mean(y)).^2);
    if ss_tot > 0
        R2 = 1-sum((y-y_fit).^2)/ss_tot;
    else
        R2 = NaN;
    end

    % Find exact crossing of the fitted |SD gradient| (original method).
    if abs(grad_fun(0)) <= threshold
        mixing_time = t0;
    elseif abs(grad_fun(x(end))) <= threshold
        crossing_x = fzero(@(z)abs(grad_fun(z))-threshold,[0,x(end)]);
        mixing_time = crossing_x+t0;
    else
        mixing_time = NaN;
    end

    fit.t0 = t0;
    fit.model = model;
    fit.fit_fun = fit_fun;
    fit.grad_fun = grad_fun;
    fit.mixing_time = mixing_time;
    fit.R2 = R2;
    fit.AICc_single = AICc1;
    fit.AICc_double = AICc2;
end

function save_plot(fig,folder,filename)
    path = fullfile(folder,filename);
    % PNG at high resolution, compatible with GitHub Markdown image links.
    if exist('exportgraphics','file') || exist('exportgraphics','builtin')
        exportgraphics(fig,path,'Resolution',300);
    else
        print(fig,path,'-dpng','-r300');
    end
end
