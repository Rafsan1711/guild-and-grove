require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const logger = require('./logger');
const { verifyFirebaseToken } = require('./auth');
const GameWorld = require('./gameWorld');

const app = express();
const server = http.createServer(app);

// CORS — সব platform থেকে connect হতে দাও
const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    },
    pingTimeout: 60000,
    pingInterval: 25000
});

app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/', (req, res) => {
    res.json({ 
        status: 'Guild & Grove Server Running',
        players: Object.keys(GameWorld.players).length,
        uptime: process.uptime()
    });
});

// Game world instance
const gameWorld = new GameWorld();

// Socket.io connection handling
io.on('connection', async (socket) => {
    logger.info(`New connection attempt: ${socket.id}`);

    // === AUTH VERIFICATION ===
    socket.on('authenticate', async (data) => {
        try {
            const { token } = data;
            const decodedUser = await verifyFirebaseToken(token);
            
            if (!decodedUser) {
                socket.emit('auth_failed', { message: 'Invalid token' });
                socket.disconnect();
                return;
            }

            socket.userId = decodedUser.uid;
            socket.displayName = decodedUser.name || 'Traveler';
            socket.photoURL = decodedUser.picture || '';

            logger.info(`Player authenticated: ${socket.displayName} (${socket.userId})`);

            // Player world এ যোগ করো
            const playerData = await gameWorld.addPlayer(socket);
            socket.emit('auth_success', playerData);

            // বাকি সবাইকে জানাও
            socket.broadcast.emit('player_joined', {
                uid: socket.userId,
                name: socket.displayName,
                photo: socket.photoURL,
                x: playerData.x,
                y: playerData.y
            });

        } catch (err) {
            logger.error('Auth error:', err);
            socket.emit('auth_failed', { message: 'Authentication error' });
        }
    });

    // === PLAYER MOVEMENT ===
    socket.on('player_move', (data) => {
        if (!socket.userId) return;
        
        const { x, y, direction, state } = data;
        
        // Server-side validation (cheating prevent করতে)
        if (!gameWorld.validatePosition(x, y)) {
            socket.emit('position_correct', gameWorld.players[socket.userId]);
            return;
        }

        gameWorld.updatePlayerPosition(socket.userId, x, y, direction, state);

        // Nearby players কে update দাও (সবাইকে না — optimization)
        const nearbyPlayers = gameWorld.getNearbyPlayers(socket.userId, 1000);
        nearbyPlayers.forEach(uid => {
            const targetSocket = gameWorld.getSocket(uid);
            if (targetSocket) {
                targetSocket.emit('player_moved', {
                    uid: socket.userId,
                    x, y, direction, state
                });
            }
        });
    });

    // === CHAT ===
    socket.on('chat_public_request', (data) => {
        if (!socket.userId) return;
        
        const { targetUid } = data;
        const targetSocket = gameWorld.getSocket(targetUid);
        
        if (targetSocket) {
            targetSocket.emit('chat_request_received', {
                from_uid: socket.userId,
                from_name: socket.displayName,
                from_photo: socket.photoURL,
                type: 'public'
            });
        }
    });

    socket.on('chat_private_request', (data) => {
        if (!socket.userId) return;
        
        const { targetUid } = data;
        const targetSocket = gameWorld.getSocket(targetUid);
        
        if (targetSocket) {
            targetSocket.emit('chat_request_received', {
                from_uid: socket.userId,
                from_name: socket.displayName,
                type: 'private'
            });
        }
    });

    socket.on('send_message', (data) => {
        if (!socket.userId) return;
        
        const { room_id, message, type } = data;
        const timestamp = new Date().toISOString();
        
        const msgData = {
            from_uid: socket.userId,
            from_name: socket.displayName,
            from_photo: socket.photoURL,
            message: message.substring(0, 500), // Max 500 chars
            timestamp,
            type
        };

        if (type === 'public') {
            io.to(room_id).emit('new_message', msgData);
        } else {
            // Private — শুধু sender আর receiver দেখবে
            socket.emit('new_message', msgData);
            const targetSocket = gameWorld.getSocket(data.targetUid);
            if (targetSocket) targetSocket.emit('new_message', msgData);
        }
        
        logger.debug(`Chat [${type}] from ${socket.displayName}: ${message.substring(0, 50)}`);
    });

    // === DISCONNECT ===
    socket.on('disconnect', () => {
        if (!socket.userId) return;
        
        gameWorld.removePlayer(socket.userId);
        
        io.emit('player_left', { uid: socket.userId });
        logger.info(`Player disconnected: ${socket.displayName} (${socket.userId})`);
    });
});

// Server চালু করো
const PORT = process.env.PORT || 7860;  // HuggingFace port 7860 ব্যবহার করে
server.listen(PORT, () => {
    logger.info(`🌿 Guild & Grove Server running on port ${PORT}`);
});

// Unhandled errors catch করো — server crash prevent
process.on('uncaughtException', (err) => {
    logger.error('Uncaught Exception:', err);
});

process.on('unhandledRejection', (reason, promise) => {
    logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
});