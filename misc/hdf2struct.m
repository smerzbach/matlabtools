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
% all attributs and datasets in the HDF5 hierarchy and stores them in a
% struct. Additionally, it will return a string representation of the
% hierary.
% Since HDF5 can have arbitrary strings in the hierarchy, which are illegal
% as field names for a Matlab struct, the strings are parsed and illegal
% characters are replaced. In case of strings starting with numbers, a
% prefix 'f' is prepended.
% Optionally, certain parts of the hierarchy can be excluded, and redundant
% subtrees like /path/to/data/Data can be skipped in the struct by
% assigning Data directly to s.path.to.data instead of s.path.to.data.Data.
function [s, tree] = hdf2struct(input, excludes, skips)
    if ~exist('excludes', 'var')
        excludes = {};
    end
    
    if ~exist('skips', 'var')
        skips = {};
    end
    
    if ~iscell(excludes)
        excludes = {excludes};
    end
    
    if ~iscell(skips)
        skips = {skips};
    end
    
    if ischar(input)
        % filename given as input -> extract meta data using hdf5info
        meta = hdf5info(input);
        node = meta.GroupHierarchy;
        [s, tree] = hdf2struct(node, excludes, skips);
        return;
    else
        node = input;
    end
    
    % filtering function for producing valid fieldnames from the paths in
    % the HDF5 file
    mv = @make_valid_fieldname;
    
    % initialize outputs
    tree = ['T ', node.Name];
    s = struct();
    
    % list attributes of current node
    for ai = 1 : numel(node.Attributes)
        if ~any(cellfun(@(exclude) strcmp(node.Attributes(ai).Shortname, exclude), excludes))
            tmp = node.Attributes(ai).Value;
            if isa(tmp, 'hdf5.h5string')
                tmp = tmp.Data;
            end
            s.(mv(filename(node.Attributes(ai).Name))) = tmp;
            
            % add to tree string as well
            tree = [tree, newline, 'A ', node.Attributes(ai).Name]; %#ok<AGROW>
        end
    end
    
    % load datasets
    for di = 1 : numel(node.Datasets)
        tmp = hdf5read(node.Filename, node.Datasets(di).Name);
        
        % convert HDF5 string objects to Matlab strings
        if isa(tmp, 'hdf5.h5string')
            tmp = afun(@(tmp) tmp.Data, tmp);
            tmp = string(tmp);
        end
        s.(mv(filename(node.Datasets(di).Name))) = tmp;
        
        % add entry to tree string
        tree = [tree, newline, 'D ', node.Datasets(di).Name, ' [', node.Datasets(di).Datatype.Class, ']']; %#ok<AGROW>
        if ~isempty(node.Datasets(di).Dims)
            tree = [tree, ' (', sprintf('%d, ', node.Datasets(di).Dims), ')']; %#ok<AGROW>
        end
    end
    
    % recurse into child nodes
    for ci = 1 : numel(node.Groups)
        [s.(mv(filename(node.Groups(ci).Name))), subtree] = hdf2struct(node.Groups(ci), excludes, skips);
        
        % add to tree string as well
        tree = [tree, newline, subtree]; %#ok<AGROW>
    end
    
    % remove redundant fields like 'Data'
    fns = fieldnames(s);
    if ~isempty(skips) && numel(fns) == 1
        skips_found = strcmp(fns{1}, skips);
        if nnz(skips_found) == 1
            s = s.(fns{1});
        end
    end
end
