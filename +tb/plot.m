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
% Wrapper around plot that allows re-using existing plot handles.
function h = plot(h, xdata, ydata, varargin)
    assert(ismatrix(xdata) && ismatrix(ydata), ...
        'input must be in a 1D or 2D array!');
    
    n = numel(ydata);
    
    if isempty(xdata)
        % default x-axis
        xdata = 1 : n;
    end
    
    assert(numel(xdata) == n, 'number of elements in xdata and ydata must match!');
    
    % create new axes object?
    create = true;
    % determine if image dimensions have changed
    if isa(h, 'matlab.graphics.chart.primitive.Line')
        create = false;
    end
    
    if create
        if isa(h, 'matlab.graphics.axis.Axes')
            axes_handle = h;
        else
            axes_handle = handle(axes());
        end
    else
        h = handle(h);
        axes_handle = h.Parent;
    end
    
    if create
        % we have to create new plot objects
        h = handle(plot(xdata, ydata, 'Parent', axes_handle, varargin{:}));
    else
        h.XData = xdata;
        h.YData = ydata;
    end
    
    if numel(varargin)
        set(h, varargin{:});
    end
    
    % if the axes object's data mode is set to manual, the plot objects
    % might lie outside of the axis limits
    % this should be handled outside of the plotting function, though
    if false
        axes_handle = h(1).Parent;
        axes_handle.XLim = [min(axes_handle.XLim(1), min(xdata)), ...
            max(axes_handle.XLim(2), max(xdata))];
        axes_handle.YLim = [min(axes_handle.YLim(1), min(ydata)), ...
            max(axes_handle.YLim(2), max(ydata))];
    end
end
