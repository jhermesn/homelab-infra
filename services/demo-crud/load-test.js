// grafana k6 load test

import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '10s', target: 10 },
    { duration: '30s', target: 10 },
    { duration: '10s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.01'],
  },
};

const BASE_URL = 'http://demo-crud:3000'; 

export default function () {
  const resHome = http.get(`${BASE_URL}/`);
  check(resHome, { 
    'home status is 200': (r) => r.status === 200 
  });

  const payload = JSON.stringify({
    name: `K6 User ${__VU}`,
    email: `k6user${__VU}-${Date.now()}@example.com`,
  });

  const params = {
    headers: { 'Content-Type': 'application/json' },
  };

  const resPost = http.post(`${BASE_URL}/users`, payload, params);
  check(resPost, { 
    'create user status is 201': (r) => r.status === 201 
  });

  const resList = http.get(`${BASE_URL}/users`);
  check(resList, { 
    'list users status is 200': (r) => r.status === 200 
  });

  sleep(Math.random() * 1 + 0.5); 
}