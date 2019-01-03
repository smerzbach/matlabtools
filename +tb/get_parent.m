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
% Given a handle to an axes, container or even figure handle object, this
% function returns the object's direct parent (e.g. some container like an
% uipanel) and the containing figure.
function [figure_handle, parent_handle, axes_handle] = get_parent(input)
    if isempty(input)
        error('get_parent:invalid_input', 'input cannot be empty');
    end
    
    figure_handle = [];
    parent_handle = [];
    axes_handle = [];
    
    if isa(input, 'matlab.graphics.axis.Axes') || isa(input, 'axes')
        axes_handle = input;
        parent_handle = input.Parent;
    elseif isa(input, 'matlab.ui.container.Panel') || isa(input, 'uipanel')
        parent_handle = input;
    elseif isa(input, 'matlab.ui.Figure') || isa(input, 'figure')
        figure_handle = input;
        parent_handle = input;
    elseif isa(input, 'uix.Container') || isa(input, 'uiextras.Container')
        parent_handle = input;
        figure_handle = input.Parent;
        max_depth = 1000;
        depth = 0;
        while ~isa(figure_handle, 'matlab.ui.Figure') && depth < max_depth
            try
                figure_handle = figure_handle.Parent;
                depth = depth + 1;
            catch
                error('get_parent:invalid_input', ...
                    'cannot find parent figure');
            end
        end
        
        if ~isa(figure_handle, 'matlab.ui.Figure')
            error('get_parent:invalid_input', ...
                'could not find parent figure!');
        end
    elseif ~isempty(input)
        error('get_parent:invalid_input', ...
            'input must be an axes, container of figure object');
    end

    if isempty(parent_handle) && ~isempty(axes_handle)
        parent_handle = axes_handle.Parent;
    end

    if isempty(figure_handle)
        figure_handle = ancestor(parent_handle, 'figure');
    end
end
