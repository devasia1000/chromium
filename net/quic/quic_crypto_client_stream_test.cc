// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "net/quic/quic_crypto_client_stream.h"

#include "base/memory/scoped_ptr.h"
#include "net/quic/crypto/aes_128_gcm_encrypter.h"
#include "net/quic/crypto/quic_decrypter.h"
#include "net/quic/crypto/quic_encrypter.h"
#include "net/quic/quic_protocol.h"
#include "net/quic/test_tools/crypto_test_utils.h"
#include "net/quic/test_tools/quic_test_utils.h"
#include "net/quic/test_tools/simple_quic_framer.h"
#include "testing/gmock/include/gmock/gmock.h"
#include "testing/gtest/include/gtest/gtest.h"

namespace net {
namespace test {
namespace {

const char kServerHostname[] = "localhost";

class TestQuicVisitor : public NoOpFramerVisitor {
 public:
  TestQuicVisitor()
      : frame_valid_(false) {
  }

  // NoOpFramerVisitor
  virtual bool OnStreamFrame(const QuicStreamFrame& frame) OVERRIDE {
    frame_ = frame;
    frame_valid_ = true;
    return true;
  }

  bool frame_valid() const {
    return frame_valid_;
  }
  QuicStreamFrame* frame() { return &frame_; }

 private:
  QuicStreamFrame frame_;
  bool frame_valid_;

  DISALLOW_COPY_AND_ASSIGN(TestQuicVisitor);
};

class QuicCryptoClientStreamTest : public ::testing::Test {
 public:
  QuicCryptoClientStreamTest()
      : addr_(),
        connection_(new PacketSavingConnection(1, addr_, true)),
        session_(connection_, QuicConfig(), true),
        stream_(kServerHostname, &session_, &crypto_config_) {
    session_.SetCryptoStream(&stream_);
    session_.config()->SetDefaults();
    crypto_config_.SetDefaults();
  }

  void CompleteCryptoHandshake() {
    EXPECT_TRUE(stream_.CryptoConnect());
    CryptoTestUtils::HandshakeWithFakeServer(connection_, &stream_);
  }

  void ConstructHandshakeMessage() {
    CryptoFramer framer;
    message_data_.reset(framer.ConstructHandshakeMessage(message_));
  }

  IPEndPoint addr_;
  PacketSavingConnection* connection_;
  TestSession session_;
  QuicCryptoClientStream stream_;
  CryptoHandshakeMessage message_;
  scoped_ptr<QuicData> message_data_;
  QuicCryptoClientConfig crypto_config_;
};

TEST_F(QuicCryptoClientStreamTest, NotInitiallyConected) {
  if (!Aes128GcmEncrypter::IsSupported()) {
    LOG(INFO) << "AES GCM not supported. Test skipped.";
    return;
  }

  EXPECT_FALSE(stream_.encryption_established());
  EXPECT_FALSE(stream_.handshake_confirmed());
}

TEST_F(QuicCryptoClientStreamTest, ConnectedAfterSHLO) {
  if (!Aes128GcmEncrypter::IsSupported()) {
    LOG(INFO) << "AES GCM not supported. Test skipped.";
    return;
  }

  CompleteCryptoHandshake();
  EXPECT_TRUE(stream_.encryption_established());
  EXPECT_TRUE(stream_.handshake_confirmed());
}

TEST_F(QuicCryptoClientStreamTest, MessageAfterHandshake) {
  if (!Aes128GcmEncrypter::IsSupported()) {
    LOG(INFO) << "AES GCM not supported. Test skipped.";
    return;
  }

  CompleteCryptoHandshake();

  EXPECT_CALL(*connection_, SendConnectionClose(
      QUIC_CRYPTO_MESSAGE_AFTER_HANDSHAKE_COMPLETE));
  message_.set_tag(kCHLO);
  ConstructHandshakeMessage();
  stream_.ProcessData(message_data_->data(), message_data_->length());
}

TEST_F(QuicCryptoClientStreamTest, BadMessageType) {
  if (!Aes128GcmEncrypter::IsSupported()) {
    LOG(INFO) << "AES GCM not supported. Test skipped.";
    return;
  }

  EXPECT_TRUE(stream_.CryptoConnect());

  message_.set_tag(kCHLO);
  ConstructHandshakeMessage();

  EXPECT_CALL(*connection_, SendConnectionCloseWithDetails(
        QUIC_INVALID_CRYPTO_MESSAGE_TYPE, "Expected REJ"));
  stream_.ProcessData(message_data_->data(), message_data_->length());
}

TEST_F(QuicCryptoClientStreamTest, NegotiatedParameters) {
  if (!Aes128GcmEncrypter::IsSupported()) {
    LOG(INFO) << "AES GCM not supported. Test skipped.";
    return;
  }

  CompleteCryptoHandshake();

  const QuicConfig* config = session_.config();
  EXPECT_EQ(kQBIC, config->congestion_control());
  EXPECT_EQ(kDefaultTimeoutSecs,
            config->idle_connection_state_lifetime().ToSeconds());
  EXPECT_EQ(kDefaultMaxStreamsPerConnection,
            config->max_streams_per_connection());
  EXPECT_EQ(0, config->keepalive_timeout().ToSeconds());

  const QuicCryptoNegotiatedParameters& crypto_params(
      stream_.crypto_negotiated_params());
  EXPECT_EQ(kAESG, crypto_params.aead);
  EXPECT_EQ(kC255, crypto_params.key_exchange);
}

}  // namespace
}  // namespace test
}  // namespace net
