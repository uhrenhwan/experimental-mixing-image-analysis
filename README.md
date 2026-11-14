# MATLAB-Based Video Analysis of Liquid–Liquid Mixing

**Experimental mixing analysis | MATLAB | Image processing | Curve fitting | Statistical comparison**

## Project overview

This project developed a MATLAB-based video-analysis workflow to quantify the mixing performance of **sunscreen dispersed in water** under different mixing configurations. The experimental investigation considered **impeller shape, the presence of baffles, and impeller surface coating**, with the aim of exploring how these conditions influence mixing behaviour, comparing performance across different mixing regimes and identifying favourable operating configurations.

The scripts convert recorded mixing videos into a time-resolved image-intensity signal, estimate a **mixing time** using nonlinear curve fitting and a gradient threshold, and compare experimental setups using plots and uncertainty estimates. The focus of this repository is the **analysis methodology and its application to similar recorded mixing experiments**, rather than reporting the complete experimental findings or establishing a universally optimal mixing condition.

### Analysis workflow

```text
Three videos per experimental configuration
                |
                v
  video_analysis_3_trials.m
  Grayscale image processing + region-of-interest cropping
                |
                v
  Three Excel files: time vs pixel-intensity SD
                |
                v
  plot_each_trial.m
  Exponential fitting + gradient-based mixing times
  + SEM across three trials
                |
                +------> Manually compile an averaged SD Excel file
                |         and transfer SEM values
                v
  plot_comparison.m
  Compare experimental configurations using fitted
  SD curves, gradients, and mixing-time bar charts
```

An additional script, [`mixing_analysis_pipeline.m`](mixing_analysis_pipeline.m), connects these steps in an **optional automated workflow**. Both approaches are documented below; the original three-script workflow was used for the laboratory analysis.

## How mixing time is determined

### 1. Image-based measure of mixing

For each selected video frame, MATLAB converts the image to grayscale, crops a defined **region of interest (ROI)**, and computes the standard deviation (SD) of pixel intensity within that region using `std2`:

$$
\mathrm{SD}(t) = \sqrt{\frac{1}{N-1}\sum_{i=1}^{N}\left(I_i(t)-\overline{I}(t)\right)^2}.
$$

Here, $I_i(t)$ is the grayscale intensity of pixel $i$ at time $t$, and $N$ is the number of pixels in the ROI. Changes in this spatial intensity variation provide a **visual proxy for changing mixture uniformity**. The metric is not a direct concentration measurement; its interpretation depends on lighting, camera position, visible contrast, and ROI selection.

### 2. Curve fitting and model selection

The SD data are fitted with both a **single-exponential** and a **double-exponential** function:

$$
\mathrm{SD}(t) = A e^{-kt}+C
$$

$$
\mathrm{SD}(t) = A_1e^{-k_1t}+A_2e^{-k_2t}+C.
$$

The scripts use `fminsearch` for parameter fitting and the **corrected Akaike information criterion (AICc)** to compare the models. In the provided implementation, the double-exponential model is selected when its AICc is more than 2 units below that of the single-exponential model. Time is shifted relative to the first imported data point during fitting.

### 3. Mixing-time criterion

Mixing time is defined as the first point within the analysed interval at which the **absolute gradient of the fitted SD curve** falls below the selected threshold:

$$
\left|\frac{d\,\mathrm{SD}}{dt}\right| \leq 0.025.
$$

The threshold of `0.025` is the value used for this dataset and is adjustable in the MATLAB scripts. It provides a **consistent operational definition of mixing time for this image-analysis method**; it should not be interpreted as a general physical mixing criterion without further validation.

### 4. Repeatability and uncertainty

Each experimental configuration is analysed using three trials. The original `plot_each_trial.m` calculates the **standard error of the mean (SEM)** from the three individual trial mixing times:

$$
\mathrm{SEM} = \frac{s_t}{\sqrt{3}},
$$

where $s_t$ is the sample standard deviation of the three mixing times. SEM is used as an uncertainty indication when comparing configurations.

## Repository files

| File | Role |
| --- | --- |
| [`video_analysis_3_trials.m`](video_analysis_3_trials.m) | Reads three videos, samples frames, computes grayscale-intensity SD, and exports one Excel dataset per trial. |
| [`plot_each_trial.m`](plot_each_trial.m) | Fits individual trial curves, identifies mixing times, plots fitted SD and gradients, and calculates trial-based SEM. |
| [`plot_comparison.m`](plot_comparison.m) | Compares experimental setups using compiled averaged SD datasets; plots fitted curves, gradients, and bar charts with manually supplied uncertainty values. |
| [`mixing_analysis_pipeline.m`](mixing_analysis_pipeline.m) | Optional integrated alternative that processes videos or existing trial spreadsheets and automates compilation, summary statistics, and comparison plots. |
| [`figures/`](figures/) | Selected example outputs illustrating the MATLAB analysis and plotting functionality. |

## Requirements

- MATLAB, with access to `VideoReader`, `readmatrix`, `writematrix`, `fminsearch`, and the plotting functions used in the scripts.
- **Image Processing Toolbox** for the video-processing functions `imcrop` and `std2` (and grayscale conversion as used in the original script).
- Three recorded videos for each configuration, or previously generated time–SD spreadsheets.
- Spreadsheet software such as Excel **only if using the original workflow's manual compilation step**.

The repository contains analysis scripts and example figures, but **does not include the original experimental videos or complete trial spreadsheets**. To reproduce a specific analysis, supply your own videos or the corresponding extracted SD data.

## Usage: original three-script workflow

### Step 1 — Extract SD data from three trial videos

Open [`video_analysis_3_trials.m`](video_analysis_3_trials.m) and edit the input section:

```matlab
files = {
    'exp13_1.MOV'
    'exp13_2.MOV'
    'exp13_3.MOV'
};

experimentnames = {'exp13_1', 'exp13_2', 'exp13_3'};

% Crop coordinates for each video: [x, y, width, height]
crops = {
    [x1 y1 width1 height1]
    [x2 y2 width2 height2]
    [x3 y3 width3 height3]
};

time2start = 1;   % s
time2end   = 120; % s
df         = 50;  % Process every 50th frame
```

Replace the illustrative `x1`, `y1`, etc. with **measured pixel coordinates** for your actual footage (the committed script already contains coordinates from one experimental setup). Ensure the files can be found from MATLAB's current folder or provide full paths. Select a consistent, relevant ROI for the three videos and keep video-acquisition conditions as comparable as possible.

Run the script. It creates **three two-column Excel files**, such as:

```text
exp13_1.xlsx
exp13_2.xlsx
exp13_3.xlsx
```

Each file contains **time (s)** in column 1 and **grayscale pixel-intensity SD** in column 2. It also plots the measured SD profile for each video. The files are written to the current MATLAB folder by the original script.

### Step 2 — Fit individual trials and calculate SEM

Open [`plot_each_trial.m`](plot_each_trial.m) and update the `files` list to point to your three newly generated workbooks and **one compiled workbook**:

```matlab
files = {
    'exp13_1.xlsx'
    'exp13_2.xlsx'
    'exp13_3.xlsx'
    'exp13_compiled.xlsx'
};

threshold = 0.025;
```

**Manual Excel compilation:** Create `exp13_compiled.xlsx` with the same two-column format. The first column should contain timestamps shared across the trials; the second should contain the **mean of the three SD values at each corresponding time**. If the recorded timestamps differ, align or interpolate the data to a common time grid **before** calculating the mean—do not average unrelated spreadsheet rows. Retain only an overlapping time interval that is supported by all three trials.

Run `plot_each_trial.m` to obtain:

- Fitted SD curves and their gradients for the three trials and the compiled mean SD profile.
- An estimated mixing time for each individual trial, based on the configured gradient threshold.
- `SEM`, calculated from the **three individual trial mixing times**.
- A separate mixing-time estimate for the compiled averaged SD curve.

**Note:** The original script's fourth `files` entry is the compiled mean SD curve, *not* a fourth experimental trial. For comparison error bars, use the `SEM` based on the three individual trials, not the separately printed `SEM_v2` quantity.

### Step 3 — Compare different configurations

Repeat Steps 1–2 for each experimental configuration (for example, coated vs non-coated impellers, different impeller shapes, or with vs without baffles). Create one compiled workbook and calculate one SEM per configuration.

Open [`plot_comparison.m`](plot_comparison.m) and update the configuration-specific inputs:

```matlab
files = {
    'exp1_compiled.xlsx'
    'exp6_compiled.xlsx'
};

legend_names = {'Coating', 'Non-coating'};

% Replace with the SEM values calculated for these setups
horizontal_errors = [SEM_exp1, SEM_exp6];
```

Replace `SEM_exp1` and `SEM_exp6` with the **actual numeric SEM values** from `plot_each_trial.m`. Also change the chart titles and axis/category labels to suit the comparison. The uploaded `plot_comparison.m` is currently configured for **two experimental setups**; to compare more, update its loop and associated input arrays accordingly.

Running this script generates fitted-curve comparisons, gradient plots, and a bar chart. In the **original script**, the displayed bar heights are mixing times obtained by fitting the **compiled averaged SD profiles**; the manually entered error bars come from individual trial mixing times. The two estimates need not be numerically identical, so interpret this comparison accordingly.

## Usage: optional automated pipeline

[`mixing_analysis_pipeline.m`](mixing_analysis_pipeline.m) is a later integrated version of the workflow. It is included for convenience; it **was not the original three-script route used to generate the laboratory analysis**.

Edit the `USER INPUTS` section near the top of the file:

1. Choose `input_source = "videos"` to extract SD values from new video files, or `input_source = "excel"` to analyse existing individual-trial spreadsheets.
2. Configure `experiments(e).id` and `.label` for each setup. In video mode, also supply exactly three video filenames and a 3 × 4 matrix of ROI crop coordinates for each setup.
3. Keep files in the script's configured input folders (the defaults are the repository/script folder), then run the script in MATLAB.

For example, to compare two setups using already extracted Excel files, set `input_source = "excel"` and use:

```matlab
experiments = struct([]);
experiments(1).id = 'exp1';
experiments(1).label = 'Coating';
experiments(2).id = 'exp6';
experiments(2).label = 'Non-coating';
```

This configuration looks for `exp1_1.xlsx`–`exp1_3.xlsx` and `exp6_1.xlsx`–`exp6_3.xlsx` (with `.xls` also accepted). The integrated script automatically:

- Fits the three trial SD curves and determines their individual mixing times.
- Calculates the **mean mixing time and SEM from those same three trials**.
- Aligns trial timestamps and generates an averaged SD spreadsheet.
- Produces per-trial, comparison, and bar-chart figures.
- Saves processed files in `outputs/data/` and figures in `outputs/figures/`.

**Validation status:** This integrated version has not been independently runtime-tested against the original MATLAB analysis. Check its outputs against known trial results before relying on it for reporting.

## Example visualisations

The [`figures/`](figures/) folder contains **selected illustrative outputs** from the analysis scripts. These show how experimental video data can be transformed into fitted mixing curves and comparisons across configurations. They are **not presented as a complete report of the experimental findings**, nor as evidence that a particular impeller or vessel design is universally optimal.

The key outputs to inspect are:

1. **Trial fitting:** Grayscale-intensity SD versus time with fitted exponential curves and indicated mixing times.
2. **Gradient-based criterion:** Derivatives of the fitted curves with the selected threshold marked.
3. **Configuration comparison:** Mixing-time bar plots with error bars, alongside fitted SD curves for different setups.

To display chosen PNGs directly in this README, add Markdown image links using their actual names, for example: `![Trial fitting output](figures/ACTUAL_FILENAME.png)`.

## Interpretation and limitations

- **Indirect measurement:** Grayscale-intensity SD measures spatial variation in the selected image region, not concentration homogeneity throughout the full three-dimensional liquid volume.
- **Dependence on recording conditions:** Lighting, reflections, camera movement, crop placement, and differences in visual contrast can affect the SD signal and its comparability between setups.
- **Operational threshold:** The `0.025` gradient threshold is a user-selected analysis criterion. Threshold sensitivity should be evaluated before adopting the method for a substantially different experiment.
- **Curve-fitting assumptions:** Single- and double-exponential functions are empirical descriptions of the measured SD trends; model selection by AICc does not establish a physical mixing mechanism.
- **Uncertainty:** Three trials provide only a limited estimate of repeatability. SEM describes uncertainty in the estimated trial mean; it does not quantify all measurement and modelling uncertainty.
- **Workflow distinction:** The original three-script process includes manual SD compilation and SEM transfer. The integrated version automates those steps and calculates comparison bar heights from trial-level means; its summary values can therefore differ from the original comparison script.

## Intended use

This repository is intended as a **reusable MATLAB analysis example** for visually recorded mixing experiments where changes in image-intensity distribution can be used to follow mixing progress. It demonstrates experimental video processing, data preparation, nonlinear curve fitting, mixing-time estimation, and comparisons across equipment configurations. Adapt the ROI, timing settings, gradient threshold, and experimental controls when applying it to another system.
