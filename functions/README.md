# Functions for Disenounico

This folder contains Cloud Functions that send FCM notifications when orders are created or updated.

Setup & deploy:

1. Install dependencies:

   cd functions
   npm install

2. Deploy with Firebase CLI:

   firebase deploy --only functions

Make sure you have initialized Firebase project and are logged in with `firebase login`.

The function listens to `orders/{orderId}` onCreate and onUpdate and sends notifications to `users` documents that have `fcmToken` fields, excluding the author.
