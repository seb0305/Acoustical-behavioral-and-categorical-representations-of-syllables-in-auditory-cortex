function BMAT = get_taskbehavior(MAT, behav, vals)
%GET_TASKBEHAVIOR Map vowel–speaker morphs to behavioral labels.
%
% This function converts 2D vowel–speaker morph coordinates for each trial
% into a 1D behavioral predictor, based on post-scan behavioral data.[file:1][file:3]
%
% INPUTS
%   MAT   : [nTrials x 2] matrix
%           - column 1: vowel morph value for each trial
%           - column 2: speaker morph value for each trial[file:3]
%
%   behav : [nVowel x nSpeaker] matrix of behavioral values
%           e.g. average proportion of "eu" responses (vowel task)
%           or average proportion of "female" responses (speaker task).[file:1]
%
%   vals  : vector of morph values (length = nVowel = nSpeaker)
%           specifying the grid on which 'behav' is defined.
%           Example: vals = 4:8:96;[file:1][file:3]
%
% OUTPUT
%   BMAT  : [nTrials x 1] behavioral label per trial
%           - obtained by looking up behav(vowelIndex, speakerIndex)
%           - then mean-centered
%           - then scaled to [-1, 1] by dividing by max absolute value.[file:3]
%
% EXAMPLE
%   % Suppose vals defines the morph grid and behav holds mean "eu" responses
%   vals   = 4:8:96;
%   behav  = rand(numel(vals));        % dummy behavioral matrix
%   MAT    = [50 50; 20 80; 96 4];     % [vowelMorph, speakerMorph] per trial
%   BMAT   = get_taskbehavior(MAT, behav, vals);
%
%   % BMAT now contains normalized behavioral labels for each trial.
%
% See also: build_behavioral_model (if you wrap this into a larger pipeline).

    ntr  = size(MAT, 1);
    BMAT = zeros(ntr, 1);

    % Vowel is 1st column in MAT, speaker is 2nd column in MAT.
    % Vowel is 1st dimension in behav, speaker is 2nd dimension in behav.[file:3]

    for tr = 1:ntr
        hv = find(vals == MAT(tr, 1));  % vowel index
        hs = find(vals == MAT(tr, 2));  % speaker index

        if isempty(hv) || isempty(hs)
            error('Morph value not found in vals for trial %d (vowel=%g, speaker=%g).', ...
                  tr, MAT(tr,1), MAT(tr,2));
        end

        BMAT(tr) = behav(hv, hs);
    end

    % Mean-center behavioral labels.[file:3]
    BMAT = BMAT - mean(BMAT);

    % Scale to [-1, 1] by dividing by max absolute value (if non-zero).[file:3]
    maxAbs = max(abs(BMAT));
    if maxAbs > 0
        BMAT = BMAT ./ maxAbs;
    end
end
