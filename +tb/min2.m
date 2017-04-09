% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-03-15
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
% Minimum along multiple dimensions.
function res = min2(varargin)
    if numel(varargin) < 3
        res = min(varargin{:});
    elseif numel(varargin) == 3
        assert(isempty(varargin{2}));
        dims = varargin{3};
        dims = sort(dims);
        res = varargin{1};
        for ii = numel(dims) : -1 : 1
            res = min(res, [], dims(ii));
        end
    end
end
