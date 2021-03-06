// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef NATIVE_CLIENT_SRC_TRUSTED_PLUGIN_PNACL_RESOURCES_H_
#define NATIVE_CLIENT_SRC_TRUSTED_PLUGIN_PNACL_RESOURCES_H_

#include <map>
#include <vector>

#include "native_client/src/include/nacl_macros.h"
#include "native_client/src/include/nacl_string.h"
#include "native_client/src/trusted/desc/nacl_desc_wrapper.h"
#include "native_client/src/trusted/plugin/nexe_arch.h"
#include "native_client/src/trusted/plugin/plugin_error.h"

#include "ppapi/c/private/pp_file_handle.h"
#include "ppapi/cpp/completion_callback.h"

namespace plugin {

class Manifest;
class Plugin;
class PnaclCoordinator;

// Constants for loading LLC and LD.
class PnaclUrls {
 public:
  static nacl::string GetBaseUrl();
  static bool IsPnaclComponent(const nacl::string& full_url);
  static nacl::string PnaclComponentURLToFilename(
      const nacl::string& full_url);
  static const nacl::string GetLlcUrl() { return nacl::string(kLlcUrl); }
  static const nacl::string GetLdUrl() { return nacl::string(kLdUrl); }
 private:
  static const char kLlcUrl[];
  static const char kLdUrl[];
};

// Loads a list of resources, providing a way to get file descriptors for
// these resources.  URLs for resources are resolved by the manifest
// and point to pnacl component filesystem resources.
class PnaclResources {
 public:
  PnaclResources(Plugin* plugin,
                 PnaclCoordinator* coordinator,
                 const Manifest* manifest,
                 const std::vector<nacl::string>& resource_urls,
                 const pp::CompletionCallback& all_loaded_callback)
      : plugin_(plugin),
        coordinator_(coordinator),
        manifest_(manifest),
        resource_urls_(resource_urls),
        all_loaded_callback_(all_loaded_callback) {
  }
  virtual ~PnaclResources();

  // Start loading the resources.  After construction, this is the first step.
  virtual void StartLoad();
  // Get file descs by name. Only valid after all_loaded_callback_ has been run.
  nacl::DescWrapper* WrapperForUrl(const nacl::string& url);

  static int32_t GetPnaclFD(Plugin* plugin, const char* filename);

 private:
  NACL_DISALLOW_COPY_AND_ASSIGN(PnaclResources);

  // The plugin requesting the resource loading.
  Plugin* plugin_;
  // The coordinator responsible for reporting errors, etc.
  PnaclCoordinator* coordinator_;
  // The manifest for looking up resource URLs.
  const Manifest* manifest_;
  // The list of resource URLs (relative to resource_base_url_) to load.
  std::vector<nacl::string> resource_urls_;
  // Callback to be invoked when all resources can be guaranteed available.
  pp::CompletionCallback all_loaded_callback_;
  // The descriptor wrappers for the downloaded URLs.  Only valid
  // once all_loaded_callback_ has been invoked.
  std::map<nacl::string, nacl::DescWrapper*> resource_wrappers_;
};

}  // namespace plugin;
#endif  // NATIVE_CLIENT_SRC_TRUSTED_PLUGIN_PNACL_RESOURCES_H_
