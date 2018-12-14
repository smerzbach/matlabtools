% *************************************************************************
% * Copyright 2018 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2018-12-14
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
% Return a conversion matrix from sRGB (linearized!) to XYZ under a
% specified whitepoint. For now, only the equal energy whitepoint 'E' is
% supported.
function conversion_matrix = mat_linearSRGB2XYZ(wp)
    if isnumeric(wp) && ~isequal(wp(:), [1; 1; 1])
        error('mat_linearSRGB2XYZ:unsupported_whitepoint', ...
            'Only whitepoint [1, 1, 1] is supported right now.');
    elseif ischar(wp) && ~strcmpi(wp, 'e')
        error('mat_linearSRGB2XYZ:unsupported_whitepoint', ...
            'Only whitepoint ''E'' is supported right now.');
    elseif ~isnumeric(wp) && ~ischar(wp)
        error('mat_linearSRGB2XYZ:invalid_whitepoint_format', ...
            'Whitepoint must be specified as characters or as 3 element numeric array.');
    end
    
    % only the hard coded conversion matrix for converting linear sRGB to
    % XYZ under equal energy whitepoint for now
	conversion_matrix = [0.496921017402945, 0.339089692101740, 0.163989290495315;
        0.256224899598394, 0.678179384203481, 0.065595716198126
        0.023293172690763, 0.113029897367247, 0.863676929941990];
end
