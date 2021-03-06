# Copyright (c) 2012 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import cStringIO
import json
import logging
import socket
import threading


from telemetry.core import util
from telemetry.core.chrome import trace_result
from telemetry.core.chrome import websocket
from telemetry.core.timeline import trace_event_importer


class TracingUnsupportedException(Exception):
  pass

class TraceResultImpl(object):
  def __init__(self, tracing_data):
    self._tracing_data = tracing_data

  def Serialize(self, f):
    f.write('{"traceEvents": [')
    d = self._tracing_data
    # Note: we're not using ','.join here because the strings that are in the
    # tracing data are typically many megabytes in size. In the fast case, f is
    # just a file, so by skipping the in memory step we keep our memory
    # footprint low and avoid additional processing.
    if len(d) == 0:
      pass
    elif len(d) == 1:
      f.write(d[0])
    else:
      f.write(d[0])
      for i in range(1, len(d)):
        f.write(',')
        f.write(d[i])
    f.write(']}')

  def AsTimelineModel(self):
    f = cStringIO.StringIO()
    self.Serialize(f)
    return trace_event_importer.Import(
      f.getvalue())

class TracingBackend(object):
  def __init__(self, devtools_port):
    debugger_url = 'ws://localhost:%i/devtools/browser' % devtools_port
    self._socket = websocket.create_connection(debugger_url)
    self._next_request_id = 0
    self._cur_socket_timeout = 0
    self._thread = None
    self._tracing_data = []

  def BeginTracing(self):
    self._CheckNotificationSupported()
    req = {'method': 'Tracing.start'}
    self._SyncRequest(req)
    # Tracing.start will send asynchronous notifications containing trace
    # data, until Tracing.end is called.
    self._thread = threading.Thread(target=self._TracingReader)
    self._thread.start()

  def EndTracing(self):
    req = {'method': 'Tracing.end'}
    self._SyncRequest(req)
    self._thread.join()
    self._thread = None

  def GetTraceResultAndReset(self):
    assert not self._thread
    ret = trace_result.TraceResult(
      TraceResultImpl(self._tracing_data))
    self._tracing_data = []
    return ret

  def Close(self):
    if self._socket:
      self._socket.close()
      self._socket = None

  def _TracingReader(self):
    while self._socket:
      try:
        data = self._socket.recv()
        if not data:
          break
        res = json.loads(data)
        logging.debug('got [%s]', data)
        if 'Tracing.dataCollected' == res.get('method'):
          value = res.get('params', {}).get('value')
          self._tracing_data.append(value)
        elif 'Tracing.tracingComplete' == res.get('method'):
          break
      except (socket.error, websocket.WebSocketException):
        logging.warning('Timeout waiting for tracing response, unusual.')

  def _SyncRequest(self, req, timeout=10):
    self._SetTimeout(timeout)
    req['id'] = self._next_request_id
    self._next_request_id += 1
    data = json.dumps(req)
    logging.debug('will send [%s]', data)
    self._socket.send(data)

  def _SetTimeout(self, timeout):
    if self._cur_socket_timeout != timeout:
      self._socket.settimeout(timeout)
      self._cur_socket_timeout = timeout

  def _CheckNotificationSupported(self):
    """Ensures we're running against a compatible version of chrome."""
    req = {'method': 'Tracing.hasCompleted'}
    self._SyncRequest(req)
    while True:
      try:
        data = self._socket.recv()
      except (socket.error, websocket.WebSocketException):
        raise util.TimeoutException(
            'Timed out waiting for reply. This is unusual.')
      logging.debug('got [%s]', data)
      res = json.loads(data)
      if res['id'] != req['id']:
        logging.debug('Dropped reply: %s', json.dumps(res))
        continue
      if res.get('response'):
        raise TracingUnsupportedException(
            'Tracing not supported for this browser')
      elif 'error' in res:
        return
