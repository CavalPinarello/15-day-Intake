// Load environment variables first
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { initDatabase } = require('./database/init');
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const questionRoutes = require('./routes/questions');
const dayRoutes = require('./routes/days');
const responseRoutes = require('./routes/responses');
const adminRoutes = require('./routes/admin');
const assessmentRoutes = require('./routes/assessment');
const healthRoutes = require('./routes/health');
const interventionRoutes = require('./routes/interventions');
const coachRoutes = require('./routes/coach');

const app = express();
const PORT = process.env.PORT || 3001;

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
  crossOriginEmbedderPolicy: false // Allow embedding for development
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // Limit each IP to 1000 requests per windowMs (increased for development)
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});

// Stricter rate limiting for auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // Limit each IP to 10 login attempts per windowMs
  message: 'Too many login attempts, please try again later.',
  skipSuccessfulRequests: true,
});

// Very lenient rate limiting for response saving (slider interactions)
const responseLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 500, // Allow 500 response saves per minute (for slider interactions)
  message: 'Too many requests, please slow down.',
  standardHeaders: true,
  legacyHeaders: false,
});

// Apply rate limiting
app.use('/api/', limiter);
app.use('/api/auth/login', authLimiter);
app.use('/api/auth/register', authLimiter);
app.use('/api/assessment/user/:userId/response', responseLimiter);

// CORS middleware
app.use(cors({
  origin: ['http://localhost:3000', 'http://127.0.0.1:3000'],
  credentials: true
}));

// Body parsing middleware
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Log all requests for debugging
app.use((req, res, next) => {
  console.log(`${req.method} ${req.path}`);
  next();
});

// Initialize database
// Always initialize SQLite for backward compatibility (some routes still use it)
// Convex is used for new operations, but SQLite is still available
const USE_CONVEX = process.env.USE_CONVEX === 'true' || process.env.NODE_ENV === 'production';
initDatabase().then(() => {
  if (USE_CONVEX) {
    console.log('SQLite initialized (for backward compatibility)');
    console.log('Using Convex database for new operations');
  } else {
    console.log('SQLite database initialized successfully');
  }
}).catch(err => {
  console.error('SQLite database initialization failed:', err);
});

// Health check (before routes to avoid conflict)
app.get('/api/health-check', (req, res) => {
  res.json({ status: 'ok', message: 'ZOE API Server is running' });
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/questions', questionRoutes);
app.use('/api/days', dayRoutes);
app.use('/api/responses', responseRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/assessment', assessmentRoutes);
app.use('/api/health', healthRoutes);
app.use('/api', interventionRoutes);
app.use('/api', coachRoutes);

app.listen(PORT, () => {
  console.log(`\n✅ Server running on http://localhost:${PORT}`);
  console.log(`📡 API available at http://localhost:${PORT}/api`);
  console.log(`\n💡 Make sure your client .env.local has:`);
  console.log(`   NEXT_PUBLIC_API_URL=http://localhost:${PORT}/api\n`);
});

