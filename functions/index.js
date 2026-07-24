// --- Imports ---
const {onDocumentCreated, onDocumentUpdated} =
  require("firebase-functions/v2/firestore");
const {onCall, onRequest, HttpsError} =
  require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");

const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const stripe = require("stripe");

initializeApp();
const db = getFirestore();

// ====================== SECRETS ======================
const stripeTestKey = defineSecret("STRIPE_SECRET_TEST_KEY");
const stripeLiveKey = defineSecret("STRIPE_SECRET_LIVE_KEY");
const webhookTestKey = defineSecret("STRIPE_WEBHOOK_TEST_KEY");
const webhookLiveKey = defineSecret("STRIPE_WEBHOOK_LIVE_KEY");

// ====================== TEST USERS ======================
// Add your UID and any tester UIDs here
const TEST_USERS = [
  // ← Replace with your actual Firebase UID
  "3thmMojTt4brj6JcxrrihVblA6n2",
  "jgitF3Wn9zZa8Kue1nVItjkd7dg2"
  // "another-tester-uid-2",
];

// ====================== HELPERS ======================
const isTestUser = (userId) => TEST_USERS.includes(userId || "");

const getStripeClient = (userId) => {
  const useTest = isTestUser(userId);
  const key = useTest ? stripeTestKey.value() : stripeLiveKey.value();

  console.log(`🔑 Stripe Mode for user ${userId}: ${useTest ? "TEST" : "LIVE"}`);
  return stripe(key);
};


// =============================================================================
// FUNCTION 1: NOTIFY DRIVERS OF NEW RIDES
// =============================================================================
exports.notifyDriversOfNewRide = onDocumentCreated("rideRequests/{rideId}",
    (event) => {
      const snapshot = event.data;
      if (!snapshot) {
        console.log("No data associated with the event");
        return;
      }
      const rideRequest = snapshot.data();
      const rideId = event.params.rideId;

      const logMessage =
        `New ride request: ${rideId}. ` +
        `Pickup: ${rideRequest.pickupAddress || "Unknown"}`;
      console.log(logMessage);

      const message = {
        topic: "online_drivers",
        android: {
          notification: {sound: "ridenotification"},
          priority: "high",
        },
        apns: {
          headers: {
            "apns-push-type": "alert",
            "apns-priority": "10",
          },
          payload: {
            aps: {
              alert: {
                title: "New Ride Request!",
                body: `Pickup from: ${rideRequest.pickupAddress || "Unknown"}`,
              },
              sound: "ridenotification.wav",
            },
          },
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          rideId: rideId,
          type: "ride_request",
          title: "New Ride Request!",
          body: `Pickup from: ${rideRequest.pickupAddress || "Unknown"}`,
        },
      };

      return getMessaging().send(message)
          .then((response) => console.log("Notification sent successfully"))
          .catch((error) => console.error("Notification error:", error));
    });

// =============================================================================
// FUNCTION 2: NOTIFY ON NEW CHAT MESSAGE
// =============================================================================
exports.notifyOnNewChatMessage = onDocumentCreated(
    "chats/{rideId}/messages/{messageId}",
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;

      const msg = snapshot.data();
      const receiverId = msg.receiverId;
      if (!receiverId) return;

      const senderName = msg.senderName || "Your driver/passenger";
      const text = msg.text || "New message";

      const message = {
        topic: `user_${receiverId}`,
        notification: {
          title: senderName,
          body: text.length > 100 ? text.substring(0, 97) + "..." : text,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "default_channel",
            sound: "default",
            priority: "high",
          },
        },
        apns: {
          payload: {aps: {sound: "default"}},
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          type: "chat",
          rideId: event.params.rideId,
        },
      };

      try {
        await getMessaging().send(message);
        console.log("Chat notification sent");
      } catch (error) {
        console.error("Chat notification error:", error);
      }
    });

// =============================================================================
// FUNCTION 3: NOTIFY PASSENGER OF RIDE STATUS CHANGES
// =============================================================================
exports.notifyPassengerOfRideStatusChange = onDocumentUpdated(
    "rideRequests/{rideId}",
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();

      if (before.status === after.status) return;

      const passengerId = after.passengerId;
      if (!passengerId) return;

      let title; let body;
      switch (after.status) {
        case "accepted":
          title = "Driver Found!";
          body = "Your driver is on the way to pick you up.";
          break;
        case "enroute":
          title = "Driver Arriving!";
          body = "Your driver is at your pickup location.";
          break;
        case "ongoing":
          title = "Trip Started";
          body = `Your trip to ${after.destinationAddress} has begun.`;
          break;
        case "completed":
          title = "Trip Completed";
          body = "You have arrived. Thanks for riding with LeisureRyde!";
          break;
        case "cancelled_by_driver":
        case "cancelled":
          title = "Ride Cancelled";
          body = after.status === "cancelled_by_driver" ?
          "Your driver has cancelled the ride." :
          "Your ride has been cancelled.";
          break;
        default:
          return;
      }

      const message = {
        topic: `user_${passengerId}`,
        notification: {title, body},
        android: {
          priority: "high",
          notification: {
            channelId: "default_channel",
            sound: "default",
            priority: "high",
          },
        },
        apns: {
          headers: {
            "apns-push-type": "alert",
            "apns-priority": "10",
          },
          payload: {
            aps: {alert: {title, body}, sound: "default"},
          },
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          type: "ride_status",
          rideId: event.params.rideId,
          status: after.status,
        },
      };

      try {
        await getMessaging().send(message);
        console.log(`Passenger notified — status: ${after.status}`);
      } catch (error) {
        console.error("Passenger notification error:", error);
      }
    });

// =============================================================================
// FUNCTION 5: CREATE STRIPE CHECKOUT SESSION (Per User Decision)
// =============================================================================
exports.createStripeCheckout = onCall(
    {secrets: [stripeTestKey, stripeLiveKey]},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "You must be logged in to make a payment.",
        );
      }

      const userId = request.auth.uid;
      const {amount, currency, bookingId} = request.data || {};

      if (!amount || !currency || !bookingId) {
        throw new HttpsError(
            "invalid-argument",
            "Missing required payment data.",
        );
      }

      const paymentRef = db.collection("payments").doc();
      const paymentId = paymentRef.id;

      try {
        const stripeClient = getStripeClient(userId);

        const session = await stripeClient.checkout.sessions.create({
          payment_method_types: ["card"],
          mode: "payment",
          line_items: [{
            price_data: {
              currency: currency,
              unit_amount: Math.round(parseFloat(amount) * 100),
              product_data: {name: "Leisure Ryde Service"},
            },
            quantity: 1,
          }],
          success_url: "https://example.com/success",
          cancel_url: "https://example.com/cancel",
          metadata: {
            payment_id: paymentId,
            user_id: userId,
          },
        });

        await paymentRef.set({
          userId: userId,
          bookingId: bookingId,
          amount: parseFloat(amount),
          currency: currency,
          status: "pending",
          createdAt: FieldValue.serverTimestamp(),
          stripeSessionId: session.id,
        });

        return {checkoutUrl: session.url, paymentId: paymentId};
      } catch (error) {
        console.error("Stripe session creation failed:", error);
        throw new HttpsError("internal", "Could not create a payment session.");
      }
    });

// =============================================================================
// FUNCTION 6: STRIPE WEBHOOK LISTENER (Works for both Test & Live)
// =============================================================================
exports.stripeWebhook = onRequest(
    {secrets: [stripeTestKey, stripeLiveKey, webhookTestKey, webhookLiveKey]},
    async (req, res) => {
      const sig = req.headers["stripe-signature"];

      // Use the appropriate webhook secret based on current preference
      const stripeClient = stripe(stripeTestKey.value());

      let event;

      try {
        event = stripeClient.webhooks.constructEvent(
            req.rawBody, sig, webhookLiveKey.value(), // try live secret first
        );
      } catch (liveErr) {
        try {
          event = stripeClient.webhooks.constructEvent(
              req.rawBody, sig, webhookTestKey.value(), // fall back to test
          );
        } catch (testErr) {
          // both failed — genuinely invalid signature
          res.status(400).send(`Webhook Error: ${testErr.message}`);
          return;
        }
      }

      if (event.type === "checkout.session.completed") {
        const session = event.data.object;
        const paymentId = session.metadata.payment_id;

        await db.collection("payments").doc(paymentId).update({
          status: "succeeded",
          updatedAt: FieldValue.serverTimestamp(),
          stripePaymentIntentId: session.payment_intent,
        });
        console.log(`Updated payment ${paymentId} to 'succeeded'.`);
      }

      res.json({received: true});
    });
