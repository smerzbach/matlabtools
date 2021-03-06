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
% returned nan. In the second to last argument, a boolean array of matching
% strings is returned. The last one contains the full strings that matched.
%
% Usage example: parse numeric arguments from filenames:
%
% fnames = {'file_index001_a100_b0.005.txt'; ...
%     'file_index002_a050_b1.42.txt'; ...
%     'file_index003_a002_b0.03.txt'; ...
%     'file_index004_a120_b10.5587.txt'; ...
%     'this_will_not_match.txt'};
%
% numeric = true;
%
% [index, a, b, matched, matching_fnames] = strparse(fnames, ...
%     'index(\d+)_a(\d+)_b(\d+\.\d+)\.txt', numeric)
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
% 
% matched =
%   5×1 logical array
%    1
%    1
%    1
%    1
%    0
% 
% matching_fnames =
%   4×1 cell array
%     {'file_index001_a100_b0.005.txt'  }
%     {'file_index002_a050_b1.42.txt'   }
%     {'file_index003_a002_b0.03.txt'   }
%     {'file_index004_a120_b10.5587.txt'}
function varargout = strparse(input, pattern, numeric) %#ok<INUSD>
    numeric = default('numeric', false);
    
    was_cell = iscell(input);
    if ~was_cell
        input = {input};
    end
    
    tokens = regexp(input, pattern, 'tokens');
    matching = ~cellfun(@isempty, tokens);
    
    if ~any(matching)
        varargout = cell(1, nargout());
        varargout{end} = matching;
        return;
    end
    
    % determine number of matching groups
    nout = numel(tokens{find(matching, 1)}{1});
    varargout = cell(1, nout + 2);
    varargout{nout + 1} = matching;
    varargout{nout + 2} = input(matching);
    
    [varargout{1 : nout}] = cfun(@(t) deal(t{1}{:}), tokens(matching));
    
    if numeric
        for ii = 1 : nout
            tmp = cellfun(@str2double, varargout{ii});
            if ~any(isnan(tmp))
                varargout{ii} = tmp;
            else
                varargout{ii}(~isnan(tmp)) = num2cell(tmp(~isnan(tmp)));
            end
        end
    elseif ~was_cell
        % if input was a single string, we don't need to return cell arrays
        for ii = 1 : nout
            varargout{ii} = varargout{ii}{1};
        end
    end
end
