% *************************************************************************
% * Copyright 2020 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2020-05-17
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
% Dump string to file, opposite of fileread().
function textwrite(fname, text, varargin)
    [varargin, permission] = arg(varargin, 'permission', 'w');
    [varargin, machinefmt] = arg(varargin, 'machinefmt', 'native');
    [varargin, encoding] = arg(varargin, 'encoding', 'UTF-8');
    arg(varargin);
    
    fid = fopen(fname, permission, machinefmt, encoding);
    if fid == -1
        error('textwrite:filenotfound', 'cannot open file %s', fname);
    end
    fwrite(fid, text, '*char');
    fclose(fid);
end
