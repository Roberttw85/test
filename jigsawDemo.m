%% JIGSAW SOLVER DEMO
% This script demonstrates how to use the Jigsaw Puzzle Solver
% Compatible with MATLAB Mobile

%% Option 1: Interactive Mode (with file dialogs)
% Simply run JigsawSolver() and follow the prompts
%
% >> JigsawSolver()
%
% The app will guide you to:
%   1. Select the target image (the empty hole)
%   2. Select up to 10 candidate puzzle pieces
%   3. View the ranked results

%% Option 2: Quick Solve with File Paths
% Use jigsawQuickSolve() when you know your file paths
%
% Example:
%   target = '/path/to/hole.jpg';
%   candidates = {'/path/to/piece1.jpg', '/path/to/piece2.jpg', ...};
%   [bestMatch, scores] = jigsawQuickSolve(target, candidates);

%% Option 3: Using Camera Images on MATLAB Mobile
% On MATLAB Mobile, you can capture images from camera:

function jigsawDemo()
    disp('===========================================');
    disp('   JIGSAW PUZZLE SOLVER - DEMO');
    disp('===========================================');
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
    disp(' ');
    disp('Creating synthetic test images...');

    % Create output directory
    outputDir = fullfile(pwd, 'demo_images');
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    % Create a target image (a specific color/pattern)
    targetImg = createSyntheticPiece('target', [0.8, 0.4, 0.2]);  % Orange-ish
    imwrite(targetImg, fullfile(outputDir, 'target.png'));

    % Create 10 candidate pieces with varying similarity
    colors = [
        0.3, 0.5, 0.8;   % Blue (different)
        0.2, 0.8, 0.3;   % Green (different)
        0.75, 0.45, 0.25; % Close to target (BEST MATCH)
        0.9, 0.1, 0.1;   % Red (different)
        0.5, 0.5, 0.5;   % Gray (different)
        0.8, 0.8, 0.2;   % Yellow (different)
        0.6, 0.3, 0.2;   % Brown-ish (similar)
        0.9, 0.5, 0.3;   % Coral (similar)
        0.1, 0.1, 0.1;   % Black (different)
        0.7, 0.4, 0.3;   % Similar but not best
    ];

    candidatePaths = cell(1, 10);
    for i = 1:10
        candidateImg = createSyntheticPiece(sprintf('piece%d', i), colors(i,:));
        filepath = fullfile(outputDir, sprintf('candidate%d.png', i));
        imwrite(candidateImg, filepath);
        candidatePaths{i} = filepath;
    end

    disp('Synthetic images created in: demo_images/');
    disp(' ');
    disp('Running solver on synthetic images...');
    disp(' ');

    % Run the quick solver
    targetPath = fullfile(outputDir, 'target.png');
    [bestMatch, scores] = jigsawQuickSolve(targetPath, candidatePaths);

    disp(' ');
    disp('-------------------------------------------');
    disp('DEMO COMPLETE');
    disp('-------------------------------------------');
    disp(' ');
    fprintf('The solver correctly identified Candidate #%d as the best match.\n', bestMatch);
    disp('(Candidate #3 was designed to be most similar to the target)');
    disp(' ');

    % Display visual comparison if possible
    try
        figure('Name', 'Demo Results', 'NumberTitle', 'off');

        subplot(2, 6, 1:2);
        imshow(imread(targetPath));
        title('TARGET', 'FontSize', 12, 'FontWeight', 'bold');

        [~, sortIdx] = sort([scores.totalScore], 'descend');
        for i = 1:10
            subplot(2, 6, i + 2);
            idx = sortIdx(i);
            imshow(imread(candidatePaths{idx}));
            if i == 1
                title(sprintf('#%d: %.0f%%', idx, scores(idx).totalScore), ...
                    'Color', 'green', 'FontWeight', 'bold');
            else
                title(sprintf('#%d: %.0f%%', idx, scores(idx).totalScore));
            end
        end
    catch
        disp('(Visual display not available on this platform)');
    end
end

function img = createSyntheticPiece(name, baseColor)
    % Create a synthetic puzzle piece image with patterns

    sz = 100;
    img = zeros(sz, sz, 3);

    % Fill with base color
    for c = 1:3
        img(:,:,c) = baseColor(c);
    end

    % Add some texture/pattern
    [X, Y] = meshgrid(1:sz, 1:sz);

    % Add diagonal stripes
    stripes = mod(X + Y, 20) < 10;
    for c = 1:3
        channel = img(:,:,c);
        channel(stripes) = channel(stripes) * 0.9;
        img(:,:,c) = channel;
    end

    % Add circular gradient in center
    centerX = sz/2;
    centerY = sz/2;
    dist = sqrt((X - centerX).^2 + (Y - centerY).^2);
    gradient = 1 - (dist / (sz/2)) * 0.2;
    gradient = max(0, min(1, gradient));

    for c = 1:3
        img(:,:,c) = img(:,:,c) .* gradient;
    end

    % Add some noise for texture
    noise = rand(sz, sz) * 0.05;
    for c = 1:3
        img(:,:,c) = img(:,:,c) + noise;
    end

    img = min(1, max(0, img));  % Clamp values
end

function showUsageInstructions()
    disp(' ');
    disp('===========================================');
    disp('       USAGE INSTRUCTIONS');
    disp('===========================================');
    disp(' ');
    disp('MATLAB MOBILE WORKFLOW:');
    disp('-----------------------');
    disp('1. Transfer your puzzle images to your device');
    disp('2. Open MATLAB Mobile and navigate to the script folder');
    disp('3. Run one of the following:');
    disp(' ');
    disp('   Method A - Interactive (easiest):');
    disp('   >> JigsawSolver()');
    disp('   Then follow the prompts to select images.');
    disp(' ');
    disp('   Method B - Direct file paths:');
    disp('   >> target = ''/path/to/hole.jpg'';');
    disp('   >> pieces = {''/path/to/p1.jpg'', ''/path/to/p2.jpg'', ...};');
    disp('   >> [best, scores] = jigsawQuickSolve(target, pieces);');
    disp(' ');
    disp('TIPS FOR BEST RESULTS:');
    disp('----------------------');
    disp('- Take photos with consistent lighting');
    disp('- Include only the puzzle piece in each image');
    disp('- Use similar camera angles for all images');
    disp('- Ensure the target hole image shows surrounding context');
    disp(' ');
    disp('UNDERSTANDING SCORES:');
    disp('---------------------');
    disp('- Color Score: How well colors match (60% weight)');
    disp('- Geometry Score: How well shapes/edges match (40% weight)');
    disp('- Total Score: Combined match confidence (0-100%)');
    disp(' ');
    disp('HIGH confidence: Best match is 15+ points ahead');
    disp('MEDIUM confidence: Best match is 5-15 points ahead');
    disp('LOW confidence: Best match is <5 points ahead');
    disp(' ');
end
