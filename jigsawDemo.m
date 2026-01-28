%% JIGSAW SOLVER DEMO
% Demonstrates the Jigsaw Puzzle Solver
% Now handles: puzzles with missing pieces (holes) + photos with multiple pieces
%
% Compatible with MATLAB Mobile

function jigsawDemo()
    disp('===========================================');
    disp('   JIGSAW PUZZLE SOLVER - DEMO');
    disp('===========================================');
    disp(' ');
    disp('This solver finds pieces to fill holes in your puzzle!');
    disp(' ');
    disp('How it works:');
    disp('  1. You provide a photo of your puzzle (with missing pieces)');
    disp('  2. You provide photos of loose pieces (multiple per photo OK)');
    disp('  3. The solver matches pieces to holes by edge colors');
    disp(' ');
    disp('Choose a demo option:');
    disp('  1. Run interactive solver');
    disp('  2. Run synthetic demo (creates test images)');
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
            disp('Invalid choice.');
    end
end

function runSyntheticDemo()
    disp(' ');
    disp('Creating synthetic test images...');

    outputDir = fullfile(pwd, 'demo_images');
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    %% Create puzzle with holes
    puzzleSize = [400, 500];
    [puzzleImg, holeInfo] = createPuzzleWithHoles(puzzleSize, 2);
    imwrite(puzzleImg, fullfile(outputDir, 'puzzle.png'));
    disp('Created puzzle.png with 2 missing pieces (holes)');

    %% Create photos with candidate pieces
    % Photo 1: 4 pieces (includes 1 matching piece for hole 1)
    pieceColors1 = {
        holeInfo(1).matchColor,     % Match for hole 1
        [0.3, 0.5, 0.8],            % Blue (wrong)
        [0.2, 0.7, 0.3],            % Green (wrong)
        [0.8, 0.8, 0.2]             % Yellow (wrong)
    };
    photo1 = createPhotoWithPieces(pieceColors1, [350, 500]);
    imwrite(photo1, fullfile(outputDir, 'pieces_photo1.png'));
    disp('Created pieces_photo1.png with 4 pieces (1 matches hole 1)');

    % Photo 2: 3 pieces (includes 1 matching piece for hole 2)
    pieceColors2 = {
        [0.5, 0.5, 0.5],            % Gray (wrong)
        holeInfo(2).matchColor,     % Match for hole 2
        [0.9, 0.3, 0.3]             % Red (wrong)
    };
    photo2 = createPhotoWithPieces(pieceColors2, [350, 450]);
    imwrite(photo2, fullfile(outputDir, 'pieces_photo2.png'));
    disp('Created pieces_photo2.png with 3 pieces (1 matches hole 2)');

    disp(' ');
    disp('Running solver...');
    disp(' ');

    % Run solver
    puzzlePath = fullfile(outputDir, 'puzzle.png');
    photoPaths = {
        fullfile(outputDir, 'pieces_photo1.png'),
        fullfile(outputDir, 'pieces_photo2.png')
    };

    [matches, ~] = jigsawQuickSolve(puzzlePath, photoPaths);

    disp(' ');
    disp('-------------------------------------------');
    disp('DEMO COMPLETE');
    disp('-------------------------------------------');
    disp(' ');

    for i = 1:length(matches)
        fprintf('Hole %d matched to Photo %d, Piece %d (Score: %.1f%%)\n', ...
            i, matches(i).photoIndex, matches(i).pieceIndex, matches(i).score);
    end

    disp(' ');
    disp('Expected: Hole 1 -> Photo 1, Piece 1');
    disp('Expected: Hole 2 -> Photo 2, Piece 2');

    % Visual display
    try
        figure('Name', 'Demo Results', 'NumberTitle', 'off');

        subplot(2, 3, 1);
        imshow(imread(puzzlePath));
        title('Puzzle with Holes', 'FontWeight', 'bold');

        for i = 1:min(2, length(matches))
            subplot(2, 3, 1 + i);
            imshow(matches(i).pieceImage);
            title(sprintf('Hole %d Match\nPhoto %d, Piece %d', ...
                i, matches(i).photoIndex, matches(i).pieceIndex), 'Color', [0, 0.5, 0]);
        end

        subplot(2, 3, 4);
        imshow(imread(photoPaths{1}));
        title('Photo 1', 'FontSize', 10);

        subplot(2, 3, 5);
        imshow(imread(photoPaths{2}));
        title('Photo 2', 'FontSize', 10);

        set(gcf, 'Position', [50, 100, 1000, 600]);
    catch
        disp('(Visual display not available)');
    end
end

function [puzzleImg, holeInfo] = createPuzzleWithHoles(sz, numHoles)
    h = sz(1); w = sz(2);

    % Create colorful puzzle base
    puzzleImg = zeros(h, w, 3);

    % Create gradient background for puzzle
    [X, Y] = meshgrid(1:w, 1:h);
    puzzleImg(:,:,1) = 0.4 + 0.3 * (X / w);      % Red gradient
    puzzleImg(:,:,2) = 0.3 + 0.2 * (Y / h);      % Green gradient
    puzzleImg(:,:,3) = 0.5 - 0.2 * (X / w);      % Blue gradient

    % Add some texture
    noise = rand(h, w) * 0.1;
    for c = 1:3
        puzzleImg(:,:,c) = puzzleImg(:,:,c) + noise;
    end

    % Add grid lines (puzzle piece edges)
    gridSpacing = 50;
    for x = gridSpacing:gridSpacing:w
        puzzleImg(:, max(1,x-1):min(w,x+1), :) = puzzleImg(:, max(1,x-1):min(w,x+1), :) * 0.7;
    end
    for y = gridSpacing:gridSpacing:h
        puzzleImg(max(1,y-1):min(h,y+1), :, :) = puzzleImg(max(1,y-1):min(h,y+1), :, :) * 0.7;
    end

    holeInfo = struct();

    % Create holes (dark regions representing missing pieces)
    holePositions = [
        round(h * 0.3), round(w * 0.3);
        round(h * 0.6), round(w * 0.7)
    ];

    holeSize = [60, 70];

    for i = 1:min(numHoles, size(holePositions, 1))
        cy = holePositions(i, 1);
        cx = holePositions(i, 2);

        y1 = max(1, cy - holeSize(1)/2);
        y2 = min(h, cy + holeSize(1)/2);
        x1 = max(1, cx - holeSize(2)/2);
        x2 = min(w, cx + holeSize(2)/2);

        % Sample edge colors before creating hole
        edgeColors = struct();
        edgeColors.top = squeeze(mean(puzzleImg(max(1,y1-5):y1, x1:x2, :), [1, 2]))';
        edgeColors.bottom = squeeze(mean(puzzleImg(y2:min(h,y2+5), x1:x2, :), [1, 2]))';
        edgeColors.left = squeeze(mean(puzzleImg(y1:y2, max(1,x1-5):x1, :), [1, 2]))';
        edgeColors.right = squeeze(mean(puzzleImg(y1:y2, x2:min(w,x2+5), :), [1, 2]))';

        % The matching piece color should match these edges
        holeInfo(i).edgeColors = edgeColors;
        holeInfo(i).matchColor = (edgeColors.top + edgeColors.bottom + edgeColors.left + edgeColors.right) / 4;
        holeInfo(i).position = [y1, x1, y2-y1, x2-x1];

        % Create dark hole (simulating table showing through)
        puzzleImg(y1:y2, x1:x2, 1) = 0.15;
        puzzleImg(y1:y2, x1:x2, 2) = 0.12;
        puzzleImg(y1:y2, x1:x2, 3) = 0.1;
    end

    puzzleImg = min(1, max(0, puzzleImg));
end

function photo = createPhotoWithPieces(pieceColors, photoSize)
    h = photoSize(1); w = photoSize(2);

    % Light background
    photo = ones(h, w, 3) * 0.85;
    photo = photo + rand(h, w, 1) * 0.05;

    numPieces = length(pieceColors);
    cols = ceil(sqrt(numPieces));
    rows = ceil(numPieces / cols);

    cellW = floor(w / cols);
    cellH = floor(h / rows);
    pieceSize = min(cellW, cellH) - 20;

    idx = 1;
    for row = 1:rows
        for col = 1:cols
            if idx > numPieces
                break;
            end

            cx = (col - 0.5) * cellW + randi([-10, 10]);
            cy = (row - 0.5) * cellH + randi([-10, 10]);

            x1 = max(1, round(cx - pieceSize/2));
            y1 = max(1, round(cy - pieceSize/2));
            x2 = min(w, round(cx + pieceSize/2));
            y2 = min(h, round(cy + pieceSize/2));

            baseColor = pieceColors{idx};
            if length(baseColor) ~= 3
                baseColor = [0.5, 0.5, 0.5];
            end

            % Create piece with texture
            pieceH = y2 - y1 + 1;
            pieceW = x2 - x1 + 1;
            [PX, PY] = meshgrid(1:pieceW, 1:pieceH);

            for c = 1:3
                piece = ones(pieceH, pieceW) * baseColor(c);
                % Add gradient
                piece = piece + (PX / pieceW - 0.5) * 0.1;
                piece = piece + (PY / pieceH - 0.5) * 0.05;
                % Add noise
                piece = piece + rand(pieceH, pieceW) * 0.05;
                photo(y1:y2, x1:x2, c) = piece;
            end

            idx = idx + 1;
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
    disp('WHAT YOU NEED:');
    disp('  1. A photo of your puzzle WITH MISSING PIECES');
    disp('     - The holes (missing areas) should be visible');
    disp('     - The table/background should show through the holes');
    disp(' ');
    disp('  2. Photos of the loose puzzle pieces');
    disp('     - Place pieces on a plain background');
    disp('     - Multiple pieces per photo is OK!');
    disp('     - Space pieces apart so they don''t touch');
    disp(' ');
    disp('HOW TO RUN:');
    disp('-----------');
    disp(' ');
    disp('Method A - Interactive:');
    disp('  >> JigsawSolver()');
    disp('  Then select your images when prompted.');
    disp(' ');
    disp('Method B - Direct paths:');
    disp('  >> puzzle = ''/path/to/puzzle_with_holes.jpg'';');
    disp('  >> pieces = {''/path/to/pieces1.jpg'', ''/path/to/pieces2.jpg''};');
    disp('  >> [matches, scores] = jigsawQuickSolve(puzzle, pieces);');
    disp(' ');
    disp('TIPS FOR BEST RESULTS:');
    disp('----------------------');
    disp('- Holes should be clearly visible (contrasting with puzzle)');
    disp('- Use consistent lighting for all photos');
    disp('- Place loose pieces on a plain, uniform background');
    disp('- Avoid shadows on the pieces');
    disp(' ');
    disp('UNDERSTANDING RESULTS:');
    disp('---------------------');
    disp('For each hole in your puzzle, the solver tells you:');
    disp('  - Which PHOTO contains the matching piece');
    disp('  - Which PIECE number in that photo');
    disp('  - Match score (higher = better match)');
    disp(' ');
    disp('Multiple connected holes are treated as one region.');
    disp('The solver matches by comparing colors around the hole');
    disp('edges with the colors of each piece.');
    disp(' ');
end
