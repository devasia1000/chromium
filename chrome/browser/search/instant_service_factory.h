// Copyright 2013 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef CHROME_BROWSER_SEARCH_INSTANT_SERVICE_FACTORY_H_
#define CHROME_BROWSER_SEARCH_INSTANT_SERVICE_FACTORY_H_

#include "base/basictypes.h"
#include "base/compiler_specific.h"
#include "base/memory/singleton.h"
#include "chrome/browser/profiles/profile_keyed_service_factory.h"

class InstantService;
class Profile;
class ProfileKeyedService;

// Singleton that owns all InstantServices and associates them with Profiles.
class InstantServiceFactory : public ProfileKeyedServiceFactory {
 public:
  // Returns the InstantService for |profile|.
  static InstantService* GetForProfile(Profile* profile);

  static InstantServiceFactory* GetInstance();

 private:
  friend struct DefaultSingletonTraits<InstantServiceFactory>;

  InstantServiceFactory();
  virtual ~InstantServiceFactory();

  // Overridden from ProfileKeyedServiceFactory:
  virtual content::BrowserContext* GetBrowserContextToUse(
      content::BrowserContext* context) const OVERRIDE;
  virtual ProfileKeyedService* BuildServiceInstanceFor(
      content::BrowserContext* profile) const OVERRIDE;

  DISALLOW_COPY_AND_ASSIGN(InstantServiceFactory);
};

#endif  // CHROME_BROWSER_SEARCH_INSTANT_SERVICE_FACTORY_H_
