const admin = require('firebase-admin');
const logger = require('./logger');

// Firebase Admin initialize
let firebaseApp;

function initFirebase() {
    if (firebaseApp) return;
    
    try {
        // Service account credentials (HuggingFace Secret এ রাখব)
        const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
        
        firebaseApp = admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });
        
        logger.info('Firebase Admin initialized');
    } catch (err) {
        logger.error('Firebase Admin init failed:', err);
    }
}

initFirebase();

async function verifyFirebaseToken(token) {
    try {
        const decoded = await admin.auth().verifyIdToken(token);
        return decoded;
    } catch (err) {
        logger.error('Token verification failed:', err.message);
        return null;
    }
}

module.exports = { verifyFirebaseToken };