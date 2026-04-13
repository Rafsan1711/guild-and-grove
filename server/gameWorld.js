const logger = require('./logger');

class GameWorld {
    constructor() {
        this.players = {};    // { uid: playerData }
        this.sockets = {};    // { uid: socket }
        
        // World boundaries
        this.worldWidth = 5000;
        this.worldHeight = 5000;
        
        logger.info('Game world initialized');
    }

    async addPlayer(socket) {
        const uid = socket.userId;
        
        // Default spawn position (world center এর কাছে)
        const spawnX = 2400 + Math.random() * 200;
        const spawnY = 2400 + Math.random() * 200;
        
        this.players[uid] = {
            uid,
            name: socket.displayName,
            photo: socket.photoURL,
            x: spawnX,
            y: spawnY,
            direction: 'down',
            state: 'idle',
            lastUpdate: Date.now()
        };
        
        this.sockets[uid] = socket;
        
        logger.info(`Player added to world: ${socket.displayName} at (${Math.round(spawnX)}, ${Math.round(spawnY)})`);
        
        return this.players[uid];
    }

    removePlayer(uid) {
        delete this.players[uid];
        delete this.sockets[uid];
    }

    updatePlayerPosition(uid, x, y, direction, state) {
        if (!this.players[uid]) return;
        
        this.players[uid].x = x;
        this.players[uid].y = y;
        this.players[uid].direction = direction;
        this.players[uid].state = state;
        this.players[uid].lastUpdate = Date.now();
    }

    validatePosition(x, y) {
        // World boundary check
        if (x < 0 || x > this.worldWidth) return false;
        if (y < 0 || y > this.worldHeight) return false;
        return true;
    }

    getNearbyPlayers(uid, radius) {
        const player = this.players[uid];
        if (!player) return [];
        
        return Object.keys(this.players).filter(otherUid => {
            if (otherUid === uid) return false;
            const other = this.players[otherUid];
            const dist = Math.sqrt(
                Math.pow(player.x - other.x, 2) + 
                Math.pow(player.y - other.y, 2)
            );
            return dist <= radius;
        });
    }

    getSocket(uid) {
        return this.sockets[uid] || null;
    }

    getAllPlayers() {
        return Object.values(this.players);
    }
}

module.exports = GameWorld;