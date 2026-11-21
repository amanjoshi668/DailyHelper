const assert = require('assert');
const http = require('http');
const { app } = require('./server');

function reqJson(port, method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const req = http.request(
      {
        hostname: '127.0.0.1',
        port,
        path,
        method,
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
          ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {})
        }
      },
      res => {
        let data = '';
        res.on('data', c => (data += c));
        res.on('end', () => {
          const isJson = (res.headers['content-type'] || '').includes('application/json');
          resolve({ status: res.statusCode, body: isJson ? JSON.parse(data || '{}') : data });
        });
      }
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function run() {
  const server = app.listen(0);
  const port = server.address().port;
  try {
    // 1. Health & Privacy
    const h = await reqJson(port, 'GET', '/health');
    assert.strictEqual(h.status, 200);
    assert.strictEqual(h.body.status, 'ok');

    const priv = await reqJson(port, 'GET', '/privacy');
    assert.strictEqual(priv.status, 200);
    assert(priv.body.includes('DailyHelper Privacy Policy'));

    // 2. Register Customer & Professional
    const regCust = await reqJson(port, 'POST', '/api/v1/auth/register', {
      name: 'Priya Menon',
      email: 'priya@test.local',
      password: 'password123',
      phone: '+919845011223',
      role: 'customer'
    });
    assert.strictEqual(regCust.status, 201);
    assert.strictEqual(regCust.body.user.role, 'customer');
    const custToken = regCust.body.token;

    const regPro = await reqJson(port, 'POST', '/api/v1/auth/register', {
      name: 'Ramesh Electric',
      email: 'ramesh@test.local',
      password: 'password123',
      phone: '+919900144556',
      role: 'professional',
      trade: 'electrician',
      pin: '560034'
    });
    assert.strictEqual(regPro.status, 201);
    assert.strictEqual(regPro.body.user.role, 'professional');
    const proToken = regPro.body.token;
    const proId = regPro.body.user.id;

    // 3. Workers discovery & AI parse
    const workers = await reqJson(port, 'GET', '/api/v1/workers?trade=electrician');
    assert.strictEqual(workers.status, 200);
    assert(workers.body.workers.length >= 2);

    const ai = await reqJson(port, 'POST', '/api/v1/dailyhelper/ai-parse', { text: 'kitchen tap paani leak' });
    assert.strictEqual(ai.status, 200);
    assert.strictEqual(ai.body.trade, 'plumber');

    // 4. Booking + Top Notifications + Completion
    const bk = await reqJson(port, 'POST', '/api/v1/bookings', {
      workerId: proId,
      workerName: 'Ramesh Electric',
      trade: 'electrician',
      pinCode: '560034',
      fullAddress: 'Flat 402, Palm Grove',
      bookingDate: 'Today',
      slotWindow: '02:00 - 04:00 PM',
      issueNote: 'Switchboard sparking',
      visitFeeInr: 149
    }, custToken);
    assert.strictEqual(bk.status, 201);
    const bkId = bk.body.booking.id;

    const proNotifs = await reqJson(port, 'GET', '/api/v1/notifications', null, proToken);
    assert.strictEqual(proNotifs.status, 200);
    assert(proNotifs.body.notifications.length >= 1);

    const accept = await reqJson(port, 'PATCH', `/api/v1/bookings/${bkId}`, { status: 'confirmed' }, proToken);
    assert.strictEqual(accept.status, 200);

    const custNotifs = await reqJson(port, 'GET', '/api/v1/notifications', null, custToken);
    assert(custNotifs.body.notifications.some(n => n.title.includes('Confirmed')));
    const dismissRes = await reqJson(port, 'PATCH', `/api/v1/notifications/${custNotifs.body.notifications[0].id}/dismiss`, {}, custToken);
    assert.strictEqual(dismissRes.status, 200);

    // 5. Bug Triage open -> resolve pruning
    const postBug = await reqJson(port, 'POST', '/api/v1/bugs', {
      userEmail: 'priya@test.local',
      description: 'Test bug report',
      pageContext: 'Explore',
      appVersion: '1.0.0'
    });
    assert.strictEqual(postBug.status, 201);
    const bugId = postBug.body.bug.id;

    const openBefore = await reqJson(port, 'GET', '/api/v1/bugs?status=open');
    assert(openBefore.body.bugs.some(b => b.id === bugId));

    await reqJson(port, 'PATCH', `/api/v1/bugs/${bugId}`, { status: 'resolved', resolutionNotes: 'Fixed in test' });
    const openAfter = await reqJson(port, 'GET', '/api/v1/bugs?status=open');
    assert(!openAfter.body.bugs.some(b => b.id === bugId));

    console.log('ALL BACKEND TESTS PASSED!');
  } finally {
    server.close();
  }
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
