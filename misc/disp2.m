% *************************************************************************
% * Copyright 2018 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2018-08-06
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
% Create string reprentations of input in valid Matlab syntax, that can be
% pasted as code, e.g. for variable initialization.
function str = disp2(input)
    if iscell(input)
        str = strrep(evalc('disp(input)'), newline, sprintf(';\n '));
        str = str(1 : end - 3);
        str = ['{', str, '}'];
    elseif isstring(input)
        if numel(input) == 1
            str = ['"', input{1}, '"'];
        else
            str = strrep(evalc('disp(input)'), newline, sprintf(';\n '));
            str = str(1 : end - 3);
            str = ['[', str, ']'];
        end
    else
        error('disp2:not_implemented', 'not implemented');
    end
end
