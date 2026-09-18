%% Change Detection in Hyperspectral Imagery — River Dataset
% Uses: Image Processing Toolbox (Hyperspectral Imaging Library add-on)
%
% Follows the project's suggested steps:
%   1. Load dataset
%   2. (Calibration/atmospheric correction — see note in Section 2)
%   3. Pseudo-binary change detection -> initial change mask
%   4. Endmember extraction on changed pixels + hierarchical clustering
%      + spectral matching (SAM) to resolve mixed pixels / multiple changes
%   5. Generate final change detection map
%
% Requires: nfindr, countEndmembersHFC, sam
%           (from the Hyperspectral Imaging Library — all accept plain
%            H-by-W-by-B numeric arrays, no hypercube object needed)

clear; clc; close all;

%% 1. Load data
dataFolder = pwd;
before3D = loadMainArray(fullfile(dataFolder, 'river_before.mat'));
after3D  = loadMainArray(fullfile(dataFolder, 'river_after.mat'));
gt       = loadMainArray(fullfile(dataFolder, 'groundtruth.mat'));

gt = squeeze(gt);
if ~islogical(gt)
    gt = gt > 0.5 * max(gt(:));
end

[H, W, B] = size(before3D);

% NOTE: Earlier versions of this script wrapped the data in hypercube()
% objects. That's not actually required — nfindr, countEndmembersHFC,
% and spectralMatch all accept a plain H-by-W-by-B numeric array directly
% (a hypercube object is optional, not mandatory), so we skip it here to
% avoid a constructor issue some installs hit.
rgbBands = min([33 22 11], B);
toRGB = @(cube) mat2gray(cube(:,:,rgbBands));

figure('Name','False color');
subplot(1,3,1); imshow(toRGB(before3D)); title('Before');
subplot(1,3,2); imshow(toRGB(after3D));  title('After');
subplot(1,3,3); imshow(gt); title('Ground Truth');

%% 2. Calibration / correction note
% river_before.mat / river_after.mat from the GETNET/River dataset are
% typically already radiometrically corrected and band-cleaned (dropped
% from 242 -> ~198 bands). If your source data is raw/uncorrected, apply
% the library's correction functions here first, e.g.:
%   hcBefore = correctRadiometry(hcBefore, ...)   % if flat-field/dark data available
% Skipped here since the standard River release is pre-corrected.

%% 3. Pseudo-binary change detection (initial change mask)
X1 = reshape(before3D, H*W, B);
X2 = reshape(after3D,  H*W, B);

mu  = mean([X1; X2], 1);
sig = std([X1; X2], 0, 1) + eps;
X1n = (X1 - mu) ./ sig;
X2n = (X2 - mu) ./ sig;

diffVec   = X1n - X2n;
magnitude = sqrt(sum(diffVec.^2, 2));
magImg    = reshape(magnitude, H, W);

% Denoise the magnitude image before thresholding (this is what removes
% the speckle/striping you saw in the earlier CVA-only attempt)
magImgFilt = medfilt2(magImg, [5 5]);

level = graythresh(mat2gray(magImgFilt));
initialChangeMask = imbinarize(mat2gray(magImgFilt), level);
initialChangeMask = bwareaopen(initialChangeMask, 15);  % drop tiny speckle blobs

figure('Name','Pseudo-binary change mask');
imshow(initialChangeMask); title('Step 3: Initial (pseudo-binary) change mask');

%% 4. Endmember extraction on the changed region + hierarchical clustering
% Only pull spectra from pixels flagged as "changed" — these are the
% ambiguous / mixed pixels we need to resolve into distinct change types.
changeIdx = find(initialChangeMask(:));

% Use the *difference* spectrum at changed pixels so endmembers represent
% distinct "modes of change" rather than raw land-cover types
diffCube = reshape(X1n - X2n, H, W, B);
diffAtChange = reshape(diffCube, H*W, B);
diffAtChange = diffAtChange(changeIdx, :);

% countEndmembersHFC / nfindr reject any singleton spatial dimension, so
% we can't just reshape the list of changed-pixel spectra into an N-by-1
% cube. Instead, arrange them into a genuine (non-singleton) M-by-N grid,
% padding by repeating a few pixels if the pixel count isn't a perfect
% rectangle. Spatial layout is arbitrary here — only the per-pixel
% spectra matter for endmember extraction, not their true image position.
pseudoCube = pixelsToPseudoCube(diffAtChange, B);

numEndmembers = countEndmembersHFC(pseudoCube, 'PFA', 1e-6);
numEndmembers = max(2, min(numEndmembers, 8));  % keep it sane or override manually
fprintf('Estimated number of change endmembers: %d\n', numEndmembers);

endmembers = nfindr(pseudoCube, numEndmembers);
% nfindr returns endmembers as numBands-by-numEndmembers (B x nE) — i.e.
% one endmember spectrum PER COLUMN, not per row. Transpose immediately
% so the rest of the script (which treats each ROW as one endmember
% spectrum) works correctly.
endmembers = endmembers';
% endmembers is now numEndmembers-by-B: each row is one "change-mode" spectrum

% --- Hierarchical clustering of the endmembers using spectral angle ---
% Spectral Angle distance between endmember pairs
nE = size(endmembers,1);
angleDist = zeros(nE, nE);
for i = 1:nE
    for j = 1:nE
        v1 = endmembers(i,:); v2 = endmembers(j,:);
        cosSim = dot(v1,v2) / (norm(v1)*norm(v2) + eps);
        cosSim = min(1, max(-1, cosSim));  % clamp against float rounding
        angleDist(i,j) = acos(cosSim);
    end
end
angleDist(1:nE+1:end) = 0;              % force exact-zero diagonal
angleDist = (angleDist + angleDist') / 2;  % force exact symmetry
Z = linkage(squareform(angleDist,'tovector'), 'average');
figure('Name','Endmember dendrogram');
dendrogram(Z);
title('Hierarchical clustering of change endmembers (spectral angle)');

% Cut the tree to merge visually/spectrally similar endmembers
% (adjust maxClusters based on the dendrogram / your judgement)
maxClusters = min(3, nE);
endmemberClusterID = cluster(Z, 'maxclust', maxClusters);

%% 5. Spectral matching (SAM) to assign every changed pixel to a cluster
% Build representative spectra for each cluster = mean of its endmembers
clusterSpectra = zeros(maxClusters, B);
for c = 1:maxClusters
    clusterSpectra(c,:) = mean(endmembers(endmemberClusterID==c, :), 1);
end

% Use the documented `sam` (Spectral Angle Mapper) function directly:
% score = sam(inputData, refSpectrum) — one reference spectrum at a time,
% inputData is a plain H-by-W-by-B array, refSpectrum is a B-by-1 column
% vector. Lower score = smaller spectral angle = better match. We loop
% once per cluster to build a full H-by-W-by-maxClusters score stack.
diffCubeFull = reshape(X1n - X2n, H, W, B);
scoreMaps = zeros(H, W, maxClusters);
for c = 1:maxClusters
    refSpectrum = clusterSpectra(c, :)';   % B-by-1 column vector
    scoreMaps(:,:,c) = sam(diffCubeFull, refSpectrum);
end
% scoreMaps: H x W x maxClusters, lower SAM angle = better match

[bestScore, bestCluster] = min(scoreMaps, [], 3);  % H x W each

%% 5b. Resolve mixed/ambiguous pixels
% A pixel flagged as "changed" in Step 3 is genuinely ambiguous if it
% doesn't match ANY change-endmember cluster well (its best SAM angle is
% still large). This is the actual "resolves ambiguity at mixed pixels"
% requirement: reject those back to no-change instead of forcing every
% Step-3 pixel into its nearest cluster regardless of match quality.
scoresAtChange = bestScore(initialChangeMask);
ambigLevel = graythresh(mat2gray(scoresAtChange));      % Otsu on match quality
scoreThreshold = ambigLevel * (max(scoresAtChange) - min(scoresAtChange)) + min(scoresAtChange);

refinedChangeMask = initialChangeMask & (bestScore <= scoreThreshold);

figure('Name','Ambiguous pixels removed');
imshowpair(initialChangeMask, refinedChangeMask, 'montage');
title('Step 3 mask (left) vs after mixed-pixel resolution (right)');

% Final change map: cluster assignment kept ONLY where the pixel survived
% mixed-pixel resolution (i.e. matched some change type convincingly)
finalChangeMap = zeros(H, W);
finalChangeMap(refinedChangeMask) = bestCluster(refinedChangeMask);

figure('Name','Final change map');
imagesc(finalChangeMap); axis image off; colormap(jet(maxClusters+1)); colorbar;
title('Step 5: Final Change Detection Map (colored by change type)');

%% 6. Evaluate the binary version against ground truth
binaryFinal = finalChangeMap > 0;   % now genuinely different from Step 3
resultsFinal = evaluateChangeMap(binaryFinal, gt, [], 'Final pipeline (binary)');
resultsInit  = evaluateChangeMap(initialChangeMask, gt, magImgFilt, 'Step-3 pseudo-binary only');

figure('Name','Before vs After pipeline stages');
subplot(1,3,1); imshow(gt); title('Ground Truth');
subplot(1,3,2); imshow(initialChangeMask); title(sprintf('Step 3 only (OA=%.2f%%)', resultsInit.OA*100));
subplot(1,3,3); imshow(binaryFinal); title(sprintf('Final pipeline (OA=%.2f%%)', resultsFinal.OA*100));

fprintf('\n=== Summary ===\n');
fprintf('Step-3 pseudo-binary:  OA=%.2f%%  Kappa=%.3f  F1=%.3f\n', ...
    resultsInit.OA*100, resultsInit.Kappa, resultsInit.F1);
fprintf('Final (endmember+SAM): OA=%.2f%%  Kappa=%.3f  F1=%.3f\n', ...
    resultsFinal.OA*100, resultsFinal.Kappa, resultsFinal.F1);

%% 7. Clean overlay visualizations (change highlighted on the actual scene)
% A colored, semi-transparent overlay on the "after" false-color image
% reads far more clearly in a report than a plain black/white mask, and
% doubles as a true-vs-predicted comparison against the ground truth.

afterRGB = toRGB(after3D);   % same false-color composite used earlier

% Light morphological cleanup for DISPLAY ONLY — do not use this cleaned
% version for your reported metrics, only for the figure, since evaluation
% should reflect the raw detector output.
displayMask = imopen(binaryFinal, strel('disk', 2));   % strip thin noise/striping
displayMask = imclose(displayMask, strel('disk', 3));  % fill small gaps in real blobs
displayMask = bwareaopen(displayMask, 60);             % drop small leftover speckle

overlayFinal = labeloverlay(afterRGB, displayMask, ...
    'Colormap', [1 0 0], 'Transparency', 0.55);   % red = detected change

overlayGT = labeloverlay(afterRGB, gt, ...
    'Colormap', [0 1 1], 'Transparency', 0.55);    % cyan = ground-truth change

figure('Name','Change highlighted on scene');
subplot(1,2,1); imshow(overlayGT);    title('Ground Truth (change highlighted)');
subplot(1,2,2); imshow(overlayFinal); title('Detected Change (final pipeline)');

% Comparison overlay: green = correctly detected change, red = false
% alarm, yellow = missed change — all overlaid on the real scene.
TPmask = displayMask & gt;
FPmask = displayMask & ~gt;
FNmask = ~displayMask & gt;

comparisonOverlay = afterRGB;
comparisonOverlay = labeloverlay(comparisonOverlay, TPmask, 'Colormap', [0 1 0], 'Transparency', 0.4); % green = correct
comparisonOverlay = labeloverlay(comparisonOverlay, FPmask, 'Colormap', [1 0 0], 'Transparency', 0.4); % red = false alarm
comparisonOverlay = labeloverlay(comparisonOverlay, FNmask, 'Colormap', [1 1 0], 'Transparency', 0.4); % yellow = missed

figure('Name','Detection accuracy overlay');
imshow(comparisonOverlay);
title('Green=Correct  Red=False Alarm  Yellow=Missed');

% (PNG export removed — figures are just displayed in MATLAB, not saved
% to disk. Use File > Save As directly on a figure window if you want to
% export one manually.)

%% ================= Local functions =================

function cube = pixelsToPseudoCube(spectra, B)
    % Reshapes a P-by-B list of pixel spectra into an M-by-N-by-B array
    % with M>1 and N>1 (required by countEndmembersHFC/nfindr, which
    % reject singleton spatial dimensions). Pads by repeating existing
    % pixels if P isn't a perfect rectangle — padding with real spectra
    % (not zeros) avoids injecting a fake "all-zero" endmember.
    P = size(spectra, 1);
    rows = max(2, floor(sqrt(P)));
    cols = ceil(P / rows);
    total = rows * cols;
    if total > P
        padNeeded = total - P;
        padIdx = mod((0:padNeeded-1), P) + 1;   % wrap around if padNeeded > P
        spectra = [spectra; spectra(padIdx, :)];
    end
    cube = reshape(spectra, rows, cols, B);
end

function arr = loadMainArray(matFile)
    s = load(matFile);
    fn = fieldnames(s);
    bestName = ''; bestNumel = -1;
    for k = 1:numel(fn)
        v = s.(fn{k});
        if isnumeric(v) || islogical(v)
            if numel(v) > bestNumel
                bestNumel = numel(v);
                bestName = fn{k};
            end
        end
    end
    if isempty(bestName)
        error('No numeric array found in %s. Variables: %s', matFile, strjoin(fn, ', '));
    end
    arr = s.(bestName);
    fprintf('Loaded variable "%s" from %s\n', bestName, matFile);
end

function results = evaluateChangeMap(predMap, gtMap, ~, methodName)
    pred = logical(predMap(:));
    gt   = logical(gtMap(:));

    TP = sum(pred & gt);  TN = sum(~pred & ~gt);
    FP = sum(pred & ~gt); FN = sum(~pred & gt);

    OA = (TP + TN) / numel(gt);
    precision = TP / max(TP + FP, 1);
    recall    = TP / max(TP + FN, 1);
    F1 = 2 * precision * recall / max(precision + recall, eps);

    total = numel(gt);
    pE = ((TP+FP)*(TP+FN) + (FN+TN)*(FP+TN)) / total^2;
    kappa = (OA - pE) / (1 - pE);

    results.OA = OA; results.Precision = precision; results.Recall = recall;
    results.F1 = F1; results.Kappa = kappa;
    results.ConfusionMatrix = [TP FP; FN TN];

    fprintf('--- %s ---\n', methodName);
    disp(results.ConfusionMatrix);
    fprintf('  OA=%.4f  Precision=%.4f  Recall=%.4f  F1=%.4f  Kappa=%.4f\n\n', ...
        OA, precision, recall, F1, kappa);
end