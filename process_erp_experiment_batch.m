function process_erp_experiment_batch(experiment_num, input_dir, behavior_dir, bins_file, output_dir, chanLoc_file)
% process_erp_experiment_batch - Automated batch processing for ERP experiments
%   process_erp_experiment_batch(experiment_num, input_dir, behavior_dir, bins_file, output_dir, chanLoc_file)
%
% Inputs:
%   experiment_num - Experiment number (1, 2, or 3)
%   input_dir      - Folder with .mat files (e.g., 'D:\Mona Lisa EEG\Data\E1')
%   behavior_dir   - Folder with Excel behavioral files (e.g., 'D:\...\Conductuales_1')
%   bins_file      - Path to bin definition file (e.g., 'bins imagenes.txt')
%   output_dir     - Base output folder
%   chanLoc_file   - Path to GSN-HydroCel-65_1.0.sfp file
%
% Pipeline:
%   1. Load .mat → Label channels → Locations → Reference → Filter
%   2. Import events from ECI_TCPIP_55513
%   3. Filter events (keep only 'imag' and 'TRSP')
%   4. Rename TRSP → TRSP1, TRSP2 based on sequence
%   5. Match with behavioral data (Excel) and recode events
%   6. Remove incorrect trials
%   7. Clean (visual or automatic) → ICA → Reject artifacts
%   8. Create event list → Assign bins → Epoch → Average
%   9. Save cleaned .set, epoched .set, and .erp files
%
% Output structure:
%   output_dir/EX/
%   ├── cleaned/
%   │   ├── S_01_EX.set
%   │   ├── S_02_EX.set
%   ├── epoched/
%   │   ├── S_01_EX_epoched.set
%   │   ├── S_02_EX_epoched.set
%   └── erp/
%       ├── S_01_EX.erp
%       ├── S_02_EX.erp
%   └── reports/
%       ├── S_01_EX_report.txt
%       ├── processing_log.txt

    % Initialize EEGLAB
    eeglab('nogui');
    
    % Create experiment-specific output directories
    exp_str = sprintf('E%d', experiment_num);
    exp_output = fullfile(output_dir, exp_str);
    
    cleaned_dir = fullfile(exp_output, 'Cleaned');
    set_dir = fullfile(exp_output, 'Set');
    erp_dir = fullfile(exp_output, 'ERP');
    report_dir = fullfile(exp_output, 'Reports');
    problematic_dir = fullfile(exp_output, 'Problematic');
    
    % Create all directories
    dirs_to_create = {cleaned_dir, set_dir, erp_dir, report_dir, problematic_dir};
    for d = 1:length(dirs_to_create)
        if ~exist(dirs_to_create{d}, 'dir')
            mkdir(dirs_to_create{d});
        end
    end
    
    % Initialize master log
    log_file = fullfile(report_dir, 'processing_log.txt');
    fid_log = fopen(log_file, 'w');
    fprintf(fid_log, '=== ERP Experiment %d Processing Log ===\n', experiment_num);
    fprintf(fid_log, 'Date: %s\n', datestr(now));
    fprintf(fid_log, 'Input Directory: %s\n', input_dir);
    fprintf(fid_log, 'Behavior Directory: %s\n', behavior_dir);
    fprintf(fid_log, 'Bins File: %s\n', bins_file);
    fprintf(fid_log, 'Output Directory: %s\n\n', exp_output);
    fclose(fid_log);
    
    % Find all .mat files
    mat_files = dir(fullfile(input_dir, '*.mat'));
    if isempty(mat_files)
        error('No .mat files found in %s', input_dir);
    end
    
    fprintf('\n=== Found %d .mat files for Experiment %d ===\n\n', length(mat_files), experiment_num);
    
    % Process each file
    n_success = 0;
    n_failed = 0;
    
    for i = 1:length(mat_files)
        fname = mat_files(i).name;
        fprintf('\n========================================\n');
        fprintf('Processing file %d/%d: %s\n', i, length(mat_files), fname);
        fprintf('========================================\n');
        
        try
            % Process single subject
            [success, msg] = process_single_erp_subject(...
                fullfile(input_dir, fname), ...
                behavior_dir, ...
                bins_file, ...
                cleaned_dir, ...
                set_dir, ...
                erp_dir, ...
                report_dir, ...
                problematic_dir, ...
                chanLoc_file, ...
                experiment_num);
            
            % Log result
            append_to_log(log_file, fname, success, msg);
            
            if success
                n_success = n_success + 1;
                fprintf('✓ SUCCESS: %s\n', fname);
            else
                n_failed = n_failed + 1;
                fprintf('✗ FAILED: %s\n', fname);
                fprintf('  Reason: %s\n', msg);
            end
            
        catch ME
            n_failed = n_failed + 1;
            error_msg = sprintf('EXCEPTION: %s', ME.message);
            append_to_log(log_file, fname, false, error_msg);
            fprintf('✗ EXCEPTION: %s\n', fname);
            fprintf('  Error: %s\n', ME.message);
        end
    end
    
    % Final summary
    fprintf('\n========================================\n');
    fprintf('=== PROCESSING COMPLETE ===\n');
    fprintf('========================================\n');
    fprintf('Experiment: %d\n', experiment_num);
    fprintf('Total files: %d\n', length(mat_files));
    fprintf('Successful: %d\n', n_success);
    fprintf('Failed: %d\n', n_failed);
    fprintf('Success rate: %.1f%%\n', (n_success/length(mat_files))*100);
    fprintf('\nDetailed log: %s\n', log_file);
    
    % Append summary to log
    fid_log = fopen(log_file, 'a');
    fprintf(fid_log, '\n=== FINAL SUMMARY ===\n');
    fprintf(fid_log, 'Total files: %d\n', length(mat_files));
    fprintf(fid_log, 'Successful: %d\n', n_success);
    fprintf(fid_log, 'Failed: %d\n', n_failed);
    fprintf(fid_log, 'Success rate: %.1f%%\n', (n_success/length(mat_files))*100);
    fclose(fid_log);
end


function append_to_log(log_file, fname, success, msg)
% Helper function to append processing result to master log
    fid = fopen(log_file, 'a');
    if success
        fprintf(fid, '[SUCCESS] %s - %s\n', fname, msg);
    else
        fprintf(fid, '[FAILED]  %s - %s\n', fname, msg);
    end
    fclose(fid);
end
