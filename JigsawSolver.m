%% JIGSAW PUZZLE SOLVER - MATLAB Mobile Script
% This script helps find the best matching puzzle pieces for missing holes
% in a puzzle by analyzing geometry and color patterns at the edges.
%
% User Flow:
%   1. Upload the "Puzzle Image" (puzzle with missing pieces/holes)
%   2. Upload up to 10 "Candidate Photos" (photos with multiple puzzle pieces)
%   3. The app detects holes, detects pieces, and suggests the best matches
%
% Compatible with MATLAB Mobile

function JigsawSolver()
    close all;
    clc;

    disp('===========================================');
    disp('       JIGSAW PUZZLE SOLVER');
    disp('===========================================');
    disp('Finds pieces to fill holes in your puzzle!');
    disp(' ');

    %% Step 1: Load Puzzle Image (with missing pieces)
    disp('Step 1: Select the PUZZLE IMAGE (with missing pieces/holes)');
    disp('-------------------------------------------');

    puzzleImage = loadImage('puzzle', 1024);
    if isempty(puzzleImage)
        disp('Error: No puzzle image loaded. Exiting.');
        return;
    end
    disp('Puzzle image loaded successfully!');
    disp(' ');

    %% Step 2: Detect holes in the puzzle
    disp('Step 2: Detecting missing piece locations (holes)...');
    disp('-------------------------------------------');

    [holeRegions, holeMask, holeEdges] = detectHoles(puzzleImage);
    numHoles = length(holeRegions);

    if numHoles == 0
        disp('No holes detected. Make sure the missing area is visible.');
        disp('Tip: Holes should contrast with the puzzle pieces.');
        return;
    end

    fprintf('Detected %d hole region(s) in the puzzle.\n\n', numHoles);

    %% Step 3: Load Candidate Photos (containing puzzle pieces)
    disp('Step 3: Select CANDIDATE PHOTOS (containing puzzle pieces)');
    disp('         Each photo can contain multiple pieces.');
    disp('-------------------------------------------');

    maxPhotos = 10;
    candidatePhotos = cell(1, maxPhotos);
    validPhotos = 0;

    for i = 1:maxPhotos
        fprintf('Loading photo %d of %d...\n', i, maxPhotos);
        img = loadImage(sprintf('photo_%d', i), 1024);
        if ~isempty(img)
            validPhotos = validPhotos + 1;
            candidatePhotos{validPhotos} = img;
        else
            fprintf('Skipping photo %d\n', i);
            if i < maxPhotos
                cont = input('Continue loading more photos? (y/n): ', 's');
                if lower(cont) ~= 'y'
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

    %% Step 4: Detect pieces in candidate photos
    disp('Step 4: Detecting puzzle pieces in photos...');
    disp('-------------------------------------------');

    allPieces = {};
    pieceInfo = [];

    for photoIdx = 1:validPhotos
        fprintf('Processing photo %d...\n', photoIdx);
        [pieces, bboxes] = detectPieces(candidatePhotos{photoIdx});

        fprintf('  Found %d pieces\n', length(pieces));

        for p = 1:length(pieces)
            allPieces{end+1} = pieces{p};
            pieceInfo(end+1).photoIndex = photoIdx;
            pieceInfo(end).pieceIndex = p;
            pieceInfo(end).boundingBox = bboxes{p};
        end
    end

    totalPieces = length(allPieces);
    fprintf('\nTotal pieces detected: %d\n\n', totalPieces);

    if totalPieces == 0
        disp('Error: No pieces detected. Check lighting and background.');
        return;
    end

    %% Step 5: Match pieces to holes
    disp('Step 5: Matching pieces to holes...');
    disp('-------------------------------------------');

    [matches, allScores] = matchPiecesToHoles(puzzleImage, holeRegions, holeEdges, ...
                                               allPieces, pieceInfo);

    %% Step 6: Display Results
    displayResults(puzzleImage, holeMask, holeRegions, candidatePhotos, ...
                   allPieces, pieceInfo, matches, allScores);
end

%% IMAGE LOADING FUNCTION
function img = loadImage(imageName, maxSize)
    try
        [filename, pathname] = uigetfile(...
            {'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff', 'Image Files'; ...
             '*.*', 'All Files'}, ...
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

        img = resizeImage(img, maxSize);

    catch ME
        fprintf('Error loading image: %s\n', ME.message);
        img = [];
    end
end

%% IMAGE RESIZE FUNCTION
function imgResized = resizeImage(img, maxSize)
    [h, w, ~] = size(img);
    if max(h, w) > maxSize
        scale = maxSize / max(h, w);
        imgResized = imresize(img, scale);
    else
        imgResized = img;
    end
end

%% HOLE DETECTION FUNCTION
function [holeRegions, holeMask, holeEdges] = detectHoles(puzzleImg)
    % Detect missing piece locations (holes) in the puzzle
    % Holes are typically darker, uniform areas or visible background

    [h, w, ~] = size(puzzleImg);
    imgDouble = im2double(puzzleImg);
    imgGray = rgb2gray(puzzleImg);
    imgHSV = rgb2hsv(puzzleImg);

    %% Method 1: Detect dark/uniform regions (table showing through)
    % Holes often appear as dark uniform areas
    brightness = imgHSV(:,:,3);
    saturation = imgHSV(:,:,2);

    % Low brightness and low saturation often indicates hole/background
    darkMask = brightness < 0.3;

    %% Method 2: Detect uniform color regions (low texture)
    % Calculate local variance - holes have low texture
    windowSize = 9;
    localVar = stdfilt(imgGray, ones(windowSize));
    lowTextureMask = localVar < 0.03;

    %% Method 3: Color uniformity - holes often have consistent color
    % Sample potential hole colors (often dark/gray/brown table)
    rChannel = imgDouble(:,:,1);
    gChannel = imgDouble(:,:,2);
    bChannel = imgDouble(:,:,3);

    % Calculate color variance in local neighborhoods
    colorVar = stdfilt(rChannel, ones(7)) + stdfilt(gChannel, ones(7)) + stdfilt(bChannel, ones(7));
    uniformColorMask = colorVar < 0.05;

    %% Method 4: Edge density - puzzle pieces have more edges than holes
    edges = edge(imgGray, 'canny');
    edgeDensity = imfilter(double(edges), ones(15)/225, 'symmetric');
    lowEdgeMask = edgeDensity < 0.05;

    %% Combine methods
    % A hole should be: (dark OR low texture) AND uniform color AND low edges
    holeMask = (darkMask | lowTextureMask) & uniformColorMask & lowEdgeMask;

    % Alternative: detect by saturation - holes often less saturated
    desaturatedMask = saturation < 0.15 & brightness < 0.5;
    holeMask = holeMask | desaturatedMask;

    %% Clean up mask
    % Remove small regions (noise)
    minHoleArea = round(h * w * 0.005);  % At least 0.5% of image
    holeMask = bwareaopen(holeMask, minHoleArea);

    % Fill small gaps within holes
    holeMask = imclose(holeMask, strel('disk', 10));
    holeMask = imfill(holeMask, 'holes');

    % Remove regions touching image border (probably not holes)
    holeMask = imclearborder(holeMask);

    %% Find connected hole regions
    CC = bwconncomp(holeMask);
    stats = regionprops(CC, 'BoundingBox', 'Area', 'Centroid', 'PixelIdxList', 'ConvexHull');

    holeRegions = [];
    holeEdges = {};

    maxHoleArea = round(h * w * 0.5);  % Max 50% of image

    for i = 1:length(stats)
        area = stats(i).Area;
        if area < minHoleArea || area > maxHoleArea
            continue;
        end

        % Extract hole info
        holeRegions(end+1).boundingBox = stats(i).BoundingBox;
        holeRegions(end).area = area;
        holeRegions(end).centroid = stats(i).Centroid;
        holeRegions(end).pixelIdx = stats(i).PixelIdxList;

        % Extract edge colors around this hole
        holeMaskSingle = false(h, w);
        holeMaskSingle(stats(i).PixelIdxList) = true;
        holeEdges{end+1} = extractHoleEdgeFeatures(puzzleImg, holeMaskSingle);
    end

    % If no holes detected, try alternative method
    if isempty(holeRegions)
        fprintf('  Trying alternative hole detection...\n');
        [holeRegions, holeMask, holeEdges] = detectHolesAlternative(puzzleImg);
    end
end

%% ALTERNATIVE HOLE DETECTION
function [holeRegions, holeMask, holeEdges] = detectHolesAlternative(puzzleImg)
    % Try detecting holes by finding the most uniform/different regions

    [h, w, ~] = size(puzzleImg);
    imgGray = rgb2gray(puzzleImg);
    imgDouble = im2double(puzzleImg);

    % Use Otsu's method to find threshold
    level = graythresh(imgGray);

    % Try both dark and light regions
    darkMask = imgGray < level * 0.6 * 255;
    lightMask = imgGray > level * 1.4 * 255;

    % Calculate texture
    localStd = stdfilt(imgGray, ones(11));
    lowTexture = localStd < prctile(localStd(:), 20);

    % Combine
    holeMask = (darkMask | lightMask) & lowTexture;

    % Clean up
    minArea = round(h * w * 0.01);
    holeMask = bwareaopen(holeMask, minArea);
    holeMask = imclose(holeMask, strel('disk', 8));
    holeMask = imfill(holeMask, 'holes');
    holeMask = imclearborder(holeMask);

    % Find regions
    CC = bwconncomp(holeMask);
    stats = regionprops(CC, 'BoundingBox', 'Area', 'Centroid', 'PixelIdxList');

    holeRegions = [];
    holeEdges = {};

    for i = 1:length(stats)
        if stats(i).Area < minArea
            continue;
        end

        holeRegions(end+1).boundingBox = stats(i).BoundingBox;
        holeRegions(end).area = stats(i).Area;
        holeRegions(end).centroid = stats(i).Centroid;
        holeRegions(end).pixelIdx = stats(i).PixelIdxList;

        holeMaskSingle = false(h, w);
        holeMaskSingle(stats(i).PixelIdxList) = true;
        holeEdges{end+1} = extractHoleEdgeFeatures(puzzleImg, holeMaskSingle);
    end
end

%% EXTRACT HOLE EDGE FEATURES
function edgeFeatures = extractHoleEdgeFeatures(puzzleImg, holeMask)
    % Extract color/pattern features from the edges surrounding the hole
    % These features will be matched against piece edges

    [h, w, ~] = size(puzzleImg);
    imgDouble = im2double(puzzleImg);

    % Dilate hole mask to get surrounding region
    surroundWidth = 15;  % pixels to sample around hole
    dilated = imdilate(holeMask, strel('disk', surroundWidth));
    edgeRegion = dilated & ~holeMask;

    % Extract colors from edge region
    edgeFeatures = struct();

    if sum(edgeRegion(:)) < 100
        % Not enough edge pixels, use hole boundary
        boundary = bwperim(holeMask);
        dilatedBoundary = imdilate(boundary, strel('disk', 5));
        edgeRegion = dilatedBoundary & ~holeMask;
    end

    % Color features from surrounding puzzle pieces
    for c = 1:3
        channel = imgDouble(:,:,c);
        if sum(edgeRegion(:)) > 50
            edgeFeatures.meanColor(c) = mean(channel(edgeRegion));
            edgeFeatures.stdColor(c) = std(channel(edgeRegion));
        else
            edgeFeatures.meanColor(c) = mean(channel(:));
            edgeFeatures.stdColor(c) = std(channel(:));
        end
    end

    % Color histogram of surrounding area
    numBins = 16;
    R = puzzleImg(:,:,1);
    G = puzzleImg(:,:,2);
    B = puzzleImg(:,:,3);

    if sum(edgeRegion(:)) > 50
        edgeFeatures.histR = histcounts(R(edgeRegion), 0:256/numBins:256, 'Normalization', 'probability')';
        edgeFeatures.histG = histcounts(G(edgeRegion), 0:256/numBins:256, 'Normalization', 'probability')';
        edgeFeatures.histB = histcounts(B(edgeRegion), 0:256/numBins:256, 'Normalization', 'probability')';
    else
        edgeFeatures.histR = zeros(numBins, 1);
        edgeFeatures.histG = zeros(numBins, 1);
        edgeFeatures.histB = zeros(numBins, 1);
    end

    % Edge direction features (from surrounding pieces)
    imgGray = rgb2gray(puzzleImg);
    [Gx, Gy] = imgradientxy(double(imgGray)/255, 'sobel');
    gradMag = sqrt(Gx.^2 + Gy.^2);
    gradDir = atan2(Gy, Gx);

    strongEdges = edgeRegion & (gradMag > 0.1);
    if sum(strongEdges(:)) > 20
        edgeFeatures.edgeHist = histcounts(gradDir(strongEdges), linspace(-pi, pi, 9), 'Normalization', 'probability');
    else
        edgeFeatures.edgeHist = ones(1, 8) / 8;
    end

    % Texture features
    if sum(edgeRegion(:)) > 50
        grayDouble = double(imgGray) / 255;
        edgeFeatures.texture = std(grayDouble(edgeRegion));
    else
        edgeFeatures.texture = 0.1;
    end

    % Store edge region for visualization
    edgeFeatures.edgeRegion = edgeRegion;

    % Sample colors at 4 sides of hole (top, right, bottom, left)
    edgeFeatures.sideColors = extractSideColors(puzzleImg, holeMask);
end

%% EXTRACT SIDE COLORS
function sideColors = extractSideColors(puzzleImg, holeMask)
    % Sample colors from each side of the hole for directional matching

    [h, w, ~] = size(puzzleImg);
    imgDouble = im2double(puzzleImg);

    % Get hole bounding box
    [rows, cols] = find(holeMask);
    if isempty(rows)
        sideColors = struct('top', [0.5, 0.5, 0.5], 'right', [0.5, 0.5, 0.5], ...
                           'bottom', [0.5, 0.5, 0.5], 'left', [0.5, 0.5, 0.5]);
        return;
    end

    minRow = min(rows); maxRow = max(rows);
    minCol = min(cols); maxCol = max(cols);

    sampleWidth = 10;

    % Top edge (sample above the hole)
    topRegion = max(1, minRow-sampleWidth):max(1, minRow-1);
    topCols = minCol:maxCol;
    sideColors.top = sampleRegionColor(imgDouble, topRegion, topCols);

    % Bottom edge
    bottomRegion = min(h, maxRow+1):min(h, maxRow+sampleWidth);
    sideColors.bottom = sampleRegionColor(imgDouble, bottomRegion, topCols);

    % Left edge
    leftCols = max(1, minCol-sampleWidth):max(1, minCol-1);
    leftRows = minRow:maxRow;
    sideColors.left = sampleRegionColor(imgDouble, leftRows, leftCols);

    % Right edge
    rightCols = min(w, maxCol+1):min(w, maxCol+sampleWidth);
    sideColors.right = sampleRegionColor(imgDouble, leftRows, rightCols);
end

function color = sampleRegionColor(imgDouble, rows, cols)
    if isempty(rows) || isempty(cols)
        color = [0.5, 0.5, 0.5];
        return;
    end

    region = imgDouble(rows, cols, :);
    color = squeeze(mean(mean(region, 1), 2))';

    if length(color) ~= 3
        color = [0.5, 0.5, 0.5];
    end
end

%% PIECE DETECTION FUNCTION
function [pieces, boundingBoxes] = detectPieces(img)
    pieces = {};
    boundingBoxes = {};

    [h, w, ~] = size(img);
    imgDouble = im2double(img);
    imgGray = rgb2gray(img);

    % Detect background from corners
    cornerSize = round(min(h, w) * 0.05);
    corners = [
        imgDouble(1:cornerSize, 1:cornerSize, :);
        imgDouble(1:cornerSize, end-cornerSize+1:end, :);
        imgDouble(end-cornerSize+1:end, 1:cornerSize, :);
        imgDouble(end-cornerSize+1:end, end-cornerSize+1:end, :)
    ];
    bgColor = squeeze(mean(reshape(corners, [], 3), 1));

    % Color distance from background
    colorDist = sqrt(sum((imgDouble - reshape(bgColor, 1, 1, 3)).^2, 3));

    threshold = max(0.12, graythresh(colorDist) * 0.7);
    mask = colorDist > threshold;

    % Clean up
    mask = imfill(mask, 'holes');
    minArea = round(h * w * 0.003);
    mask = bwareaopen(mask, minArea);
    mask = imclose(mask, strel('disk', 4));
    mask = imerode(mask, strel('disk', 2));
    mask = imdilate(mask, strel('disk', 2));

    CC = bwconncomp(mask);
    stats = regionprops(CC, 'BoundingBox', 'Area', 'PixelIdxList');

    maxArea = round(h * w * 0.6);

    for i = 1:length(stats)
        area = stats(i).Area;
        if area < minArea || area > maxArea
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

        pad = 3;
        x1 = max(1, x - pad);
        y1 = max(1, y - pad);
        x2 = min(w, x + bw + pad);
        y2 = min(h, y + bh + pad);

        pieceImg = img(y1:y2, x1:x2, :);

        pieceMask = false(h, w);
        pieceMask(stats(i).PixelIdxList) = true;
        pieceMaskCropped = pieceMask(y1:y2, x1:x2);

        % Apply mask (white background)
        for c = 1:3
            ch = pieceImg(:,:,c);
            ch(~pieceMaskCropped) = 255;
            pieceImg(:,:,c) = ch;
        end

        pieceImg = resizeImage(pieceImg, 256);

        pieces{end+1} = pieceImg;
        boundingBoxes{end+1} = [x1, y1, x2-x1, y2-y1];
    end

    if isempty(pieces)
        [pieces, boundingBoxes] = detectPiecesFallback(img);
    end
end

%% FALLBACK PIECE DETECTION
function [pieces, boundingBoxes] = detectPiecesFallback(img)
    pieces = {};
    boundingBoxes = {};

    [h, w, ~] = size(img);
    imgHSV = rgb2hsv(img);

    sat = imgHSV(:,:,2);
    mask = sat > graythresh(sat) * 0.4;
    mask = mask | (stdfilt(rgb2gray(img), ones(11)) > 0.05);

    mask = imfill(mask, 'holes');
    minArea = round(h * w * 0.005);
    mask = bwareaopen(mask, minArea);
    mask = imclose(mask, strel('disk', 6));

    CC = bwconncomp(mask);
    stats = regionprops(CC, 'BoundingBox', 'Area', 'PixelIdxList');

    maxArea = round(h * w * 0.6);

    for i = 1:length(stats)
        area = stats(i).Area;
        if area < minArea || area > maxArea
            continue;
        end

        bbox = stats(i).BoundingBox;
        x = max(1, floor(bbox(1)));
        y = max(1, floor(bbox(2)));
        bw = min(w - x, ceil(bbox(3)));
        bh = min(h - y, ceil(bbox(4)));

        if max(bw, bh) / max(1, min(bw, bh)) > 5
            continue;
        end

        pad = 3;
        x1 = max(1, x - pad);
        y1 = max(1, y - pad);
        x2 = min(w, x + bw + pad);
        y2 = min(h, y + bh + pad);

        pieceImg = img(y1:y2, x1:x2, :);

        pieceMask = false(h, w);
        pieceMask(stats(i).PixelIdxList) = true;
        pieceMaskCropped = pieceMask(y1:y2, x1:x2);

        for c = 1:3
            ch = pieceImg(:,:,c);
            ch(~pieceMaskCropped) = 255;
            pieceImg(:,:,c) = ch;
        end

        pieceImg = resizeImage(pieceImg, 256);

        pieces{end+1} = pieceImg;
        boundingBoxes{end+1} = [x1, y1, x2-x1, y2-y1];
    end
end

%% MATCH PIECES TO HOLES
function [matches, allScores] = matchPiecesToHoles(puzzleImg, holeRegions, holeEdges, pieces, pieceInfo)
    numHoles = length(holeRegions);
    numPieces = length(pieces);

    fprintf('Matching %d pieces to %d hole region(s)...\n', numPieces, numHoles);

    % Calculate scores for each piece against each hole
    allScores = struct();

    for hIdx = 1:numHoles
        fprintf('  Analyzing hole %d...\n', hIdx);

        for pIdx = 1:numPieces
            pieceFeatures = extractPieceEdgeFeatures(pieces{pIdx});

            % Calculate match score
            score = calculateEdgeMatchScore(holeEdges{hIdx}, pieceFeatures);

            allScores(hIdx, pIdx).holeIndex = hIdx;
            allScores(hIdx, pIdx).pieceIndex = pIdx;
            allScores(hIdx, pIdx).photoIndex = pieceInfo(pIdx).photoIndex;
            allScores(hIdx, pIdx).localPieceIndex = pieceInfo(pIdx).pieceIndex;
            allScores(hIdx, pIdx).score = score.total;
            allScores(hIdx, pIdx).colorScore = score.color;
            allScores(hIdx, pIdx).edgeScore = score.edge;
            allScores(hIdx, pIdx).textureScore = score.texture;
        end
    end

    % Find best matches for each hole
    matches = struct();

    for hIdx = 1:numHoles
        scores = [allScores(hIdx, :).score];
        [bestScore, bestPieceIdx] = max(scores);

        matches(hIdx).holeIndex = hIdx;
        matches(hIdx).bestPieceIndex = bestPieceIdx;
        matches(hIdx).bestScore = bestScore;
        matches(hIdx).photoIndex = allScores(hIdx, bestPieceIdx).photoIndex;
        matches(hIdx).localPieceIndex = allScores(hIdx, bestPieceIdx).localPieceIndex;

        % Get top 3 candidates
        [sortedScores, sortIdx] = sort(scores, 'descend');
        numTop = min(3, length(sortIdx));
        matches(hIdx).topCandidates = sortIdx(1:numTop);
        matches(hIdx).topScores = sortedScores(1:numTop);

        fprintf('  Hole %d: Best match is Piece %d (Photo %d, #%d) - Score: %.1f%%\n', ...
            hIdx, bestPieceIdx, matches(hIdx).photoIndex, ...
            matches(hIdx).localPieceIndex, bestScore);
    end
end

%% EXTRACT PIECE EDGE FEATURES
function features = extractPieceEdgeFeatures(pieceImg)
    imgDouble = im2double(pieceImg);

    % Exclude white background
    whiteMask = all(imgDouble > 0.95, 3);
    validMask = ~whiteMask;

    features = struct();

    % Overall color features
    numBins = 16;
    R = pieceImg(:,:,1);
    G = pieceImg(:,:,2);
    B = pieceImg(:,:,3);

    if sum(validMask(:)) > 50
        features.histR = histcounts(R(validMask), 0:256/numBins:256, 'Normalization', 'probability')';
        features.histG = histcounts(G(validMask), 0:256/numBins:256, 'Normalization', 'probability')';
        features.histB = histcounts(B(validMask), 0:256/numBins:256, 'Normalization', 'probability')';

        for c = 1:3
            ch = imgDouble(:,:,c);
            features.meanColor(c) = mean(ch(validMask));
            features.stdColor(c) = std(ch(validMask));
        end
    else
        features.histR = imhist(R, numBins) / numel(R);
        features.histG = imhist(G, numBins) / numel(G);
        features.histB = imhist(B, numBins) / numel(B);
        features.meanColor = squeeze(mean(mean(imgDouble, 1), 2))';
        features.stdColor = [0.1, 0.1, 0.1];
    end

    % Edge colors (sample from piece boundaries)
    features.sideColors = extractPieceSideColors(pieceImg, validMask);

    % Edge direction histogram
    imgGray = rgb2gray(pieceImg);
    [Gx, Gy] = gradient(double(imgGray)/255);
    gradMag = sqrt(Gx.^2 + Gy.^2);
    gradDir = atan2(Gy, Gx);

    strongEdges = gradMag > 0.05;
    if sum(strongEdges(:)) > 20
        features.edgeHist = histcounts(gradDir(strongEdges), linspace(-pi, pi, 9), 'Normalization', 'probability');
    else
        features.edgeHist = ones(1, 8) / 8;
    end

    % Texture
    features.texture = std(double(imgGray(validMask))/255);
end

%% EXTRACT PIECE SIDE COLORS
function sideColors = extractPieceSideColors(pieceImg, validMask)
    imgDouble = im2double(pieceImg);
    [h, w, ~] = size(pieceImg);

    sampleWidth = max(5, round(min(h, w) * 0.1));

    % Top edge
    topRegion = 1:min(sampleWidth, h);
    topMask = validMask(topRegion, :);
    sideColors.top = sampleMaskedColor(imgDouble(topRegion, :, :), topMask);

    % Bottom edge
    bottomRegion = max(1, h-sampleWidth+1):h;
    bottomMask = validMask(bottomRegion, :);
    sideColors.bottom = sampleMaskedColor(imgDouble(bottomRegion, :, :), bottomMask);

    % Left edge
    leftCols = 1:min(sampleWidth, w);
    leftMask = validMask(:, leftCols);
    sideColors.left = sampleMaskedColor(imgDouble(:, leftCols, :), leftMask);

    % Right edge
    rightCols = max(1, w-sampleWidth+1):w;
    rightMask = validMask(:, rightCols);
    sideColors.right = sampleMaskedColor(imgDouble(:, rightCols, :), rightMask);
end

function color = sampleMaskedColor(region, mask)
    if sum(mask(:)) < 10
        color = [0.5, 0.5, 0.5];
        return;
    end

    color = zeros(1, 3);
    for c = 1:3
        ch = region(:,:,c);
        color(c) = mean(ch(mask));
    end
end

%% CALCULATE EDGE MATCH SCORE
function score = calculateEdgeMatchScore(holeFeatures, pieceFeatures)
    % Compare hole edge features with piece edge features

    %% Color histogram similarity
    histSimR = sum(min(holeFeatures.histR, pieceFeatures.histR));
    histSimG = sum(min(holeFeatures.histG, pieceFeatures.histG));
    histSimB = sum(min(holeFeatures.histB, pieceFeatures.histB));
    histSim = (histSimR + histSimG + histSimB) / 3;

    %% Mean color similarity
    meanDist = norm(holeFeatures.meanColor - pieceFeatures.meanColor);
    meanSim = max(0, 1 - meanDist / sqrt(3));

    %% Side color matching (important for edge matching)
    sides = {'top', 'bottom', 'left', 'right'};
    sideSim = 0;
    for i = 1:length(sides)
        side = sides{i};
        if isfield(holeFeatures.sideColors, side) && isfield(pieceFeatures.sideColors, side)
            dist = norm(holeFeatures.sideColors.(side) - pieceFeatures.sideColors.(side));
            sideSim = sideSim + max(0, 1 - dist / sqrt(3));
        else
            sideSim = sideSim + 0.5;
        end
    end
    sideSim = sideSim / 4;

    %% Edge direction similarity
    edgeSim = sum(min(holeFeatures.edgeHist, pieceFeatures.edgeHist));

    %% Texture similarity
    textureDiff = abs(holeFeatures.texture - pieceFeatures.texture);
    textureSim = max(0, 1 - textureDiff * 5);

    %% Combined scores
    score.color = 100 * (0.3 * histSim + 0.3 * meanSim + 0.4 * sideSim);
    score.edge = 100 * edgeSim;
    score.texture = 100 * textureSim;

    % Total weighted score
    score.total = 0.60 * score.color + 0.25 * score.edge + 0.15 * score.texture;
end

%% DISPLAY RESULTS
function displayResults(puzzleImg, holeMask, holeRegions, candidatePhotos, ...
                        pieces, pieceInfo, matches, allScores)
    disp(' ');
    disp('===========================================');
    disp('             RESULTS');
    disp('===========================================');
    disp(' ');

    numHoles = length(matches);

    for hIdx = 1:numHoles
        fprintf('HOLE #%d:\n', hIdx);
        fprintf('  Best Match: Photo #%d, Piece #%d\n', ...
            matches(hIdx).photoIndex, matches(hIdx).localPieceIndex);
        fprintf('  Score: %.1f%%\n', matches(hIdx).bestScore);

        if length(matches(hIdx).topScores) > 1
            scoreDiff = matches(hIdx).topScores(1) - matches(hIdx).topScores(2);
            if scoreDiff > 15
                fprintf('  Confidence: HIGH\n');
            elseif scoreDiff > 5
                fprintf('  Confidence: MEDIUM\n');
            else
                fprintf('  Confidence: LOW\n');
            end
        end

        fprintf('\n  Top 3 candidates:\n');
        for i = 1:length(matches(hIdx).topCandidates)
            pIdx = matches(hIdx).topCandidates(i);
            fprintf('    %d. Photo %d, Piece %d - Score: %.1f%%\n', ...
                i, pieceInfo(pIdx).photoIndex, pieceInfo(pIdx).pieceIndex, ...
                matches(hIdx).topScores(i));
        end
        disp(' ');
    end

    %% Visual display
    try
        % Figure 1: Puzzle with holes and matches
        figure('Name', 'Jigsaw Solver Results', 'NumberTitle', 'off');

        % Show puzzle with holes highlighted
        subplot(2, 3, 1);
        imshow(puzzleImg);
        hold on;
        % Highlight holes in red
        holeOverlay = cat(3, ones(size(holeMask)), zeros(size(holeMask)), zeros(size(holeMask)));
        hImg = imshow(holeOverlay);
        set(hImg, 'AlphaData', holeMask * 0.4);
        title('Puzzle with Holes', 'FontWeight', 'bold', 'FontSize', 11);
        hold off;

        % Show best matches for each hole
        for hIdx = 1:min(numHoles, 3)
            subplot(2, 3, 1 + hIdx);
            bestPieceIdx = matches(hIdx).bestPieceIndex;
            imshow(pieces{bestPieceIdx});
            title(sprintf('Hole %d Match\nPhoto %d, Piece %d\nScore: %.0f%%', ...
                hIdx, matches(hIdx).photoIndex, matches(hIdx).localPieceIndex, ...
                matches(hIdx).bestScore), 'FontSize', 10, 'Color', [0, 0.5, 0]);
        end

        % Show source photos with matching pieces highlighted
        numPhotos = length(candidatePhotos);
        for pIdx = 1:min(numPhotos, 2)
            subplot(2, 3, 4 + pIdx);
            imshow(candidatePhotos{pIdx});
            hold on;

            % Highlight pieces that matched holes
            for hIdx = 1:numHoles
                if matches(hIdx).photoIndex == pIdx
                    bbox = pieceInfo(matches(hIdx).bestPieceIndex).boundingBox;
                    rectangle('Position', bbox, 'EdgeColor', 'green', 'LineWidth', 3);
                    text(bbox(1), bbox(2)-10, sprintf('H%d', hIdx), ...
                        'Color', 'green', 'FontWeight', 'bold', 'FontSize', 12);
                end
            end

            title(sprintf('Photo %d', pIdx), 'FontSize', 10);
            hold off;
        end

        set(gcf, 'Position', [50, 100, 1200, 700]);

    catch ME
        disp('Could not display visual results.');
        disp(['Reason: ' ME.message]);
    end

    disp('===========================================');
    disp('Green rectangles show matching pieces!');
    disp('===========================================');
end
