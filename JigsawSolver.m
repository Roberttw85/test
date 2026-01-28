%% JIGSAW PUZZLE SOLVER - MATLAB Mobile Script
% This script helps find the best matching puzzle piece for a target hole
% by analyzing geometry and color patterns.
%
% User Flow:
%   1. Upload a "Target Image" (the empty hole in the puzzle)
%   2. Upload 10 "Candidate Images" (individual puzzle pieces)
%   3. The app analyzes and suggests the best match
%
% Compatible with MATLAB Mobile

function JigsawSolver()
    % Clear workspace and close figures
    close all;
    clc;

    % Display welcome message
    disp('===========================================');
    disp('       JIGSAW PUZZLE SOLVER');
    disp('===========================================');
    disp(' ');

    %% Step 1: Load Target Image (the hole to fill)
    disp('Step 1: Select the TARGET IMAGE (empty puzzle hole)');
    disp('-------------------------------------------');

    targetImage = loadImage('target');
    if isempty(targetImage)
        disp('Error: No target image loaded. Exiting.');
        return;
    end
    disp('Target image loaded successfully!');
    disp(' ');

    %% Step 2: Load Candidate Images (puzzle pieces)
    disp('Step 2: Select CANDIDATE IMAGES (up to 10 puzzle pieces)');
    disp('-------------------------------------------');

    numCandidates = 10;
    candidateImages = cell(1, numCandidates);
    validCandidates = 0;

    for i = 1:numCandidates
        fprintf('Loading candidate piece %d of %d...\n', i, numCandidates);
        img = loadImage(sprintf('candidate_%d', i));
        if ~isempty(img)
            validCandidates = validCandidates + 1;
            candidateImages{validCandidates} = img;
        else
            fprintf('Skipping candidate %d (no image selected)\n', i);
            % Ask if user wants to continue adding more
            if i < numCandidates
                continueLoading = input('Continue loading more candidates? (y/n): ', 's');
                if lower(continueLoading) ~= 'y'
                    break;
                end
            end
        end
    end

    if validCandidates == 0
        disp('Error: No candidate images loaded. Exiting.');
        return;
    end

    % Trim cell array to valid candidates only
    candidateImages = candidateImages(1:validCandidates);
    fprintf('\nLoaded %d candidate pieces.\n\n', validCandidates);

    %% Step 3: Analyze and Find Best Match
    disp('Step 3: Analyzing puzzle pieces...');
    disp('-------------------------------------------');

    scores = analyzePieces(targetImage, candidateImages);

    %% Step 4: Display Results
    displayResults(targetImage, candidateImages, scores);
end

%% IMAGE LOADING FUNCTION
function img = loadImage(imageName)
    % Load an image file - compatible with MATLAB Mobile
    % Returns empty if user cancels or file is invalid

    try
        % Use uigetfile for file selection (works on MATLAB Mobile)
        [filename, pathname] = uigetfile(...
            {'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff', 'Image Files (*.jpg, *.png, *.bmp, *.tif)'; ...
             '*.*', 'All Files (*.*)'}, ...
            sprintf('Select %s image', strrep(imageName, '_', ' ')));

        if isequal(filename, 0) || isequal(pathname, 0)
            img = [];
            return;
        end

        fullpath = fullfile(pathname, filename);
        img = imread(fullpath);

        % Convert to RGB if grayscale
        if size(img, 3) == 1
            img = cat(3, img, img, img);
        end

        % Resize for consistent processing (max 512 pixels on longest side)
        img = resizeImage(img, 512);

    catch ME
        fprintf('Error loading image: %s\n', ME.message);
        img = [];
    end
end

%% IMAGE RESIZE FUNCTION
function imgResized = resizeImage(img, maxSize)
    % Resize image to have maximum dimension of maxSize
    [h, w, ~] = size(img);

    if max(h, w) > maxSize
        if h > w
            newH = maxSize;
            newW = round(w * maxSize / h);
        else
            newW = maxSize;
            newH = round(h * maxSize / w);
        end
        imgResized = imresize(img, [newH, newW]);
    else
        imgResized = img;
    end
end

%% MAIN ANALYSIS FUNCTION
function scores = analyzePieces(targetImage, candidateImages)
    % Analyze all candidate pieces against the target
    % Returns a structure array with scores for each candidate

    numCandidates = length(candidateImages);
    scores = struct('index', {}, 'colorScore', {}, 'geometryScore', {}, ...
                    'totalScore', {}, 'rank', {});

    % Extract target features
    disp('Extracting target image features...');
    targetFeatures = extractFeatures(targetImage);

    % Analyze each candidate
    for i = 1:numCandidates
        fprintf('Analyzing candidate %d of %d...\n', i, numCandidates);

        candidateFeatures = extractFeatures(candidateImages{i});

        % Calculate color similarity score (0-100)
        colorScore = calculateColorSimilarity(targetFeatures, candidateFeatures);

        % Calculate geometry similarity score (0-100)
        geometryScore = calculateGeometrySimilarity(targetFeatures, candidateFeatures);

        % Combined score (weighted average)
        % Color is weighted more for jigsaw puzzles as geometry varies
        totalScore = 0.6 * colorScore + 0.4 * geometryScore;

        scores(i).index = i;
        scores(i).colorScore = colorScore;
        scores(i).geometryScore = geometryScore;
        scores(i).totalScore = totalScore;
    end

    % Rank candidates by total score
    totalScores = [scores.totalScore];
    [~, sortIdx] = sort(totalScores, 'descend');

    for rank = 1:numCandidates
        scores(sortIdx(rank)).rank = rank;
    end

    disp('Analysis complete!');
end

%% FEATURE EXTRACTION FUNCTION
function features = extractFeatures(img)
    % Extract color and geometry features from an image

    features = struct();

    % Convert to double for processing
    imgDouble = im2double(img);

    %% Color Features
    % 1. Color histogram for each channel
    numBins = 32;
    features.histR = imhist(img(:,:,1), numBins) / numel(img(:,:,1));
    features.histG = imhist(img(:,:,2), numBins) / numel(img(:,:,2));
    features.histB = imhist(img(:,:,3), numBins) / numel(img(:,:,3));

    % 2. Mean color values
    features.meanColor = squeeze(mean(mean(imgDouble, 1), 2));

    % 3. Color standard deviation
    features.stdColor = squeeze(std(std(imgDouble, 0, 1), 0, 2));

    % 4. HSV color space features
    imgHSV = rgb2hsv(img);
    features.histH = imhist(imgHSV(:,:,1), numBins) / numel(imgHSV(:,:,1));
    features.histS = imhist(imgHSV(:,:,2), numBins) / numel(imgHSV(:,:,2));
    features.histV = imhist(imgHSV(:,:,3), numBins) / numel(imgHSV(:,:,3));

    % 5. Dominant colors (using simple clustering approach)
    features.dominantColors = extractDominantColors(img, 5);

    %% Geometry Features
    % 1. Convert to grayscale for edge detection
    imgGray = rgb2gray(img);

    % 2. Edge detection using Sobel operator
    [Gx, Gy] = imgradientxy(imgGray, 'sobel');
    features.edgeMagnitude = sqrt(Gx.^2 + Gy.^2);
    features.edgeDirection = atan2(Gy, Gx);

    % 3. Edge histogram (direction distribution)
    edgeDirs = features.edgeDirection(features.edgeMagnitude > 0.1);
    features.edgeHist = histcounts(edgeDirs, linspace(-pi, pi, 17), 'Normalization', 'probability');

    % 4. Shape descriptors
    features.aspectRatio = size(img, 2) / size(img, 1);

    % 5. Texture features using local binary pattern approximation
    features.textureFeatures = extractTextureFeatures(imgGray);

    % 6. Corner detection (Harris corners approximation)
    features.cornerStrength = detectCornerStrength(imgGray);

    % 7. Contour features
    features.contourFeatures = extractContourFeatures(imgGray);
end

%% DOMINANT COLOR EXTRACTION
function dominantColors = extractDominantColors(img, k)
    % Extract k dominant colors using simple binning approach
    % (K-means alternative for MATLAB Mobile compatibility)

    % Reshape image to pixel list
    pixels = reshape(im2double(img), [], 3);

    % Quantize colors to reduce complexity
    quantized = round(pixels * 7) / 7;  % 8 levels per channel

    % Find unique colors and their frequencies
    [uniqueColors, ~, idx] = unique(quantized, 'rows');
    counts = accumarray(idx, 1);

    % Sort by frequency and get top k
    [~, sortIdx] = sort(counts, 'descend');
    numColors = min(k, length(sortIdx));

    dominantColors = zeros(k, 3);
    for i = 1:numColors
        dominantColors(i, :) = uniqueColors(sortIdx(i), :);
    end
end

%% TEXTURE FEATURE EXTRACTION
function textureFeatures = extractTextureFeatures(imgGray)
    % Extract simple texture features

    imgDouble = im2double(imgGray);

    % 1. Contrast
    textureFeatures.contrast = std(imgDouble(:))^2;

    % 2. Energy (uniformity)
    textureFeatures.energy = sum(imgDouble(:).^2) / numel(imgDouble);

    % 3. Entropy
    textureFeatures.entropy = entropy(imgGray);

    % 4. Homogeneity approximation using gradient magnitude
    [Gx, Gy] = gradient(imgDouble);
    gradMag = sqrt(Gx.^2 + Gy.^2);
    textureFeatures.smoothness = 1 - mean(gradMag(:));

    % 5. Local variance (texture roughness)
    windowSize = 5;
    localMean = imfilter(imgDouble, ones(windowSize)/windowSize^2, 'symmetric');
    localVar = imfilter(imgDouble.^2, ones(windowSize)/windowSize^2, 'symmetric') - localMean.^2;
    textureFeatures.roughness = mean(localVar(:));
end

%% CORNER STRENGTH DETECTION
function cornerStrength = detectCornerStrength(imgGray)
    % Simple corner detection using gradient analysis

    imgDouble = im2double(imgGray);

    % Calculate gradients
    [Ix, Iy] = gradient(imgDouble);

    % Gaussian window
    windowSize = 5;
    sigma = 1.5;
    [x, y] = meshgrid(-floor(windowSize/2):floor(windowSize/2));
    gaussWin = exp(-(x.^2 + y.^2) / (2*sigma^2));
    gaussWin = gaussWin / sum(gaussWin(:));

    % Structure tensor components
    Ix2 = imfilter(Ix.^2, gaussWin, 'symmetric');
    Iy2 = imfilter(Iy.^2, gaussWin, 'symmetric');
    Ixy = imfilter(Ix.*Iy, gaussWin, 'symmetric');

    % Harris corner response
    k = 0.04;
    detM = Ix2.*Iy2 - Ixy.^2;
    traceM = Ix2 + Iy2;
    R = detM - k * traceM.^2;

    % Return total corner strength
    cornerStrength = sum(max(R(:), 0));
end

%% CONTOUR FEATURE EXTRACTION
function contourFeatures = extractContourFeatures(imgGray)
    % Extract features from image contours/edges

    % Edge detection
    edges = edge(imgGray, 'canny');

    % Contour density
    contourFeatures.density = sum(edges(:)) / numel(edges);

    % Edge pixel locations for shape analysis
    [edgeY, edgeX] = find(edges);

    if ~isempty(edgeX)
        % Centroid of edge pixels
        contourFeatures.centroidX = mean(edgeX) / size(edges, 2);
        contourFeatures.centroidY = mean(edgeY) / size(edges, 1);

        % Spread of edges
        contourFeatures.spreadX = std(edgeX) / size(edges, 2);
        contourFeatures.spreadY = std(edgeY) / size(edges, 1);

        % Edge distribution in quadrants
        midX = size(edges, 2) / 2;
        midY = size(edges, 1) / 2;
        contourFeatures.quadrantDist = [
            sum(edgeX <= midX & edgeY <= midY), ...
            sum(edgeX > midX & edgeY <= midY), ...
            sum(edgeX <= midX & edgeY > midY), ...
            sum(edgeX > midX & edgeY > midY)
        ] / length(edgeX);
    else
        contourFeatures.centroidX = 0.5;
        contourFeatures.centroidY = 0.5;
        contourFeatures.spreadX = 0;
        contourFeatures.spreadY = 0;
        contourFeatures.quadrantDist = [0.25, 0.25, 0.25, 0.25];
    end
end

%% COLOR SIMILARITY CALCULATION
function score = calculateColorSimilarity(targetFeatures, candidateFeatures)
    % Calculate color similarity score (0-100)

    % 1. Histogram intersection for RGB channels
    histSimR = sum(min(targetFeatures.histR, candidateFeatures.histR));
    histSimG = sum(min(targetFeatures.histG, candidateFeatures.histG));
    histSimB = sum(min(targetFeatures.histB, candidateFeatures.histB));
    rgbHistSim = (histSimR + histSimG + histSimB) / 3;

    % 2. Histogram intersection for HSV channels
    histSimH = sum(min(targetFeatures.histH, candidateFeatures.histH));
    histSimS = sum(min(targetFeatures.histS, candidateFeatures.histS));
    histSimV = sum(min(targetFeatures.histV, candidateFeatures.histV));
    hsvHistSim = (histSimH + histSimS + histSimV) / 3;

    % 3. Mean color distance
    meanColorDist = norm(targetFeatures.meanColor - candidateFeatures.meanColor);
    meanColorSim = max(0, 1 - meanColorDist / sqrt(3));  % Normalize by max possible distance

    % 4. Dominant color similarity
    domColorSim = calculateDominantColorSimilarity(...
        targetFeatures.dominantColors, candidateFeatures.dominantColors);

    % 5. Color variance similarity
    stdDiff = abs(targetFeatures.stdColor - candidateFeatures.stdColor);
    stdSim = max(0, 1 - mean(stdDiff));

    % Weighted combination
    score = 100 * (0.25 * rgbHistSim + 0.20 * hsvHistSim + ...
                   0.25 * meanColorSim + 0.20 * domColorSim + 0.10 * stdSim);
end

%% DOMINANT COLOR SIMILARITY
function similarity = calculateDominantColorSimilarity(colors1, colors2)
    % Calculate similarity between two sets of dominant colors

    totalSim = 0;
    for i = 1:size(colors1, 1)
        % Find best matching color in colors2
        minDist = inf;
        for j = 1:size(colors2, 1)
            dist = norm(colors1(i,:) - colors2(j,:));
            minDist = min(minDist, dist);
        end
        % Convert distance to similarity (max distance is sqrt(3))
        totalSim = totalSim + max(0, 1 - minDist / sqrt(3));
    end

    similarity = totalSim / size(colors1, 1);
end

%% GEOMETRY SIMILARITY CALCULATION
function score = calculateGeometrySimilarity(targetFeatures, candidateFeatures)
    % Calculate geometry similarity score (0-100)

    % 1. Edge direction histogram similarity
    edgeHistSim = sum(min(targetFeatures.edgeHist, candidateFeatures.edgeHist));

    % 2. Texture similarity
    textureSim = calculateTextureSimilarity(...
        targetFeatures.textureFeatures, candidateFeatures.textureFeatures);

    % 3. Aspect ratio similarity
    arDiff = abs(targetFeatures.aspectRatio - candidateFeatures.aspectRatio);
    arSim = max(0, 1 - arDiff / 2);  % Allow up to 2:1 ratio difference

    % 4. Corner strength similarity (normalized)
    maxCorner = max(targetFeatures.cornerStrength, candidateFeatures.cornerStrength);
    if maxCorner > 0
        cornerSim = 1 - abs(targetFeatures.cornerStrength - candidateFeatures.cornerStrength) / maxCorner;
    else
        cornerSim = 1;
    end

    % 5. Contour similarity
    contourSim = calculateContourSimilarity(...
        targetFeatures.contourFeatures, candidateFeatures.contourFeatures);

    % Weighted combination
    score = 100 * (0.25 * edgeHistSim + 0.25 * textureSim + ...
                   0.15 * arSim + 0.15 * cornerSim + 0.20 * contourSim);
end

%% TEXTURE SIMILARITY CALCULATION
function similarity = calculateTextureSimilarity(tex1, tex2)
    % Calculate similarity between texture features

    % Normalize and compare each feature
    features = {'contrast', 'energy', 'entropy', 'smoothness', 'roughness'};
    totalSim = 0;

    for i = 1:length(features)
        f = features{i};
        maxVal = max(tex1.(f), tex2.(f));
        if maxVal > 0
            sim = 1 - abs(tex1.(f) - tex2.(f)) / maxVal;
        else
            sim = 1;
        end
        totalSim = totalSim + sim;
    end

    similarity = totalSim / length(features);
end

%% CONTOUR SIMILARITY CALCULATION
function similarity = calculateContourSimilarity(cont1, cont2)
    % Calculate similarity between contour features

    % Density similarity
    densitySim = 1 - abs(cont1.density - cont2.density);

    % Centroid similarity
    centroidDist = sqrt((cont1.centroidX - cont2.centroidX)^2 + ...
                        (cont1.centroidY - cont2.centroidY)^2);
    centroidSim = max(0, 1 - centroidDist);

    % Spread similarity
    spreadDiff = sqrt((cont1.spreadX - cont2.spreadX)^2 + ...
                      (cont1.spreadY - cont2.spreadY)^2);
    spreadSim = max(0, 1 - spreadDiff * 2);

    % Quadrant distribution similarity
    quadSim = 1 - sum(abs(cont1.quadrantDist - cont2.quadrantDist)) / 2;

    similarity = 0.2 * densitySim + 0.3 * centroidSim + 0.2 * spreadSim + 0.3 * quadSim;
end

%% DISPLAY RESULTS FUNCTION
function displayResults(targetImage, candidateImages, scores)
    % Display analysis results with visual comparison

    disp(' ');
    disp('===========================================');
    disp('             RESULTS');
    disp('===========================================');
    disp(' ');

    % Sort by rank
    [~, sortIdx] = sort([scores.rank]);

    % Display text results
    fprintf('%-6s %-15s %-15s %-15s\n', 'Rank', 'Color Score', 'Geometry Score', 'Total Score');
    disp('-----------------------------------------------------------');

    for i = 1:length(scores)
        idx = sortIdx(i);
        fprintf('%-6d %-15.2f %-15.2f %-15.2f\n', ...
            scores(idx).rank, scores(idx).colorScore, ...
            scores(idx).geometryScore, scores(idx).totalScore);
    end

    disp(' ');

    % Identify best match
    bestIdx = sortIdx(1);
    fprintf('BEST MATCH: Candidate #%d (Score: %.2f)\n', ...
        scores(bestIdx).index, scores(bestIdx).totalScore);

    % Confidence assessment
    if length(scores) > 1
        secondBestIdx = sortIdx(2);
        scoreDiff = scores(bestIdx).totalScore - scores(secondBestIdx).totalScore;

        if scoreDiff > 15
            confidence = 'HIGH';
        elseif scoreDiff > 5
            confidence = 'MEDIUM';
        else
            confidence = 'LOW';
        end

        fprintf('Confidence: %s (%.2f points ahead of 2nd place)\n', confidence, scoreDiff);
    end

    disp(' ');

    %% Visual Display
    try
        % Create figure for visual comparison
        figure('Name', 'Jigsaw Solver Results', 'NumberTitle', 'off');

        numCandidates = length(candidateImages);
        numCols = min(4, numCandidates + 1);
        numRows = ceil((numCandidates + 1) / numCols);

        % Display target image
        subplot(numRows, numCols, 1);
        imshow(targetImage);
        title('TARGET (Hole)', 'FontWeight', 'bold', 'Color', 'blue');

        % Display candidates in ranked order
        for i = 1:numCandidates
            idx = sortIdx(i);
            subplot(numRows, numCols, i + 1);
            imshow(candidateImages{scores(idx).index});

            if i == 1
                titleColor = 'green';
                titleStr = sprintf('#%d BEST (%.1f)', scores(idx).index, scores(idx).totalScore);
            else
                titleColor = 'black';
                titleStr = sprintf('#%d (%.1f)', scores(idx).index, scores(idx).totalScore);
            end

            title(titleStr, 'FontWeight', 'bold', 'Color', titleColor);
        end

        % Adjust figure size
        set(gcf, 'Position', [100, 100, 300*numCols, 300*numRows]);

    catch ME
        disp('Note: Could not display visual results.');
        disp(['Reason: ' ME.message]);
    end

    %% Detailed Analysis for Best Match
    disp('-------------------------------------------');
    disp('DETAILED ANALYSIS OF BEST MATCH:');
    disp('-------------------------------------------');
    fprintf('Color Score Breakdown:\n');
    fprintf('  - Overall color match: %.2f%%\n', scores(bestIdx).colorScore);
    fprintf('Geometry Score Breakdown:\n');
    fprintf('  - Overall shape match: %.2f%%\n', scores(bestIdx).geometryScore);
    fprintf('Combined Score: %.2f%%\n', scores(bestIdx).totalScore);

    disp(' ');
    disp('===========================================');
    disp('Analysis complete! Thank you for using');
    disp('       JIGSAW PUZZLE SOLVER');
    disp('===========================================');
end
