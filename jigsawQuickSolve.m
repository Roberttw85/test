function [bestMatch, allScores] = jigsawQuickSolve(targetPath, candidatePaths)
%JIGSAWQUICKSOLVE Quick jigsaw puzzle solver for MATLAB Mobile
%   Detects multiple pieces in each candidate photo and finds the best match
%
%   Usage:
%       [bestMatch, scores] = jigsawQuickSolve(targetPath, candidatePaths)
%
%   Inputs:
%       targetPath     - Path to the target image (hole to fill)
%       candidatePaths - Cell array of paths to candidate photos
%                        (each photo can contain multiple puzzle pieces)
%
%   Outputs:
%       bestMatch - Structure with info about the best matching piece:
%                   .photoIndex  - Which photo contains the piece
%                   .pieceIndex  - Which piece within that photo
%                   .score       - Match score (0-100)
%                   .pieceImage  - Cropped image of the matching piece
%       allScores - Structure array with scores for all detected pieces
%
%   Example:
%       target = 'images/hole.jpg';
%       photos = {'images/pieces_photo1.jpg', 'images/pieces_photo2.jpg'};
%       [best, scores] = jigsawQuickSolve(target, photos);
%       fprintf('Best match: Photo #%d, Piece #%d (Score: %.1f%%)\n', ...
%           best.photoIndex, best.pieceIndex, best.score);

    %% Validate inputs
    if ~exist(targetPath, 'file')
        error('Target image not found: %s', targetPath);
    end

    if ~iscell(candidatePaths)
        error('candidatePaths must be a cell array of file paths');
    end

    %% Load target image
    fprintf('Loading target image...\n');
    targetImg = loadAndPreprocess(targetPath, 512);

    %% Process each candidate photo and detect pieces
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

        % Detect pieces in this photo
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
    fprintf('\nTotal pieces detected: %d\n', totalPieces);

    if totalPieces == 0
        error('No pieces detected in any photo. Check image quality and lighting.');
    end

    %% Analyze each piece against target
    fprintf('Analyzing pieces...\n');

    targetFeatures = quickExtractFeatures(targetImg);
    allScores = struct('pieceIndex', {}, 'photoIndex', {}, 'localPieceIndex', {}, ...
                       'colorScore', {}, 'geometryScore', {}, 'totalScore', {});

    for i = 1:totalPieces
        candidateFeatures = quickExtractFeatures(allPieces{i});

        colorScore = quickColorScore(targetFeatures, candidateFeatures);
        geometryScore = quickGeometryScore(targetFeatures, candidateFeatures);
        totalScore = 0.6 * colorScore + 0.4 * geometryScore;

        allScores(i).pieceIndex = i;
        allScores(i).photoIndex = pieceInfo(i).photoIndex;
        allScores(i).localPieceIndex = pieceInfo(i).pieceIndex;
        allScores(i).colorScore = colorScore;
        allScores(i).geometryScore = geometryScore;
        allScores(i).totalScore = totalScore;
        allScores(i).boundingBox = pieceInfo(i).boundingBox;

        fprintf('  Piece %d (Photo %d, #%d): %.1f%%\n', ...
            i, pieceInfo(i).photoIndex, pieceInfo(i).pieceIndex, totalScore);
    end

    %% Find best match
    [bestScore, bestIdx] = max([allScores.totalScore]);

    bestMatch.photoIndex = allScores(bestIdx).photoIndex;
    bestMatch.pieceIndex = allScores(bestIdx).localPieceIndex;
    bestMatch.globalIndex = bestIdx;
    bestMatch.score = bestScore;
    bestMatch.colorScore = allScores(bestIdx).colorScore;
    bestMatch.geometryScore = allScores(bestIdx).geometryScore;
    bestMatch.pieceImage = allPieces{bestIdx};
    bestMatch.boundingBox = allScores(bestIdx).boundingBox;
    bestMatch.photoPath = pieceInfo(bestIdx).photoPath;

    fprintf('\n=== RESULT ===\n');
    fprintf('Best match: Photo #%d, Piece #%d\n', bestMatch.photoIndex, bestMatch.pieceIndex);
    fprintf('Score: %.1f%% (Color: %.1f%%, Geometry: %.1f%%)\n', ...
        bestMatch.score, bestMatch.colorScore, bestMatch.geometryScore);
    fprintf('Photo path: %s\n', bestMatch.photoPath);

    % Confidence
    if totalPieces > 1
        sortedScores = sort([allScores.totalScore], 'descend');
        scoreDiff = sortedScores(1) - sortedScores(2);
        if scoreDiff > 15
            fprintf('Confidence: HIGH (%.1f points ahead)\n', scoreDiff);
        elseif scoreDiff > 5
            fprintf('Confidence: MEDIUM (%.1f points ahead)\n', scoreDiff);
        else
            fprintf('Confidence: LOW (%.1f points ahead)\n', scoreDiff);
        end
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
        scale = maxSize / max(h, w);
        img = imresize(img, scale);
    end
end

%% QUICK PIECE DETECTION
function [pieces, boundingBoxes] = detectPiecesQuick(img)
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

    % Threshold
    threshold = max(0.12, graythresh(colorDist) * 0.7);
    mask = colorDist > threshold;

    % Clean up
    mask = imfill(mask, 'holes');
    minArea = round(h * w * 0.003);
    mask = bwareaopen(mask, minArea);
    mask = imclose(mask, strel('disk', 4));
    mask = imerode(mask, strel('disk', 2));
    mask = imdilate(mask, strel('disk', 2));

    % Find connected components
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

        % Skip very elongated shapes
        aspectRatio = max(bw, bh) / max(1, min(bw, bh));
        if aspectRatio > 5
            continue;
        end

        % Extract with padding
        pad = 3;
        x1 = max(1, x - pad);
        y1 = max(1, y - pad);
        x2 = min(w, x + bw + pad);
        y2 = min(h, y + bh + pad);

        pieceImg = img(y1:y2, x1:x2, :);

        % Create piece mask
        pieceMask = false(h, w);
        pieceMask(stats(i).PixelIdxList) = true;
        pieceMaskCropped = pieceMask(y1:y2, x1:x2);

        % Apply mask
        for c = 1:3
            ch = pieceImg(:,:,c);
            ch(~pieceMaskCropped) = 255;
            pieceImg(:,:,c) = ch;
        end

        % Resize for analysis
        [ph, pw, ~] = size(pieceImg);
        if max(ph, pw) > 200
            scale = 200 / max(ph, pw);
            pieceImg = imresize(pieceImg, scale);
        end

        pieces{end+1} = pieceImg;
        boundingBoxes{end+1} = [x1, y1, x2-x1, y2-y1];
    end

    % Fallback if no pieces found
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

    % Use saturation and value
    sat = imgHSV(:,:,2);
    val = imgHSV(:,:,3);

    % Pieces typically have higher saturation
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

        [ph, pw, ~] = size(pieceImg);
        if max(ph, pw) > 200
            pieceImg = imresize(pieceImg, 200 / max(ph, pw));
        end

        pieces{end+1} = pieceImg;
        boundingBoxes{end+1} = [x1, y1, x2-x1, y2-y1];
    end
end

%% QUICK FEATURE EXTRACTION
function features = quickExtractFeatures(img)
    imgDouble = im2double(img);

    % Exclude white background
    whiteMask = all(imgDouble > 0.95, 3);
    validMask = ~whiteMask;

    % Color histograms
    numBins = 16;
    if sum(validMask(:)) > 50
        features.histR = histcounts(img(repmat(validMask, [1,1,1]) & (repmat((1:size(img,3))==1, [size(img,1), size(img,2), 1])), ...
            0:256/numBins:256, 'Normalization', 'probability')';
        R = img(:,:,1); G = img(:,:,2); B = img(:,:,3);
        features.histR = histcounts(R(validMask), 0:256/numBins:256, 'Normalization', 'probability')';
        features.histG = histcounts(G(validMask), 0:256/numBins:256, 'Normalization', 'probability')';
        features.histB = histcounts(B(validMask), 0:256/numBins:256, 'Normalization', 'probability')';
    else
        features.histR = imhist(img(:,:,1), numBins) / numel(img(:,:,1));
        features.histG = imhist(img(:,:,2), numBins) / numel(img(:,:,2));
        features.histB = imhist(img(:,:,3), numBins) / numel(img(:,:,3));
    end

    % Mean color
    for c = 1:3
        ch = imgDouble(:,:,c);
        if sum(validMask(:)) > 50
            features.meanColor(c) = mean(ch(validMask));
        else
            features.meanColor(c) = mean(ch(:));
        end
    end

    % Geometry features
    imgGray = rgb2gray(img);
    imgGrayD = im2double(imgGray);

    [Gx, Gy] = gradient(imgGrayD);
    gradMag = sqrt(Gx.^2 + Gy.^2);
    gradDir = atan2(Gy, Gx);

    mask = gradMag > 0.05;
    if sum(mask(:)) > 10
        features.edgeHist = histcounts(gradDir(mask), linspace(-pi, pi, 9), 'Normalization', 'probability');
    else
        features.edgeHist = zeros(1, 8);
    end

    features.contrast = std(imgGrayD(:));
    features.smoothness = 1 - mean(gradMag(:));
end

%% QUICK COLOR SCORE
function score = quickColorScore(f1, f2)
    histSim = (sum(min(f1.histR, f2.histR)) + ...
               sum(min(f1.histG, f2.histG)) + ...
               sum(min(f1.histB, f2.histB))) / 3;

    meanDist = norm(f1.meanColor - f2.meanColor);
    meanSim = max(0, 1 - meanDist / sqrt(3));

    score = 100 * (0.6 * histSim + 0.4 * meanSim);
end

%% QUICK GEOMETRY SCORE
function score = quickGeometryScore(f1, f2)
    edgeSim = sum(min(f1.edgeHist, f2.edgeHist));

    contrastDiff = abs(f1.contrast - f2.contrast);
    contrastSim = max(0, 1 - contrastDiff * 4);

    smoothDiff = abs(f1.smoothness - f2.smoothness);
    smoothSim = max(0, 1 - smoothDiff * 4);

    score = 100 * (0.5 * edgeSim + 0.25 * contrastSim + 0.25 * smoothSim);
end
