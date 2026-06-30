
function [success, msg] = process_single_erp_subject(mat_path, behavior_dir, bins_file, ...
                                                       cleaned_dir, set_dir, erp_dir, ...
                                                       report_dir, problematic_dir, ...
                                                       chanLoc_file, experiment_num)
% process_single_erp_subject - Process one ERP experiment file through complete pipeline
%
% Returns:
%   success - true if processing completed successfully
%   msg     - descriptive message of outcome

    success = false;
    msg = '';
    
    % Extract subject and experiment info from filename
    [~, fname, ~] = fileparts(mat_path);
    
    % Parse filename: E1_1 → S_01_E1 or E2_8 → S_08_E2
    tokens = regexp(fname, 'E(\d+)_(\d+)', 'tokens');
    if isempty(tokens)
        msg = 'Cannot parse filename - expected format: EX_Y...';
        return;
    end
    
    exp_num_file = tokens{1}{1};    % Experiment number from file
    subj_num = tokens{1}{2};         % Subject number
    
    % Verify experiment number matches
    if str2num(exp_num_file) ~= experiment_num
        msg = sprintf('File experiment (%s) does not match expected (%d)', exp_num_file, experiment_num);
        return;
    end
    
    % Format output names
    subj_id = sprintf('S_%02d_E%d', str2num(subj_num), experiment_num);
    
    % Create subject-specific log
    subj_log = fullfile(report_dir, sprintf('%s_report.txt', subj_id));
    fid_subj = fopen(subj_log, 'w');
    fprintf(fid_subj, '=== Processing Report: %s ===\n', subj_id);
    fprintf(fid_subj, 'Source file: %s\n', fname);
    fprintf(fid_subj, 'Processing date: %s\n\n', datestr(now));
    
    try
        %% STEP 1: Load and basic preprocessing
        fprintf('  [1/9] Loading .mat file...\n');
        fprintf(fid_subj, '--- STEP 1: Loading Data ---\n');
        
        % Load .mat file
        data = load(mat_path);
        var_names = fieldnames(data);
        
        fprintf(fid_subj, 'Variables in .mat file: %s\n', strjoin(var_names, ', '));
        
        % Construct expected variable name: "E1_1 20240305 1123" → "E1_1_20240305_11232"
        expected_var = [strrep(fname, ' ', '_') '2'];
        fprintf(fid_subj, 'Expected EEG variable name: %s\n', expected_var);
        
        % Check if expected variable exists
        if ~isfield(data, expected_var)
            eeg_var = '';
            for v = 1:length(var_names)
                if ~strcmp(var_names{v}, 'ECI_TCPIP_55513') && ...
                   ~strcmp(var_names{v}, 'samplingRate') && ...
                   ~contains(var_names{v}, 'Impedances') && ...
                   endsWith(var_names{v}, '2') && ...
                   size(data.(var_names{v}), 1) == 65
                    eeg_var = var_names{v};
                    fprintf(fid_subj, 'Found alternative EEG variable: %s\n', eeg_var);
                    break;
                end
            end
            
            if isempty(eeg_var)
                msg = sprintf('Cannot find EEG data variable. Expected: %s', expected_var);
                fprintf(fid_subj, 'ERROR: %s\n', msg);
                fclose(fid_subj);
                return;
            end
        else
            eeg_var = expected_var;
        end
        
        fprintf(fid_subj, 'Using EEG variable: %s\n', eeg_var);
        fprintf(fid_subj, 'Data size: %s\n', mat2str(size(data.(eeg_var))));
        
        % Load variable into base workspace
        assignin('base', eeg_var, data.(eeg_var));
        
        % Import into EEGLAB
        EEG = pop_importdata('dataformat', 'array', ...
                            'nbchan', 0, ...
                            'data', eeg_var, ...
                            'setname', subj_id, ...
                            'srate', 500, ...
                            'pnts', 0, ...
                            'xmin', 0);
        EEG = eeg_checkset(EEG);
        
        % Clean up base workspace
        evalin('base', sprintf('clear %s', eeg_var));
        
        fprintf(fid_subj, 'Imported: %d channels, %d points, %.2f sec\n', ...
                EEG.nbchan, EEG.pnts, EEG.pnts/EEG.srate);
        
        %% STEP 2: Label channels
        fprintf('  [2/9] Labeling channels...\n');
        fprintf(fid_subj, '\n--- STEP 2: Channel Labeling ---\n');
        
        standard_labels = {'E1','E2','E3','E4','E5','E6','E7','E8','E9',...
                          'E10','E11','E12','E13','E14','E15','E16','E17','E18','E19',...
                          'E20','E21','E22','E23','E24','E25','E26','E27','E28','E29',...
                          'E30','E31','E32','E33','E34','E35','E36','E37','E38','E39',...
                          'E40','E41','E42','E43','E44','E45','E46','E47','E48','E49',...
                          'E50','E51','E52','E53','E54','E55','E56','E57','E58','E59',...
                          'E60','E61','E62','E63','E64','Cz'};
        
        for i = 1:65
            EEG.chanlocs(i).labels = standard_labels{i};
        end
        EEG = eeg_checkset(EEG);
        fprintf(fid_subj, 'Channels labeled: E1-E64, Cz\n');
        
        %% STEP 3: Set channel locations
        fprintf('  [3/9] Loading channel locations...\n');
        fprintf(fid_subj, '\n--- STEP 3: Channel Locations ---\n');
        
        EEG = pop_chanedit(EEG, 'lookup', chanLoc_file);
        EEG = eeg_checkset(EEG);
        fprintf(fid_subj, 'Channel locations loaded\n');
        
        %% STEP 4: Re-reference to Cz
        fprintf('  [4/9] Re-referencing to Cz...\n');
        fprintf(fid_subj, '\n--- STEP 4: Re-referencing ---\n');
        
        EEG = pop_reref(EEG, 65);
        EEG = eeg_checkset(EEG);
        fprintf(fid_subj, 'Re-referenced to Cz (channel 65)\n');
        
        %% STEP 5: Filtering
        fprintf('  [5/9] Filtering (0.5-35 Hz)...\n');
        fprintf(fid_subj, '\n--- STEP 5: Filtering ---\n');
        
        EEG = pop_basicfilter(EEG, 1:64, ...
                             'Boundary', 'boundary', ...
                             'Cutoff', [0.5 35], ...
                             'Design', 'butter', ...
                             'Filter', 'bandpass', ...
                             'Order', 2);
        EEG = eeg_checkset(EEG);
        fprintf(fid_subj, 'Bandpass filter: 0.5-35 Hz (Butterworth, order 2)\n');
        
        %% STEP 6: Import and process events
        fprintf('  [6/9] Importing and processing events...\n');
        fprintf(fid_subj, '\n--- STEP 6: Event Processing ---\n');
        
        % Check event variable exists
        if ~isfield(data, 'ECI_TCPIP_55513')
            msg = 'Event variable ECI_TCPIP_55513 not found';
            fprintf(fid_subj, 'ERROR: %s\n', msg);
            fclose(fid_subj);
            return;
        end
        
        % Import events
        tipos = data.ECI_TCPIP_55513(1, :);
        frames = cell2mat(data.ECI_TCPIP_55513(4, :));
        
        EEG.event = [];
        for i = 1:length(frames)
            if isnumeric(frames(i)) && frames(i) > 0 && frames(i) <= EEG.pnts
                EEG.event(end+1).type = tipos{i};
                EEG.event(end).latency = frames(i);
            end
        end
        EEG = eeg_checkset(EEG);
        
        fprintf(fid_subj, 'Total events imported: %d\n', length(EEG.event));
        event_types_all = unique({EEG.event.type});
        fprintf(fid_subj, 'Event types: %s\n', strjoin(event_types_all, ', '));
        
        % Filter events: keep only 'imag' and 'TRSP'
        event_types = {EEG.event.type};
        keep_mask = strcmp(event_types, 'imag') | strcmp(event_types, 'TRSP');
        EEG.event = EEG.event(keep_mask);
        
        fprintf(fid_subj, 'After filtering (imag + TRSP): %d events\n', length(EEG.event));
        
        % Rename TRSP to TRSP1 and TRSP2 based on sequence
        i = 1;
        while i <= length(EEG.event) - 2
            if strcmp(EEG.event(i).type, 'imag') && ...
               strcmp(EEG.event(i+1).type, 'TRSP') && ...
               strcmp(EEG.event(i+2).type, 'TRSP')
                
                EEG.event(i+1).type = 'TRSP1';
                EEG.event(i+2).type = 'TRSP2';
                i = i + 3;
            else
                i = i + 1;
            end
        end
        
        n_imag = sum(strcmp({EEG.event.type}, 'imag'));
        n_trsp1 = sum(strcmp({EEG.event.type}, 'TRSP1'));
        n_trsp2 = sum(strcmp({EEG.event.type}, 'TRSP2'));
        fprintf(fid_subj, 'Event counts: imag=%d, TRSP1=%d, TRSP2=%d\n', n_imag, n_trsp1, n_trsp2);
        
        %% STEP 7: Match with behavioral data and recode events
        fprintf('  [7/9] Matching behavioral data...\n');
        fprintf(fid_subj, '\n--- STEP 7: Behavioral Data Matching ---\n');
        
        % Find behavioral Excel file
        % Pattern: E{exp}_{subj}.xlsx (e.g., E1_3.xlsx, E2_8.xlsx)
        beh_pattern = sprintf('E%d_%s.xlsx', experiment_num, subj_num);
        beh_files = dir(fullfile(behavior_dir, beh_pattern));
        
        % If not found with exact pattern, try wildcards
        if isempty(beh_files)
            beh_pattern_alt = sprintf('*E%d*%s*.xlsx', experiment_num, subj_num);
            beh_files = dir(fullfile(behavior_dir, beh_pattern_alt));
        end
        
        if isempty(beh_files)
            msg = sprintf('No behavioral file found. Tried: E%d_%s.xlsx and *E%d*%s*.xlsx', ...
                         experiment_num, subj_num, experiment_num, subj_num);
            fprintf(fid_subj, 'ERROR: %s\n', msg);
            fprintf(fid_subj, 'Files in behavior directory: %s\n', strjoin({dir(behavior_dir).name}, ', '));
            fclose(fid_subj);
            return;
        end
        
        beh_file = fullfile(behavior_dir, beh_files(1).name);
        fprintf(fid_subj, 'Behavioral file: %s\n', beh_files(1).name);
        
        % Read Excel file
        [~, ~, beh_data] = xlsread(beh_file);
        headers = beh_data(1, :);
        beh_data = beh_data(2:end, :);
        
        % Find columns
        correctCol = find(strcmp(headers, 'Correct'));
        correct2Col = find(strcmp(headers, 'Correct2'));
        pre1AccCol = find(strcmp(headers, 'preg1ACC'));
        pre2AccCol = find(strcmp(headers, 'preg2ACC'));
        
        if isempty(correctCol) || isempty(correct2Col) || isempty(pre1AccCol) || isempty(pre2AccCol)
            msg = 'Required columns not found in behavioral file';
            fprintf(fid_subj, 'ERROR: %s\n', msg);
            fclose(fid_subj);
            return;
        end
        
        % Recode 'imag' events based on valencia and congruencia
        imagCounter = 0;
        for i = 1:length(EEG.event)
            if strcmp(EEG.event(i).type, 'imag')
                imagCounter = imagCounter + 1;
                if imagCounter <= size(beh_data, 1)
                    valencia = beh_data{imagCounter, correctCol};      % 1, 2, 3
                    congruencia = beh_data{imagCounter, correct2Col};  % 1, 2
                    
                    if isnumeric(valencia) && isnumeric(congruencia)
                        nuevo_tipo = congruencia * 10 + valencia;
                        EEG.event(i).type = num2str(nuevo_tipo);
                    end
                end
            end
        end
        
        fprintf(fid_subj, 'Recoded %d "imag" events\n', imagCounter);
        
        % Recode TRSP1 and TRSP2
        trsp1Counter = 0;
        trsp2Counter = 0;
        
        for i = 1:length(EEG.event)
            if strcmp(EEG.event(i).type, 'TRSP1')
                trsp1Counter = trsp1Counter + 1;
                if trsp1Counter <= size(beh_data, 1)
                    val = beh_data{trsp1Counter, correctCol};  % 1→100, 2→200, 3→300
                    if isnumeric(val)
                        EEG.event(i).type = num2str(val * 100);
                    end
                end
            elseif strcmp(EEG.event(i).type, 'TRSP2')
                trsp2Counter = trsp2Counter + 1;
                if trsp2Counter <= size(beh_data, 1)
                    val = beh_data{trsp2Counter, correct2Col};  % 1→1000, 2→2000
                    if isnumeric(val)
                        EEG.event(i).type = num2str(val * 1000);
                    end
                end
            end
        end
        
        fprintf(fid_subj, 'Recoded TRSP1: %d, TRSP2: %d\n', trsp1Counter, trsp2Counter);
        
        % Remove incorrect trials
        event_keep_mask = true(1, length(EEG.event));
        trsp1_index = 0;
        trsp2_index = 0;
        
        for i = 1:length(EEG.event)
            tipo = EEG.event(i).type;
            
            % Check TRSP1 accuracy
            if any(strcmp(tipo, {'100', '200', '300'}))
                trsp1_index = trsp1_index + 1;
                if trsp1_index <= size(beh_data, 1)
                    acc = beh_data{trsp1_index, pre1AccCol};
                    if isnumeric(acc) && acc == 0
                        event_keep_mask(i) = false;
                    end
                end
            end
            
            % Check TRSP2 accuracy
            if any(strcmp(tipo, {'1000', '2000'}))
                trsp2_index = trsp2_index + 1;
                if trsp2_index <= size(beh_data, 1)
                    acc = beh_data{trsp2_index, pre2AccCol};
                    if isnumeric(acc) && acc == 0
                        event_keep_mask(i) = false;
                    end
                end
            end
        end
        
        events_before = length(EEG.event);
        EEG.event = EEG.event(event_keep_mask);
        events_removed = events_before - length(EEG.event);
        EEG = eeg_checkset(EEG, 'eventconsistency');
        
        fprintf(fid_subj, 'Removed %d incorrect trials\n', events_removed);
        fprintf(fid_subj, 'Final event count: %d\n', length(EEG.event));
        
        % Log final event types
        final_types = unique({EEG.event.type});
        fprintf(fid_subj, 'Final event types: %s\n', strjoin(final_types, ', '));
        
        %% STEP 8: Clean, ICA, and artifact rejection
        fprintf('  [8/9] Cleaning and ICA...\n');
        fprintf(fid_subj, '\n--- STEP 8: Artifact Removal ---\n');
        
        [EEG, clean_info, ica_info] = clean_and_ica_continuous(EEG, fid_subj);
        
        % Save cleaned dataset
        cleaned_filename = sprintf('%s_clean.set', subj_id);
        pop_saveset(EEG, 'filename', cleaned_filename, 'filepath', cleaned_dir);
        fprintf(fid_subj, '\nSaved cleaned file: %s\n', cleaned_filename);
        
        %% STEP 9: Create bins, epoch, and generate ERPs
        fprintf('  [9/9] Creating bins and ERPs...\n');
        fprintf(fid_subj, '\n--- STEP 9: Bins & ERPs ---\n');
        
        % Create event list
        EEG = pop_creabasiceventlist(EEG, ...
            'AlphanumericCleaning', 'on', ...
            'BoundaryNumeric', {-99}, ...
            'BoundaryString', {'boundary'});
        EEG = eeg_checkset(EEG);
        fprintf(fid_subj, 'Event list created\n');
        
        % Assign bins
        if ~exist(bins_file, 'file')
            msg = sprintf('Bins file not found: %s', bins_file);
            fprintf(fid_subj, 'ERROR: %s\n', msg);
            fclose(fid_subj);
            return;
        end
        
        EEG = pop_binlister(EEG, ...
            'BDF', bins_file, ...
            'IndexEL', 1, ...
            'SendEL2', 'EEG', ...
            'Voutput', 'EEG');
        EEG = eeg_checkset(EEG);
        fprintf(fid_subj, 'Bins assigned from: %s\n', bins_file);
        
        % Extract bin-based epochs
        EEG = pop_epochbin(EEG, [-200.0 800.0], [-200 0]);
        EEG = eeg_checkset(EEG);
        fprintf(fid_subj, 'Epochs extracted: %d epochs\n', EEG.trials);
        
        % Save epoched dataset
        set_filename = sprintf('%s.set', subj_id);
        pop_saveset(EEG, 'filename', set_filename, 'filepath', set_dir);
        fprintf(fid_subj, 'Saved epoched file: %s\n', set_filename);
        
        % Generate ERP
        ERP = pop_averager(EEG, ...
            'Criterion', 'good', ...
            'DQ_custom_wins', 0, ...
            'DQ_flag', 1, ...
            'DQ_preavg_txt', 0, ...
            'ExcludeBoundary', 'on', ...
            'SEM', 'on');
        
        % Create averaged channel E65 (average of channels 33-40)
        fprintf(fid_subj, '\nCreating averaged channel E65...\n');
        ERP = pop_erpchanoperator(ERP, ...
            {'ch65 = (ch33 + ch34 + ch35 + ch36 + ch37 + ch38 + ch39 + ch40)/8 label E65'}, ...
            'ErrorMsg', 'popup', ...
            'KeepLocations', 1, ...
            'Warning', 'on');
        fprintf(fid_subj, 'Channel E65 created (average of ch33-40)\n');
        
        % Save ERP
        erp_filename = sprintf('%s.erp', subj_id);
        ERP = pop_savemyerp(ERP, ...
            'erpname', subj_id, ...
            'filename', erp_filename, ...
            'filepath', erp_dir, ...
            'Warning', 'on');
        fprintf(fid_subj, 'Saved ERP file: %s\n', erp_filename);
        
        %% Summary
        fprintf(fid_subj, '\n=== PROCESSING SUMMARY ===\n');
        fprintf(fid_subj, 'Status: SUCCESS\n');
        fprintf(fid_subj, 'Samples removed (ASR): %d (%.2f%%)\n', ...
                clean_info.removed_samples, clean_info.percent_removed);
        fprintf(fid_subj, 'ICA components rejected: %d/%d\n', ...
                ica_info.n_rejected, ica_info.n_total);
        fprintf(fid_subj, 'Rejected components: %s\n', mat2str(ica_info.rejected_comps));
        fprintf(fid_subj, 'Final epochs: %d\n', EEG.trials);
        
        success = true;
        msg = sprintf('Completed: %s_clean.set, %s.set, %s.erp', subj_id, subj_id, subj_id);
        
    catch ME
        success = false;
        msg = sprintf('Exception: %s', ME.message);
        fprintf(fid_subj, '\n=== ERROR ===\n');
        fprintf(fid_subj, '%s\n', ME.message);
        fprintf(fid_subj, 'Stack trace:\n');
        for k = 1:length(ME.stack)
            fprintf(fid_subj, '  %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
        end
    end
    
    fclose(fid_subj);
end


function [EEG, clean_info, ica_info] = clean_and_ica_continuous(EEG, fid_subj)
% Clean continuous data with ASR, run ICA, and reject artifacts
    
    %% Clean with ASR
    fprintf(fid_subj, '\n[Clean] Applying ASR artifact rejection...\n');
    
    pnts_before = EEG.pnts;
    
    EEG = pop_clean_rawdata(EEG, ...
        'FlatlineCriterion', 'off', ...
        'ChannelCriterion', 'off', ...
        'LineNoiseCriterion', 'off', ...
        'Highpass', 'off', ...
        'BurstCriterion', 20, ...
        'WindowCriterion', 0.25, ...
        'BurstRejection', 'on', ...
        'Distance', 'Euclidian', ...
        'WindowCriterionTolerances', [-Inf 7]);
    EEG = eeg_checkset(EEG);
    
    pnts_after = EEG.pnts;
    removed_samples = pnts_before - pnts_after;
    percent_removed = (removed_samples / pnts_before) * 100;
    
    fprintf(fid_subj, '  Samples before: %d\n', pnts_before);
    fprintf(fid_subj, '  Samples after: %d\n', pnts_after);
    fprintf(fid_subj, '  Samples removed: %d (%.2f%%)\n', removed_samples, percent_removed);
    
    clean_info.removed_samples = removed_samples;
    clean_info.percent_removed = percent_removed;
    
    %% Run ICA
    fprintf(fid_subj, '\n[ICA] Running extended Infomax ICA...\n');
    
    EEG = pop_runica(EEG, ...
        'icatype', 'runica', ...
        'extended', 1, ...
        'pca', 64, ...
        'interrupt', 'off');
    EEG = eeg_checkset(EEG);
    
    n_components = size(EEG.icaweights, 1);
    fprintf(fid_subj, '  ICA complete: %d components\n', n_components);
    
    %% Label and reject components
    fprintf(fid_subj, '\n[ICLabel] Classifying components...\n');
    
    EEG = pop_iclabel(EEG, 'default');
    EEG = eeg_checkset(EEG);
    
    % Flag artifacts: Muscle, Eye, Heart, Channel Noise ≥ 70%
    EEG = pop_icflag(EEG, [NaN NaN; 0.7 1; 0.7 1; 0.7 1; NaN NaN; 0.7 1; NaN NaN]);
    EEG = eeg_checkset(EEG);
    
    rejected_comps = find(EEG.reject.gcompreject);
    n_rejected = length(rejected_comps);
    
    fprintf(fid_subj, '  Components flagged: %d/%d\n', n_rejected, n_components);
    if n_rejected > 0
        fprintf(fid_subj, '  Rejected indices: %s\n', mat2str(rejected_comps));
        
        class_labels = {'Brain', 'Muscle', 'Eye', 'Heart', 'LineNoise', 'ChanNoise', 'Other'};
        for c = rejected_comps
            [max_prob, max_idx] = max(EEG.etc.ic_classification.ICLabel.classifications(c, :));
            fprintf(fid_subj, '    Comp %d: %s (%.1f%%)\n', c, class_labels{max_idx}, max_prob*100);
        end
    end
    
    ica_info.n_total = n_components;
    ica_info.n_rejected = n_rejected;
    ica_info.rejected_comps = rejected_comps;
    
    %% Remove components
    fprintf(fid_subj, '\n[Reject] Removing flagged components...\n');
    
    EEG = pop_subcomp(EEG, [], 0);
    EEG = eeg_checkset(EEG);
    
    fprintf(fid_subj, '  Final dataset: %d channels, %d samples\n', EEG.nbchan, EEG.pnts);
end
