function [matches, allScores] = jigsawQuickSolve(puzzlePath, candidatePaths)
%JIGSAWQUICKSOLVE Quick jigsaw puzzle solver for MATLAB Mobile
%   Detects holes in puzzle and finds matching pieces from candidate photos
%
%   Usage:
%       [matches, scores] = jigsawQuickSolve(puzzlePath, candidatePaths)
%
%   Inputs:
%       puzzlePath     - Path to puzzle image (with missing pieces/holes)
%       candidatePaths - Cell array of paths to photos containing pieces
%
%   Outputs:
%       matches   - Structure array with best match for each hole:
%                   .holeIndex, .photoIndex, .pieceIndex, .score
%       allScores - Full score matrix for all hole-piece combinations
%
%   Example:
%       puzzle = 'images/puzzle_with_holes.jpg';
%       photos = {'images/pieces1.jpg', 'images/pieces2.jpg'};
%       [matches, scores] = jigsawQuickSolve(puzzle, photos);

    %% Validate inputs
    if ~exist(puzzlePath, 'file')
        error('Puzzle image not found: %s', puzzlePath);
    end

    if ~iscell(candidatePaths)
        error('candidatePaths must be a cell array of file paths');
    end

    %% Load puzzle image
    fprintf('Loading puzzle image...\n');
    puzzleImg = loadAndPreprocess(puzzlePath, 1024);

    %% Detect holes in puzzle
    fprintf('Detecting holes in puzzle...\n');
    [holeRegions, holeMask, holeEdges] = detectHolesQuick(puzzleImg);
    numHoles = length(holeRegions);

    if numHoles == 0
        error('No holes detected in puzzle. Ensure missing areas are visible.');
    end

    fprintf('Found %d hole region(s)\n\n', numHoles);

    %% Detect pieces in candidate photos
    allPieces = {};
    pieceInfo = [];

    numPhotos = length(candidatePaths);
    fprintf('Processing %d photos for puzzle pieces...\n', numPhotos);

    for photoIdx = 1:numPhotos
        if ~exist(candidatePaths{photoIdx}, 'file')
            warning('Photo %d not found: %s', photoIdx, candidatePaths{photoIdx});
            continue;
        end

        fprintf('  Photo %d: ', photoIdx);
        photoImg = loadAndPreprocess(candidatePaths{photoIdx}, 1024);
        [pieces, bboxes] = detectPiecesQuick(photoImg);
        fprintf('found %d pieces\n', length(pieces));

        for p = 1:length(pieces)
            allPieces{end+1} = pieces{p};
            pieceInfo(end+1).photoIndex = photoIdx;
            pieceInfo(end).pieceIndex = p;
            pieceInfo(end).boundingBox = bboxes{p};
            pieceInfo(end).photoPath = candidatePaths{photoIdx};
        end
    end

    totalPieces = length(allPieces);
    fprintf('\nTotal pieces: %d\n\n', totalPieces);

    if totalPieces == 0
        error('No pieces detected. Check lighting and background.');
    end

    %% Match pieces to holes
    fprintf('Matching pieces to holes...\n');

    allScores = struct();
    for hIdx = 1:numHoles
        for pIdx = 1:totalPieces
            pieceFeatures = extractPieceFeaturesQuick(allPieces{pIdx});
            score = calculateMatchScore(holeEdges{hIdx}, pieceFeatures);

            allScores(hIdx, pIdx).holeIndex = hIdx;
            allScores(hIdx, pIdx).pieceIndex = pIdx;
            allScores(hIdx, pIdx).photoIndex = pieceInfo(pIdx).photoIndex;
            allScores(hIdx, pIdx).localPieceIndex = pieceInfo(pIdx).pieceIndex;
            allScores(hIdx, pIdx).score = score;
        end
    end

    %% Find best matches
    matches = struct();
    for hIdx = 1:numHoles
        scores = [allScores(hIdx, :).score];
        [bestScore, bestIdx] = max(scores);

        matches(hIdx).holeIndex = hIdx;
        matches(hIdx).bestPieceIndex = bestIdx;
        matches(hIdx).photoIndex = pieceInfo(bestIdx).photoIndex;
        matches(hIdx).pieceIndex = pieceInfo(bestIdx).pieceIndex;
        matches(hIdx).score = bestScore;
        matches(hIdx).pieceImage = allPieces{bestIdx};
        matches(hIdx).boundingBox = pieceInfo(bestIdx).boundingBox;

        fprintf('  Hole %d -> Photo %d, Piece %d (Score: %.1f%%)\n', ...
            hIdx, matches(hIdx).photoIndex, matches(hIdx).pieceIndex, bestScore);
    end

    fprintf('\n=== RESULTS ===\n');
    for hIdx = 1:numHoles
        fprintf('Hole %d: Best match is Photo #%d, Piece #%d (Score: %.1f%%)\n', ...
            hIdx, matches(hIdx).photoIndex, matches(hIdx).pieceIndex, matches(hIdx).score);
    end
end

%% LOAD AND PREPROCESS
function img = loadAndPreprocess(filepath, maxSize)
    img = imread(filepath);
    if size(img, 3) == 1
        img = cat(3, img, img, img);
    end
    [h, w, ~] = size(img);
    if max(h, w) > maxSize
        img = imresize(img, maxSize / max(h, w));
    end
end

%% QUICK HOLE DETECTION
function [holeRegions, holeMask, holeEdges] = detectHolesQuick(puzzleImg)
    [h, w, ~] = size(puzzleImg);
    imgGray = rgb2gray(puzzleImg);
    imgHSV = rgb2hsv(puzzleImg);
    imgDouble = im2double(puzzleImg);

    % Detect dark, uniform, low-texture regions
    brightness = imgHSV(:,:,3);
    localVar = stdfilt(imgGray, ones(9));

    darkMask = brightness < 0.35;
    lowTexture = localVar < 0.04;

    % Color uniformity
    colorVar = stdfilt(imgDouble(:,:,1), ones(7)) + ...
               stdfilt(imgDouble(:,:,2), ones(7)) + ...
               stdfilt(imgDouble(:,:,3), ones(7));
    uniformColor = colorVar < 0.06;

    holeMask = (darkMask | lowTexture) & uniformColor;

    % Clean up
    minArea = round(h * w * 0.005);
    holeMask = bwareaopen(holeMask, minArea);
    holeMask = imclose(holeMask, strel('disk', 8));
    holeMask = imfill(holeMask, 'holes');
    holeMask = imclearborder(holeMask);

    % Find regions
    CC = bwconncomp(holeMask);
    stats = regionprops(CC, 'BoundingBox', 'Area', 'PixelIdxList');

    holeRegions = [];
    holeEdges = {};

    for i = 1:length(stats)
        if stats(i).Area < minArea
            continue;
        end

        holeRegions(end+1).boundingBox = stats(i).BoundingBox;
        holeRegions(end).area = stats(i).Area;
        holeRegions(end).pixelIdx = stats(i).PixelIdxList;

        singleMask = false(h, w);
        singleMask(stats(i).PixelIdxList) = true;
        holeEdges{end+1} = extractHoleEdgesQuick(puzzleImg, singleMask);
    end
end

%% EXTRACT HOLE EDGE FEATURES
function features = extractHoleEdgesQuick(puzzleImg, holeMask)
    imgDouble = im2double(puzzleImg);
    [h, w, ~] = size(puzzleImg);

    % Get surrounding region
    dilated = imdilate(holeMask, strel('disk', 12));
    edgeRegion = dilated & ~holeMask;

    features = struct();

    % Color features from edge
    for c = 1:3
        ch = imgDouble(:,:,c);
        if sum(edgeRegion(:)) > 30
            features.meanColor(c) = mean(ch(edgeRegion));
        else
            features.meanColor(c) = 0.5;
        end
    end

    % Color histogram
    numBins = 12;
    R = puzzleImg(:,:,1); G = puzzleImg(:,:,2); B = puzzleImg(:,:,3);
    if sum(edgeRegion(:)) > 30
        features.histR = histcounts(R(edgeRegion), 0:256/numBins:256, 'Normalization', 'probability')';
        features.histG = histcounts(G(edgeRegion), 0:256/numBins:256, 'Normalization', 'probability')';
        features.histB = histcounts(B(edgeRegion), 0:256/numBins:256, 'Normalization', 'probability')';
    else
        features.histR = ones(numBins, 1) / numBins;
        features.histG = ones(numBins, 1) / numBins;
        features.histB = ones(numBins, 1) / numBins;
    end

    % Side colors
    [rows, cols] = find(holeMask);
    if ~isempty(rows)
        minR = min(rows); maxR = max(rows);
        minC = min(cols); maxC = max(cols);
        sw = 8;

        % Sample each side
        features.topColor = sampleArea(imgDouble, max(1,minR-sw):max(1,minR-1), minC:maxC);
        features.bottomColor = sampleArea(imgDouble, min(h,maxR+1):min(h,maxR+sw), minC:maxC);
        features.leftColor = sampleArea(imgDouble, minR:maxR, max(1,minC-sw):max(1,minC-1));
        features.rightColor = sampleArea(imgDouble, minR:maxR, min(w,maxC+1):min(w,maxC+sw));
    else
        features.topColor = [0.5, 0.5, 0.5];
        features.bottomColor = [0.5, 0.5, 0.5];
        features.leftColor = [0.5, 0.5, 0.5];
        features.rightColor = [0.5, 0.5, 0.5];
    end
end

function color = sampleArea(img, rows, cols)
    if isempty(rows) || isempty(cols)
        color = [0.5, 0.5, 0.5];
        return;
    end
    region = img(rows, cols, :);
    color = squeeze(mean(mean(region, 1), 2))';
    if length(color) ~= 3
        color = [0.5, 0.5, 0.5];
    end
end

%% QUICK PIECE DETECTION
function [pieces, boundingBoxes] = detectPiecesQuick(img)
    pieces = {};
    boundingBoxes = {};

    [h, w, ~] = size(img);
    imgDouble = im2double(img);

    % Background from corners
    cs = round(min(h, w) * 0.05);
    corners = [imgDouble(1:cs, 1:cs, :); imgDouble(1:cs, end-cs+1:end, :);
               imgDouble(end-cs+1:end, 1:cs, :); imgDouble(end-cs+1:end, end-cs+1:end, :)];
    bgColor = squeeze(mean(reshape(corners, [], 3), 1));

    colorDist = sqrt(sum((imgDouble - reshape(bgColor, 1, 1, 3)).^2, 3));
    mask = colorDist > max(0.12, graythresh(colorDist) * 0.7);

    mask = imfill(mask, 'holes');
    minArea = round(h * w * 0.003);
    mask = bwareaopen(mask, minArea);
    mask = imclose(mask, strel('disk', 4));

    CC = bwconncomp(mask);
    stats = regionprops(CC, 'BoundingBox', 'Area', 'PixelIdxList');

    for i = 1:length(stats)
        if stats(i).Area < minArea || stats(i).Area > h*w*0.6
            continue;
        end

        bbox = stats(i).BoundingBox;
        x = max(1, floor(bbox(1))); y = max(1, floor(bbox(2)));
        bw = min(w-x, ceil(bbox(3))); bh = min(h-y, ceil(bbox(4)));

        if max(bw,bh)/max(1,min(bw,bh)) > 5
            continue;
        end

        x1 = max(1, x-2); y1 = max(1, y-2);
        x2 = min(w, x+bw+2); y2 = min(h, y+bh+2);

        pieceImg = img(y1:y2, x1:x2, :);
        pieceMask = false(h, w);
        pieceMask(stats(i).PixelIdxList) = true;
        pieceMaskCrop = pieceMask(y1:y2, x1:x2);

        for c = 1:3
            ch = pieceImg(:,:,c);
            ch(~pieceMaskCrop) = 255;
            pieceImg(:,:,c) = ch;
        end

        if max(size(pieceImg,1), size(pieceImg,2)) > 200
            pieceImg = imresize(pieceImg, 200/max(size(pieceImg,1), size(pieceImg,2)));
        end

        pieces{end+1} = pieceImg;
        boundingBoxes{end+1} = [x1, y1, x2-x1, y2-y1];
    end
end

%% EXTRACT PIECE FEATURES
function features = extractPieceFeaturesQuick(pieceImg)
    imgDouble = im2double(pieceImg);
    whiteMask = all(imgDouble > 0.95, 3);
    validMask = ~whiteMask;

    features = struct();

    numBins = 12;
    R = pieceImg(:,:,1); G = pieceImg(:,:,2); B = pieceImg(:,:,3);

    if sum(validMask(:)) > 30
        features.histR = histcounts(R(validMask), 0:256/numBins:256, 'Normalization', 'probability')';
        features.histG = histcounts(G(validMask), 0:256/numBins:256, 'Normalization', 'probability')';
        features.histB = histcounts(B(validMask), 0:256/numBins:256, 'Normalization', 'probability')';

        for c = 1:3
            ch = imgDouble(:,:,c);
            features.meanColor(c) = mean(ch(validMask));
        end
    else
        features.histR = ones(numBins, 1) / numBins;
        features.histG = ones(numBins, 1) / numBins;
        features.histB = ones(numBins, 1) / numBins;
        features.meanColor = [0.5, 0.5, 0.5];
    end

    % Side colors
    [h, w, ~] = size(pieceImg);
    sw = max(3, round(min(h, w) * 0.1));

    features.topColor = sampleMasked(imgDouble(1:min(sw,h), :, :), validMask(1:min(sw,h), :));
    features.bottomColor = sampleMasked(imgDouble(max(1,h-sw+1):h, :, :), validMask(max(1,h-sw+1):h, :));
    features.leftColor = sampleMasked(imgDouble(:, 1:min(sw,w), :), validMask(:, 1:min(sw,w)));
    features.rightColor = sampleMasked(imgDouble(:, max(1,w-sw+1):w, :), validMask(:, max(1,w-sw+1):w));
end

function color = sampleMasked(region, mask)
    if sum(mask(:)) < 5
        color = [0.5, 0.5, 0.5];
        return;
    end
    color = zeros(1, 3);
    for c = 1:3
        ch = region(:,:,c);
        color(c) = mean(ch(mask));
    end
end

%% CALCULATE MATCH SCORE
function score = calculateMatchScore(holeFeatures, pieceFeatures)
    % Histogram similarity
    histSim = (sum(min(holeFeatures.histR, pieceFeatures.histR)) + ...
               sum(min(holeFeatures.histG, pieceFeatures.histG)) + ...
               sum(min(holeFeatures.histB, pieceFeatures.histB))) / 3;

    % Mean color similarity
    meanDist = norm(holeFeatures.meanColor - pieceFeatures.meanColor);
    meanSim = max(0, 1 - meanDist / sqrt(3));

    % Side color matching
    sides = {'top', 'bottom', 'left', 'right'};
    sideSim = 0;
    for i = 1:4
        hField = [sides{i} 'Color'];
        pField = [sides{i} 'Color'];
        if isfield(holeFeatures, hField) && isfield(pieceFeatures, pField)
            dist = norm(holeFeatures.(hField) - pieceFeatures.(pField));
            sideSim = sideSim + max(0, 1 - dist / sqrt(3));
        else
            sideSim = sideSim + 0.5;
        end
    end
    sideSim = sideSim / 4;

    % Combined score
    score = 100 * (0.25 * histSim + 0.35 * meanSim + 0.40 * sideSim);
end
