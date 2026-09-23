import { CorsOptions } from 'cors'

const allowedOrigins = (process.env.CORS_ORIGINS || '').split(',').map(origin => origin.trim())

export const corsOptions: CorsOptions = {
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, curl, etc.)
    if (!origin) return callback(null, true)
    
    // Check explicit origins
    if (allowedOrigins.includes(origin)) return callback(null, true)
    
    // Allow localhost for development
    if (/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) {
      return callback(null, true)
    }
    
    // Allow all Vercel domains
    if (/^https:\/\/.*\.vercel\.app$/.test(origin)) {
      return callback(null, true)
    }
    
    callback(new Error('CORS: Origin not allowed'))
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-requested-with']
}