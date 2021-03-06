# Copyright (c) 2012 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

{
  'targets': [
    {
      'target_name': 'webkit_base',
      'type': '<(component)',
      'variables': { 'enable_wexit_time_destructors': 1, },
      'dependencies': [
        '<(DEPTH)/base/base.gyp:base',
        '<(DEPTH)/build/temp_gyp/googleurl.gyp:googleurl',
        '<(DEPTH)/net/net.gyp:net',
        '<(DEPTH)/third_party/WebKit/Source/WebKit/chromium/WebKit.gyp:webkit',
      ],
      'defines': ['WEBKIT_BASE_IMPLEMENTATION'],
      'sources': [
        'data_element.cc',
        'data_element.h',
        'file_path_string_conversions.cc',
        'file_path_string_conversions.h',
        'origin_url_conversions.cc',
        'origin_url_conversions.h',
        'webkit_base_export.h',
      ],
    },
  ],
}
