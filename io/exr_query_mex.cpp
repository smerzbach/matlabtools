/**************************************************************************
 * Copyright 2017 Sebastian Merzbach
 *
 * authors:
 *  - Sebastian Merzbach <smerzbach@gmail.com>
 *
 * file creation date: 2017-11-26
 *
 * This file is part of smml.
 *
 * smml is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * smml is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 * License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with smml.  If not, see <http://www.gnu.org/licenses/>.
 *
 **************************************************************************
 *
 * Mex file for querying meta data from an OpenEXR image file.
 *
 * TODO: parse all custom attributes
 */

#include <string>
#include <vector>

#include <mex.h>

#define TINYEXR_IMPLEMENTATION
#include "tinyexr.h"

#define NUMBER_OF_FIELDS (sizeof(field_names)/sizeof(*field_names))

void mexFunction( int nlhs, mxArray *plhs[],
        int nrhs, const mxArray *prhs[])
{
    // check inputs
    if(nrhs != 1) {
        mexErrMsgTxt("Usage: meta = exr_query(path_to_exr_file)");
    }
    
    // read inputs
    char *filename = mxArrayToString(prhs[0]);
    
    try {
        EXRVersion exr_version;
        EXRHeader exr_header;
        InitEXRHeader(&exr_header);

        int ret = ParseEXRVersionFromFile(&exr_version, filename);
        if (ret != TINYEXR_SUCCESS) {
            mexErrMsgTxt((std::string("Error parsing EXR version from file ") + 
                    std::string(filename) + std::string(". Not an OpenEXR file?")).c_str());
        }

        if (exr_version.multipart || exr_version.non_image) {
            mexErrMsgTxt("Loading multipart or DeepImage is not supported yet.\n");
        }

        const char** err;
        ret = ParseEXRHeaderFromFile(&exr_header, &exr_version, filename, err);
        if (ret != TINYEXR_SUCCESS) {
            mexErrMsgTxt("parsing header from file failed.\n");
        }

        int height= exr_header.data_window[3] - exr_header.data_window[1] + 1;
        int width = exr_header.data_window[2] - exr_header.data_window[0] + 1;
        int num_channels = exr_header.num_channels;
        int compression_type = exr_header.compression_type;

        std::vector<std::string> vec_chan_names(num_channels);
        std::vector<std::string> vec_chan_types(num_channels);
        for (size_t i = 0; i < exr_header.num_channels; i++) {
            vec_chan_names[i] = std::string(exr_header.channels[i].name);

            int type = exr_header.pixel_types[i];
            vec_chan_types[i] = (type == TINYEXR_PIXELTYPE_UINT) ? "uint" : 
                ((type == TINYEXR_PIXELTYPE_HALF) ? "half" : "float");
        }

        // attempt to parse comments as custom attribute
        std::string comments;
        for (size_t i = 0; i < TINYEXR_MAX_ATTRIBUTES; i++) {
            if (exr_header.custom_attributes[i].size && 
                    0 == strcmp(exr_header.custom_attributes[i].name, "comments")) {
                comments = std::string((char*) exr_header.custom_attributes[i].value);
            }
        }

        // create meta struct
        mwSize dims[2] = {1, 1};
        const char *field_names[] = {"width", "height", "num_channels", 
            "compression_type", "channel_names", "channel_types", "comments"};
        plhs[0] = mxCreateStructArray(2, dims, NUMBER_OF_FIELDS, field_names);

        // set struct fields
        mxArray* field_value = mxCreateDoubleMatrix(1, 1, mxREAL);
        *mxGetPr(field_value) = width;
        mxSetFieldByNumber(plhs[0], 0, mxGetFieldNumber(plhs[0], "width"), field_value);

        field_value = mxCreateDoubleMatrix(1, 1, mxREAL);
        *mxGetPr(field_value) = height;
        mxSetFieldByNumber(plhs[0], 0, mxGetFieldNumber(plhs[0], "height"), field_value);

        field_value = mxCreateDoubleMatrix(1, 1, mxREAL);
        *mxGetPr(field_value) = num_channels;
        mxSetFieldByNumber(plhs[0], 0, mxGetFieldNumber(plhs[0], "num_channels"), field_value);
        
        field_value = mxCreateDoubleMatrix(1, 1, mxREAL);
        *mxGetPr(field_value) = compression_type;
        mxSetFieldByNumber(plhs[0], 0, mxGetFieldNumber(plhs[0], "compression_type"), field_value);

        // create cell arrays of strings for the channel names and types
        mxArray* cell_array_ptr_channel_names = mxCreateCellMatrix((mwSize)num_channels, 1);
        mxArray* cell_array_ptr_channel_types = mxCreateCellMatrix((mwSize)num_channels, 1);
        for (size_t i = 0; i < num_channels; i++) {
            mxSetCell(cell_array_ptr_channel_names, i, mxCreateString(vec_chan_names[i].c_str()));
            mxSetCell(cell_array_ptr_channel_types, i, mxCreateString(vec_chan_types[i].c_str()));
        }
        mxSetFieldByNumber(plhs[0], 0, mxGetFieldNumber(plhs[0], "channel_names"), cell_array_ptr_channel_names);
        mxSetFieldByNumber(plhs[0], 0, mxGetFieldNumber(plhs[0], "channel_types"), cell_array_ptr_channel_types);

        mxSetFieldByNumber(plhs[0], 0, mxGetFieldNumber(plhs[0], "comments"), 
            mxCreateString(comments.c_str()));

        FreeEXRHeader(&exr_header);
    } catch (std::runtime_error err) {
        mexErrMsgTxt((std::string("error reading EXR file ") + 
                std::string(filename) + std::string("\n")).c_str());
    }
}
