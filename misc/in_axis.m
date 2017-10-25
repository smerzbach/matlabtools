% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-10-25
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
% Given figure and axis handles, this function determines if the current
% mouse position is in the axis object or not.
function res = in_axis(figure_handle, axis_handle)
    if isempty(figure_handle) || isempty(axis_handle)
        res = false;
        return;
    end
    
    % axis object's position in absolute pixel coordinates inside the figure
    axp = getpixelposition(axis_handle, true);
    
    % current point in pixel coordinates inside the figure
    cp = get(figure_handle,'currentpoint');

    % compare coordinates and thus determine if the cursor is inside the
    % axis object
    res = axp(1) <= cp(1) && cp(1) <= axp(1) + axp(3) && ...
        axp(2) <= cp(2) && cp(2) <= axp(2) + axp(4);
end
