# Comparing Acoustical, Behavioral and Categorical Representations of Syllables in Auditory Cortex
**MATLAB/BrainVoyager pipeline for 7T fMRI GLM and behavioral model construction**

[![MATLAB](https://img.shields.io/badge/MATLAB-R2021a%2B-orange)](https://www.mathworks.com/products/matlab.html)
[![BrainVoyager](https://img.shields.io/badge/BrainVoyager-GLM-blue)](https://www.brainvoyager.com/)
[![NeuroElf](https://img.shields.io/badge/NeuroElf-Toolbox-green)](https://www.neuroelf.net/)
[![7T fMRI](https://img.shields.io/badge/7T-fMRI-red)](https://en.wikipedia.org/wiki/Functional_magnetic_resonance_imaging)

## Description

This repository contains the core MATLAB code used in my thesis “Comparing acoustical, behavioral and categorical representations of syllables in auditory cortex – Predicting two-dimensional speech morphs from high-field fMRI data”. It focuses on:
- Creating BrainVoyager-compatible GLM design files (SDMs/MDMs) for a fast event-related 7T fMRI experiment
- Building trial-wise behavioral predictors from post-scan vowel/speaker categorization tasks

More encoding/decoding and analysis code will be added over time.

## 🎯 Features

| Component | Description                                                                                                                |
|---------|----------------------------------------------------------------------------------------------------------------------------|
| **GLM SDM/MDM Creation** | Generate SOUND/TARGET regressors, convolve with 2-gamma HRF, add baseline + motion, and save SDM/MDM files per subject/run |
| **Behavioral Predictor Mapping** | Map 2D vowel–speaker morph coordinates to behavioral labels (e.g. “eu” or “female” response proportions)                   |
| **Normalization** | Center and scale behavioral labels to −1,1 for use in encoding/decoding models                                             |
| **Configurable Experiment Params** | TR, HRF oversampling, number of runs, TRs per run, and input/output paths configurable via function arguments                                                                          |
| **BrainVoyager Integration** | Uses BrainVoyager/NeuroElf objects to create SDM/MDM files that slot into your standard GLM workflow                                                      |

## 🏗️ Code Overview

src/preprocessing/create_sdms_mdms_glm.m
Creates BrainVoyager SDM and MDM files for each subject and run:
- Reads per-trial logfiles (S<id>_run<r>_log.txt)
- Builds:
  - SOUND predictor: all non-silent, non-target, non-button sound trials
  - TARGET predictor: catch trials with prolonged sounds
- Convolves predictors with a 2-gamma HRF (configurable TR and oversampling)
- Downsamples to TR resolution and adds:
  - Constant BASE predictor
  - Optional 6 motion regressors (X, Y, Z, RX, RY, RZ) from 3DMC SDM files
- Saves one SDM per run and one MDM per subject
Logfile format (per row):
- Column 1: vowel morph value (0 for silence)
- Column 2: speaker morph value (0 for silence)
- Column 3: onset time in TR units (integer)
- Column 4: target flag (1 = catch, 0 = normal)
- Column 5: button press flag (1 = button pressed, 0 otherwise)
src/behavior/get_taskbehavior.m
Utility for building trial-wise behavioral predictors from post-scan tasks:
- Input:
  - MAT: nTrialsx2 matrix (vowel morph, speaker morph per trial)
  - behav: nVowelxnSpeaker grid (e.g. mean “eu” or “female” responses)
  - vals: vector of morph values corresponding to rows/cols in behav
- Output:
  - BMAT: nTrialsx1 behavioral label per trial, mean-centered and scaled to −1,1

This implements the behavioral sound representation model described in the thesis (post-scan vowel and speaker categorization tasks).

## 🧰 Tech Stack
- Language: MATLAB (tested with R2021a)
- Neuroimaging: BrainVoyager / NeuroElf (for SDM/MDM/VTC handling)
- Data: 7T fMRI, fast event-related design, vowel–speaker morph continuum
Planned additions:
- Ridge/Lasso encoding models for acoustical, categorical, and behavioral predictors
- Cross-validated prediction pipeline (train/test across stimulus sets)
- ROI-based performance aggregation and statistical testing
- Visualization scripts for model performance per ROI


## 🚀 Quick Start

⚠️ The original 7T fMRI data and behavioral data are not included in this repo. You must supply your own data in a compatible format.

1. Clone the repo
```bash
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>
```
2. Prepare your data layout
Expected structure:
```text
<rootDir>/
  Logfiles/
    S2_run1_log.txt
    S2_run2_log.txt
    ...
  S2/
    S2_run1_SCSTBL_3DMCTS_undist_TAL.vtc
    S2_run1_3DMC.sdm
    ...
  S3/
    ...
```
Adjust filenames in create_sdms_mdms_glm.m if your naming differs.

3. Generate SDMs & MDMs
In MATLAB:

```matlab
addpath(genpath('src'));

rootDir = 'D:\CATMORPH';          % your project root
subs    = [2 3 4 5 6 7 8 9 10 11 12 13];
nRuns   = 6;                      % runs per subject
nTR_run = [251 255 251 255 251 255];  % TRs per run

create_sdms_mdms_glm(rootDir, subs, nRuns, nTR_run, ...
    'TR', 2500, ...
    'HRFRes', 5, ...
    'AddMotion', true);
```
This will write:

- S(i)_RUN<r>_GLMANA_v1.sdm files to <rootDir>/MDM_SDM/

- S(i)_GLMANA.mdm files linking VTC + SDM for each subject

4. Build behavioral predictors
```matlab
% Example values and fake behavioral matrix
vals   = 4:8:96;                  % morph grid values
behav  = rand(numel(vals));       % replace with real behavioral data

% Trial-wise morphs (vowel, speaker) for your design
MAT    = [50 50; 20 80; 96 4];    % example trial coordinates

BMAT   = get_taskbehavior(MAT, behav, vals);
```
BMAT can then be used as the behavioral predictor in your encoding models.


## 🔬 Relation to the Thesis
This code corresponds to the following parts of the written thesis:

- fMRI measurement & analysis – GLM setup, HRF convolution, design matrix construction

- Sound representation models – behavioral model based on post-scan categorization tasks

- Prediction of fMRI responses – preparation of predictors for ridge/lasso decoding (planned)

The aim is to make the original analysis pipeline transparent and reusable for related vowel/speaker fMRI experiments.

## 🔮 Roadmap
- Add scripts for:

  - Ridge regression with inner CV over λ 
  - Lasso regression and model comparison
  - 3-fold cross-validation across stimulus sets

- Implement ROI-based performance aggregation and statistical testing

- Reproduce key figures and tables from the thesis (model performance per ROI)

- Provide small synthetic demo data to run the full pipeline without proprietary fMRI data

## 🙌 Contributing
Suggestions, issues, and PRs are very welcome, especially for:

- Generalizing the code to other paradigms (different morph continua / tasks)

- Adding alternative encoding/decoding methods or cross-validation schemes

- Improving documentation and examples

1. Fork this repo

2. Create a feature branch

3. Commit your changes

4. Open a pull request with a clear description

## 📄 License
MIT - Free for educational use!

Built with curiosity for how the brain turns continuous speech into meaningful categories.