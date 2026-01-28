%% JIGSAW SOLVER DEMO
% This script demonstrates how to use the Jigsaw Puzzle Solver
% Now supports multiple pieces per photo!
%
% Compatible with MATLAB Mobile

function jigsawDemo()
    disp('===========================================');
    disp('   JIGSAW PUZZLE SOLVER - DEMO');
    disp('===========================================');
    disp(' ');
    disp('NEW: Each photo can contain multiple pieces!');
    disp('The solver will detect and analyze each piece.');
    disp(' ');
    disp('Choose a demo option:');
    disp('  1. Run interactive solver (JigsawSolver)');
    disp('  2. Create sample test with synthetic images');
    disp('  3. Show usage instructions');
    disp(' ');

    choice = input('Enter choice (1-3): ');

    switch choice
        case 1
            JigsawSolver();

        case 2
            runSyntheticDemo();

        case 3
            showUsageInstructions();

        otherwise
            disp('Invalid choice. Please run jigsawDemo() again.');
    end
end

function runSyntheticDemo()
    % Create synthetic test images to demonstrate the solver
    % Creates photos with MULTIPLE pieces each
    disp(' ');
    disp('Creating synthetic test images...');
    disp('Each photo will contain multiple puzzle pieces.');

    % Create output directory
    outputDir = fullfile(pwd, 'demo_images');
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    % Create a target image (the piece we're looking for)
    targetColor = [0.8, 0.4, 0.2];  % Orange-brown
    targetImg = createSyntheticPiece(targetColor, 'wavy');
    imwrite(targetImg, fullfile(outputDir, 'target.png'));
    disp('Created target image (orange-brown piece)');

    % Create 3 photos, each with multiple pieces
    % Photo 1: 4 pieces (none matching)
    photo1 = createPhotoWithPieces({
        {[0.3, 0.5, 0.8], 'zigzag'},   % Blue
        {[0.2, 0.8, 0.3], 'straight'}, % Green
        {[0.9, 0.1, 0.1], 'wavy'},     % Red
        {[0.5, 0.5, 0.5], 'zigzag'}    % Gray
    }, [400, 600]);
    imwrite(photo1, fullfile(outputDir, 'photo1.png'));
    disp('Created photo1.png with 4 pieces (no match)');

    % Photo 2: 3 pieces (one similar, one best match)
    photo2 = createPhotoWithPieces({
        {[0.75, 0.42, 0.22], 'wavy'},  % BEST MATCH - very close to target
        {[0.8, 0.8, 0.2], 'straight'}, % Yellow
        {[0.6, 0.3, 0.2], 'zigzag'}    % Brown (similar but not best)
    }, [400, 500]);
    imwrite(photo2, fullfile(outputDir, 'photo2.png'));
    disp('Created photo2.png with 3 pieces (contains BEST MATCH)');

    % Photo 3: 3 pieces (some similar)
    photo3 = createPhotoWithPieces({
        {[0.1, 0.1, 0.1], 'straight'}, % Black
        {[0.7, 0.4, 0.3], 'wavy'},     % Similar
        {[0.9, 0.5, 0.3], 'zigzag'}    % Coral
    }, [400, 500]);
    imwrite(photo3, fullfile(outputDir, 'photo3.png'));
    disp('Created photo3.png with 3 pieces (some similar)');

    disp(' ');
    disp('Synthetic images created in: demo_images/');
    disp(' ');
    disp('Running solver on synthetic images...');
    disp(' ');

    % Run the quick solver
    targetPath = fullfile(outputDir, 'target.png');
    photoPaths = {
        fullfile(outputDir, 'photo1.png'),
        fullfile(outputDir, 'photo2.png'),
        fullfile(outputDir, 'photo3.png')
    };

    [bestMatch, scores] = jigsawQuickSolve(targetPath, photoPaths);

    disp(' ');
    disp('-------------------------------------------');
    disp('DEMO COMPLETE');
    disp('-------------------------------------------');
    disp(' ');
    fprintf('The solver found the best match in Photo #%d, Piece #%d\n', ...
        bestMatch.photoIndex, bestMatch.pieceIndex);
    disp('(The best matching piece was placed in photo2.png as piece #1)');
    disp(' ');

    % Display visual comparison if possible
    try
        figure('Name', 'Demo Results', 'NumberTitle', 'off');

        % Target
        subplot(2, 4, 1);
        imshow(imread(targetPath));
        title('TARGET', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'blue');

        % Best match piece
        subplot(2, 4, 2);
        imshow(bestMatch.pieceImage);
        title(sprintf('BEST MATCH\nPhoto %d, Piece %d\nScore: %.0f%%', ...
            bestMatch.photoIndex, bestMatch.pieceIndex, bestMatch.score), ...
            'FontSize', 10, 'FontWeight', 'bold', 'Color', 'green');

        % Show all photos
        subplot(2, 4, 5);
        imshow(imread(photoPaths{1}));
        title('Photo 1', 'FontSize', 10);

        subplot(2, 4, 6);
        img2 = imread(photoPaths{2});
        imshow(img2);
        hold on;
        if bestMatch.photoIndex == 2
            rectangle('Position', bestMatch.boundingBox, 'EdgeColor', 'green', 'LineWidth', 2);
        end
        title('Photo 2 (has match)', 'FontSize', 10, 'Color', [0, 0.5, 0]);
        hold off;

        subplot(2, 4, 7);
        imshow(imread(photoPaths{3}));
        title('Photo 3', 'FontSize', 10);

        % Top 5 candidates
        subplot(2, 4, [3, 4, 8]);
        [~, sortIdx] = sort([scores.totalScore], 'descend');
        numShow = min(5, length(scores));

        barData = zeros(numShow, 1);
        labels = cell(numShow, 1);
        for i = 1:numShow
            idx = sortIdx(i);
            barData(i) = scores(idx).totalScore;
            labels{i} = sprintf('P%d-#%d', scores(idx).photoIndex, scores(idx).localPieceIndex);
        end

        barh(barData);
        set(gca, 'YTickLabel', labels, 'YTick', 1:numShow);
        xlabel('Match Score (%)');
        title('Top 5 Candidates', 'FontWeight', 'bold');
        xlim([0, 100]);
        grid on;

        set(gcf, 'Position', [50, 100, 1000, 600]);

    catch ME
        disp('(Visual display not available on this platform)');
        disp(['Reason: ' ME.message]);
    end
end

function img = createSyntheticPiece(baseColor, edgeType)
    % Create a synthetic puzzle piece image with patterns

    sz = 80;
    img = zeros(sz, sz, 3);

    % Fill with base color
    for c = 1:3
        img(:,:,c) = baseColor(c);
    end

    % Add texture pattern based on edge type
    [X, Y] = meshgrid(1:sz, 1:sz);

    switch edgeType
        case 'wavy'
            pattern = sin(X/5) .* cos(Y/5) * 0.1;
        case 'zigzag'
            pattern = mod(X + Y, 15) / 150;
        case 'straight'
            pattern = mod(X, 10) / 100;
        otherwise
            pattern = zeros(sz);
    end

    for c = 1:3
        img(:,:,c) = img(:,:,c) + pattern;
    end

    % Add circular gradient
    centerX = sz/2;
    centerY = sz/2;
    dist = sqrt((X - centerX).^2 + (Y - centerY).^2);
    gradient = 1 - (dist / (sz/2)) * 0.15;
    gradient = max(0, min(1, gradient));

    for c = 1:3
        img(:,:,c) = img(:,:,c) .* gradient;
    end

    % Add slight noise
    noise = rand(sz, sz) * 0.03;
    for c = 1:3
        img(:,:,c) = img(:,:,c) + noise;
    end

    img = min(1, max(0, img));
end

function photo = createPhotoWithPieces(pieceSpecs, photoSize)
    % Create a photo containing multiple puzzle pieces on a background
    % pieceSpecs: cell array of {color, edgeType} pairs
    % photoSize: [height, width] of the photo

    h = photoSize(1);
    w = photoSize(2);

    % Create light gray background
    photo = ones(h, w, 3) * 0.85;

    % Add slight background texture
    bgNoise = rand(h, w) * 0.05;
    for c = 1:3
        photo(:,:,c) = photo(:,:,c) + bgNoise;
    end

    numPieces = length(pieceSpecs);

    % Calculate grid layout for pieces
    cols = ceil(sqrt(numPieces));
    rows = ceil(numPieces / cols);

    cellW = floor(w / cols);
    cellH = floor(h / rows);

    pieceIdx = 1;
    for row = 1:rows
        for col = 1:cols
            if pieceIdx > numPieces
                break;
            end

            % Create piece
            spec = pieceSpecs{pieceIdx};
            piece = createSyntheticPiece(spec{1}, spec{2});
            [pH, pW, ~] = size(piece);

            % Calculate position with some random offset
            baseX = (col - 1) * cellW + round(cellW/2 - pW/2);
            baseY = (row - 1) * cellH + round(cellH/2 - pH/2);

            % Add random offset (but keep within bounds)
            offsetX = randi([-15, 15]);
            offsetY = randi([-15, 15]);

            startX = max(1, min(w - pW, baseX + offsetX));
            startY = max(1, min(h - pH, baseY + offsetY));

            % Place piece on photo
            photo(startY:startY+pH-1, startX:startX+pW-1, :) = piece;

            pieceIdx = pieceIdx + 1;
        end
    end

    photo = min(1, max(0, photo));
end

function showUsageInstructions()
    disp(' ');
    disp('===========================================');
    disp('       USAGE INSTRUCTIONS');
    disp('===========================================');
    disp(' ');
    disp('NEW FEATURE: Multi-Piece Detection!');
    disp('Each candidate photo can contain multiple puzzle pieces.');
    disp('The solver automatically detects and analyzes each piece.');
    disp(' ');
    disp('MATLAB MOBILE WORKFLOW:');
    disp('-----------------------');
    disp('1. Take a photo of the empty puzzle hole (target)');
    disp('2. Take photos of your puzzle pieces (multiple pieces per photo OK!)');
    disp('3. Transfer photos to your device or use MATLAB Mobile camera');
    disp('4. Run one of the following:');
    disp(' ');
    disp('   Method A - Interactive (easiest):');
    disp('   >> JigsawSolver()');
    disp('   Then follow the prompts to select images.');
    disp(' ');
    disp('   Method B - Direct file paths:');
    disp('   >> target = ''/path/to/hole.jpg'';');
    disp('   >> photos = {''/path/to/pieces1.jpg'', ''/path/to/pieces2.jpg''};');
    disp('   >> [best, scores] = jigsawQuickSolve(target, photos);');
    disp(' ');
    disp('TIPS FOR BEST PIECE DETECTION:');
    disp('------------------------------');
    disp('- Use a plain, uniform background (white, black, or solid color)');
    disp('- Ensure good lighting without harsh shadows');
    disp('- Space pieces apart so they don''t touch');
    disp('- Keep camera parallel to the surface (avoid angles)');
    disp('- Pieces should be 1-50% of the image area each');
    disp(' ');
    disp('UNDERSTANDING OUTPUT:');
    disp('---------------------');
    disp('The solver tells you:');
    disp('  - Which PHOTO contains the matching piece');
    disp('  - Which PIECE number within that photo');
    disp('  - The matching piece is highlighted in green');
    disp(' ');
    disp('UNDERSTANDING SCORES:');
    disp('---------------------');
    disp('- Color Score: How well colors match (60% of total)');
    disp('- Geometry Score: How well patterns/edges match (40% of total)');
    disp('- Total Score: Combined match confidence (0-100%)');
    disp(' ');
    disp('CONFIDENCE LEVELS:');
    disp('  HIGH   - Best match is 15+ points ahead (reliable)');
    disp('  MEDIUM - Best match is 5-15 points ahead (likely correct)');
    disp('  LOW    - Best match is <5 points ahead (uncertain)');
    disp(' ');
end
