import 'dotenv/config'
import express from 'express'
import cors from 'cors'
import helmet from 'helmet'
import compression from 'compression'
import morgan from 'morgan'
import cookieParser from 'cookie-parser'
import rateLimit from 'express-rate-limit'
import { connectDB } from './utils/database'
import { seedDemoData, seedDemoDoctors } from './services/seedData'
import { errorHandler } from './middleware/errorHandler'
import { corsOptions } from './utils/cors'

// Route imports
import authRoutes from './routes/auth'
import institutionRoutes from './routes/institutions'
import doctorRoutes from './routes/doctors'
import patientRoutes from './routes/patients'
import appointmentRoutes from './routes/appointments'
import dashboardRoutes from './routes/dashboard'

const app = express()
const PORT = process.env.PORT || 4000
const HOST = process.env.HOST || '0.0.0.0'

// ── Security & Middleware ──────────────────────────────────────────────────
app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }))
app.use(cors(corsOptions))
app.use(compression())

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.API_RATE_LIMIT || '100'), // limit each IP
  message: { success: false, message: 'Too many requests, please try again later.' }
})
app.use('/api/', limiter)

// Body parsing
app.use(express.json({ limit: '10mb' }))
app.use(express.urlencoded({ extended: true }))
app.use(cookieParser())

// Logging
if (process.env.NODE_ENV !== 'production') {
  app.use(morgan('dev'))
}

// ── Health Check ────────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({ 
    success: true, 
    message: 'TOSUMO Hospital Web Backend is running',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  })
})

// ── API Routes ──────────────────────────────────────────────────────────────
const API_PREFIX = '/api/v1'

app.use(`${API_PREFIX}/auth`, authRoutes)
app.use(`${API_PREFIX}/institutions`, institutionRoutes)
app.use(`${API_PREFIX}/doctors`, doctorRoutes)
app.use(`${API_PREFIX}/patients`, patientRoutes)
app.use(`${API_PREFIX}/appointments`, appointmentRoutes)
app.use(`${API_PREFIX}/dashboard`, dashboardRoutes)

// ── Error Handling ──────────────────────────────────────────────────────────
app.use(errorHandler)

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ 
    success: false, 
    message: `Route ${req.method} ${req.originalUrl} not found` 
  })
})

// ── Database Connection & Server Start ──────────────────────────────────────
async function startServer() {
  try {
    await connectDB()
    console.log('✅ Connected to MongoDB Atlas')

    // Seed demo data in development
    if (process.env.DEMO_MODE === 'true') {
      await seedDemoData()
      await seedDemoDoctors()
    }

    const port = parseInt(PORT.toString())
    app.listen(port, HOST, () => {
      console.log(`🚀 TOSUMO Hospital Web Backend running on http://${HOST}:${port}`)
      console.log(`📋 Health check: http://${HOST}:${port}/health`)
      console.log(`🔗 API Base: http://${HOST}:${port}${API_PREFIX}`)
      console.log(`🌍 Environment: ${process.env.NODE_ENV}`)
      
      if (process.env.DEMO_MODE === 'true') {
        console.log('\n🎯 Demo Credentials:')
        console.log(`   Phone: ${process.env.DEMO_ADMIN_PHONE}`)
        console.log(`   Password: ${process.env.DEMO_ADMIN_PASSWORD}`)
        console.log('   Role: institution_admin')
      }
    })
  } catch (error) {
    console.error('❌ Failed to start server:', error)
    process.exit(1)
  }
}

startServer()

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('🔄 SIGTERM received, shutting down gracefully...')
  process.exit(0)
})

process.on('SIGINT', () => {
  console.log('🔄 SIGINT received, shutting down gracefully...')
  process.exit(0)
})

export default app