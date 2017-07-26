% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-05-06
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
% Given a string representation of a 2D array, this functio attempts to
% parse and return a numeric array. This function can be seen as acting
% inversely to what mat2str() does.
%
% Test this with e.g. 
% errs = zeros(10000, 1);
% for ii = 1 : 10000
%     try
%         [~, errs(ii)] = tb.str2mat2(randn(randi(9, 1) + 1, randi(9, 1) + 1));
%     catch err;
%         break;
%     end;
% end
% if exist('err', 'var')
%     rethrow(err)
% end
% sum(errs)
function [mat, e] = str2mat2(str)
    if ~exist('str', 'var') || isempty(str)
        % examplary string representation of a 2D array
        str = '[1, -2, 3.5; -4, 5.5 6;  1.01, .0001, 100.0]';
    end
    
    % for testing
    str_orig = str;
    if isnumeric(str)
        str = mat2str(str);
    end

    str = strrep(str, sprintf('\n'), ';');
    str = strrep(str, '[', '');
    str = strrep(str, ']', '');
    str = strrep(str, ',', ' ');
    strs = strsplit(str, ';');
    tokens = regexp(strs, '((-?\d+\.?\d*|-?\d*\.\d+)(e[+-]\d+)?|(-?Inf|NaN))', 'tokens');
    
    if numel(strs) ~= numel(tokens)
        str_orig %#ok<NOPRT>
        error('str2mat2:internal_error', 'not all rows could be matched!');
    end
    
    % concatenate colums to cell arrays of strings
    tokens = cfun(@(r) [r{:}], tokens);
    
    % check number of colums per row
    col_nums = cellfun(@numel, tokens);
    if ~all(col_nums == col_nums(1))
        str_orig %#ok<NOPRT>
        col_nums %#ok<NOPRT>
        error('str2mat2:internal_error', ...
            'different number of columns for some of the rows');
    end
    
    % convert to doubles
    tokens = cfun(@str2double, tokens);
    
    % concatenate final array
    mat = vertcat(tokens{:});
    
    % for testing
    if isnumeric(str_orig)
        e = sum(abs(str_orig(:) - mat(:)));
    end
end

