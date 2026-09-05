function cfg = config(dataset_name)
% CONFIG Returns configuration settings for target dataset
if nargin < 1
    dataset_name = 'hermiston'; % Default: 'hermiston' or 'yellow_river'
end
cfg.dataset_name = lower(dataset_name);

% Base directory paths
cfg.root_dir = fileparts(mfilename('fullpath'));
cfg.data_dir = fullfile(cfg.root_dir, 'data', cfg.dataset_name);
cfg.results_dir = fullfile(cfg.root_dir, 'results');
if ~exist(cfg.results_dir, 'dir'), mkdir(cfg.results_dir); end

% Dataset-specific parameters
switch cfg.dataset_name
    case 'hermiston'
        cfg.t1_file = 'PreImg_2004.mat';
        cfg.t2_file = 'PostImg_2007.mat';
        cfg.gt_file = 'Reference_Map_Binary.mat';
        cfg.num_pc  = 6;
        cfg.trim_bands = false;

    case 'yellow_river'
        cfg.t1_file = 'PreImg.mat';
        cfg.t2_file = 'PostImg.mat';
        cfg.gt_file = 'Reference_Map_Binary.mat';
        cfg.num_pc  = 8;
        cfg.trim_bands = true;

    otherwise
        error('Invalid dataset specified. Choose "hermiston" or "yellow_river".');
end

% Processing toggles
cfg.apply_spatial_filter = true;
cfg.filter_sigma = 1.0;
cfg.threshold_method = 'otsu';
end