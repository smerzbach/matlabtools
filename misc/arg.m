% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-10-09
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
% Given a cell array of name-value argument pairs, this function looks for
% the value for a given name and removes the pair from the cell array. If
% it cannot find the name, it returns a default value. Also works for
% multiple names. The corresponding values are returned starting from the
% second return argument.
%
% Example:
% args = {'a', 1, 'b', 2, 'd', 4, 'f', 'test'};
% [args, a, b, c] = arg(args, {'a', 'b', 'c'}, 0)
% 
% args =
%   1×4 cell array
%     'd'    [4]    'f'    'test'
% 
% a =
%      1
% 
% b =
%      2
%
% c =
%      0
function [args, varargout] = arg(args, names, defaults, match_case) %#ok<INUSD>
    if ~iscell(args)
        error('arg:invalid_input', 'first input must be cell array');
    end
    
    if ~iscell(names)
        names = {names};
    end
    
    if ~exist('defaults', 'var')
        defaults = [];
    end
    
    if ~iscell(defaults)
        defaults = {defaults};
    end
    
    defaults = repmat(defaults(:), ceil(numel(names) / numel(defaults)), 1);
    
    match_case = default('match_case', true);
    
    if match_case
        matching = find(cellfun(@(name) any(strcmp(name, args(1 : 2 : end))), names));
        inds = cellfun(@(name) find(strcmp(name, args), 1), names(matching));
    else
        matching = find(cellfun(@(name) any(strcmpi(name, args(1 : 2 : end))), names));
        inds = cellfun(@(name) find(strcmpi(name, args), 1), names(matching));
    end
    
    if any(inds + 1 > numel(args))
        error('arg:invalid_input', 'input must contain name-value-pairs');
    end
        
    varargout = cell(1, numel(names));
    
    if isempty(args)
        [varargout{:}] = deal(defaults{:});
    else
        % return values that were found
        [varargout{matching}] = deal(args{inds + 1});

        % set defaults for those names not found
        missing = setdiff(1 : numel(names), matching);
        [varargout{missing}] = deal(defaults{missing});

        % remove those name-value-pairs that were found
        args([inds, inds + 1]) = [];
    end
end
