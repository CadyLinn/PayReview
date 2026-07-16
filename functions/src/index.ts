import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

initializeApp();

const db = getFirestore();

export const ensureAccountState = onCall(
  { region: "asia-east1" },
  async (request) => {
    const userID = request.auth?.uid;

    if (!userID) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const accountStateReference = db.doc(`accountStates/${userID}`);
    const status = await db.runTransaction(async (transaction) => {
      const accountState = await transaction.get(accountStateReference);

      if (!accountState.exists) {
        transaction.create(accountStateReference, {
          status: "active",
          schemaVersion: 1,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        });
        return "active";
      }

      const existingStatus = accountState.get("status");

      if (existingStatus === "active") {
        return "active";
      }

      throw new HttpsError(
        "failed-precondition",
        "This account is not available for use."
      );
    });

    return { status };
  }
);
