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
% args = {'a', 1, 'd', 4, 'f', 'test', 'b', 2, };
% [args, a_b_or_c] = arg(args, {'a', 'b', 'c'}, 0)
% 
% args =
%   1×4 cell array
%     'd'    [4]    'f'    'test'
% 
% a_b_or_c =
%      1
function [args, value] = arg(args, names, default, match_case)
    if ~exist('names', 'var') || isempty(names)
        % error checking mode (if args is not empty, there were unsupported
        % parameter value pairs)
        err_str = '';
        try %#ok<TRYNC>
            err_str = tb.to_str(args(1 : 2 : end));
        end
        assert(isempty(args), 'unsupportet parameter(s): %s', err_str);
        return;
    end

    if ~iscell(args) && ~isstruct(args)
        error('arg:invalid_input', 'first input must be cell array or struct');
    end
    
    if ~iscell(names)
        names = {names};
    end
    
    if ~exist('default', 'var')
        default = [];
    end
    
    value = default;
    
    if ~exist('match_case', 'var') || isempty(match_case)
        match_case = true;
    end
    
    % find first name that matches any of the specified ones
    if iscell(args)
        if match_case
%             matching = find(cellfun(@(name) any(strcmp(name, args(1 : 2 : end))), names));
            matching = find(cellfun(@(arg) any(find(strcmp(names, arg))), args(1 : 2 : end)));
        else
%             matching = find(cellfun(@(name) any(strcmpi(name, args(1 : 2 : end))), names));
            matching = find(cellfun(@(arg) any(find(strcmpi(names, arg))), args(1 : 2 : end)));
        end

        if any(2 * matching > numel(args))
            error('arg:invalid_input', 'input must contain name-value-pairs');
        end
        
        if ~isempty(matching)
            value = args{2 * matching(1)};
        end
    elseif isstruct(args)
        fns = fieldnames(args);
        fns2 = fns;
        names2 = names;
        if match_case
            matching = find(cellfun(@(name) any(strcmp(name, fns2)), names2));
        else
            matching = find(cellfun(@(name) any(strcmpi(name, fns2)), names2));
        end
        if ~isempty(matching)
            value = args.(names{matching(1)});
        end
    else
        error('arg:invalid_input', 'input of type %s is not supported.', class(args));
    end
    
    if ~isempty(matching)
        % remove those name-value-pairs that were found
        if iscell(args)
            args(2 * matching + [-1; 0]) = [];
        elseif isstruct(args)
            for ii = 1 : numel(matching)
                args = rmfield(args, fns{matching(ii)});
            end
        end
    end
end
