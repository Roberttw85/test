function [bestMatch, scores] = jigsawQuickSolve(targetPath, candidatePaths)
%JIGSAWQUICKSOLVE Quick jigsaw puzzle solver for MATLAB Mobile
%   Simplified version that accepts file paths directly
%
%   Usage:
%       [bestMatch, scores] = jigsawQuickSolve(targetPath, candidatePaths)
%
%   Inputs:
%       targetPath     - Path to the target image (hole to fill)
%       candidatePaths - Cell array of paths to candidate images
%
%   Outputs:
%       bestMatch - Index of the best matching candidate (1-based)
%       scores    - Structure array with detailed scores for each candidate
%
%   Example:
%       target = 'images/hole.jpg';
%       candidates = {'images/piece1.jpg', 'images/piece2.jpg', ...
%                     'images/piece3.jpg', 'images/piece4.jpg', ...
%                     'images/piece5.jpg', 'images/piece6.jpg', ...
%                     'images/piece7.jpg', 'images/piece8.jpg', ...
%                     'images/piece9.jpg', 'images/piece10.jpg'};
%       [best, scores] = jigsawQuickSolve(target, candidates);
%       fprintf('Best match is piece #%d\n', best);

    %% Validate inputs
    if ~exist(targetPath, 'file')
        error('Target image not found: %s', targetPath);
    end

    if ~iscell(candidatePaths)
        error('candidatePaths must be a cell array of file paths');
    end

    %% Load target image
    fprintf('Loading target image...\n');
    targetImg = loadAndPreprocess(targetPath);

    %% Load and analyze candidates
    numCandidates = length(candidatePaths);
    scores = struct('index', {}, 'colorScore', {}, 'geometryScore', {}, ...
                    'totalScore', {}, 'path', {});

    fprintf('Analyzing %d candidates...\n', numCandidates);

    targetFeatures = quickExtractFeatures(targetImg);

    for i = 1:numCandidates
        if ~exist(candidatePaths{i}, 'file')
            warning('Candidate %d not found: %s', i, candidatePaths{i});
            continue;
        end

        candidateImg = loadAndPreprocess(candidatePaths{i});
        candidateFeatures = quickExtractFeatures(candidateImg);

        % Calculate scores
        colorScore = quickColorScore(targetFeatures, candidateFeatures);
        geometryScore = quickGeometryScore(targetFeatures, candidateFeatures);
        totalScore = 0.6 * colorScore + 0.4 * geometryScore;

        scores(i).index = i;
        scores(i).colorScore = colorScore;
        scores(i).geometryScore = geometryScore;
        scores(i).totalScore = totalScore;
        scores(i).path = candidatePaths{i};

        fprintf('  Candidate %d: %.1f%%\n', i, totalScore);
    end

    %% Find best match
    totalScores = [scores.totalScore];
    [~, bestMatch] = max(totalScores);

    fprintf('\n=== RESULT ===\n');
    fprintf('Best match: Candidate #%d (Score: %.1f%%)\n', bestMatch, scores(bestMatch).totalScore);
    fprintf('Path: %s\n', scores(bestMatch).path);
end

function img = loadAndPreprocess(filepath)
    img = imread(filepath);

    % Convert grayscale to RGB
    if size(img, 3) == 1
        img = cat(3, img, img, img);
    end

    % Resize to max 256px for faster mobile processing
    [h, w, ~] = size(img);
    maxSize = 256;
    if max(h, w) > maxSize
        scale = maxSize / max(h, w);
        img = imresize(img, scale);
    end
end

function features = quickExtractFeatures(img)
    % Simplified feature extraction for speed

    imgDouble = im2double(img);

    % Color histogram (16 bins)
    features.histR = imhist(img(:,:,1), 16) / numel(img(:,:,1));
    features.histG = imhist(img(:,:,2), 16) / numel(img(:,:,2));
    features.histB = imhist(img(:,:,3), 16) / numel(img(:,:,3));

    % Mean color
    features.meanColor = squeeze(mean(mean(imgDouble, 1), 2));

    % Grayscale for geometry
    imgGray = rgb2gray(img);
    imgGrayD = im2double(imgGray);

    % Edge histogram
    [Gx, Gy] = gradient(imgGrayD);
    gradMag = sqrt(Gx.^2 + Gy.^2);
    gradDir = atan2(Gy, Gx);
    mask = gradMag > 0.05;
    features.edgeHist = histcounts(gradDir(mask), linspace(-pi, pi, 9), 'Normalization', 'probability');

    % Texture: contrast and smoothness
    features.contrast = std(imgGrayD(:));
    features.smoothness = 1 - mean(gradMag(:));
end

function score = quickColorScore(f1, f2)
    % Quick color similarity

    histSim = (sum(min(f1.histR, f2.histR)) + ...
               sum(min(f1.histG, f2.histG)) + ...
               sum(min(f1.histB, f2.histB))) / 3;

    meanDist = norm(f1.meanColor - f2.meanColor);
    meanSim = max(0, 1 - meanDist / sqrt(3));

    score = 100 * (0.6 * histSim + 0.4 * meanSim);
end

function score = quickGeometryScore(f1, f2)
    % Quick geometry similarity

    edgeSim = sum(min(f1.edgeHist, f2.edgeHist));

    contrastDiff = abs(f1.contrast - f2.contrast);
    contrastSim = max(0, 1 - contrastDiff * 4);

    smoothDiff = abs(f1.smoothness - f2.smoothness);
    smoothSim = max(0, 1 - smoothDiff * 4);

    score = 100 * (0.5 * edgeSim + 0.25 * contrastSim + 0.25 * smoothSim);
end
