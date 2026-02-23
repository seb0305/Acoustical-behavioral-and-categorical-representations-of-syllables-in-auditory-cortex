% make_dummy_models.m
% Generate tiny synthetic model label matrices for documentation/demo.
%
% This script creates:
%   vals                - example morph values
%   acoustic_vowel      - continuous vowel labels (0..1)
%   acoustic_speaker    - continuous speaker labels (0..1)
%   categorical_vowel   - 3-class vowel labels (-1,0,+1)
%   categorical_speaker - 3-class speaker labels (-1,0,+1)
%
% and saves them to data/models/dummy_models.mat

vals = [20 60 100];  % example morph values along each continuum

n = numel(vals);
[vGrid, sGrid] = ndgrid(vals, vals);

% Acoustical model: simple normalized ramps from low to high morph values
acoustic_vowel   = (vGrid - min(vals)) / (max(vals) - min(vals));      % 0..1
acoustic_speaker = (sGrid - min(vals)) / (max(vals) - min(vals));      % 0..1

% Categorical model: 3 classes as in the thesis description:
%   low morphs   -> category -1  ("ee" / male)
%   middle morphs-> category  0  (ambiguous)
%   high morphs  -> category +1  ("eu" / female)[file:1]

categorical_vowel   = zeros(n);
categorical_speaker = zeros(n);

lowIdx  = vals <= 40;   % treat 20 as "low"
highIdx = vals >= 80;   % treat 100 as "high"

categorical_vowel( lowIdx,  :) = -1;
categorical_vowel( highIdx, :) =  1;

categorical_speaker(:, lowIdx)  = -1;
categorical_speaker(:, highIdx) =  1;

% Make sure output folder exists
outDir = fullfile('data', 'models');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

save(fullfile(outDir, 'dummy_models.mat'), ...
     'vals', ...
     'acoustic_vowel', 'acoustic_speaker', ...
     'categorical_vowel', 'categorical_speaker');
