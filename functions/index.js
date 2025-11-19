const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

async function getAllOtherTokens(excludeUsername) {
  const tokens = [];
  // Collect from users collection
  const usersSnap = await db.collection('users').get();
  usersSnap.forEach(doc => {
    const d = doc.data();
    if (doc.id === excludeUsername) return; // skip author
    if (d && d.fcmToken) tokens.push(d.fcmToken);
  });
  // Also collect from profiles collection as fallback
  const profilesSnap = await db.collection('profiles').get();
  profilesSnap.forEach(doc => {
    if (doc.id === excludeUsername) return;
    const d = doc.data();
    if (d && d.fcmToken) {
      // avoid duplicates
      if (!tokens.includes(d.fcmToken)) tokens.push(d.fcmToken);
    }
  });
  return tokens;
}

async function getTokenForUser(username) {
  const doc = await db.collection('users').doc(username).get();
  if (!doc.exists) return null;
  const d = doc.data();
  return d && d.fcmToken ? d.fcmToken : null;
}

async function getTokenFromProfiles(username) {
  const doc = await db.collection('profiles').doc(username).get();
  if (!doc.exists) return null;
  const d = doc.data();
  return d && d.fcmToken ? d.fcmToken : null;
}

function sendToTokens(tokens, payload) {
  if (!tokens || tokens.length === 0) {
    console.log('sendToTokens: no tokens to send to');
    return null;
  }
  return admin.messaging().sendToDevice(tokens, payload)
    .then(response => {
      console.log('sendToTokens: success', response);
      return response;
    })
    .catch(err => {
      console.error('sendToTokens: error', err);
      throw err;
    });
}

exports.onOrderCreated = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const owner = data?.ownerName || data?.ownerId || 'Alguien';
    const ownerUsername = data?.ownerName || data?.ownerId;

    // Pair mapping: send only to the other user (david1720 <-> maria1720)
    let targetTokens = [];
    let recipient = null;
    if (ownerUsername === 'david1720') recipient = 'maria1720';
    else if (ownerUsername === 'maria1720') recipient = 'david1720';

    if (recipient) {
        let token = await getTokenForUser(recipient);
        if (!token) {
          // fallback to profiles collection if users doc doesn't have token
          token = await getTokenFromProfiles(recipient);
        }
        if (token) targetTokens.push(token);
    } else {
      // fallback: send to all except author
      const exclude = data?.ownerId || null;
      targetTokens = await getAllOtherTokens(exclude);
    }

    const payload = {
      notification: {
        title: 'Nuevo pedido',
        body: `${owner} agregó un pedido.`,
      },
      data: { type: 'order_created', orderId: context.params.orderId }
    };
    console.log('onOrderCreated: recipient=', recipient, 'tokens=', targetTokens, 'payload=', payload);
    return sendToTokens(targetTokens, payload);
  });

exports.onOrderUpdated = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const ownerUsername = after?.ownerName || after?.ownerId;

    // Pair mapping: send only to the other user when possible
    let targetTokens = [];
    let recipient = null;
    if (ownerUsername === 'david1720') recipient = 'maria1720';
    else if (ownerUsername === 'maria1720') recipient = 'david1720';

    // Map friendly display names to usernames if necessary
    const friendlyMap = { 'Esteban': 'david1720', 'Luisa': 'maria1720' };
    let resolvedRecipient = recipient;
    if (!resolvedRecipient && friendlyMap[ownerUsername]) {
      resolvedRecipient = friendlyMap[ownerUsername];
    }

    if (resolvedRecipient) {
      let token = await getTokenForUser(resolvedRecipient);
      if (!token) token = await getTokenFromProfiles(resolvedRecipient);
      if (token) targetTokens.push(token);
    } else {
      const exclude = after?.ownerId || null;
      targetTokens = await getAllOtherTokens(exclude);
    }

    // Determine type of update
    let title = 'Pedido actualizado';
    let body = 'Se actualizó un pedido.';
    if (before && after) {
      if ((before.paid === false || before.paid === undefined) && after.paid === true) {
        title = 'Pedido realizado';
        body = 'Un pedido fue marcado como realizado.';
      } else {
        title = 'Pedido modificado';
        body = 'Un pedido fue modificado.';
      }
    }

    const payload = {
      notification: { title, body },
      data: { type: 'order_updated', orderId: context.params.orderId }
    };
    console.log('onOrderUpdated: ownerUsername=', ownerUsername, 'recipient=', resolvedRecipient, 'tokens=', targetTokens, 'payload=', payload);
    return sendToTokens(targetTokens, payload);
  });
