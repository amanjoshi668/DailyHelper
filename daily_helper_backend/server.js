const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const https = require('https');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
const { OAuth2Client } = require('google-auth-library');

const app = express();
app.use(cors());
app.use(express.json({ limit: '2mb' }));

const PORT = process.env.PORT || 8080;
const JWT_SECRET = process.env.JWT_SECRET || 'dailyhelper-dev-secret-change-in-prod';
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID || '';
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || '';
const googleClient = GOOGLE_CLIENT_ID ? new OAuth2Client(GOOGLE_CLIENT_ID) : null;

// --- Optional PostgreSQL Pool with Seamless In-Memory Fallback ---
let pool = null;
if (process.env.DATABASE_URL) {
  pool = new Pool({ connectionString: process.env.DATABASE_URL });
} else if (process.env.INSTANCE_CONNECTION_NAME && process.env.DB_USER && process.env.DB_NAME) {
  pool = new Pool({
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    host: `/cloudsql/${process.env.INSTANCE_CONNECTION_NAME}`
  });
}

// --- In-Memory Store (Used when DB is not configured) ---
const mem = {
  users: new Map(), // id -> user
  usersByEmail: new Map(), // lowerEmail -> id
  vaults: new Map(), // userId -> snapshot
  workers: new Map(), // workerId -> profile
  bookings: new Map(), // bookingId -> booking
  notifications: [], // { id, userId, bookingId, title, body, isDismissed, createdAt }
  bugs: [], // { id, userEmail, description, pageContext, appVersion, deviceInfo, status, resolutionNotes, createdAt, resolvedAt }
  mobileGoogleSessions: new Map() // sessionId -> { status, token, user, createdAt }
};

function seedMemoryWorkers() {
  const starterWorkers = [
    {
      id: 'w1',
      nameEn: 'Ramesh Kumar',
      nameHi: 'रमेश कुमार',
      trade: 'electrician',
      skills: ['Switchboard & MCB Repair', 'Ceiling Fan & Regulator', 'Geyser Point & Inverter'],
      servicePins: ['560034', '110001', '400050'],
      experienceYears: 8,
      visitFeeInr: 149,
      hourlyRateInr: 250,
      upiId: 'ramesh.elec@okaxis',
      phone: '+91 99001 44556',
      languages: 'Hindi, English',
      verified: true,
      isOnline: true,
      blockedSlots: [],
      ratingAvg: 4.9,
      jobsCompleted: 64,
      khataTodayInr: 450,
      khataMonthInr: 18400
    },
    {
      id: 'w2',
      nameEn: 'Suresh Yadav',
      nameHi: 'सुरेश यादव',
      trade: 'plumber',
      skills: ['Tap & Mixer Leak', 'Flush Tank Repair', 'Kitchen Sink Unclog'],
      servicePins: ['560034', '110001', '400050'],
      experienceYears: 6,
      visitFeeInr: 129,
      hourlyRateInr: 220,
      upiId: 'suresh.plumb@paytm',
      phone: '+91 98112 33445',
      languages: 'Hindi, English',
      verified: true,
      isOnline: true,
      blockedSlots: [],
      ratingAvg: 4.7,
      jobsCompleted: 41,
      khataTodayInr: 300,
      khataMonthInr: 15200
    },
    {
      id: 'w3',
      nameEn: 'Salim Ansari',
      nameHi: 'सलीम अंसारी',
      trade: 'carpenter',
      skills: ['Door Lock & Hinge Fix', 'Wardrobe Sliding Track', 'Curtain Rod & Drill'],
      servicePins: ['560034', '110001', '400050'],
      experienceYears: 14,
      visitFeeInr: 149,
      hourlyRateInr: 300,
      upiId: 'salim.wood@ybl',
      phone: '+91 98204 77889',
      languages: 'Hindi, English',
      verified: true,
      isOnline: true,
      blockedSlots: ['11:00 - 01:00 PM'],
      ratingAvg: 4.8,
      jobsCompleted: 92,
      khataTodayInr: 600,
      khataMonthInr: 24500
    },
    {
      id: 'w4',
      nameEn: 'Vikram Sharma',
      nameHi: 'विक्रम शर्मा',
      trade: 'appliance',
      skills: ['Split AC Servicing', 'Washing Machine Repair', 'RO Water Purifier'],
      servicePins: ['560034', '110001', '400050'],
      experienceYears: 9,
      visitFeeInr: 199,
      hourlyRateInr: 350,
      upiId: 'vikram.cool@okicici',
      phone: '+91 97390 55661',
      languages: 'Hindi, English',
      verified: true,
      isOnline: true,
      blockedSlots: [],
      ratingAvg: 4.9,
      jobsCompleted: 78,
      khataTodayInr: 898,
      khataMonthInr: 29100
    },
    {
      id: 'w5',
      nameEn: 'Manoj Verma',
      nameHi: 'मनोज वर्मा',
      trade: 'painter',
      skills: ['Dampness & Putty Patch', 'Single Room Repaint', 'Wood Touch-up'],
      servicePins: ['560034', '110001', '400050'],
      experienceYears: 11,
      visitFeeInr: 99,
      hourlyRateInr: 200,
      upiId: 'manoj.paint@ybl',
      phone: '+91 96501 88990',
      languages: 'Hindi',
      verified: true,
      isOnline: true,
      blockedSlots: [],
      ratingAvg: 4.6,
      jobsCompleted: 29,
      khataTodayInr: 0,
      khataMonthInr: 16800
    }
  ];
  for (const w of starterWorkers) {
    mem.workers.set(w.id, w);
  }
}
seedMemoryWorkers();

// --- Crypto & JWT Helpers ---
function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const derived = crypto.scryptSync(password, salt, 64).toString('hex');
  return `${salt}:${derived}`;
}

function verifyPassword(password, storedHash) {
  if (!storedHash || !storedHash.includes(':')) return false;
  const [salt, keyHex] = storedHash.split(':');
  const derived = crypto.scryptSync(password, salt, 64);
  const keyBuf = Buffer.from(keyHex, 'hex');
  if (derived.length !== keyBuf.length) return false;
  return crypto.timingSafeEqual(derived, keyBuf);
}

function issueJwt(user) {
  return jwt.sign(
    { id: user.id, email: user.email, role: user.role || 'customer', name: user.name },
    JWT_SECRET,
    { expiresIn: '30d' }
  );
}

function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'] || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Missing bearer token' });
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch (_) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

async function createNotification({ userId, bookingId = null, title, body }) {
  if (!userId) return;
  if (pool) {
    try {
      await pool.query(
        'INSERT INTO notifications (user_id, booking_id, title, body) VALUES ($1, $2, $3, $4)',
        [userId, bookingId, title, body]
      );
      return;
    } catch (_) {}
  }
  mem.notifications.unshift({
    id: crypto.randomUUID(),
    userId,
    bookingId,
    title,
    body,
    isDismissed: false,
    createdAt: new Date().toISOString()
  });
}

// --- Health & Privacy Routes ---
app.get('/health', async (_req, res) => {
  let dbMode = 'in-memory';
  if (pool) {
    try {
      await pool.query('SELECT 1');
      dbMode = 'postgres';
    } catch (_) {
      dbMode = 'in-memory-fallback';
    }
  }
  res.json({ status: 'ok', service: 'daily-helper-backend', version: '1.0.0', dbMode });
});

app.get('/privacy', (_req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(`<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>DailyHelper Privacy Policy</title>
<style>body{font-family:system-ui,sans-serif;max-width:720px;margin:40px auto;padding:0 20px;line-height:1.6;color:#1f2937}</style></head>
<body>
  <h1>DailyHelper Privacy Policy</h1>
  <p><strong>Effective Date:</strong> November 21, 2026</p>
  <p>DailyHelper connects customers with local independent blue-collar professionals (electricians, plumbers, carpenters, appliance technicians, and painters).</p>
  <h2>1. Information We Collect</h2>
  <ul>
    <li><strong>Account Information:</strong> Name, email address, phone number, and chosen role (Customer or Professional) when you create an account or sign in with Google.</li>
    <li><strong>Booking &amp; Service Details:</strong> Service PIN code, booking address, appointment time slot, and repair notes shared strictly between the customer and selected professional.</li>
    <li><strong>Diagnostics &amp; Bug Reports:</strong> Voluntary bug reports submitted via Settings &rarr; Report a Bug (including page context and app version) to resolve product issues.</li>
  </ul>
  <h2>2. Direct Payments</h2>
  <p>DailyHelper facilitates direct Cash or UPI settlement between customers and professionals on job completion and does not store credit card or bank credentials.</p>
  <h2>3. Permissions &amp; Notifications</h2>
  <p>Notification permission (<code>POST_NOTIFICATIONS</code>) is used solely to deliver booking status alerts and 60-minute appointment reminders.</p>
  <h2>4. Data Isolation &amp; Deletion</h2>
  <p>Local device data is isolated per user account and cleared upon sign-out. Users may request account deletion at any time by contacting support.</p>
</body>
</html>`);
});

// --- Auth Endpoints ---
app.post('/api/v1/auth/register', async (req, res) => {
  try {
    const name = String(req.body.name || '').trim();
    const email = String(req.body.email || '').trim().toLowerCase();
    const password = String(req.body.password || '');
    const phone = String(req.body.phone || '').trim();
    const role = req.body.role === 'professional' ? 'professional' : 'customer';
    const trade = String(req.body.trade || 'electrician').trim();
    const pin = String(req.body.pin || '560034').trim();

    if (!name || !email || password.length < 4) {
      return res.status(400).json({ error: 'Name, valid email, and password (min 4 chars) required' });
    }
    const passwordHash = hashPassword(password);

    if (pool) {
      const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
      if (existing.rows.length > 0) {
        return res.status(409).json({ error: 'Account already exists with this email' });
      }
      const ins = await pool.query(
        'INSERT INTO users (name, email, phone, role, password_hash) VALUES ($1, $2, $3, $4, $5) RETURNING id, name, email, phone, role',
        [name, email, phone, role, passwordHash]
      );
      const user = ins.rows[0];
      if (role === 'professional') {
        await pool.query(
          `INSERT INTO worker_profiles (user_id, name_en, trade, service_pins, phone)
           VALUES ($1, $2, $3, $4::jsonb, $5) ON CONFLICT (user_id) DO NOTHING`,
          [user.id, name, trade, JSON.stringify([pin]), phone]
        );
      }
      return res.status(201).json({ token: issueJwt(user), user });
    }

    if (mem.usersByEmail.has(email)) {
      return res.status(409).json({ error: 'Account already exists with this email' });
    }
    const id = crypto.randomUUID();
    const user = { id, name, email, phone, role, passwordHash };
    mem.users.set(id, user);
    mem.usersByEmail.set(email, id);
    if (role === 'professional') {
      mem.workers.set(id, {
        id,
        nameEn: name,
        nameHi: name,
        trade,
        skills: ['General Inspection & Repair'],
        servicePins: [pin, '560034'],
        experienceYears: 5,
        visitFeeInr: 149,
        hourlyRateInr: 250,
        upiId: `${name.toLowerCase().replace(/[^a-z0-9]/g, '')}@upi`,
        phone: phone || '+91 99000 00000',
        languages: 'Hindi, English',
        verified: true,
        isOnline: true,
        blockedSlots: [],
        ratingAvg: 4.8,
        jobsCompleted: 0,
        khataTodayInr: 0,
        khataMonthInr: 0
      });
    }
    const safeUser = { id, name, email, phone, role };
    return res.status(201).json({ token: issueJwt(safeUser), user: safeUser });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

app.post('/api/v1/auth/login', async (req, res) => {
  try {
    const email = String(req.body.email || '').trim().toLowerCase();
    const password = String(req.body.password || '');
    if (!email || !password) return res.status(400).json({ error: 'Email and password required' });

    if (pool) {
      const q = await pool.query('SELECT id, name, email, phone, role, password_hash FROM users WHERE email = $1', [email]);
      if (q.rows.length === 0 || !verifyPassword(password, q.rows[0].password_hash)) {
        return res.status(401).json({ error: 'Invalid email or password' });
      }
      const u = q.rows[0];
      const safeUser = { id: u.id, name: u.name, email: u.email, phone: u.phone, role: u.role };
      return res.json({ token: issueJwt(safeUser), user: safeUser });
    }

    const uid = mem.usersByEmail.get(email);
    const u = uid ? mem.users.get(uid) : null;
    if (!u || !verifyPassword(password, u.passwordHash)) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }
    const safeUser = { id: u.id, name: u.name, email: u.email, phone: u.phone, role: u.role };
    return res.json({ token: issueJwt(safeUser), user: safeUser });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

async function upsertGoogleUser({ email, name, googleId, role }) {
  const cleanRole = role === 'professional' ? 'professional' : 'customer';
  if (pool) {
    const existing = await pool.query('SELECT id, name, email, phone, role FROM users WHERE email = $1', [email]);
    if (existing.rows.length > 0) {
      await pool.query('UPDATE users SET google_id = $1, updated_at = NOW() WHERE id = $2', [googleId, existing.rows[0].id]);
      return existing.rows[0];
    }
    const ins = await pool.query(
      'INSERT INTO users (name, email, role, google_id) VALUES ($1, $2, $3, $4) RETURNING id, name, email, phone, role',
      [name, email, cleanRole, googleId]
    );
    return ins.rows[0];
  }

  const existingId = mem.usersByEmail.get(email);
  if (existingId) {
    const u = mem.users.get(existingId);
    u.googleId = googleId;
    return { id: u.id, name: u.name, email: u.email, phone: u.phone || '', role: u.role };
  }
  const id = crypto.randomUUID();
  const u = { id, name, email, phone: '', role: cleanRole, googleId };
  mem.users.set(id, u);
  mem.usersByEmail.set(email, id);
  return { id, name, email, phone: '', role: cleanRole };
}

app.post('/api/v1/auth/google', async (req, res) => {
  try {
    const { idToken, role } = req.body;
    if (!idToken) return res.status(400).json({ error: 'Missing idToken' });
    let payload;
    if (googleClient && GOOGLE_CLIENT_ID) {
      const ticket = await googleClient.verifyIdToken({ idToken, audience: GOOGLE_CLIENT_ID });
      payload = ticket.getPayload();
    } else {
      return res.status(503).json({ error: 'GOOGLE_CLIENT_ID not configured on server' });
    }
    const user = await upsertGoogleUser({
      email: String(payload.email).toLowerCase(),
      name: payload.name || payload.email.split('@')[0],
      googleId: payload.sub,
      role
    });
    return res.json({ token: issueJwt(user), user });
  } catch (err) {
    return res.status(401).json({ error: 'Google verification failed: ' + err.message });
  }
});

// Android Browser Google Sign-In Handoff
app.post('/api/v1/auth/mobile-google/init', (req, res) => {
  const sessionId = crypto.randomUUID();
  const role = req.body.role === 'professional' ? 'professional' : 'customer';
  mem.mobileGoogleSessions.set(sessionId, { status: 'pending', role, createdAt: Date.now() });
  res.json({ sessionId, authUrl: `/auth/mobile-google?session=${sessionId}` });
});

app.get('/auth/mobile-google', (req, res) => {
  const session = String(req.query.session || '');
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(`<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Sign in to DailyHelper</title>
<script src="https://accounts.google.com/gsi/client" async defer></script></head>
<body style="font-family:system-ui,sans-serif;display:flex;flex-direction:column;align-items:center;justify-content:center;min-height:80vh;padding:20px;text-align:center">
  <h2>Sign in to DailyHelper</h2>
  <p>Complete Google Sign-In to return to the app.</p>
  <div id="g_id_onload" data-client_id="${GOOGLE_CLIENT_ID}" data-callback="onGoogleSignIn"></div>
  <div class="g_id_signin" data-type="standard" data-size="large"></div>
  <p id="msg" style="margin-top:16px;color:#4b5563"></p>
  <script>
    async function onGoogleSignIn(resp) {
      document.getElementById('msg').textContent = 'Verifying account...';
      const r = await fetch('/api/v1/auth/mobile-google/complete', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ session: ${JSON.stringify(session)}, idToken: resp.credential })
      });
      if (r.ok) {
        document.getElementById('msg').textContent = 'Signed in! You may return to the DailyHelper app.';
      } else {
        document.getElementById('msg').textContent = 'Sign-in could not be completed.';
      }
    }
  </script>
</body></html>`);
});

app.post('/api/v1/auth/mobile-google/complete', async (req, res) => {
  try {
    const { session, idToken } = req.body;
    const entry = mem.mobileGoogleSessions.get(session);
    if (!entry) return res.status(404).json({ error: 'Invalid session' });
    if (!googleClient || !GOOGLE_CLIENT_ID) return res.status(503).json({ error: 'Google OAuth not configured' });
    const ticket = await googleClient.verifyIdToken({ idToken, audience: GOOGLE_CLIENT_ID });
    const payload = ticket.getPayload();
    const user = await upsertGoogleUser({
      email: String(payload.email).toLowerCase(),
      name: payload.name || payload.email.split('@')[0],
      googleId: payload.sub,
      role: entry.role
    });
    entry.status = 'complete';
    entry.token = issueJwt(user);
    entry.user = user;
    return res.json({ ok: true });
  } catch (err) {
    return res.status(401).json({ error: err.message });
  }
});

app.get('/api/v1/auth/mobile-google/poll', (req, res) => {
  const session = String(req.query.session || '');
  const entry = mem.mobileGoogleSessions.get(session);
  if (!entry) return res.status(404).json({ status: 'expired' });
  if (entry.status === 'complete') {
    mem.mobileGoogleSessions.delete(session);
    return res.json({ status: 'complete', token: entry.token, user: entry.user });
  }
  return res.json({ status: 'pending' });
});

// --- Full JSONB Vault State Sync ---
app.get('/api/v1/dailyhelper/state', authenticateToken, async (req, res) => {
  if (pool) {
    const q = await pool.query('SELECT snapshot, updated_at FROM user_vaults WHERE user_id = $1', [req.user.id]);
    return res.json({ snapshot: q.rows[0]?.snapshot || null, updatedAt: q.rows[0]?.updated_at || null });
  }
  return res.json({ snapshot: mem.vaults.get(req.user.id) || null });
});

app.post('/api/v1/dailyhelper/state', authenticateToken, async (req, res) => {
  const snapshot = req.body.snapshot || {};
  if (pool) {
    await pool.query(
      `INSERT INTO user_vaults (user_id, snapshot, updated_at)
       VALUES ($1, $2::jsonb, NOW())
       ON CONFLICT (user_id) DO UPDATE SET snapshot = EXCLUDED.snapshot, updated_at = NOW()`,
      [req.user.id, JSON.stringify(snapshot)]
    );
    return res.json({ success: true });
  }
  mem.vaults.set(req.user.id, snapshot);
  return res.json({ success: true });
});

// --- Workers Discovery & Professional Rate Card ---
app.get('/api/v1/workers', async (req, res) => {
  const trade = String(req.query.trade || 'all').toLowerCase();
  let list = Array.from(mem.workers.values());
  if (pool) {
    try {
      const q = await pool.query('SELECT * FROM worker_profiles WHERE is_online = TRUE ORDER BY rating_avg DESC');
      if (q.rows.length > 0) {
        const dbWorkers = q.rows.map(r => ({
          id: r.user_id,
          nameEn: r.name_en,
          nameHi: r.name_hi || r.name_en,
          trade: r.trade,
          skills: r.skills || [],
          servicePins: r.service_pins || [],
          experienceYears: r.experience_years,
          visitFeeInr: r.visit_fee_inr,
          hourlyRateInr: r.hourly_rate_inr,
          upiId: r.upi_id,
          phone: r.phone,
          languages: r.languages,
          verified: r.verified,
          isOnline: r.is_online,
          blockedSlots: r.blocked_slots || [],
          ratingAvg: Number(r.rating_avg),
          jobsCompleted: r.jobs_completed
        }));
        list = [...dbWorkers, ...list];
      }
    } catch (_) {}
  }
  if (trade && trade !== 'all') {
    list = list.filter(w => w.trade === trade);
  }
  res.json({ workers: list });
});

app.put('/api/v1/workers/me', authenticateToken, async (req, res) => {
  const uid = req.user.id;
  const existing = mem.workers.get(uid) || mem.workers.get('w1');
  const updated = {
    ...existing,
    id: uid,
    visitFeeInr: Number(req.body.visitFeeInr ?? existing.visitFeeInr),
    hourlyRateInr: Number(req.body.hourlyRateInr ?? existing.hourlyRateInr),
    upiId: String(req.body.upiId ?? existing.upiId),
    isOnline: req.body.isOnline !== undefined ? Boolean(req.body.isOnline) : existing.isOnline,
    blockedSlots: Array.isArray(req.body.blockedSlots) ? req.body.blockedSlots : existing.blockedSlots
  };
  mem.workers.set(uid, updated);
  if (pool) {
    try {
      await pool.query(
        `UPDATE worker_profiles SET visit_fee_inr = $1, hourly_rate_inr = $2, upi_id = $3, is_online = $4, blocked_slots = $5::jsonb, updated_at = NOW() WHERE user_id = $6`,
        [updated.visitFeeInr, updated.hourlyRateInr, updated.upiId, updated.isOnline, JSON.stringify(updated.blockedSlots), uid]
      );
    } catch (_) {}
  }
  res.json({ worker: updated });
});

// --- Bookings & Notifications ---
app.get('/api/v1/bookings', authenticateToken, async (req, res) => {
  if (pool) {
    try {
      const q = await pool.query(
        'SELECT * FROM bookings WHERE customer_id = $1 OR worker_id = $1 ORDER BY created_at DESC',
        [req.user.id]
      );
      return res.json({ bookings: q.rows });
    } catch (_) {}
  }
  const all = Array.from(mem.bookings.values()).filter(
    b => b.customerId === req.user.id || b.workerId === req.user.id || (req.user.role === 'professional' && b.workerId === 'w1')
  );
  res.json({ bookings: all });
});

app.post('/api/v1/bookings', authenticateToken, async (req, res) => {
  const b = {
    id: req.body.id || `BK-${Date.now().toString().slice(-5)}`,
    customerId: req.user.id,
    customerName: req.body.customerName || req.user.name || 'Customer',
    customerPhone: req.body.customerPhone || '',
    workerId: req.body.workerId || 'w1',
    workerName: req.body.workerName || 'Ramesh Kumar',
    trade: req.body.trade || 'electrician',
    pinCode: req.body.pinCode || '560034',
    locality: req.body.locality || '',
    fullAddress: req.body.fullAddress || '',
    bookingDate: req.body.bookingDate || 'Today',
    slotWindow: req.body.slotWindow || '02:00 - 04:00 PM',
    issueNote: req.body.issueNote || 'General inspection & repair',
    visitFeeInr: Number(req.body.visitFeeInr || 149),
    finalAmountInr: null,
    paymentMethod: null,
    status: 'requested',
    customerRating: null,
    createdAt: new Date().toISOString()
  };

  mem.bookings.set(b.id, b);
  if (pool) {
    try {
      await pool.query(
        `INSERT INTO bookings (id, customer_id, customer_name, customer_phone, worker_id, worker_name, trade, pin_code, locality, full_address, booking_date, slot_window, issue_note, visit_fee_inr, status)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)`,
        [b.id, b.customerId, b.customerName, b.customerPhone, b.workerId, b.workerName, b.trade, b.pinCode, b.locality, b.fullAddress, b.bookingDate, b.slotWindow, b.issueNote, b.visitFeeInr, b.status]
      );
    } catch (_) {}
  }

  await createNotification({
    userId: b.workerId,
    bookingId: b.id,
    title: 'New Booking Request',
    body: `${b.customerName} requested ${b.bookingDate}, ${b.slotWindow} (PIN ${b.pinCode}).`
  });

  res.status(201).json({ booking: b });
});

app.patch('/api/v1/bookings/:id', authenticateToken, async (req, res) => {
  const id = req.params.id;
  const b = mem.bookings.get(id);
  if (!b && !pool) return res.status(404).json({ error: 'Booking not found' });

  if (b) {
    if (req.body.status) b.status = req.body.status;
    if (req.body.finalAmountInr !== undefined) b.finalAmountInr = Number(req.body.finalAmountInr);
    if (req.body.paymentMethod) b.paymentMethod = req.body.paymentMethod;
    if (req.body.customerRating !== undefined) b.customerRating = Number(req.body.customerRating);

    if (req.body.status === 'confirmed') {
      await createNotification({
        userId: b.customerId,
        bookingId: b.id,
        title: 'Booking Confirmed!',
        body: `${b.workerName} accepted ${b.bookingDate}, ${b.slotWindow}.`
      });
    } else if (req.body.status === 'completed') {
      await createNotification({
        userId: b.customerId,
        bookingId: b.id,
        title: 'Job Completed',
        body: `Settled ₹${b.finalAmountInr || b.visitFeeInr} via ${b.paymentMethod || 'Cash'}.`
      });
    }
  }

  if (pool) {
    try {
      await pool.query(
        `UPDATE bookings SET
          status = COALESCE($1, status),
          final_amount_inr = COALESCE($2, final_amount_inr),
          payment_method = COALESCE($3, payment_method),
          customer_rating = COALESCE($4, customer_rating),
          updated_at = NOW()
         WHERE id = $5`,
        [req.body.status || null, req.body.finalAmountInr ?? null, req.body.paymentMethod || null, req.body.customerRating ?? null, id]
      );
    } catch (_) {}
  }

  res.json({ booking: b || { id, ...req.body } });
});

app.get('/api/v1/notifications', authenticateToken, async (req, res) => {
  if (pool) {
    try {
      const q = await pool.query(
        'SELECT id, booking_id AS "bookingId", title, body, is_dismissed AS "isDismissed", created_at AS "createdAt" FROM notifications WHERE user_id = $1 AND is_dismissed = FALSE ORDER BY created_at DESC LIMIT 20',
        [req.user.id]
      );
      return res.json({ notifications: q.rows });
    } catch (_) {}
  }
  const items = mem.notifications.filter(
    n => !n.isDismissed && (n.userId === req.user.id || (req.user.role === 'professional' && n.userId === 'w1'))
  );
  res.json({ notifications: items.slice(0, 20) });
});

app.patch('/api/v1/notifications/:id/dismiss', authenticateToken, async (req, res) => {
  const id = req.params.id;
  const item = mem.notifications.find(n => n.id === id);
  if (item) item.isDismissed = true;
  if (pool) {
    try {
      await pool.query('UPDATE notifications SET is_dismissed = TRUE WHERE id = $1', [id]);
    } catch (_) {}
  }
  res.json({ ok: true });
});

// --- $0.00 Hybrid AI Issue Parser Proxy (Free-Tier Gemini 2.5 Flash-Lite + Fallback) ---
function deterministicClassify(text) {
  const q = String(text || '').toLowerCase();
  let trade = 'electrician';
  if (/(tap|nal|leak|paani|flush|pipe|sink|plumb|नल|पानी|लीक)/.test(q)) trade = 'plumber';
  else if (/(door|lock|hinge|almari|wood|bed|curtain|carpent|दरवाजा|अलमारी)/.test(q)) trade = 'carpenter';
  else if (/(ac|cooling|fridge|washing|ro|geyser|एसी)/.test(q)) trade = 'appliance';
  else if (/(paint|damp|putty|पेंट|सीलन)/.test(q)) trade = 'painter';
  return {
    trade,
    summaryNote: String(text || '').trim(),
    source: 'deterministic-fallback'
  };
}

function callGeminiFlashLite(promptText) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      contents: [{
        parts: [{
          text: `Classify this household repair issue into one of [electrician, plumber, carpenter, appliance, painter] and write a short 1-sentence job note. Respond strictly as JSON {"trade":"...","summaryNote":"..."}. Input: ${promptText}`
        }]
      }],
      generationConfig: { responseMimeType: 'application/json', temperature: 0.1 }
    });
    const req = https.request(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=${GEMINI_API_KEY}`,
      { method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) }, timeout: 2600 },
      res => {
        let data = '';
        res.on('data', chunk => (data += chunk));
        res.on('end', () => {
          try {
            const parsed = JSON.parse(data);
            const raw = parsed?.candidates?.[0]?.content?.parts?.[0]?.text || '{}';
            resolve(JSON.parse(raw));
          } catch (e) {
            reject(e);
          }
        });
      }
    );
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });
    req.write(payload);
    req.end();
  });
}

app.post('/api/v1/dailyhelper/ai-parse', async (req, res) => {
  const text = String(req.body.text || '').trim();
  if (!text) return res.status(400).json({ error: 'Missing text' });
  if (GEMINI_API_KEY) {
    try {
      const ai = await callGeminiFlashLite(text);
      if (ai && ai.trade) {
        return res.json({ trade: ai.trade, summaryNote: ai.summaryNote || text, source: 'gemini-2.5-flash-lite' });
      }
    } catch (_) {}
  }
  return res.json(deterministicClassify(text));
});

// --- Closed-Loop In-App Bug Triage Endpoints ---
app.post('/api/v1/bugs', async (req, res) => {
  try {
    const description = String(req.body.description || '').trim();
    if (!description) return res.status(400).json({ error: 'Description is required' });
    const userEmail = String(req.body.userEmail || req.body.user_email || 'anonymous@tester.local').trim().toLowerCase();
    const pageContext = String(req.body.pageContext || req.body.page_context || '').trim();
    const appVersion = String(req.body.appVersion || req.body.app_version || '1.0.0').trim();
    const deviceInfo = req.body.deviceInfo || req.body.device_info || {};

    if (pool) {
      const q = await pool.query(
        `INSERT INTO bug_reports (user_email, description, page_context, app_version, device_info, status)
         VALUES ($1, $2, $3, $4, $5::jsonb, 'open')
         RETURNING id, user_email, description, page_context, app_version, status, resolution_notes, created_at`,
        [userEmail, description, pageContext, appVersion, JSON.stringify(deviceInfo)]
      );
      return res.status(201).json({ success: true, bug: q.rows[0] });
    }

    const bug = {
      id: crypto.randomUUID(),
      user_email: userEmail,
      userEmail,
      description,
      page_context: pageContext,
      pageContext,
      app_version: appVersion,
      appVersion,
      device_info: deviceInfo,
      status: 'open',
      resolution_notes: '',
      created_at: new Date().toISOString(),
      resolved_at: null
    };
    mem.bugs.unshift(bug);
    return res.status(201).json({ success: true, bug });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

app.get('/api/v1/bugs', async (req, res) => {
  try {
    const status = String(req.query.status || 'open').toLowerCase();
    const limit = Math.min(parseInt(req.query.limit || '100', 10) || 100, 500);

    if (pool) {
      const q = status === 'all'
        ? await pool.query('SELECT * FROM bug_reports ORDER BY created_at DESC LIMIT $1', [limit])
        : await pool.query('SELECT * FROM bug_reports WHERE status = $1 ORDER BY created_at DESC LIMIT $2', [status, limit]);
      return res.json({ bugs: q.rows });
    }

    const filtered = status === 'all' ? mem.bugs : mem.bugs.filter(b => b.status === status);
    return res.json({ bugs: filtered.slice(0, limit) });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

app.patch('/api/v1/bugs/:id', async (req, res) => {
  try {
    const id = req.params.id;
    const status = req.body.status || null;
    const resolutionNotes = req.body.resolutionNotes ?? req.body.resolution_notes ?? null;

    if (pool) {
      const q = await pool.query(
        `UPDATE bug_reports SET
          status = COALESCE($1, status),
          resolution_notes = COALESCE($2, resolution_notes),
          resolved_at = CASE WHEN $1 = 'resolved' THEN NOW() ELSE resolved_at END
         WHERE id = $3 RETURNING *`,
        [status, resolutionNotes, id]
      );
      if (q.rows.length === 0) return res.status(404).json({ error: 'Bug not found' });
      return res.json({ success: true, bug: q.rows[0] });
    }

    const bug = mem.bugs.find(b => b.id === id);
    if (!bug) return res.status(404).json({ error: 'Bug not found' });
    if (status) bug.status = status;
    if (resolutionNotes !== null) bug.resolution_notes = resolutionNotes;
    if (status === 'resolved') bug.resolved_at = new Date().toISOString();
    return res.json({ success: true, bug });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`DailyHelper backend listening on port ${PORT}`);
  });
}

module.exports = { app };
