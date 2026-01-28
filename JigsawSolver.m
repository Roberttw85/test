%% JIGSAW PUZZLE SOLVER - MATLAB Mobile Script
% This script helps find the best matching puzzle piece for a target hole
% by analyzing geometry and color patterns.
%
% User Flow:
%   1. Upload a "Target Image" (the empty hole in the puzzle)
%   2. Upload up to 10 "Candidate Images" (photos with multiple puzzle pieces each)
%   3. The app detects individual pieces, analyzes them, and suggests the best match
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
    disp('Each candidate photo can contain multiple pieces!');
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

    %% Step 2: Load Candidate Images (photos containing puzzle pieces)
    disp('Step 2: Select CANDIDATE IMAGES (photos with puzzle pieces)');
    disp('         Each photo can contain multiple pieces!');
    disp('-------------------------------------------');

    maxPhotos = 10;
    candidatePhotos = cell(1, maxPhotos);
    validPhotos = 0;

    for i = 1:maxPhotos
        fprintf('Loading photo %d of %d...\n', i, maxPhotos);
        img = loadImage(sprintf('photo_%d', i));
        if ~isempty(img)
            validPhotos = validPhotos + 1;
            candidatePhotos{validPhotos} = img;
        else
            fprintf('Skipping photo %d (no image selected)\n', i);
            if i < maxPhotos
                continueLoading = input('Continue loading more photos? (y/n): ', 's');
                if lower(continueLoading) ~= 'y'
                    break;
                end
            end
        end
    end

    if validPhotos == 0
        disp('Error: No candidate photos loaded. Exiting.');
        return;
    end

    candidatePhotos = candidatePhotos(1:validPhotos);
    fprintf('\nLoaded %d photos.\n\n', validPhotos);

    %% Step 3: Detect and Extract Individual Pieces from Each Photo
    disp('Step 3: Detecting puzzle pieces in each photo...');
    disp('-------------------------------------------');

    allPieces = {};  % Will store all extracted pieces
    pieceInfo = [];  % Track which photo each piece came from

    for photoIdx = 1:validPhotos
        fprintf('Processing photo %d...\n', photoIdx);
        [pieces, boundingBoxes] = detectPieces(candidatePhotos{photoIdx});

        numPieces = length(pieces);
        fprintf('  Found %d pieces in photo %d\n', numPieces, photoIdx);

        for p = 1:numPieces
            allPieces{end+1} = pieces{p};
            pieceInfo(end+1).photoIndex = photoIdx;
            pieceInfo(end).pieceIndex = p;
            pieceInfo(end).boundingBox = boundingBoxes{p};
            pieceInfo(end).sourcePhoto = candidatePhotos{photoIdx};
        end
    end

    totalPieces = length(allPieces);
    fprintf('\nTotal pieces detected: %d\n\n', totalPieces);

    if totalPieces == 0
        disp('Error: No pieces detected. Try adjusting detection settings.');
        return;
    end

    %% Step 4: Analyze and Find Best Match
    disp('Step 4: Analyzing puzzle pieces...');
    disp('-------------------------------------------');

    scores = analyzePieces(targetImage, allPieces, pieceInfo);

    %% Step 5: Display Results
    displayResults(targetImage, allPieces, pieceInfo, candidatePhotos, scores);
end

%% IMAGE LOADING FUNCTION
function img = loadImage(imageName)
    try
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

        if size(img, 3) == 1
            img = cat(3, img, img, img);
        end

        img = resizeImage(img, 1024);  % Larger size for piece detection

    catch ME
        fprintf('Error loading image: %s\n', ME.message);
        img = [];
    end
end

%% IMAGE RESIZE FUNCTION
function imgResized = resizeImage(img, maxSize)
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

%% PIECE DETECTION FUNCTION
function [pieces, boundingBoxes] = detectPieces(img)
    % Detect and extract individual puzzle pieces from an image
    % Uses color-based segmentation and connected component analysis

    pieces = {};
    boundingBoxes = {};

    [h, w, ~] = size(img);

    % Convert to different color spaces for robust segmentation
    imgDouble = im2double(img);
    imgGray = rgb2gray(img);
    imgHSV = rgb2hsv(img);

    %% Method 1: Background detection and foreground extraction
    % Assume pieces are on a relatively uniform background

    % Detect background color (sample from corners)
    cornerSize = round(min(h, w) * 0.05);
    corners = [
        imgDouble(1:cornerSize, 1:cornerSize, :);
        imgDouble(1:cornerSize, end-cornerSize+1:end, :);
        imgDouble(end-cornerSize+1:end, 1:cornerSize, :);
        imgDouble(end-cornerSize+1:end, end-cornerSize+1:end, :)
    ];
    bgColor = squeeze(mean(reshape(corners, [], 3), 1));

    % Calculate color distance from background
    colorDist = sqrt(sum((imgDouble - reshape(bgColor, 1, 1, 3)).^2, 3));

    % Threshold to find foreground (pieces)
    threshold = max(0.15, graythresh(colorDist) * 0.8);
    foregroundMask = colorDist > threshold;

    %% Method 2: Edge-based refinement
    edges = edge(imgGray, 'canny', [0.05 0.15]);
    dilatedEdges = imdilate(edges, strel('disk', 2));

    % Combine methods
    combinedMask = foregroundMask | dilatedEdges;

    %% Clean up mask
    % Fill holes
    combinedMask = imfill(combinedMask, 'holes');

    % Remove small noise
    minPieceArea = round(h * w * 0.005);  % Min 0.5% of image area
    combinedMask = bwareaopen(combinedMask, minPieceArea);

    % Close small gaps
    combinedMask = imclose(combinedMask, strel('disk', 5));

    % Erode then dilate to separate touching pieces
    combinedMask = imerode(combinedMask, strel('disk', 3));
    combinedMask = imdilate(combinedMask, strel('disk', 3));

    %% Find connected components (individual pieces)
    CC = bwconncomp(combinedMask);
    stats = regionprops(CC, 'BoundingBox', 'Area', 'Centroid', 'PixelIdxList');

    % Filter by size - pieces should be reasonably sized
    maxPieceArea = round(h * w * 0.5);  % Max 50% of image area

    for i = 1:length(stats)
        area = stats(i).Area;

        % Skip if too small or too large
        if area < minPieceArea || area > maxPieceArea
            continue;
        end

        % Get bounding box
        bbox = stats(i).BoundingBox;
        x = max(1, floor(bbox(1)));
        y = max(1, floor(bbox(2)));
        bw = min(w - x, ceil(bbox(3)));
        bh = min(h - y, ceil(bbox(4)));

        % Skip very elongated shapes (probably not puzzle pieces)
        aspectRatio = max(bw, bh) / max(1, min(bw, bh));
        if aspectRatio > 5
            continue;
        end

        % Extract piece with padding
        padding = 5;
        x1 = max(1, x - padding);
        y1 = max(1, y - padding);
        x2 = min(w, x + bw + padding);
        y2 = min(h, y + bh + padding);

        pieceImg = img(y1:y2, x1:x2, :);

        % Create mask for this piece only
        pieceMask = false(h, w);
        pieceMask(stats(i).PixelIdxList) = true;
        pieceMaskCropped = pieceMask(y1:y2, x1:x2);

        % Apply mask to remove background within bounding box
        pieceImg = applyMask(pieceImg, pieceMaskCropped);

        % Resize piece for consistent analysis
        pieceImg = resizeImage(pieceImg, 256);

        pieces{end+1} = pieceImg;
        boundingBoxes{end+1} = [x1, y1, x2-x1, y2-y1];
    end

    % If no pieces found, try alternative detection
    if isempty(pieces)
        fprintf('  Trying alternative detection method...\n');
        [pieces, boundingBoxes] = detectPiecesAlternative(img);
    end
end

%% ALTERNATIVE PIECE DETECTION
function [pieces, boundingBoxes] = detectPiecesAlternative(img)
    % Alternative detection using saturation-based segmentation
    pieces = {};
    boundingBoxes = {};

    [h, w, ~] = size(img);
    imgHSV = rgb2hsv(img);

    % Use saturation channel - pieces usually more saturated than background
    saturation = imgHSV(:,:,2);
    value = imgHSV(:,:,3);

    % Combine saturation and value
    combined = saturation .* 0.7 + (1 - value) .* 0.3;

    % Adaptive thresholding
    threshold = graythresh(combined);
    mask = combined > threshold * 0.5;

    % Alternative: use variance-based detection
    windowSize = 15;
    localVar = stdfilt(rgb2gray(img), ones(windowSize));
    varMask = localVar > graythresh(localVar) * 0.3;

    % Combine approaches
    finalMask = mask | varMask;
    finalMask = imfill(finalMask, 'holes');

    minPieceArea = round(h * w * 0.01);
    finalMask = bwareaopen(finalMask, minPieceArea);
    finalMask = imclose(finalMask, strel('disk', 8));

    CC = bwconncomp(finalMask);
    stats = regionprops(CC, 'BoundingBox', 'Area', 'PixelIdxList');

    maxPieceArea = round(h * w * 0.5);

    for i = 1:length(stats)
        area = stats(i).Area;
        if area < minPieceArea || area > maxPieceArea
            continue;
        end

        bbox = stats(i).BoundingBox;
        x = max(1, floor(bbox(1)));
        y = max(1, floor(bbox(2)));
        bw = min(w - x, ceil(bbox(3)));
        bh = min(h - y, ceil(bbox(4)));

        aspectRatio = max(bw, bh) / max(1, min(bw, bh));
        if aspectRatio > 5
            continue;
        end

        padding = 5;
        x1 = max(1, x - padding);
        y1 = max(1, y - padding);
        x2 = min(w, x + bw + padding);
        y2 = min(h, y + bh + padding);

        pieceImg = img(y1:y2, x1:x2, :);

        pieceMask = false(h, w);
        pieceMask(stats(i).PixelIdxList) = true;
        pieceMaskCropped = pieceMask(y1:y2, x1:x2);

        pieceImg = applyMask(pieceImg, pieceMaskCropped);
        pieceImg = resizeImage(pieceImg, 256);

        pieces{end+1} = pieceImg;
        boundingBoxes{end+1} = [x1, y1, x2-x1, y2-y1];
    end
end

%% APPLY MASK TO IMAGE
function maskedImg = applyMask(img, mask)
    % Apply binary mask to image, setting background to white
    maskedImg = img;
    for c = 1:size(img, 3)
        channel = maskedImg(:,:,c);
        channel(~mask) = 255;  % White background
        maskedImg(:,:,c) = channel;
    end
end

%% MAIN ANALYSIS FUNCTION
function scores = analyzePieces(targetImage, pieces, pieceInfo)
    numPieces = length(pieces);
    scores = struct('pieceIndex', {}, 'photoIndex', {}, 'colorScore', {}, ...
                    'geometryScore', {}, 'totalScore', {}, 'rank', {});

    disp('Extracting target image features...');
    targetFeatures = extractFeatures(targetImage);

    for i = 1:numPieces
        fprintf('Analyzing piece %d of %d (from photo %d)...\n', ...
            i, numPieces, pieceInfo(i).photoIndex);

        candidateFeatures = extractFeatures(pieces{i});

        colorScore = calculateColorSimilarity(targetFeatures, candidateFeatures);
        geometryScore = calculateGeometrySimilarity(targetFeatures, candidateFeatures);
        totalScore = 0.6 * colorScore + 0.4 * geometryScore;

        scores(i).pieceIndex = i;
        scores(i).photoIndex = pieceInfo(i).photoIndex;
        scores(i).localPieceIndex = pieceInfo(i).pieceIndex;
        scores(i).colorScore = colorScore;
        scores(i).geometryScore = geometryScore;
        scores(i).totalScore = totalScore;
    end

    % Rank pieces
    totalScores = [scores.totalScore];
    [~, sortIdx] = sort(totalScores, 'descend');

    for rank = 1:numPieces
        scores(sortIdx(rank)).rank = rank;
    end

    disp('Analysis complete!');
end

%% FEATURE EXTRACTION FUNCTION
function features = extractFeatures(img)
    features = struct();
    imgDouble = im2double(img);

    % Detect and exclude white background pixels
    whiteMask = all(imgDouble > 0.95, 3);
    validMask = ~whiteMask;

    %% Color Features (excluding background)
    numBins = 32;

    % Extract valid pixels only
    validPixelsR = img(:,:,1);
    validPixelsG = img(:,:,2);
    validPixelsB = img(:,:,3);

    if sum(validMask(:)) > 100
        features.histR = histcounts(validPixelsR(validMask), 0:256/numBins:256, 'Normalization', 'probability')';
        features.histG = histcounts(validPixelsG(validMask), 0:256/numBins:256, 'Normalization', 'probability')';
        features.histB = histcounts(validPixelsB(validMask), 0:256/numBins:256, 'Normalization', 'probability')';
    else
        features.histR = imhist(img(:,:,1), numBins) / numel(img(:,:,1));
        features.histG = imhist(img(:,:,2), numBins) / numel(img(:,:,2));
        features.histB = imhist(img(:,:,3), numBins) / numel(img(:,:,3));
    end

    % Mean color (excluding background)
    validDouble = imgDouble;
    for c = 1:3
        ch = validDouble(:,:,c);
        if sum(validMask(:)) > 100
            features.meanColor(c) = mean(ch(validMask));
            features.stdColor(c) = std(ch(validMask));
        else
            features.meanColor(c) = mean(ch(:));
            features.stdColor(c) = std(ch(:));
        end
    end

    % HSV features
    imgHSV = rgb2hsv(img);
    if sum(validMask(:)) > 100
        features.histH = histcounts(imgHSV(:,:,1), linspace(0,1,numBins+1), 'Normalization', 'probability')';
        features.histS = histcounts(imgHSV(:,:,2), linspace(0,1,numBins+1), 'Normalization', 'probability')';
        features.histV = histcounts(imgHSV(:,:,3), linspace(0,1,numBins+1), 'Normalization', 'probability')';
    else
        features.histH = imhist(imgHSV(:,:,1), numBins) / numel(imgHSV(:,:,1));
        features.histS = imhist(imgHSV(:,:,2), numBins) / numel(imgHSV(:,:,2));
        features.histV = imhist(imgHSV(:,:,3), numBins) / numel(imgHSV(:,:,3));
    end

    features.dominantColors = extractDominantColors(img, validMask, 5);

    %% Geometry Features
    imgGray = rgb2gray(img);
    [Gx, Gy] = imgradientxy(imgGray, 'sobel');
    features.edgeMagnitude = sqrt(Gx.^2 + Gy.^2);
    features.edgeDirection = atan2(Gy, Gx);

    edgeDirs = features.edgeDirection(features.edgeMagnitude > 0.1);
    if ~isempty(edgeDirs)
        features.edgeHist = histcounts(edgeDirs, linspace(-pi, pi, 17), 'Normalization', 'probability');
    else
        features.edgeHist = zeros(1, 16);
    end

    features.aspectRatio = size(img, 2) / size(img, 1);
    features.textureFeatures = extractTextureFeatures(imgGray);
    features.cornerStrength = detectCornerStrength(imgGray);
    features.contourFeatures = extractContourFeatures(imgGray);
end

%% DOMINANT COLOR EXTRACTION
function dominantColors = extractDominantColors(img, validMask, k)
    imgDouble = im2double(img);
    pixels = reshape(imgDouble, [], 3);
    maskFlat = validMask(:);

    if sum(maskFlat) > 100
        pixels = pixels(maskFlat, :);
    end

    quantized = round(pixels * 7) / 7;
    [uniqueColors, ~, idx] = unique(quantized, 'rows');
    counts = accumarray(idx, 1);

    [~, sortIdx] = sort(counts, 'descend');
    numColors = min(k, length(sortIdx));

    dominantColors = zeros(k, 3);
    for i = 1:numColors
        dominantColors(i, :) = uniqueColors(sortIdx(i), :);
    end
end

%% TEXTURE FEATURE EXTRACTION
function textureFeatures = extractTextureFeatures(imgGray)
    imgDouble = im2double(imgGray);

    textureFeatures.contrast = std(imgDouble(:))^2;
    textureFeatures.energy = sum(imgDouble(:).^2) / numel(imgDouble);
    textureFeatures.entropy = entropy(imgGray);

    [Gx, Gy] = gradient(imgDouble);
    gradMag = sqrt(Gx.^2 + Gy.^2);
    textureFeatures.smoothness = 1 - mean(gradMag(:));

    windowSize = 5;
    localMean = imfilter(imgDouble, ones(windowSize)/windowSize^2, 'symmetric');
    localVar = imfilter(imgDouble.^2, ones(windowSize)/windowSize^2, 'symmetric') - localMean.^2;
    textureFeatures.roughness = mean(localVar(:));
end

%% CORNER STRENGTH DETECTION
function cornerStrength = detectCornerStrength(imgGray)
    imgDouble = im2double(imgGray);
    [Ix, Iy] = gradient(imgDouble);

    windowSize = 5;
    sigma = 1.5;
    [x, y] = meshgrid(-floor(windowSize/2):floor(windowSize/2));
    gaussWin = exp(-(x.^2 + y.^2) / (2*sigma^2));
    gaussWin = gaussWin / sum(gaussWin(:));

    Ix2 = imfilter(Ix.^2, gaussWin, 'symmetric');
    Iy2 = imfilter(Iy.^2, gaussWin, 'symmetric');
    Ixy = imfilter(Ix.*Iy, gaussWin, 'symmetric');

    k = 0.04;
    detM = Ix2.*Iy2 - Ixy.^2;
    traceM = Ix2 + Iy2;
    R = detM - k * traceM.^2;

    cornerStrength = sum(max(R(:), 0));
end

%% CONTOUR FEATURE EXTRACTION
function contourFeatures = extractContourFeatures(imgGray)
    edges = edge(imgGray, 'canny');
    contourFeatures.density = sum(edges(:)) / numel(edges);

    [edgeY, edgeX] = find(edges);

    if ~isempty(edgeX)
        contourFeatures.centroidX = mean(edgeX) / size(edges, 2);
        contourFeatures.centroidY = mean(edgeY) / size(edges, 1);
        contourFeatures.spreadX = std(edgeX) / size(edges, 2);
        contourFeatures.spreadY = std(edgeY) / size(edges, 1);

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
    histSimR = sum(min(targetFeatures.histR, candidateFeatures.histR));
    histSimG = sum(min(targetFeatures.histG, candidateFeatures.histG));
    histSimB = sum(min(targetFeatures.histB, candidateFeatures.histB));
    rgbHistSim = (histSimR + histSimG + histSimB) / 3;

    histSimH = sum(min(targetFeatures.histH, candidateFeatures.histH));
    histSimS = sum(min(targetFeatures.histS, candidateFeatures.histS));
    histSimV = sum(min(targetFeatures.histV, candidateFeatures.histV));
    hsvHistSim = (histSimH + histSimS + histSimV) / 3;

    meanColorDist = norm(targetFeatures.meanColor - candidateFeatures.meanColor);
    meanColorSim = max(0, 1 - meanColorDist / sqrt(3));

    domColorSim = calculateDominantColorSimilarity(...
        targetFeatures.dominantColors, candidateFeatures.dominantColors);

    stdDiff = abs(targetFeatures.stdColor - candidateFeatures.stdColor);
    stdSim = max(0, 1 - mean(stdDiff));

    score = 100 * (0.25 * rgbHistSim + 0.20 * hsvHistSim + ...
                   0.25 * meanColorSim + 0.20 * domColorSim + 0.10 * stdSim);
end

%% DOMINANT COLOR SIMILARITY
function similarity = calculateDominantColorSimilarity(colors1, colors2)
    totalSim = 0;
    for i = 1:size(colors1, 1)
        minDist = inf;
        for j = 1:size(colors2, 1)
            dist = norm(colors1(i,:) - colors2(j,:));
            minDist = min(minDist, dist);
        end
        totalSim = totalSim + max(0, 1 - minDist / sqrt(3));
    end
    similarity = totalSim / size(colors1, 1);
end

%% GEOMETRY SIMILARITY CALCULATION
function score = calculateGeometrySimilarity(targetFeatures, candidateFeatures)
    edgeHistSim = sum(min(targetFeatures.edgeHist, candidateFeatures.edgeHist));

    textureSim = calculateTextureSimilarity(...
        targetFeatures.textureFeatures, candidateFeatures.textureFeatures);

    arDiff = abs(targetFeatures.aspectRatio - candidateFeatures.aspectRatio);
    arSim = max(0, 1 - arDiff / 2);

    maxCorner = max(targetFeatures.cornerStrength, candidateFeatures.cornerStrength);
    if maxCorner > 0
        cornerSim = 1 - abs(targetFeatures.cornerStrength - candidateFeatures.cornerStrength) / maxCorner;
    else
        cornerSim = 1;
    end

    contourSim = calculateContourSimilarity(...
        targetFeatures.contourFeatures, candidateFeatures.contourFeatures);

    score = 100 * (0.25 * edgeHistSim + 0.25 * textureSim + ...
                   0.15 * arSim + 0.15 * cornerSim + 0.20 * contourSim);
end

%% TEXTURE SIMILARITY CALCULATION
function similarity = calculateTextureSimilarity(tex1, tex2)
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
    densitySim = 1 - abs(cont1.density - cont2.density);

    centroidDist = sqrt((cont1.centroidX - cont2.centroidX)^2 + ...
                        (cont1.centroidY - cont2.centroidY)^2);
    centroidSim = max(0, 1 - centroidDist);

    spreadDiff = sqrt((cont1.spreadX - cont2.spreadX)^2 + ...
                      (cont1.spreadY - cont2.spreadY)^2);
    spreadSim = max(0, 1 - spreadDiff * 2);

    quadSim = 1 - sum(abs(cont1.quadrantDist - cont2.quadrantDist)) / 2;

    similarity = 0.2 * densitySim + 0.3 * centroidSim + 0.2 * spreadSim + 0.3 * quadSim;
end

%% DISPLAY RESULTS FUNCTION
function displayResults(targetImage, pieces, pieceInfo, candidatePhotos, scores)
    disp(' ');
    disp('===========================================');
    disp('             RESULTS');
    disp('===========================================');
    disp(' ');

    [~, sortIdx] = sort([scores.rank]);

    fprintf('%-6s %-10s %-10s %-12s %-12s %-12s\n', ...
        'Rank', 'Photo#', 'Piece#', 'Color', 'Geometry', 'Total');
    disp('---------------------------------------------------------------------');

    numDisplay = min(10, length(scores));
    for i = 1:numDisplay
        idx = sortIdx(i);
        fprintf('%-6d %-10d %-10d %-12.2f %-12.2f %-12.2f\n', ...
            scores(idx).rank, scores(idx).photoIndex, scores(idx).localPieceIndex, ...
            scores(idx).colorScore, scores(idx).geometryScore, scores(idx).totalScore);
    end

    disp(' ');

    % Best match info
    bestIdx = sortIdx(1);
    fprintf('============================================\n');
    fprintf('BEST MATCH FOUND!\n');
    fprintf('============================================\n');
    fprintf('  Photo:  #%d\n', scores(bestIdx).photoIndex);
    fprintf('  Piece:  #%d (in that photo)\n', scores(bestIdx).localPieceIndex);
    fprintf('  Score:  %.2f%%\n', scores(bestIdx).totalScore);

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

        fprintf('  Confidence: %s (%.2f points ahead)\n', confidence, scoreDiff);
    end

    disp(' ');

    %% Visual Display
    try
        % Figure 1: Best match comparison
        figure('Name', 'Best Match', 'NumberTitle', 'off');

        subplot(1, 3, 1);
        imshow(targetImage);
        title('TARGET (Hole to Fill)', 'FontWeight', 'bold', 'Color', 'blue', 'FontSize', 12);

        subplot(1, 3, 2);
        imshow(pieces{scores(bestIdx).pieceIndex});
        title(sprintf('BEST MATCH\nPhoto %d, Piece %d\nScore: %.1f%%', ...
            scores(bestIdx).photoIndex, scores(bestIdx).localPieceIndex, ...
            scores(bestIdx).totalScore), 'FontWeight', 'bold', 'Color', 'green', 'FontSize', 11);

        subplot(1, 3, 3);
        sourcePhoto = candidatePhotos{scores(bestIdx).photoIndex};
        imshow(sourcePhoto);
        hold on;
        bbox = pieceInfo(scores(bestIdx).pieceIndex).boundingBox;
        rectangle('Position', bbox, 'EdgeColor', 'green', 'LineWidth', 3);
        title('Source Photo (piece highlighted)', 'FontWeight', 'bold', 'FontSize', 11);
        hold off;

        set(gcf, 'Position', [50, 300, 1200, 400]);

        % Figure 2: Top candidates
        figure('Name', 'Top Candidates', 'NumberTitle', 'off');

        subplot(2, 6, 1:2);
        imshow(targetImage);
        title('TARGET', 'FontWeight', 'bold', 'Color', 'blue', 'FontSize', 12);

        numShow = min(10, length(scores));
        for i = 1:numShow
            subplot(2, 6, i + 2);
            idx = sortIdx(i);
            imshow(pieces{scores(idx).pieceIndex});

            if i == 1
                titleColor = [0, 0.6, 0];
            elseif i <= 3
                titleColor = [0.8, 0.5, 0];
            else
                titleColor = [0.3, 0.3, 0.3];
            end

            title(sprintf('P%d-#%d: %.0f%%', ...
                scores(idx).photoIndex, scores(idx).localPieceIndex, ...
                scores(idx).totalScore), 'Color', titleColor, 'FontWeight', 'bold');
        end

        set(gcf, 'Position', [50, 50, 1400, 500]);

    catch ME
        disp('Note: Could not display visual results.');
        disp(['Reason: ' ME.message]);
    end

    disp('===========================================');
    disp('Look for the piece highlighted in green');
    disp('in the source photo shown above!');
    disp('===========================================');
end
