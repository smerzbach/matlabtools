% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-04-08
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
% Simple wrapper for cellfun calling it with the annoying UniformOutput
% argument. Usage is exactly like cellfun otherwise.
function varargout = cfun(varargin)
    varargout = cell(max(1, nargout), 1);
    try
        % enforce at least one output argument in case cfun is called as a
        % statement on the command prompt
        [varargout{:}] = cellfun(varargin{:}, 'UniformOutput', false);
    catch
        % if the above fails for functions without return arguments, try
        % again
        varargout = {};
        cellfun(varargin{:}, 'UniformOutput', false);
    end
end
