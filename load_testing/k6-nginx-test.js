// k6 load test for the nginx-service in this repo.
//
// 1. Deploy:        kubectl apply -f deployments/nginx-deployments.yaml -f services/nginx-services.yaml
// 2. Port-forward:  kubectl port-forward svc/nginx-service 8080:8080
// 3. Run:           k6 run load_testing/k6-nginx-test.js
//    Other target:  BASE_URL=http://nginx.example.com k6 run load_testing/k6-nginx-test.js
//
// See load_testing/load_testing.md for the full walkthrough.
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export const options = {
  stages: [
    { duration: '30s', target: 10 }, // ramp up to 10 virtual users
    { duration: '1m', target: 10 },  // stay at 10 users
    { duration: '30s', target: 50 }, // spike to 50 users
    { duration: '30s', target: 0 },  // ramp down
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],   // less than 1% errors
    http_req_duration: ['p(95)<500'], // 95% of requests under 500ms
  },
};

export default function () {
  const res = http.get(`${BASE_URL}/`);
  check(res, {
    'status is 200': (r) => r.status === 200,
    'body has nginx welcome': (r) => r.body.includes('Welcome to nginx'),
  });
  sleep(1);
}
