// --- Imports ---
const {onDocumentCreated, onDocumentUpdated} =
  require("firebase-functions/v2/firestore");
const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const {defineString} = require("firebase-functions/params");
const admin = require("firebase-admin");
const stripe = require("stripe");

admin.initializeApp();

// Define the secret parameters your functions will use.
const stripeSecretKey = defineString("STRIPE_SECRET_KEY");
const stripeWebhookSecret = defineString("STRIPE_WEBHOOK_SECRET");

// Initialize Stripe with the secret key parameter's value.
const stripeClient = stripe(stripeSecretKey.value());

// =============================================================================
// FUNCTION 1: NOTIFY DRIVERS OF NEW RIDES (v2 Syntax)
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

      const logMessage = `New ride request: ${rideId}. ` +
                       `Pickup: ${rideRequest.pickupAddress}`;
      console.log(logMessage);

      // No top-level 'notification' field on Android → treated as a data-only
      // message, so onBackgroundMessage fires and can show a properly grouped
      // local notification instead of the OS displaying each one separately.
      // iOS still gets a visible alert via the apns.payload.aps.alert field.
      const message = {
        topic: "online_drivers",
        android: {priority: "high"},
        apns: {
          headers: {
            "apns-push-type": "alert",
            "apns-priority": "10",
          },
          payload: {
            aps: {
              alert: {
                title: "New Ride Request!",
                body: `Pickup from: ${rideRequest.pickupAddress}`,
              },
              sound: "default",
            },
          },
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          rideId: rideId,
          type: "ride_request",
          title: "New Ride Request!",
          body: `Pickup from: ${rideRequest.pickupAddress}`,
        },
      };


      return admin.messaging().send(message)
          .then((response) => {
            console.log("Successfully sent notification to topic:", response);
            return {success: true};
          })
          .catch((error) => {
            console.error("Error sending notification:", error);
            return {error: error};
          });
    });

// =============================================================================
// FUNCTION 2: NOTIFY ON NEW CHAT MESSAGE (v2 Syntax)
// =============================================================================
exports.notifyOnNewChatMessage = onDocumentCreated(
    "chats/{rideId}/messages/{messageId}",
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;

      const msg = snapshot.data();
      const receiverId = msg.receiverId;
      const senderName = msg.senderName || "Your driver/passenger";
      const text = msg.text || "New message";

      if (!receiverId) return;

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
          payload: {
            aps: {sound: "default"},
          },
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          type: "chat",
          rideId: event.params.rideId,
        },
      };

      try {
        const response = await admin.messaging().send(message);
        console.log("Chat notification sent:", response);
      } catch (error) {
        console.error("Error sending chat notification:", error);
      }
    });

// =============================================================================
// FUNCTION 3: NOTIFY PASSENGER OF RIDE STATUS CHANGES (v2 Syntax)
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
          title = "Ride Cancelled";
          body = "Your driver has cancelled the ride.";
          break;
        case "cancelled":
          title = "Ride Cancelled";
          body = "Your ride has been cancelled.";
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
            aps: {
              alert: {title, body},
              sound: "default",
            },
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
        const response = await admin.messaging().send(message);
        console.log(`Passenger notified — status: ${after.status}:`, response);
      } catch (error) {
        console.error("Error sending passenger notification:", error);
      }
    });

// =============================================================================
// FUNCTION 5: CREATE STRIPE CHECKOUT SESSION (v2 Syntax)
// =============================================================================
exports.createStripeCheckout = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated",
        "You must be logged in to make a payment.");
  }

  const userId = request.auth.uid;
  const {amount, currency, bookingId} = request.data;

  if (!amount || !currency || !bookingId) {
    throw new HttpsError("invalid-argument", "Missing required payment data.");
  }

  const paymentRef = admin.firestore().collection("payments").doc();
  const paymentId = paymentRef.id;

  try {
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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      stripeSessionId: session.id,
    });

    return {checkoutUrl: session.url, paymentId: paymentId};
  } catch (error) {
    console.error("Stripe session creation failed:", error);
    throw new HttpsError("internal", "Could not create a payment session.");
  }
});

// =============================================================================
// FUNCTION 6: STRIPE WEBHOOK LISTENER (v2 Syntax)
// =============================================================================
exports.stripeWebhook = onRequest(async (req, res) => {
  const sig = req.headers["stripe-signature"];
  const endpointSecret = stripeWebhookSecret.value();

  let event;
  try {
    event = stripeClient.webhooks.constructEvent(
        req.rawBody, sig, endpointSecret);
  } catch (err) {
    console.error("Webhook signature verification failed.", err.message);
    res.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  if (event.type === "checkout.session.completed") {
    const session = event.data.object;
    const paymentId = session.metadata.payment_id;

    await admin.firestore().collection("payments").doc(paymentId).update({
      status: "succeeded",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      stripePaymentIntentId: session.payment_intent,
    });
    console.log(`Updated payment ${paymentId} to 'succeeded'.`);
  }

  res.json({received: true});
});
