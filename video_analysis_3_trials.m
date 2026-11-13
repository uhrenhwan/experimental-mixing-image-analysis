
clc; clear; close all;

%% Variables (only make changes in this subsection)

% Video files
files = {
    'exp13_1.MOV'
    'exp13_2.MOV'
    'exp13_3.MOV'
};

% Experiment names (used for Excel filenames)
experimentnames = {
    'exp13_1'
    'exp13_2'
    'exp13_3'
};

% Crop values [x y width height] for each video
crops = {
    1.0e+03*[0.2035    1.2415    0.7540    0.1120]
    1.0e+03*[0.1925    1.1905    0.7180    0.0940]
    1.0e+03*[0.1565    1.1795    0.7540    0.1050]
};

time2start = 1;       % Start time (s)
time2end = 120;       % End time (s)
df = 50;              % Frame interval

%% Initialise
nFiles = numel(files);

if numel(experimentnames) ~= nFiles || numel(crops) ~= nFiles
    error('Files, experiment names, and crops must have equal lengths.');
end

%% Analyse videos
for i = 1:nFiles

    v = VideoReader(files{i});
    experimentname = experimentnames{i};
    crop = crops{i};

    framerate = v.FrameRate;

    firstframe = round(time2start*framerate) + 1;
    lastframe = min(round(time2end*framerate) + 1, v.NumFrames);

    if firstframe > lastframe
        error('Invalid time range for %s.', files{i});
    end

    frames = firstframe:df:lastframe;

    time = (frames-1)/framerate;
    stdeviation = zeros(size(frames));

    %% Calculate Standard Deviation
    for k = 1:length(frames)

        img = read(v,frames(k));
        img = rgb2gray(img);
        img = imcrop(img,crop);

        stdeviation(k) = std2(img);

    end

    %% Plot Standard Deviation
    figure;

    plot(time,stdeviation,'b-','LineWidth',1.5);

    title(['Standard Deviation - ' experimentname]);
    xlabel('Time (s)');
    ylabel('Standard Deviation');
    grid on;

    %% Export to Excel
    filename = [experimentname '.xlsx'];

    data = [time(:), stdeviation(:)];

    writematrix(data,filename);

    fprintf('Data exported to %s\n',filename);

end
