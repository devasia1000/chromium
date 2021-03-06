// Copyright 2013 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef CHROME_BROWSER_MANAGED_MODE_MANAGED_USER_REGISTRATION_SERVICE_FACTORY_H_
#define CHROME_BROWSER_MANAGED_MODE_MANAGED_USER_REGISTRATION_SERVICE_FACTORY_H_

#include "base/memory/singleton.h"
#include "chrome/browser/profiles/profile_keyed_service_factory.h"

class ManagedUserRegistrationService;

class ManagedUserRegistrationServiceFactory
    : public ProfileKeyedServiceFactory {
 public:
  static ManagedUserRegistrationService* GetForProfile(Profile* profile);

  static ManagedUserRegistrationServiceFactory* GetInstance();

  // Used to create instances for testing.
  static ProfileKeyedService* BuildInstanceFor(Profile* profile);

 private:
  friend struct DefaultSingletonTraits<ManagedUserRegistrationServiceFactory>;

  ManagedUserRegistrationServiceFactory();
  virtual ~ManagedUserRegistrationServiceFactory();

  // ProfileKeyedServiceFactory:
  virtual ProfileKeyedService* BuildServiceInstanceFor(
      content::BrowserContext* profile) const OVERRIDE;
};

#endif  // CHROME_BROWSER_MANAGED_MODE_MANAGED_USER_REGISTRATION_SERVICE_FACTORY_H_
