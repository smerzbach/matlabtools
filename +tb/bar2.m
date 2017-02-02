% *************************************************************************
% * Copyright 2016 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2016-12-28
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
% 
function bar_handle = bar2(bar_handle, xdata, ydata, varargin)
    assert(ismatrix(xdata) && ismatrix(ydata), 'input must be in a 1D or 2D array!');
    
    [d, n] = size(ydata);
    
    if isempty(xdata)
        % default x-axis
        xdata = 1 : n;
    end
    
    assert(size(xdata, 2) == n, 'first dimension of xdata and ydata must match!');
    
    % create new axes object?
    create = isempty(bar_handle);
    
    if create
        % we have to create new plot objects
        axes_handle = axes();
        hold(axes_handle, 'on');
        bar_handle = bar(xdata, ydata, ...
            'Parent', axes_handle, varargin{:});
    else
        for ii = 1 : d
            % we can simply update the plot handle
            bar_handle(ii).XData = xdata;
            bar_handle(ii).YData = ydata(ii, :);
            set(bar_handle(ii), varargin{:});
        end
    end
end
