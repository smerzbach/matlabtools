% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-11-26
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
% Check if a file name has a given extension, optionally case-insensitive.
function tf = extension(fname, ext, case_sensitive) %#ok<INUSD>
    case_sensitive = default('case_sensitive', true);
    % add leading dot
    if ext(1) ~= '.'
        ext = ['.', ext];
    end

    % check if extension could fit into file name length
    if numel(ext) > fname
        tf = false;
        return;
    end
    
    n = numel(ext);
    if case_sensitive
        tf = strncmp(fname(end : -1 : end - n + 1), ext(end : -1 : 1), n);
    else
        tf = strncmpi(fname(end : -1 : end - n + 1), ext(end : -1 : 1), n);
    end
end
