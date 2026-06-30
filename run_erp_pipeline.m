%% Run ERP Experiment Processing Pipeline
% Automated batch processing for ERP experiments (E1, E2, E3)
%
% Instructions:
%   1. Update the paths below for your system
%   2. Select which experiment to process (1, 2, or 3)
%   3. Run this script
%   4. Check output directories for results
%
% Output structure:
%   output_dir/EX/
%   ├── Cleaned/
%   │   ├── S_01_EX_clean.set
%   │   └── ...
%   ├── Set/
%   │   ├── S_01_EX.set (epoched)
%   │   └── ...
%   ├── ERP/
%   │   ├── S_01_EX.erp
%   │   └── ...
%   └── Reports/
%       ├── S_01_EX_report.txt
%       └── processing_log.txt

%% Clear environment
clc;
clear;
close all;

%% Initialize EEGLAB
eeglab;

%% ==================== CONFIGURATION ====================
% UPDATE THESE PATHS FOR YOUR SYSTEM

% Select experiment to process (1, 2, or 3)
experiment_num = 1;

% Input directory with .mat files
% Example: 'D:\Mona Lisa EEG\Data\E1'
input_dir = 'D:\Mona Lisa EEG\Data\E1';

% Behavioral data directory
% Example: 'D:\Mona Lisa EEG\Conductuales_1'
behavior_dir = 'D:\Mona Lisa EEG\Conductuales_1';

% Bins definition file (same for all experiments)
% Example: 'D:\Mona Lisa EEG\bins_imagenes.txt'
bins_file = 'D:\Mona Lisa EEG\bins_imagenes.txt';

% Output directory for processed files
% Example: 'D:\Mona Lisa EEG\Processed'
output_dir = 'D:\Mona Lisa EEG\Processed';

% Channel location file
% Example: 'C:\...\GSN-HydroCel-65_1.0.sfp'
chanLoc_file = 'C:\Users\yangy\Documents\MATLAB\eeglab2025.0.0\functions\supportfiles\channel_location_files\philips_neuro\GSN-HydroCel-65_1.0.sfp';

%% ==================== VALIDATION ====================

% Validate experiment number
if ~ismember(experiment_num, [1, 2, 3])
    error('Experiment number must be 1, 2, or 3');
end

% Check if input directory exists
if ~exist(input_dir, 'dir')
    error('Input directory does not exist: %s', input_dir);
end

% Check if behavioral directory exists
if ~exist(behavior_dir, 'dir')
    error('Behavioral directory does not exist: %s', behavior_dir);
end

% Check if bins file exists
if ~exist(bins_file, 'file')
    error('Bins file not found: %s', bins_file);
end

% Check if channel location file exists
if ~exist(chanLoc_file, 'file')
    error('Channel location file not found: %s', chanLoc_file);
end

% Check for .mat files
mat_files = dir(fullfile(input_dir, '*.mat'));
if isempty(mat_files)
    error('No .mat files found in: %s', input_dir);
end

% Display configuration
fprintf('\n=================================================\n');
fprintf('ERP Experiment Processing Pipeline\n');
fprintf('=================================================\n');
fprintf('Experiment: E%d\n', experiment_num);
fprintf('Input directory: %s\n', input_dir);
fprintf('Behavioral directory: %s\n', behavior_dir);
fprintf('Bins file: %s\n', bins_file);
fprintf('Output directory: %s\n', output_dir);
fprintf('Channel location file: %s\n', chanLoc_file);
fprintf('Number of files to process: %d\n', length(mat_files));
fprintf('=================================================\n\n');

% Confirm before starting
response = input('Start processing? (y/n): ', 's');
if ~strcmpi(response, 'y')
    fprintf('Processing cancelled.\n');
    return;
end

%% ==================== RUN PIPELINE ====================

tic; % Start timer

process_erp_experiment_batch(...
    experiment_num, ...
    input_dir, ...
    behavior_dir, ...
    bins_file, ...
    output_dir, ...
    chanLoc_file);

elapsed_time = toc;

%% ==================== COMPLETION ====================

fprintf('\n=================================================\n');
fprintf('Pipeline execution completed!\n');
fprintf('Total time: %.1f minutes (%.1f hours)\n', elapsed_time/60, elapsed_time/3600);
fprintf('=================================================\n\n');

% Show output directories
exp_output = fullfile(output_dir, sprintf('E%d', experiment_num));
fprintf('Output files saved to:\n');
fprintf('  Cleaned files: %s\n', fullfile(exp_output, 'Cleaned'));
fprintf('  Epoched sets:  %s\n', fullfile(exp_output, 'Set'));
fprintf('  ERP files:     %s\n', fullfile(exp_output, 'ERP'));
fprintf('  Reports:       %s\n', fullfile(exp_output, 'Reports'));
fprintf('\nCheck processing_log.txt and individual reports for details.\n\n');

% Open output directory
fprintf('Opening output directory...\n');
if ispc
    winopen(exp_output);
elseif ismac
    system(sprintf('open "%s"', exp_output));
else
    system(sprintf('xdg-open "%s"', exp_output));
end
