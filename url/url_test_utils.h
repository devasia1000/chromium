// Copyright 2013 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef URL_URL_TEST_UTILS_H_
#define URL_URL_TEST_UTILS_H_

// Convenience functions for string conversions.
// These are mostly intended for use in unit tests.

#include <string>

#include "base/string16.h"
#include "testing/gtest/include/gtest/gtest.h"
#include "url/url_canon_internal.h"

namespace url_test_utils {

// Converts a UTF-16 string from native wchar_t format to char16, by
// truncating the high 32 bits.  This is not meant to handle true UTF-32
// encoded strings.
inline string16 WStringToUTF16(const wchar_t* src) {
  string16 str;
  int length = static_cast<int>(wcslen(src));
  for (int i = 0; i < length; ++i) {
    str.push_back(static_cast<char16>(src[i]));
  }
  return str;
}

// Converts a string from UTF-8 to UTF-16
inline string16 ConvertUTF8ToUTF16(const std::string& src) {
  int length = static_cast<int>(src.length());
  EXPECT_LT(length, 1024);
  url_canon::RawCanonOutputW<1024> output;
  EXPECT_TRUE(url_canon::ConvertUTF8ToUTF16(src.data(), length, &output));
  return string16(output.data(), output.length());
}

// Converts a string from UTF-16 to UTF-8
inline std::string ConvertUTF16ToUTF8(const string16& src) {
  std::string str;
  url_canon::StdStringCanonOutput output(&str);
  EXPECT_TRUE(url_canon::ConvertUTF16ToUTF8(src.data(),
                                            static_cast<int>(src.length()),
                                            &output));
  output.Complete();
  return str;
}

}  // namespace url_test_utils

#endif  // URL_URL_TEST_UTILS_H_
