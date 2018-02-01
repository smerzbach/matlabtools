% *************************************************************************
% * Copyright 2018 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2018-02-02
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
% Call all input arguments that are function handles individually with all
% other arguments that are not. This allows "chaining" anonymous functions.
%
% Examples:
% 
% >> callall(@() disp('function1'), @() disp('function2'));
% function1
% function2
%
% >> callall([1, 2, 3], 2, @(a, b) disp(['fcn1: ', num2str(a + b)]), ...
%        @(a, b) disp(['fcn2: ', num2str(a - b)]));
% fcn1: 3  4  5
% fcn2: -1  0  1
%
% >> results = callall([1, 2, 3], 2, @(a, b) a + b, @(a, b) a - b)
% results =
%   1×2 cell array
%     {1×3 double}    {1×3 double}
% results{:}
% ans =
%      3     4     5
% ans =
%     -1     0     1
function varargout = callall(varargin)
    isfcn = cellfun(@(c) isa(c, 'function_handle'), varargin);
    inputs = varargin(~isfcn);
    
    varargout = cell(1, nargout);
    try
        [varargout{:}] = cellfun(@(fcn) fcn(inputs{:}), varargin(isfcn));
    catch
        [varargout{:}] = cfun(@(fcn) fcn(inputs{:}), varargin(isfcn));
    end
end
