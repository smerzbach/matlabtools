% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-01-09
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
% Given a handle to an axes object, this function returns the axes's direct
% parent (e.g. some container like an uipanel) and the containing figure.
% If the input is a uipanel or figure handle, a new axes is created
% instead.
function [figure_handle, parent_handle, axes_handle] = get_parent(input)
    figure_handle = [];
    parent_handle = [];
    axes_handle = [];
    
    if isa(input, 'matlab.graphics.axis.Axes')
        axes_handle = input;
        parent_handle = input.Parent;
    elseif isa(input, 'matlab.ui.container.Panel')
        parent_handle = input;
    elseif isa(input, 'matlab.ui.Figure')
        figure_handle = input;
        parent_handle = input;
    elseif ~isempty(input)
        error('input must be an axes, container of figure object');
    end

    if isempty(parent_handle)
        if ~isempty(axes_handle)
            parent_handle = axes_handle.Parent;
        else
            parent_handle = figure();
        end
    end

    if isempty(figure_handle)
        figure_handle = ancestor(parent_handle, 'figure');
    end
    
    if isempty(axes_handle)
        axes_handle = axes('Parent', parent_handle);
    end
end
