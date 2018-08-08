% *************************************************************************
% * Copyright 2018 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2018-08-05
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
% Given a scalar struct (i.e. not a struct array with multiple elements),
% this function allows filtering the struct fields. It will return a new
% struct that only contains those fields from the input struct that match
% the specified regular expression.
function strout = struct_grep(strin, pattern)
    fns = fieldnames(strin);
    match = regexpi(fns, pattern, 'match');
    match = match(~cellfun(@isempty, match));
    
    strout = struct();
    for fi = 1 : numel(match)
        strout.(match{fi}{1}) = strin.(match{fi}{1});
    end
end
