% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-10-04
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
% Determine if a method is already on the call stack (e.g. to prevent
% repeated callback exection).
%
% Usage:
%
% function callback()
%     if on_stack()
%         return;
%     end
%     
%     ...
% end
function tf = on_stack()
    tf = false;
    
    % query call stack
    stack = dbstack();
    
    if numel(stack) <= 2
        % to few methods on call stack for potential multiple call
        return
    end
    
    % count the occurances of the calling method in the call stack
    caller_name = stack(2).name;
    names = {stack(:).name};
    names(2) = []; % exclude caller itself
    if any(strcmp(caller_name, names))
        tf = true;
    end
end
