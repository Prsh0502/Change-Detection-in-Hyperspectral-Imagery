%% =========================================================================
%  LAB 7: HYPERSPECTRAL CHANGE DETECTION PROTOTYPE (TOOLBOX-FREE)
%  Dataset: EO-1 Hyperion (225x180x159)
%  Directory: C:\Users\prern\MATLAB Drive\SS PROJECT HYPERSPECTRAL IMAGING
%% =========================================================================
clear; clc; close all;

%% 1. DIRECTORY CONFIGURATION & SCREENSHOT FOLDER SETUP
project_dir = 'C:\Users\prern\MATLAB Drive\SS PROJECT HYPERSPECTRAL IMAGING';
if exist(project_dir, 'dir')
    cd(project_dir);
end

output_dir = fullfile(pwd, 'screenshots');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
fprintf('[+] Working Directory: %s\n', pwd);
fprintf('[+] Screenshot Export Path: %s\n\n', output_dir);

%% 2. DATASET INGESTION & NORMALIZATION
fprintf('[1/6] Loading EO-1 Hyperion Datacubes...\n');

file_t1 = fullfile(pwd, 'PreImg_2004.mat');
file_t2 = fullfile(pwd, 'PostImg_2007.mat');
file_gt = fullfile(pwd, 'Reference_Map_Binary.mat');

if ~exist(file_t1, 'file') || ~exist(file_t2, 'file') || ~exist(file_gt, 'file')
    error('Required .mat files missing from project directory.');
end

d_t1 = load(file_t1); fn1 = fieldnames(d_t1); T1 = double(d_t1.(fn1{1}));
d_t2 = load(file_t2); fn2 = fieldnames(d_t2); T2 = double(d_t2.(fn2{1}));
d_gt = load(file_gt); fngt = fieldnames(d_gt); GT = logical(d_gt.(fngt{1}));

[rows, cols, bands] = size(T1);
fprintf('      Dimensions: %d x %d pixels across %d calibrated bands.\n', rows, cols, bands);

% Radiometric normalization to [0, 1]
T1_norm = (T1 - min(T1(:))) / (max(T1(:)) - min(T1(:)) + eps);
T2_norm = (T2 - min(T2(:))) / (max(T2(:)) - min(T2(:)) + eps);

%% 3. SPECTRAL ANGLE MAPPER (SAM)
fprintf('[2/6] Computing Spectral Angle Mapper (SAM)...\n');
norm_T1 = sqrt(sum(T1_norm.^2, 3));
norm_T2 = sqrt(sum(T2_norm.^2, 3));
dot_prod = sum(T1_norm .* T2_norm, 3);
cos_theta = min(max(dot_prod ./ (norm_T1 .* norm_T2 + eps), -1), 1);
sam_map = acos(cos_theta); % Angular deviation in radians

%% 4. TOOLBOX-FREE PCA & CHANGE VECTOR ANALYSIS (CVA)
fprintf('[3/6] Computing PCA Subspace via Eigen Decomposition (Base MATLAB)...\n');
num_components = 6;

% 2D Flattening: [N_pixels x Bands]
X1_2D = reshape(T1_norm, rows * cols, bands);
X2_2D = reshape(T2_norm, rows * cols, bands);
X_all = [X1_2D; X2_2D];

% Center the data matrix
X_mean = mean(X_all, 1);
X_centered = X_all - X_mean;

% Compute Covariance Matrix (159 x 159) & Eigen Decomposition
cov_matrix = (X_centered' * X_centered) / (size(X_centered, 1) - 1);
[V, D] = eig(cov_matrix);

% Sort eigenvalues & eigenvectors in descending order
eigenvalues = diag(D);
[latent_sorted, sort_idx] = sort(eigenvalues, 'descend');
coeff = V(:, sort_idx(1:num_components));

var_retained = sum(latent_sorted(1:num_components)) / sum(latent_sorted) * 100;
fprintf('      %d Principal Components retain %.2f%% spectral variance.\n', num_components, var_retained);

% Project T1 and T2 onto the principal component subspace
Y1 = (X1_2D - X_mean) * coeff;
Y2 = (X2_2D - X_mean) * coeff;

% Compute Change Vector Magnitude
diff_pca = Y2 - Y1;
cva_mag = sqrt(sum(diff_pca.^2, 2));
cva_map = reshape(cva_mag, rows, cols);

%% 5. TOOLBOX-FREE OTSU THRESHOLDING & ACCURACY EVALUATION
fprintf('[4/6] Segmenting Difference Map & Computing Metrics...\n');
cva_scaled = (cva_map - min(cva_map(:))) / (max(cva_map(:)) - min(cva_map(:)) + eps);

% Native Otsu Implementation (No Image Processing Toolbox required)
nbins = 256;
bin_edges = linspace(0, 1, nbins + 1);
counts = histcounts(cva_scaled(:), bin_edges);
p = counts / sum(counts);
omega = cumsum(p);
mu = cumsum(p .* (1:nbins));
mu_t = mu(end);
sigma_b_sq = (mu_t * omega - mu).^2 ./ (omega .* (1 - omega) + eps);
[~, max_idx] = max(sigma_b_sq);
otsu_thresh = (max_idx - 1) / (nbins - 1);

binary_mask = cva_scaled > otsu_thresh;

% Quantitative Metrics
TP = sum(binary_mask(:) == 1 & GT(:) == 1);
FP = sum(binary_mask(:) == 1 & GT(:) == 0);
TN = sum(binary_mask(:) == 0 & GT(:) == 0);
FN = sum(binary_mask(:) == 0 & GT(:) == 1);

total_pix = rows * cols;
OA = (TP + TN) / total_pix;
Precision = TP / (TP + FP + eps);
Recall = TP / (TP + FN + eps);
F1 = 2 * (Precision * Recall) / (Precision + Recall + eps);

p_e = (((TP + FP) * (TP + FN)) + ((TN + FN) * (TN + FP))) / (total_pix^2);
Kappa = (OA - p_e) / (1 - p_e + eps);

fprintf('\n=======================================================\n');
fprintf('                 LAB 7 SUBMISSION METRICS              \n');
fprintf('=======================================================\n');
fprintf(' Overall Accuracy (OA) : %.4f (%.2f%%)\n', OA, OA * 100);
fprintf(' Kappa Coefficient (κ) : %.4f\n', Kappa);
fprintf(' F1-Score              : %.4f\n', F1);
fprintf(' Precision             : %.4f\n', Precision);
fprintf(' Recall                : %.4f\n', Recall);
fprintf('=======================================================\n\n');

%% 6. RENDERING & EXPORTING HIGH-RESOLUTION SCREENSHOTS
fprintf('[5/6] Generating and Saving Submission Figures...\n');

% Figure 1: False Color Composites (Bands 40, 20, 10) + Ground Truth
fig1 = figure('Position', [100, 100, 1100, 360], 'Color', 'w');
rgb_t1 = cat(3, T1_norm(:,:,40), T1_norm(:,:,20), T1_norm(:,:,10));
rgb_t2 = cat(3, T2_norm(:,:,40), T2_norm(:,:,20), T2_norm(:,:,10));
rgb_t1 = rgb_t1 ./ max(rgb_t1(:));
rgb_t2 = rgb_t2 ./ max(rgb_t2(:));

subplot(1, 3, 1); imshow(rgb_t1 * 1.8); title('Pre-Image (May 2004)', 'FontWeight', 'bold');
subplot(1, 3, 2); imshow(rgb_t2 * 1.8); title('Post-Image (May 2007)', 'FontWeight', 'bold');
subplot(1, 3, 3); imshow(GT); title('Ground Truth Reference Map', 'FontWeight', 'bold');
saveas(fig1, fullfile(output_dir, 'Figure1_Scene_Overview.png'));

% Figure 2: Difference Maps (SAM vs PCA-CVA)
fig2 = figure('Position', [150, 150, 950, 380], 'Color', 'w');
subplot(1, 2, 1); imagesc(sam_map); colormap(gca, 'jet'); colorbar; axis image off;
title('Spectral Angle Mapper (SAM) Map', 'FontWeight', 'bold');
subplot(1, 2, 2); imagesc(cva_map); colormap(gca, 'hot'); colorbar; axis image off;
title('PCA-CVA Magnitude Map', 'FontWeight', 'bold');
saveas(fig2, fullfile(output_dir, 'Figure2_Difference_Maps.png'));

% Figure 3: Binary Output & Spatial Error Classification Map
fig3 = figure('Position', [200, 200, 1000, 400], 'Color', 'w');
error_map = zeros(rows, cols, 3);
for c = 1:3
    slice = error_map(:,:,c);
    if c == 2, slice(binary_mask & GT) = 1; end      % Green = TP
    if c == 1, slice(binary_mask & ~GT) = 1; end     % Red = FP
    if c == 3, slice(~binary_mask & GT) = 1; end     % Blue = FN
    error_map(:,:,c) = slice;
end

subplot(1, 2, 1); imshow(binary_mask);
title(sprintf('Predicted Binary Change (Thresh = %.3f)', otsu_thresh), 'FontWeight', 'bold');
subplot(1, 2, 2); imshow(error_map);
title('Spatial Error Classification Map', 'FontWeight', 'bold');
xlabel('Green: TP | Red: FP | Blue: FN | Black: TN', 'FontWeight', 'bold');
saveas(fig3, fullfile(output_dir, 'Figure3_Binary_and_ErrorMap.png'));

% Figure 4: Spectral Signature Shifts
fig4 = figure('Position', [250, 250, 950, 360], 'Color', 'w');
[ch_r, ch_c] = find(GT == 1, 1, 'first');
[unch_r, unch_c] = find(GT == 0, 1, 'first');

subplot(1, 2, 1);
plot(squeeze(T1_norm(ch_r, ch_c, :)), 'b-', 'LineWidth', 1.6); hold on;
plot(squeeze(T2_norm(ch_r, ch_c, :)), 'r--', 'LineWidth', 1.6);
title(sprintf('Changed Pixel Profile (%d, %d)', ch_r, ch_c), 'FontWeight', 'bold');
xlabel('Spectral Band Index (1-159)'); ylabel('Normalized Reflectance');
legend('T1 (2004)', 'T2 (2007)', 'Location', 'northeast'); grid on;

subplot(1, 2, 2);
plot(squeeze(T1_norm(unch_r, unch_c, :)), 'b-', 'LineWidth', 1.6); hold on;
plot(squeeze(T2_norm(unch_r, unch_c, :)), 'g--', 'LineWidth', 1.6);
title(sprintf('Unchanged Pixel Profile (%d, %d)', unch_r, unch_c), 'FontWeight', 'bold');
xlabel('Spectral Band Index (1-159)'); ylabel('Normalized Reflectance');
legend('T1 (2004)', 'T2 (2007)', 'Location', 'northeast'); grid on;
saveas(fig4, fullfile(output_dir, 'Figure4_Spectral_Signatures.png'));

fprintf('[6/6] Complete! High-res figures saved in:\n      %s\n', output_dir);
% Print Formatted Confusion Matrix and Performance Summary
fprintf('\n=======================================================\n');
fprintf('         EO-1 HYPERION LAB 7 PERFORMANCE EVALUATION    \n');
fprintf('=======================================================\n');
fprintf(' Total Evaluated Pixels : %d (225 x 180)\n', total_pix);
fprintf(' Changed Ground Truth   : %d (%.2f%%)\n', sum(GT(:)==1), (sum(GT(:)==1)/total_pix)*100);
fprintf(' Invariant Ground Truth : %d (%.2f%%)\n', sum(GT(:)==0), (sum(GT(:)==0)/total_pix)*100);
fprintf('-------------------------------------------------------\n');
fprintf(' True Positives  (TP)   : %d\n', TP);
fprintf(' False Positives (FP)   : %d\n', FP);
fprintf(' True Negatives  (TN)   : %d\n', TN);
fprintf(' False Negatives (FN)   : %d\n', FN);
fprintf('-------------------------------------------------------\n');
fprintf(' Overall Accuracy (OA)  : %.4f (%.2f%%)\n', OA, OA * 100);
fprintf(' Kappa Coefficient (κ)  : %.4f\n', Kappa);
fprintf(' Precision              : %.4f (%.2f%%)\n', Precision, Precision * 100);
fprintf(' Recall (Sensitivity)   : %.4f (%.2f%%)\n', Recall, Recall * 100);
fprintf(' F1-Score               : %.4f\n', F1);
fprintf('=======================================================\n\n');