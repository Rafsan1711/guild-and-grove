const winston = require('winston');
const path = require('path');

const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: winston.format.combine(
        winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
        winston.format.errors({ stack: true }),
        winston.format.printf(({ timestamp, level, message, stack }) => {
            if (stack) {
                return `[${timestamp}] ${level.toUpperCase()}: ${message}\n${stack}`;
            }
            return `[${timestamp}] ${level.toUpperCase()}: ${message}`;
        })
    ),
    transports: [
        // Console এ colorful output
        new winston.transports.Console({
            format: winston.format.combine(
                winston.format.colorize(),
                winston.format.simple()
            )
        }),
        // File এ save করো errors
        new winston.transports.File({ 
            filename: 'logs/error.log', 
            level: 'error' 
        }),
        // সব logs একসাথে
        new winston.transports.File({ 
            filename: 'logs/combined.log' 
        })
    ]
});

module.exports = logger;