// Copyright 2013 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef CHROME_BROWSER_SYNC_FILE_SYSTEM_DRIVE_FILE_SYNC_TASK_MANAGER_H_
#define CHROME_BROWSER_SYNC_FILE_SYSTEM_DRIVE_FILE_SYNC_TASK_MANAGER_H_

#include <deque>

#include "base/callback.h"
#include "base/memory/scoped_ptr.h"
#include "base/memory/weak_ptr.h"
#include "base/threading/non_thread_safe.h"
#include "chrome/browser/google_apis/gdata_errorcode.h"
#include "webkit/fileapi/syncable/sync_callbacks.h"
#include "webkit/fileapi/syncable/sync_status_code.h"

class Profile;

namespace tracked_objects {
class Location;
}

namespace sync_file_system {

class DriveFileSyncService;

class DriveFileSyncTaskManager
    : public base::NonThreadSafe,
      public base::SupportsWeakPtr<DriveFileSyncTaskManager> {
 public:
  class TaskToken;
  typedef base::Callback<void(const SyncStatusCallback& callback)> Task;

  explicit DriveFileSyncTaskManager(
      base::WeakPtr<DriveFileSyncService> service);
  virtual ~DriveFileSyncTaskManager();

  // This needs to be called to start task scheduling.
  // If |status| is not SYNC_STATUS_OK calling this may change the
  // service status. This should not be called more than once.
  void Initialize(SyncStatusCode status);

  void ScheduleTask(const Task& task,
                    const SyncStatusCallback& callback);

  // Runs the posted task only when we're idle.
  void ScheduleTaskIfIdle(const Task& task);

  void NotifyLastDriveError(google_apis::GDataErrorCode error);
  void NotifyTaskDone(scoped_ptr<TaskToken> token,
                      const SyncStatusCallback& callback,
                      SyncStatusCode status);

 private:
  // This should be called when an async task needs to get a task token.
  scoped_ptr<TaskToken> GetToken(const tracked_objects::Location& from_here);

  // Creates a completion callback that calls NotifyTaskDone.
  // It is ok to give null |callback|.
  SyncStatusCallback CreateCompletionCallback(
      scoped_ptr<TaskToken> token,
      const SyncStatusCallback& callback);

  base::WeakPtr<DriveFileSyncService> service_;

  SyncStatusCode last_operation_status_;
  google_apis::GDataErrorCode last_gdata_error_;
  std::deque<base::Closure> pending_tasks_;

  // Absence of |token_| implies a task is running. Incoming tasks should
  // wait for the task to finish in |pending_tasks_| if |token_| is null.
  // Each task must take TaskToken instance from |token_| and must hold it
  // until it finished. And the task must return the instance through
  // NotifyTaskDone when the task finished.
  scoped_ptr<TaskToken> token_;

  DISALLOW_COPY_AND_ASSIGN(DriveFileSyncTaskManager);
};

}  // namespace sync_file_system

#endif  // CHROME_BROWSER_SYNC_FILE_SYSTEM_DRIVE_FILE_SYNC_TASK_MANAGER_H_
