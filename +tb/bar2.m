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
    
    % create new bar object?
    create_new = false;
    if isempty(bar_handle)
        % we have to create new plot objects
        axes_handle = handle(axes());
        hold(axes_handle, 'on');
        create_new = true;
    elseif isa(bar_handle, 'matlab.graphics.axis.Axes')
        axes_handle = bar_handle;
        create_new = true;
    elseif isa(bar_handle, 'matlab.graphics.chart.primitive.Bar')
        axes_handle = bar_handle(1).Parent;
    else
        error('bar2:input_format', 'input must be bar handle or axes handle!');
    end
    
    if create_new
        bar_handle = handle(bar(xdata, ydata, ...
            'Parent', axes_handle, varargin{:}));
    else
        bar_handle = handle(bar_handle);
        for ii = 1 : d
            % we can simply update the plot handle
            bar_handle(ii).XData = xdata;
            bar_handle(ii).YData = ydata(ii, :);
            set(bar_handle(ii), varargin{:});
        end
    end
end
