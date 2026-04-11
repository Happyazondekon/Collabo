const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

const db = getFirestore();

// ─── Helper : récupérer le token FCM d'un utilisateur ────────────────────────
async function getToken(uid) {
  const snap = await db.collection('users').doc(uid).get();
  return snap.data()?.fcmToken ?? null;
}

// ─── Helper : envoyer une notification FCM ────────────────────────────────────
async function sendPush(token, title, body, data = {}) {
  if (!token) return;
  try {
    await getMessaging().send({
      token,
      notification: { title, body },
      data: { ...data },
      android: {
        priority: 'high',
        notification: {
          channelId: data.channelId ?? 'collabo_messages',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: { sound: 'default', badge: 1 },
        },
      },
    });
  } catch (e) {
    console.error('FCM send error:', e);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 1. NOUVEAU MESSAGE DANS UNE CONVERSATION
//    conversations/{convId}/messages/{msgId}
// ═══════════════════════════════════════════════════════════════════════════════
exports.onNewMessage = onDocumentCreated(
  'conversations/{convId}/messages/{msgId}',
  async (event) => {
    const msg = event.data?.data();
    if (!msg) return;

    const { senderId, text, type } = msg;
    const convId = event.params.convId;

    // Récupérer la conversation pour trouver le destinataire
    const convSnap = await db.collection('conversations').doc(convId).get();
    const conv = convSnap.data();
    if (!conv) return;

    const participants = conv.participants ?? [];
    const recipientId = participants.find((uid) => uid !== senderId);
    if (!recipientId) return;

    // Récupérer le nom de l'expéditeur
    const senderSnap = await db.collection('users').doc(senderId).get();
    const senderName = senderSnap.data()?.displayName ?? 'Votre partenaire';

    const token = await getToken(recipientId);

    let preview = '';
    if (type === 'text') preview = text ?? '';
    else if (type === 'image') preview = '📷 Photo';
    else if (type === 'voice') preview = '🎤 Message vocal';
    else if (type === 'call') preview = '📞 Appel';
    else preview = 'Nouveau message';

    await sendPush(token, senderName, preview, {
      type: 'message',
      convId,
      channelId: 'collabo_messages',
    });
  }
);

// ═══════════════════════════════════════════════════════════════════════════════
// 2. APPEL ENTRANT
//    calls/{callId}  (status passe à 'ringing')
// ═══════════════════════════════════════════════════════════════════════════════
exports.onNewCall = onDocumentCreated('calls/{callId}', async (event) => {
  const call = event.data?.data();
  if (!call || call.status !== 'ringing') return;

  const { callerId, receiverId, callerName, type } = call;
  const isVideo = type === 'video';

  const token = await getToken(receiverId);
  const title = callerName ?? 'Appel entrant';
  const body = isVideo ? 'Appel vidéo entrant ▶' : 'Appel audio entrant 📞';

  await sendPush(token, title, body, {
    type: 'call',
    callId: event.params.callId,
    isVideo: String(isVideo),
    channelId: 'collabo_invites',
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// 3. NOUVEAU POST DANS LE FEED
//    feed_posts/{postId}
// ═══════════════════════════════════════════════════════════════════════════════
exports.onNewFeedPost = onDocumentCreated('feed_posts/{postId}', async (event) => {
  const post = event.data?.data();
  if (!post) return;

  const { authorId, caption } = post;

  // Trouver le partenaire
  const authorSnap = await db.collection('users').doc(authorId).get();
  const authorData = authorSnap.data();
  if (!authorData) return;

  const partnerUid = authorData.partnerUid;
  if (!partnerUid) return;

  const authorName = authorData.displayName ?? 'Votre partenaire';
  const token = await getToken(partnerUid);

  const body = caption?.trim()
    ? caption.substring(0, Math.min(caption.length, 80))
    : '📸 A partagé une nouvelle publication';

  await sendPush(token, authorName, body, {
    type: 'partner_post',
    postId: event.params.postId,
    channelId: 'collabo_social',
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// 4. INVITATION JEU À DISTANCE
//    couples/{coupleId}/remote_competitive  /  remote_coop  /  remote_timed
//    (status passe à 'waiting' = le premier joueur vient de créer la session)
// ═══════════════════════════════════════════════════════════════════════════════
async function handleGameInvite(coupleId, docSnap, gameLabel) {
  const session = docSnap?.data();
  if (!session || session.status !== 'waiting') return;

  const { player1Uid } = session;
  if (!player1Uid) return;

  // Trouver le partenaire du créateur
  const p1Snap = await db.collection('users').doc(player1Uid).get();
  const p1Data = p1Snap.data();
  if (!p1Data) return;

  const partnerUid = p1Data.partnerUid;
  if (!partnerUid) return;

  const senderName = p1Data.displayName ?? 'Votre partenaire';
  const token = await getToken(partnerUid);

  await sendPush(
    token,
    `${senderName} vous invite !`,
    `Rejoignez la partie ${gameLabel} 🎮`,
    { type: 'game_invite', coupleId, channelId: 'collabo_invites' }
  );
}

exports.onRemoteCompetitiveCreated = onDocumentWritten(
  'couples/{coupleId}/remote_competitive',
  async (event) => {
    const before = event.data?.before?.data()?.status;
    const after = event.data?.after?.data()?.status;
    if (before === undefined && after === 'waiting') {
      await handleGameInvite(event.params.coupleId, event.data?.after, 'Compétitif');
    }
  }
);

exports.onRemoteCoopCreated = onDocumentWritten(
  'couples/{coupleId}/remote_coop',
  async (event) => {
    const before = event.data?.before?.data()?.status;
    const after = event.data?.after?.data()?.status;
    if (before === undefined && after === 'waiting') {
      await handleGameInvite(event.params.coupleId, event.data?.after, 'Coopératif');
    }
  }
);

exports.onRemoteTimedCreated = onDocumentWritten(
  'couples/{coupleId}/remote_timed',
  async (event) => {
    const before = event.data?.before?.data()?.status;
    const after = event.data?.after?.data()?.status;
    if (before === undefined && after === 'waiting') {
      await handleGameInvite(event.params.coupleId, event.data?.after, 'Chrono');
    }
  }
);

// ═══════════════════════════════════════════════════════════════════════════════
// 5. DEMANDE DE LIAISON PARTENAIRE
//    couple_requests/{reqId}
// ═══════════════════════════════════════════════════════════════════════════════
exports.onCoupleRequest = onDocumentCreated(
  'couple_requests/{reqId}',
  async (event) => {
    const req = event.data?.data();
    if (!req) return;

    const { fromUid, toUid } = req;

    const fromSnap = await db.collection('users').doc(fromUid).get();
    const fromName = fromSnap.data()?.displayName ?? 'Quelqu\'un';

    const token = await getToken(toUid);
    await sendPush(
      token,
      `${fromName} veut vous lier 💑`,
      'Ouvrez Collabo pour accepter la demande.',
      { type: 'couple_request', channelId: 'collabo_social' }
    );
  }
);

// ═══════════════════════════════════════════════════════════════════════════════
// 6. AVERTISSEMENT APRÈS 3 SIGNALEMENTS SUR LES POSTS D'UN UTILISATEUR
//    reports/{reportId}
// ═══════════════════════════════════════════════════════════════════════════════
exports.onNewReport = onDocumentCreated(
  'reports/{reportId}',
  async (event) => {
    const report = event.data?.data();
    if (!report) return;

    const { postId } = report;
    if (!postId) return;

    // Récupérer l'auteur du post signalé
    const postSnap = await db.collection('feed_posts').doc(postId).get();
    const authorUid = postSnap.data()?.authorUid;
    if (!authorUid) return;

    // Compter tous les signalements non résolus pour les posts de cet auteur
    // On compte via les posts de l'auteur puis les signalements associés
    const postsSnap = await db.collection('feed_posts')
      .where('authorUid', '==', authorUid)
      .get();
    const postIds = postsSnap.docs.map(d => d.id);
    if (postIds.length === 0) return;

    // Firestore: 'in' supporte max 30 éléments, on tronque si nécessaire
    const chunk = postIds.slice(0, 30);
    const reportsSnap = await db.collection('reports')
      .where('postId', 'in', chunk)
      .get();

    const totalReports = reportsSnap.size;

    // Envoyer avertissement tous les 3 signalements (3, 6, 9, ...)
    if (totalReports % 3 !== 0) return;

    // Écrire un avertissement dans le document utilisateur
    await db.collection('users').doc(authorUid).update({
      pendingWarning: `Votre contenu a été signalé ${totalReports} fois. Merci de respecter les règles de la communauté Collabo.`,
      warningCount: Math.floor(totalReports / 3),
    });

    // Envoyer une notification push
    const token = await getToken(authorUid);
    await sendPush(
      token,
      '⚠️ Avertissement Collabo',
      `Votre contenu a été signalé ${totalReports} fois. Respectez les règles de la communauté.`,
      { type: 'warning', channelId: 'collabo_social' }
    );
  }
);
