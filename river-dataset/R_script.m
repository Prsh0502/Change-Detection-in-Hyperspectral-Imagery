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

rgbBands = min([33 22 11], B);
toRGB = @(cube) mat2gray(cube(:,:,rgbBands));

figure('Name','False color');
subplot(1,3,1); imshow(toRGB(before3D)); title('Before');
subplot(1,3,2); imshow(toRGB(after3D));  title('After');
subplot(1,3,3); imshow(gt); title('Ground Truth');

%% 2. Calibration / correction
% Skipped — standard River release is pre-corrected.

%% 3. Pseudo-binary change detection
X1 = reshape(before3D, H*W, B);
X2 = reshape(after3D,  H*W, B);

mu  = mean([X1; X2], 1);
sig = std([X1; X2], 0, 1) + eps;
X1n = (X1 - mu) ./ sig;
X2n = (X2 - mu) ./ sig;

diffVec   = X1n - X2n;
magnitude = sqrt(sum(diffVec.^2, 2));
magImg    = reshape(magnitude, H, W);

magImgFilt = medfilt2(magImg, [5 5]);

level = graythresh(mat2gray(magImgFilt));
initialChangeMask = imbinarize(mat2gray(magImgFilt), level);
initialChangeMask = bwareaopen(initialChangeMask, 15);

figure('Name','Pseudo-binary change mask');
imshow(initialChangeMask); title('Step 3: Initial (pseudo-binary) change mask');

%% 4. Endmember extraction + hierarchical clustering
changeIdx = find(initialChangeMask(:));

diffCube = reshape(X1n - X2n, H, W, B);
diffAtChange = reshape(diffCube, H*W, B);
diffAtChange = diffAtChange(changeIdx, :);

pseudoCube = pixelsToPseudoCube(diffAtChange, B);

numEndmembers = countEndmembersHFC(pseudoCube, 'PFA', 1e-6);
numEndmembers = max(2, min(numEndmembers, 8));
fprintf('Estimated number of change endmembers: %d\n', numEndmembers);

endmembers = nfindr(pseudoCube, numEndmembers);
endmembers = endmembers';

nE = size(endmembers,1);
angleDist = zeros(nE, nE);
for i = 1:nE
    for j = 1:nE
        v1 = endmembers(i,:); v2 = endmembers(j,:);
        cosSim = dot(v1,v2) / (norm(v1)*norm(v2) + eps);
        cosSim = min(1, max(-1, cosSim));
        angleDist(i,j) = acos(cosSim);
    end
end
angleDist(1:nE+1:end) = 0;
angleDist = (angleDist + angleDist') / 2;
Z = linkage(squareform(angleDist,'tovector'), 'average');
figure('Name','Endmember dendrogram');
dendrogram(Z);
title('Hierarchical clustering of change endmembers (spectral angle)');

maxClusters = min(3, nE);
endmemberClusterID = cluster(Z, 'maxclust', maxClusters);

%% 5. Spectral matching (SAM)
clusterSpectra = zeros(maxClusters, B);
for c = 1:maxClusters
    clusterSpectra(c,:) = mean(endmembers(endmemberClusterID==c, :), 1);
end

diffCubeFull = reshape(X1n - X2n, H, W, B);
scoreMaps = zeros(H, W, maxClusters);
for c = 1:maxClusters
    refSpectrum = clusterSpectra(c, :)';
    scoreMaps(:,:,c) = sam(diffCubeFull, refSpectrum);
end

[bestScore, bestCluster] = min(scoreMaps, [], 3);

%% 5b. Resolve mixed/ambiguous pixels
scoresAtChange = bestScore(initialChangeMask);
ambigLevel = graythresh(mat2gray(scoresAtChange));
scoreThreshold = ambigLevel * (max(scoresAtChange) - min(scoresAtChange)) + min(scoresAtChange);

refinedChangeMask = initialChangeMask & (bestScore <= scoreThreshold);

figure('Name','Ambiguous pixels removed');
imshowpair(initialChangeMask, refinedChangeMask, 'montage');
title('Step 3 mask (left) vs after mixed-pixel resolution (right)');

finalChangeMap = zeros(H, W);
finalChangeMap(refinedChangeMask) = bestCluster(refinedChangeMask);

figure('Name','Final change map');
imagesc(finalChangeMap); axis image off; colormap(jet(maxClusters+1)); colorbar;
title('Step 5: Final Change Detection Map (colored by change type)');

%% 6. Evaluation
binaryFinal = finalChangeMap > 0;
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

%% 7. Overlay visualizations
afterRGB = toRGB(after3D);

displayMask = imopen(binaryFinal, strel('disk', 2));
displayMask = imclose(displayMask, strel('disk', 3));
displayMask = bwareaopen(displayMask, 60);

overlayFinal = labeloverlay(afterRGB, displayMask, 'Colormap', [1 0 0], 'Transparency', 0.55);
overlayGT = labeloverlay(afterRGB, gt, 'Colormap', [0 1 1], 'Transparency', 0.55);

figure('Name','Change highlighted on scene');
subplot(1,2,1); imshow(overlayGT);    title('Ground Truth (change highlighted)');
subplot(1,2,2); imshow(overlayFinal); title('Detected Change (final pipeline)');

TPmask = displayMask & gt;
FPmask = displayMask & ~gt;
FNmask = ~displayMask & gt;

comparisonOverlay = afterRGB;
comparisonOverlay = labeloverlay(comparisonOverlay, TPmask, 'Colormap', [0 1 0], 'Transparency', 0.4);
comparisonOverlay = labeloverlay(comparisonOverlay, FPmask, 'Colormap', [1 0 0], 'Transparency', 0.4);
comparisonOverlay = labeloverlay(comparisonOverlay, FNmask, 'Colormap', [1 1 0], 'Transparency', 0.4);

figure('Name','Detection accuracy overlay');
imshow(comparisonOverlay);
title('Green=Correct  Red=False Alarm  Yellow=Missed');

%% ================= Local functions =================

function cube = pixelsToPseudoCube(spectra, B)
    P = size(spectra, 1);
    rows = max(2, floor(sqrt(P)));
    cols = ceil(P / rows);
    total = rows * cols;
    if total > P
        padNeeded = total - P;
        padIdx = mod((0:padNeeded-1), P) + 1;
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
