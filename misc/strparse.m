% *************************************************************************
% * Copyright 2018 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2018-01-13
% *
% * This file is part of smml.
% *
% * smml is free software: you can redistribute it and/or modify it under
% * the terms of the GNU Lesser General Public License as published by the
% * Free Software Foundation, either version 3 of the License, or (at your
% * option) any later version.
% *
% * smml is distributed in the hope that it will be useful, but WITHOUT
% * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
% * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
% * License for more details.
% *
% * You should have received a copy of the GNU Lesser General Public
% * License along with smml.  If not, see <http://www.gnu.org/licenses/>.
% *
% *************************************************************************
% 
% Given a cell array of strings, this function attempts to match each
% string against a given regular expression, capture all tokens in the
% regular expression and return them separately in multiple output
% arguments. Optionally, the function attempts converting the tokens to
% double, returning the original matching tokens where str2double()
% returned nan.
%
% Usage example: parse numeric arguments from filenames:
%
% fnames = {'file_index001_a100_b0.005.txt'; ...
%     'file_index002_a050_b1.42.txt'; ...
%     'file_index003_a002_b0.03.txt'; ...
%     'file_index004_a120_b10.5587.txt'};
% numeric = true;
% [index, a, b] = strparse(fnames, 'index(\d+)_a(\d+)_b(\d+\.\d+)\.txt', ...
%     numeric)
%
% index =
%      1
%      2
%      3
%      4
% 
% a =
%    100
%     50
%      2
%    120
% 
% b =
%     0.0050
%     1.4200
%     0.0300
%    10.5587
function varargout = strparse(fnames, pattern, numeric) %#ok<INUSD>
    numeric = default('numeric', false);
    
    tokens = regexp(fnames, pattern, 'tokens');
    matching = ~cellfun(@isempty, tokens);
    
    if ~any(matching)
        error('strparse:none_matching', ...
            'none of the input strings matches the specified pattern');
    end
    
    varargout = cell(1, numel(tokens{find(matching, 1)}{1}));
    
    [varargout{:}] = cfun(@(t) deal(t{1}{:}), tokens(matching));
    
    if numeric
        for ii = 1 : numel(varargout)
            tmp = cellfun(@str2double, varargout{ii});
            if ~any(isnan(tmp))
                varargout{ii} = tmp;
            else
                varargout{ii}(~isnan(tmp)) = num2cell(tmp(~isnan(tmp)));
            end
        end
    end
end
