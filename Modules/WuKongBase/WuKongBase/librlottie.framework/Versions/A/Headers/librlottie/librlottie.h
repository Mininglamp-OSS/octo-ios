/*
* Copyright (c) 2018 Samsung Electronics Co., Ltd. All rights reserved.
*
* This library is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
* License as published by the Free Software Foundation; either
* version 2.1 of the License, or (at your option) any later version.
*
* This library is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* Lesser General Public License for more details.
*
* You should have received a copy of the GNU Lesser General Public
* License along with this library; if not, write to the Free Software
* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
*/

#import <Foundation/Foundation.h>

//! Project version number for librlottie.
FOUNDATION_EXPORT double librlottieVersionNumber;

//! Project version string for librlottie.
FOUNDATION_EXPORT const unsigned char librlottieVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <librlottie/PublicHeader.h>

#if __has_include(<librlottie/rlottie_capi.h>)
#import <librlottie/rlottie_capi.h>
#import <librlottie/rlottiecommon.h>
#else
#import "rlottie_capi.h"
#import "rlottiecommon.h"
#endif
