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
 * Mex file for reading images in OpenEXR format. Usage:
 *
 * [image, channel_names] = exr_read_mex(filename[, pixel_type[, 
 *   region_of_interest[, strides]]]), where
 * - the optional argument pixel_type determines data type the pixel values
 *   should be converted to from the pixel format stored in file, possible
 *   values are 0 (uint32), 1 (half) or 2 (float)
 * - region_of_interest is a 6 element array with [x_min, y_min, x_max,
 *   y_max, ch_min, ch_max] specifying a sub region of the pixels
 * - strides is a 3 element array specifying [x_stride, y_stride,
 *   channel_stride]
 * Return arguments are:
 * - image, a 2D or 3D array of floats or unsigned integers (uints are also
 *   used for half precision floats)
 * - channel_names is a cell array of strings holding the names of each
 *   channel
 */

#include <cstdint>
#include <string>
#include <vector>

#include <mex.h>

#define TINYEXR_IMPLEMENTATION
#include "tinyexr.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    // check inputs
    if(1 > nrhs || nrhs > 5) {
        mexErrMsgTxt("Usage: [im, channels] = exr_read(path_to_exr_file[, requested_pixel_type[, roi[, strides[, channel_mask]]]])");
    }
    
    // read inputs
    char *filename = mxArrayToString(prhs[0]);
    
    int requested_pixel_type = TINYEXR_PIXELTYPE_FLOAT;
    if (nrhs > 1) {
        requested_pixel_type = mxGetScalar(prhs[1]);
    }
    
    if (0 > requested_pixel_type || requested_pixel_type > 2) {
        mexErrMsgTxt("requested_pixel_type must be 0 (uint), 1 (half) or 2 (float).\n");
    }
    
    try {
        EXRVersion exr_version;
        EXRImage exr_image;
        EXRHeader exr_header;
        InitEXRHeader(&exr_header);
        InitEXRImage(&exr_image);
        
        // read EXR format from file & check for compatibility
        int ret = ParseEXRVersionFromFile(&exr_version, filename);
        if (ret != TINYEXR_SUCCESS) {
            mexErrMsgTxt((std::string("Error parsing EXR version from file ") +
                    std::string(filename) + std::string(". Not an OpenEXR file?")).c_str());
        }
        if (exr_version.multipart || exr_version.non_image) {
            mexErrMsgTxt("Loading multipart or DeepImage is not supported yet.\n");
        }
        
        // read meta data from EXR file
        const char** err;
        ret = ParseEXRHeaderFromFile(&exr_header, &exr_version, filename, err);
        if (ret != TINYEXR_SUCCESS) {
            mexErrMsgTxt("parsing header from file failed.\n");
        }
        
        bool roi_specified = false;
        int dw[4];
        std::copy(&(exr_header.data_window[0]), &(exr_header.data_window[4]), &(dw[0]));
        int roi_default[4] = {dw[0], dw[1], dw[2], dw[3]};;
        int roi[4];
        std::copy(&(roi_default[0]), &(roi_default[4]), &(roi[0]));
        if (nrhs > 2) {
            if (mxGetNumberOfElements(prhs[2]) == 4) {
                double* pRoi = mxGetPr(prhs[2]);
                // [x_min, y_min, x_max, y_max]
                std::copy(&pRoi[0], &pRoi[4], &roi[0]);
                if (roi[0] < 0 || roi[1] < 0 || roi[2] < 0 || roi[3] < 0) {
                    roi_specified = false;
                    std::copy(&(roi_default[0]), &(roi_default[4]), &(roi[0]));
                } else {
                    roi_specified = true;
                }
            } else {
                mexErrMsgTxt("region of interest must be specified as [x_min, y_min, x_max, y_max]\n");
            }
        }
        
        int stride_x = 1;
        int stride_y = 1;
        if (nrhs > 3) {
            if (mxGetNumberOfElements(prhs[3]) == 2) {
                double* pStrides = mxGetPr(prhs[3]);
                // [stride_x, stride_y]
                stride_x = pStrides[0];
                stride_y = pStrides[1];
            } else {
                mexErrMsgTxt("strides must be specified as [stride_x, stride_y]\n");
            }
        }
        
        if (roi_specified && (roi[0] < exr_header.data_window[0] ||
                roi[1] < exr_header.data_window[1] ||
                roi[2] > exr_header.data_window[2] ||
                roi[3] > exr_header.data_window[3])) {
            char buffer[1000];
            sprintf(buffer, "region of interest out of image bounds: given roi: [%d, %d, %d, %d], img: [%d x %d x %d].\n",
                    roi[0], roi[1], roi[2], roi[3],
                    exr_header.data_window[2] - exr_header.data_window[0] + 1,
                    exr_header.data_window[3] - exr_header.data_window[1] + 1,
                    exr_header.num_channels);
            mexErrMsgTxt(buffer);
        }
        
        size_t num_channels_mask = mxGetNumberOfElements(prhs[4]);
        std::vector<double> channelMask(num_channels_mask);
        if (nrhs > 4) {
            double* pChannelMask = mxGetPr(prhs[4]);
            std::copy(&pChannelMask[0], &pChannelMask[num_channels_mask], &channelMask[0]);
        }
        
        // set requested pixel type (uint, half or float)
        for (size_t i = 0; i < exr_header.num_channels; i++) {
            if (exr_header.pixel_types[i] == TINYEXR_PIXELTYPE_HALF) {
                exr_header.requested_pixel_types[i] = requested_pixel_type;
            }
        }
        
        size_t height = exr_header.data_window[3] - exr_header.data_window[1] + 1;
        size_t width = exr_header.data_window[2] - exr_header.data_window[0] + 1;
        size_t height_out = roi[3] - roi[1] + 1;
        size_t width_out  = roi[2] - roi[0] + 1;
        height_out = ceil((float)height_out / stride_y);
        width_out = ceil((float)width_out / stride_x);
        size_t num_channels_out = channelMask.size();
        
        // read pixel values from EXR file
        ret = LoadEXRImageFromFile(&exr_image, &exr_header, filename, err);
        if (ret != 0) {
            mexErrMsgTxt((std::string("Load EXR error: ") + std::string(*err)).c_str());
        }
        
        // set dimensions of Matlab array
        mwSize dims[3] = {height_out, width_out, num_channels_out};
        
        // copy pixel values to Matlab array
        if (requested_pixel_type == TINYEXR_PIXELTYPE_FLOAT) {
            plhs[0] = mxCreateNumericArray(3, dims, mxSINGLE_CLASS, mxREAL);
            float* outMatrix = (float*) mxGetData(plhs[0]);
            float** images = (float**) exr_image.images;
            for (size_t ci_out = 0; ci_out < channelMask.size(); ci_out++) {
                size_t ci = channelMask[ci_out];
                size_t x_out = 0;
                for (size_t x = roi[0]; x <= roi[2]; x += stride_x) {
                    size_t y_out = 0;
                    for (size_t y = roi[1]; y <= roi[3]; y += stride_y) {
                        outMatrix[height_out * width_out * ci_out + x_out * height_out + y_out] =
                                images[ci][x + y * width];
                        y_out++;
                    }
                    x_out++;
                }
            }
        } else if (requested_pixel_type == TINYEXR_PIXELTYPE_HALF) {
            // half precision floats are stored as uint16 in matlab
            plhs[0] = mxCreateNumericArray(3, dims, mxUINT16_CLASS, mxREAL);
            unsigned short* outMatrix = (unsigned short*) mxGetData(plhs[0]);
            unsigned short** images = (unsigned short**) exr_image.images;
            for (size_t ci_out = 0; ci_out < channelMask.size(); ci_out++) {
                size_t ci = channelMask[ci_out];
                size_t x_out = 0;
                for (size_t x = roi[0]; x <= roi[2]; x += stride_x) {
                    size_t y_out = 0;
                    for (size_t y = roi[1]; y <= roi[3]; y += stride_y) {
                        outMatrix[height_out * width_out * ci_out + x_out * height_out + y_out] =
                                images[ci][x + y * width];
                        y_out++;
                    }
                    x_out++;
                }
            }
        } else {
            plhs[0] = mxCreateNumericArray(3, dims, mxUINT32_CLASS, mxREAL);
            unsigned int* outMatrix = (unsigned int*) mxGetData(plhs[0]);
            unsigned int** images = (unsigned int**) exr_image.images;
            for (size_t ci_out = 0; ci_out < channelMask.size(); ci_out++) {
                size_t ci = channelMask[ci_out];
                size_t x_out = 0;
                for (size_t x = roi[0]; x <= roi[2]; x += stride_x) {
                    size_t y_out = 0;
                    for (size_t y = roi[1]; y <= roi[3]; y += stride_y) {
                        outMatrix[height_out * width_out * ci_out + x_out * height_out + y_out] =
                                images[ci][x + y * width];
                        y_out++;
                    }
                    x_out++;
                }
            }
        }
        
        // extract channel names
        if (nlhs > 1) {
            dims[0] = 1;
            dims[1] = num_channels_out;
            
            plhs[1] = mxCreateCellArray(2, dims);
            for (size_t ci_out = 0; ci_out < channelMask.size(); ci_out++) {
                size_t ci = channelMask[ci_out];
                mxSetCell(plhs[1], ci_out, mxDuplicateArray(mxCreateString(exr_header.channels[ci].name)));
            }
        }
        
        FreeEXRImage(&exr_image);
        FreeEXRHeader(&exr_header);
    } catch (std::runtime_error err) {
        mexErrMsgTxt((std::string("error reading EXR file ") +
                std::string(filename) + std::string("\n")).c_str());
    }
}
