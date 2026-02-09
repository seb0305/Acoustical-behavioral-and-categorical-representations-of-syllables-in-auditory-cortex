function L = import_logfile(logFile)
%IMPORT_LOGFILE Load experimental logfile into a numeric matrix.
%
% This helper reads a tab- or space-delimited logfile and returns a
% numeric matrix with one row per trial and five columns:
%
%   Column 1 : vowel morph value (0 for silence)
%   Column 2 : speaker morph value (0 for silence)
%   Column 3 : onset time in TR units (integer)
%   Column 4 : target flag (1 = catch trial, 0 = normal trial)
%   Column 5 : button press flag (1 = button pressed, 0 otherwise)
%
% The function assumes:
%   - Optional header line (will be skipped if it contains non-numeric text)
%   - Columns separated by whitespace or tabs
%
% INPUT
%   logFile : full path to logfile, e.g. '.../S2_run1_log.txt'
%
% OUTPUT
%   L       : [nTrials x 5] double matrix as described above.

    if ~exist(logFile, 'file')
        error('import_logfile:FileNotFound', ...
              'Logfile not found: %s', logFile);
    end

    % Try to read with readmatrix (R2019b+), which automatically handles
    % headers and mixed content. If that fails, fall back to textscan.
    try
        M = readmatrix(logFile, 'FileType', 'text');
    catch
        M = [];
    end

    if ~isempty(M) && isnumeric(M)
        % Keep only the first 5 numeric columns, in case there are extras.
        L = M(:, 1:min(5, size(M,2)));
        return;
    end

    % Fallback: manual parsing with textscan
    fid = fopen(logFile, 'r');
    if fid == -1
        error('import_logfile:CannotOpen', ...
              'Cannot open logfile: %s', logFile);
    end

    cleaner = onCleanup(@() fclose(fid));

    % Read first line to check for header
    firstLine = fgetl(fid);
    if ~ischar(firstLine)
        error('import_logfile:EmptyFile', ...
              'Logfile is empty: %s', logFile);
    end

    % Decide if first line is header: contains any letters -> treat as header
    hasText = ~isempty(regexp(firstLine, '[A-Za-z]', 'once'));

    % Rewind or move on depending on header detection
    if hasText
        % First line was header: do nothing, continue reading remaining lines
    else
        % First line already contains numeric data: rewind to start
        frewind(fid);
    end

    % Now read numeric columns (up to 5) from the file
    fmt = '%f %f %f %f %f';
    C   = textscan(fid, fmt, 'Delimiter', {'\t',' '}, ...
                   'MultipleDelimsAsOne', true, ...
                   'CollectOutput',       true);

    if isempty(C) || isempty(C{1})
        error('import_logfile:NoData', ...
              'No numeric data could be read from: %s', logFile);
    end

    L = C{1};

    % Ensure exactly 5 columns (pad or truncate if needed)
    if size(L,2) < 5
        L(:, end+1:5) = 0;
    elseif size(L,2) > 5
        L = L(:,1:5);
    end
end
