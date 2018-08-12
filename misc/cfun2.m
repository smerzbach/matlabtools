% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-12-08
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
% Wrapper for cellfun with 'UniformOutput' enabled. Furthermore, cfun2 also
% allows a mixture of cell arrays and standard arrays as input, converting
% everything that is not a cell array. It also deals with inconsistent
% dimensions and scalars, by repmating and resizing everything to the first
% input after the function handle.
function varargout = cfun2(varargin)
    varargout = cell(max(1, nargout), 1);

    fun = varargin{1};
    args = varargin(2 : end);

    % try to convert accidental numeric arrays to cell arrays
    non_cell = ~cellfun(@iscell, args);
    args(non_cell) = cfun(@(arg) num2cell(arg), args(non_cell));
    s = size(args{1});
    n = numel(args{1});
    ns = cellfun(@numel, args);
    
    % ensure all inputs have the same number of elements
    needs_repmat = ns ~= n;
    factors = n ./ ns(needs_repmat);
    valid = factors > 1 & iswholeint(factors);
    if ~all(valid)
        error('cfun2:invalid_input', ['the following inputs'' numbers of arguments ', ...
            'are not a divisor of the first one''s number of elements: %s'], ...
            mat2str(find(~valid)));
    end
    args(needs_repmat) = cfun(@(arg, factor) repmat(arg(:), factor, 1), ...
        args(needs_repmat), num2cell(factors));
    
    % bring all inputs to the same size
    args = cfun(@(arg) reshape(arg, s), args);
    
    try
        % enforce at least one output argument in case cfun is called as a
        % statement on the command prompt
        [varargout{:}] = cellfun(fun, args{:}, 'UniformOutput', false);
    catch
        % if the above fails for functions without return arguments, try
        % again
        varargout = {};
        cellfun(fun, args{:}, 'UniformOutput', false);
    end
end

