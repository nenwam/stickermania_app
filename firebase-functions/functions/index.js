const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

const SERVICE_ACCOUNT_EMAIL = "1056784785281-compute@developer.gserviceaccount.com";
// *** ADD/CHANGE THIS LINE ***
const FUNCTION_REGION = "us-west2"; // Match your Firestore region

exports.sendChatNotification = onDocumentCreated(
  {
    document: "notifications/{notificationId}",
    serviceAccount: SERVICE_ACCOUNT_EMAIL,
    // *** ADD/CHANGE THIS LINE ***
    region: FUNCTION_REGION, // Specify the region here
  },
  async (event) => {
    // ... rest of your function code ...
    // Make sure console logs reflect the correct function if region changes
    // console.log(`Running in region: ${FUNCTION_REGION}`);
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data associated with the event");
      return;
    }
    const notificationData = snapshot.data();

    try {
        const token = notificationData.token;
        const notification = notificationData.notification;
        const data = notificationData.data || {};

        if (!token) {
            console.error(`[${FUNCTION_REGION}] Missing FCM token for doc:`, snapshot.id);
            await snapshot.ref.delete();
            console.log(`[${FUNCTION_REGION}] Deleted doc due to missing token:`, snapshot.id);
            return;
        }

        console.log(`[${FUNCTION_REGION}] Sending notification to token:`, token, "for doc:", snapshot.id);

        const message = {
          // Remove the top-level notification object
          // notification: notification, <- REMOVE THIS
          
          token: token,
          data: data,
          apns: {
            headers: {
              "apns-priority": "10"
            },
            payload: {
              aps: {
                alert: {
                  title: notification.title,
                  body: notification.body
                },
                badge: 1,
                sound: "default"
              }
            }
          }
        };

        const response = await admin.messaging().send(message);
        console.log(`[${FUNCTION_REGION}] Successfully sent message:`, response, "for doc:", snapshot.id);

        await snapshot.ref.delete();
        console.log(`[${FUNCTION_REGION}] Processed and deleted doc:`, snapshot.id);

    } catch (error) {
        console.error(`[${FUNCTION_REGION}] Error sending notification for doc:`, snapshot.id, error);
        try {
            await snapshot.ref.delete();
            console.log(`[${FUNCTION_REGION}] Deleted doc after error:`, snapshot.id);
        } catch (deleteError) {
            console.error(`[${FUNCTION_REGION}] Error deleting doc after main error:`, snapshot.id, deleteError);
        }
    }
  }
);