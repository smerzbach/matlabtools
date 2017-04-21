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
% Convert arbitrary input to a char array. Works recursively on cell
% arrays.
function str = to_str(input)
    if ischar(input)
        str = input;
    elseif isnumeric(input)
        str = num2str(input);
    elseif iscell(input)
        str = cellfun(@(x) [to_str(x), ' '], input, 'UniformOutput', false);
    elseif isa(input, 'function_handle')
        str = func2str(input);
    else
        try
            str = string(input);
            str = str.char();
        catch err
            error('Problem converting to string: %s', err.message);
        end
    end
end
