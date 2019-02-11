% *************************************************************************
% * Copyright 2018 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2018-11-04
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
% Given filename or root node extracted with hdf5info(), this method reads
% all attributs and datasets in the HDF5 hierarchy and returns a string
% representation of the hierary.
% Optionally, certain parts of the hierarchy can be excluded.
function tree = hdf2tree(input, excludes)
    if ~exist('excludes', 'var')
        excludes = {};
    end
    
    if ~iscell(excludes)
        excludes = {excludes};
    end
    
    if ischar(input)
        % filename given as input -> extract meta data using hdf5info
        meta = hdf5info(input);
        node = meta.GroupHierarchy;
        tree = hdf2tree(node, excludes);
        return;
    else
        node = input;
    end
    
    % initialize tree
    tree = ['T ', node.Name];
    
    % list attributes of current node
    for ai = 1 : numel(node.Attributes)
        if ~any(cellfun(@(exclude) strcmp(node.Attributes(ai).Shortname, exclude), excludes))
            tree = [tree, newline, 'A ', node.Attributes(ai).Name]; %#ok<AGROW>
        end
    end
    
    % list datasets
    for di = 1 : numel(node.Datasets)
        tree = [tree, newline, 'D ', node.Datasets(di).Name, ' [', node.Datasets(di).Datatype.Class, ']']; %#ok<AGROW>
        if ~isempty(node.Datasets(di).Dims)
            tree = [tree, ' (', sprintf('<strong>%d</strong>, ', node.Datasets(di).Dims), ')']; %#ok<AGROW>
        end
    end
    
    % recurse into child nodes
    for ci = 1 : numel(node.Groups)
        tree = [tree, newline, hdf2tree(node.Groups(ci), excludes)]; %#ok<AGROW>
    end
end
