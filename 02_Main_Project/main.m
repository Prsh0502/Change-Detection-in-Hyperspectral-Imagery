%% Master Hyperspectral Change Detection Pipeline
clear; clc; close all;

addpath(genpath('src'));

% 1. Configuration
target_dataset = 'hermiston';
cfg = config(target_dataset);
fprintf('[*] Target Dataset: %s\n', upper(cfg.dataset_name));

% 2. Load and Preprocess
fprintf('[+] Loading cubes...\n');
[T1, T2, GT] = load_and_clean_cube(cfg);

% 3. Feature Extraction
fprintf('[+] Computing PCA-CVA and SAM features (K = %d)...\n', cfg.num_pc);
diff_field = compute_features(T1, T2, cfg.num_pc);

% 4. Spatial Regularization
if cfg.apply_spatial_filter
    fprintf('[+] Applying spatial edge-preserving filter...\n');
    diff_field = spatial_filter(diff_field, cfg.filter_sigma);
end

% 5. Segmentation
fprintf('[+] Segmenting via Otsu optimization...\n');
[binary_mask, thresh] = segment_change(diff_field);

% 6. Evaluation
metrics = evaluate_and_save(T1, diff_field, binary_mask, GT, thresh, cfg);
fprintf('[✓] Execution Complete! Results stored in /results\n');
