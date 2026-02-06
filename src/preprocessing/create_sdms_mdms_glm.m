function create_sdms_mdms_glm(rootDir, subs, nRuns, nTR_run, varargin)
%CREATE_SDMS_MDMS_GLM Create BrainVoyager SDM/MDM files for GLM analysis.
%
% This function creates, for each subject and run:
%   - A BrainVoyager SDM file with:
%       * SOUND predictor (all non-silent, non-target, non-button sound trials)
%       * TARGET predictor (catch trials)
%       * constant baseline
%       * optional 6 motion predictors (X,Y,Z,RX,RY,RZ)
%   - A BrainVoyager MDM file linking VTCs and SDMs for all runs.
%
% It implements the fast event-related GLM setup described in the thesis
% (trial-wise sound regressors, convolved with a 2-gamma HRF; TR and TA
% chosen for the 7T fMRI study).[file:1][file:2]
%
% INPUTS
%   rootDir : project root directory, containing:
%               - 'Logfiles' folder with S<sub>_run<r>_log.txt files
%               - subject folders 'S<sub>' with VTC and motion SDM files[file:2]
%   subs    : vector of subject IDs, e.g. [2 3 4 5 6 7 8 9 10 11 12 13]
%   nRuns   : scalar or vector with number of runs per subject
%             (if scalar, same value is used for all subjects)[file:1]
%   nTR_run : vector with number of TRs per run (length = max(nRuns)), or
%             a matrix [nSubjects x maxRuns] if they differ per subject[file:2]
%
% OPTIONAL NAME-VALUE PAIRS
%   'TR'        : repetition time in ms (default: 2500)[file:2]
%   'TA'        : acquisition time in ms (default: 1500)
%   'HRFRes'    : HRF oversampling factor (integer, default: 5)
%   'AddMotion' : logical, include 6 motion regressors from BrainVoyager
%                 3DMC SDM (default: true)[file:2]
%   'LogDir'    : custom logfiles directory (default: fullfile(rootDir,'Logfiles'))
%   'SaveDir'   : custom output directory for SDM/MDM
%                 (default: fullfile(rootDir,'MDM_SDM'))[file:2]
%
% LOGFILE FORMAT (per row)
%   Column 1 : vowel morph value (0 for silence)
%   Column 2 : speaker morph value (0 for silence)
%   Column 3 : onset time in TR units (integer)
%   Column 4 : target flag (1 = catch trial, 0 otherwise)
%   Column 5 : button press flag (1 = button press, 0 otherwise)[file:2]
%
% EXAMPLE
%   rootDir = 'D:\CATMORPH';
%   subs    = [2 3 4 5 6 7 8 9 10 11 12 13];
%   nRuns   = 6;
%   nTR_run = [251 255 251 255 251 255];
%   create_sdms_mdms_glm(rootDir, subs, nRuns, nTR_run, 'TR', 2500, 'HRFRes', 5);
%
% REQUIREMENTS
%   - MATLAB
%   - BrainVoyager/NeuroElf toolbox providing the xff function
%   - Logfiles and VTC/motion SDM files with the naming conventions
%     described above.[file:2][file:1]

%% Parse inputs

p = inputParser;
p.addRequired('rootDir', @(x) ischar(x) || isstring(x));
p.addRequired('subs',    @(x) isnumeric(x) && isvector(x));
p.addRequired('nRuns',   @(x) isnumeric(x) && isvector(x));
p.addRequired('nTR_run', @(x) isnumeric(x));

p.addParameter('TR',        2500, @(x) isnumeric(x) && isscalar(x));  % ms[file:2]
p.addParameter('TA',        1500, @(x) isnumeric(x) && isscalar(x));  % ms
p.addParameter('HRFRes',    5,    @(x) isnumeric(x) && isscalar(x));  % oversampling factor[file:2]
p.addParameter('AddMotion', true, @(x) islogical(x) && isscalar(x));

p.addParameter('LogDir',  '', @(x) ischar(x) || isstring(x));
p.addParameter('SaveDir', '', @(x) ischar(x) || isstring(x));

p.parse(rootDir, subs, nRuns, nTR_run, varargin{:});
TR        = p.Results.TR;
TA        = p.Results.TA; %#ok<NASGU> % not used directly, but kept for completeness[file:1]
hrfRes    = p.Results.HRFRes;
addMotion = p.Results.AddMotion;

if isempty(p.Results.LogDir)
    logDir = fullfile(rootDir, 'Logfiles');
else
    logDir = p.Results.LogDir;
end

if isempty(p.Results.SaveDir)
    saveDir = fullfile(rootDir, 'MDM_SDM');
else
    saveDir = p.Results.SaveDir;
end

if ~exist(saveDir, 'dir')
    mkdir(saveDir);
end

subs   = subs(:)';
nSubs  = numel(subs);

% Expand nRuns if scalar
if isscalar(nRuns)
    nRuns = repmat(nRuns, 1, nSubs);
else
    nRuns = nRuns(:)';
end

% Handle nTR_run as vector or matrix
if isvector(nTR_run)
    nTR_run = nTR_run(:)';
end

%% HRF (two-gamma) construction

% Parameters as in your original code:
% pttp = 4; nttp = 12; pnr = 6; ons = 0; pdsp = 1; ndsp = 1;[file:2]
pttp = 4;
nttp = 12;
pnr  = 6;
ons  = 0;
pdsp = 1;
ndsp = 1;

% TR in seconds divided by oversampling factor
[hrfKernel, ~] = hrf('twogamma', (TR/1000)/hrfRes, pttp, nttp, pnr, ons, pdsp, ndsp);  %#ok<*NASGU>

%% Predictor names and colors

% In this version, we only use SOUND and TARGET, plus BASE and motion.
PN = {'SOUND', 'TARGET', 'BASE', 'X', 'Y', 'Z', 'RX', 'RY', 'RZ'};  % names[file:2]
% Predictor colors (RGB) for first three; motion can share a neutral color.
PC = [255 0   0;   % SOUND
      255 100 100; % TARGET
      100 100 100];% BASE[file:2]

%% Loop over subjects

for iSub = 1:nSubs

    subID   = subs(iSub);
    subjDir = fullfile(rootDir, sprintf('S%i', subID));
    nRunSub = nRuns(iSub);

    fprintf('Subject %d: %d runs\n', subID, nRunSub);

    % Determine TRs per run for this subject
    if size(nTR_run,1) == nSubs
        thisTRs = nTR_run(iSub, 1:nRunSub);
    else
        thisTRs = nTR_run(1:nRunSub);
    end

    % Preallocate SDM filenames for MDM
    sdmFiles = cell(nRunSub, 1);
    vtcFiles = cell(nRunSub, 1);

    for r = 1:nRunSub

        nTR = thisTRs(r);

        % Load logfile
        logFile = fullfile(logDir, sprintf('S%i_run%i_log.txt', subID, r));
        if ~exist(logFile, 'file')
            error('Logfile not found: %s', logFile);
        end
        L = import_logfile(logFile);  % user-provided helper[file:2]

        % Identify trial types
        target    = find(L(:,4) == 1);                   % catch trials
        nonbutton = find(L(:,5) == 0);                   % remove button-press trials
        nontarget = setdiff(1:size(L,1), target);        % remove targets
        nonsilent = find((L(:,1) == 0) + (L(:,2) == 0) < 2); % remove silent trials[file:2]

        goodtrial = intersect(intersect(nontarget, nonbutton), nonsilent);
        button    = setdiff(target, find(L(:,5) == 1));

        GT = L(goodtrial, :);  % non-silent, non-target, non-button trials

        % Initialize oversampled time courses
        nTimeFine = nTR * hrfRes;
        SOUND  = zeros(1, nTimeFine);
        TARGET = zeros(1, nTimeFine);
        BUTTON = zeros(1, nTimeFine); %#ok<NASGU>

        % Onsets are given in TR units in column 3; multiply by hrfRes for oversampled grid[file:2]
        SOUND(GT(:,3) * hrfRes)    = 1;
        TARGET(L(target,3) * hrfRes) = 1;

        % Button regressor (unused in final SDM here, but kept for completeness)
        BUTTON(L(button,3) * hrfRes) = 1;

        % Convolve with HRF
        SOUND_HRF  = conv(SOUND,  hrfKernel, 'full');
        TARGET_HRF = conv(TARGET, hrfKernel, 'full');
        BUTTON_HRF = conv(BUTTON, hrfKernel, 'full');

        % Truncate to run length (in oversampled points)
        SOUND_HRF  = SOUND_HRF(1:nTimeFine);
        TARGET_HRF = TARGET_HRF(1:nTimeFine);
        BUTTON_HRF = BUTTON_HRF(1:nTimeFine);

        % Downsample to TR resolution
        SOUND_TC  = downsample(SOUND_HRF,  hrfRes);
        TARGET_TC = downsample(TARGET_HRF, hrfRes);
        % BUTTON_TC = downsample(BUTTON_HRF, hrfRes); % not used[file:2]

        % Design matrix with task predictors
        RTCMAT = [SOUND_TC(:), TARGET_TC(:)];  % [time x 2][file:2]

        % SDM matrix: task predictors + baseline + optional motion (6 params)
        nTask = size(RTCMAT, 2);
        nMot  = 6 * addMotion;
        nCol  = nTask + 1 + nMot;  % SOUND, TARGET, BASE, (X..RZ)

        SDMMAT = zeros(nTR, nCol);
        SDMMAT(:,1:nTask) = RTCMAT;

        % Baseline (constant) predictor
        SDMMAT(:,nTask+1) = 1;

        % Motion regressors
        if addMotion
            motSDMfile = fullfile(subjDir, sprintf('S%i_run%i_3DMC.sdm', subID, r));
            if ~exist(motSDMfile, 'file')
                error('Motion SDM not found: %s', motSDMfile);
            end
            sdmmot = xff(motSDMfile);
            motMat = sdmmot.SDMMatrix;
            % Mean-center motion regressors per column[file:2]
            motMat = bsxfun(@minus, motMat, mean(motMat, 1));
            sdmmot.ClearObject();
            clear sdmmot;

            SDMMAT(:, nTask+2 : nTask+1+nMot) = motMat;
        end

        % Create SDM object
        sdm = xff('new:sdm');
        sdm.NrOfPredictors      = size(SDMMAT, 2);
        sdm.NrOfDataPoints      = nTR;
        sdm.SDMMatrix           = SDMMAT;
        sdm.RTCMatrix           = RTCMAT;
        sdm.FirstConfoundPredictor = nTask + 1;  % BASE + motion as confounds[file:2]

        % Predictor names and colors (extend colors if motion is used)
        predNames = PN(1:nTask+1);
        predColors = PC;
        if addMotion
            % Expand predictor names and colors for motion regressors
            predNames = [predNames, PN(4:9)]; %#ok<AGROW>
            motColors = repmat([150 150 150], 6, 1);
            predColors = [predColors; motColors]; %#ok<AGROW>
        end

        sdm.PredictorNames  = predNames;
        sdm.PredictorColors = predColors;

        % Save SDM
        sdmFile = fullfile(saveDir, sprintf('S%i_RUN%i_GLMANA_v1.sdm', subID, r));
        sdm.SaveAs(sdmFile);
        sdm.ClearObject();
        clear sdm;

        sdmFiles{r} = sdmFile;

        % VTC filename for this run (adapt the pattern to your data)[file:2]
        vtcFiles{r} = fullfile(subjDir, ...
            sprintf('S%i_run%i_SCSTBL_3DMCTS_undist_TAL.vtc', subID, r));
    end

    %% Create MDM for this subject

    mdm = xff('new:mdm');
    mdm.RFX_GLM          = 0;
    mdm.PSCTransformation = 1;
    mdm.zTransformation   = 0;
    mdm.SeparatePredictors = 0;
    mdm.NrOfStudies       = nRunSub;

    for r = 1:nRunSub
        mdm.XTC_RTC{r,1} = vtcFiles{r};
        mdm.XTC_RTC{r,2} = sdmFiles{r};
    end

    mdmFile = fullfile(saveDir, sprintf('S%i_GLMANA.mdm', subID));
    mdm.SaveAs(mdmFile);
    mdm.ClearObject();
    clear mdm;

    fprintf('Subject %d: SDMs and MDM written.\n', subID);
end

end
