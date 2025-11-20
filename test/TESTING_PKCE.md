# OAuth 2.0 + PKCE (RFC 7636) 테스트 가이드

이 문서는 Hyfata REST API의 PKCE (Proof Key for Code Exchange) 구현을 테스트하는 방법을 설명합니다.

## 📋 개요

PKCE는 OAuth 2.0 Authorization Code Flow의 보안을 강화하는 메커니즘으로, 특히 모바일 앱(Flutter, React Native 등)에서 Authorization Code 탈취 공격을 방지합니다.

- **구현 방식**: Authorization Code Flow + PKCE
- **3단계 프로세스**: Authorization (code_challenge 포함) → Login → Token Exchange (code_verifier 검증)
- **보안**: State + PKCE 이중 보안, SHA-256 기반 검증

---

## 🔧 선행 조건

### 1. 애플리케이션 실행
```bash
./gradlew bootRun
```

### 2. 클라이언트 등록
Postman을 사용하여 클라이언트 등록:
```bash
POST http://localhost:8080/api/clients/register
Content-Type: application/json

{
  "name": "PKCE Test Client",
  "frontendUrl": "http://localhost:3000",
  "redirectUris": ["http://localhost:3000/callback"],
  "maxTokensPerUser": 5
}
```

응답에서 `clientId`와 `clientSecret` 저장

### 3. 테스트 사용자 계정
- 이메일 검증 완료한 사용자 계정 필요
- 또는 회원가입 후 이메일 검증 완료

### 4. 도구 설치
- **Postman** (API 테스트)
- **curl** (커맨드라인 테스트)
- **openssl** (code_challenge 생성)

---

## 🔐 PKCE 플로우

```
┌──────────┐                          ┌─────────────────┐
│ Flutter  │                          │   REST API      │
│   App    │                          │   Server        │
└────┬─────┘                          └────────┬────────┘
     │                                         │
     ├─ 1. Code Verifier 생성                  │
     │    (43-128자 임의 문자열)               │
     │                                         │
     ├─ 2. Code Challenge 생성                 │
     │    (SHA-256 해시 + Base64URL)           │
     │                                         │
     │ 3. GET /oauth/authorize                 │
     │    (code_challenge, code_challenge_method=S256)
     ├────────────────────────────────────────→│
     │                                         │
     │ 4. 로그인 페이지 표시                    │
     │←────────────────────────────────────────┤
     │                                         │
     │ 5. POST /oauth/login                    │
     │    (credentials, code_challenge)        │
     ├────────────────────────────────────────→│
     │                                         │
     │ 6. Authorization Code 생성 및 리다이렉트 │
     │←─── redirect_uri?code=xxx&state=xxx ────┤
     │                                         │
     │ 7. POST /oauth/token                    │
     │    (code, code_verifier)                │
     ├────────────────────────────────────────→│
     │                                         │
     │    ✓ code_verifier 검증                 │
     │    (SHA-256 해시 → code_challenge 비교) │
     │                                         │
     │ 8. Access Token + Refresh Token 반환    │
     │←────────────────────────────────────────┤
```

---

## 📱 Postman을 사용한 테스트

### 1단계: Postman Collection 임포트

1. Postman 열기
2. **File → Import**
3. **PKCE_Postman_Collection.json** 선택
4. **Import** 클릭

또는 Postman에서 직접 요청 생성 (아래 단계 참고)

### 2단계: 환경 변수 설정

Postman → **Settings → Manage Environments**

```json
{
  "client_id": "your-client-id",
  "client_secret": "your-client-secret",
  "redirect_uri": "http://localhost:3000/callback",
  "base_url": "http://localhost:8080",
  "email": "test@hyfata.kr",
  "password": "your-password",
  "code_verifier": "",
  "code_challenge": "",
  "authorization_code": "",
  "state": "",
  "access_token": ""
}
```

### 3단계: 1단계 - Authorization Request (code_challenge 생성)

**요청 설정:**
- **Method**: GET
- **URL**: `{{base_url}}/oauth/authorize`

**쿼리 파라미터:**
```
client_id: {{client_id}}
redirect_uri: {{redirect_uri}}
response_type: code
state: {{$randomUUID}}
code_challenge: {{code_challenge}}
code_challenge_method: S256
```

**Postman Pre-request Script (code_challenge 자동 생성):**
```javascript
// crypto-js 라이브러리 필요 (Postman에 내장됨)
const crypto = require('crypto');

// code_verifier 생성 (128자)
const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
let codeVerifier = '';
for (let i = 0; i < 128; i++) {
    codeVerifier += characters.charAt(Math.floor(Math.random() * characters.length));
}

// code_challenge 생성 (SHA-256 + Base64URL)
const hash = crypto.createHash('sha256').update(codeVerifier).digest();
const codeChallenge = Buffer.from(hash)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');

// 환경 변수 저장
pm.environment.set('code_verifier', codeVerifier);
pm.environment.set('code_challenge', codeChallenge);
pm.environment.set('state', pm.variables.replaceIn('{{$randomUUID}}'));

console.log('Code Verifier:', codeVerifier);
console.log('Code Challenge:', codeChallenge);
```

**응답:**
- 로그인 페이지 HTML
- 또는 이미 로그인된 경우 redirect로 Authorization Code 반환

---

### 4단계: 2단계 - Login (Authorization Code 획득)

**요청 설정:**
- **Method**: POST
- **URL**: `{{base_url}}/oauth/login`

**Body (form-data):**
```
email: {{email}}
password: {{password}}
client_id: {{client_id}}
redirect_uri: {{redirect_uri}}
state: {{state}}
code_challenge: {{code_challenge}}
code_challenge_method: S256
```

**응답 처리 (Tests):**
```javascript
// 리다이렉트에서 code와 state 추출
const redirectUrl = pm.response.headers.get('Location');
const url = new URL(redirectUrl);

const code = url.searchParams.get('code');
const state = url.searchParams.get('state');

pm.environment.set('authorization_code', code);
pm.test("State matches", function() {
    pm.expect(state).to.equal(pm.environment.get('state'));
});

console.log('Authorization Code:', code);
```

**응답:**
```
Location: http://localhost:3000/callback?code=xxx&state=xxx
```

---

### 5단계: 3단계 - Token Exchange (PKCE 검증)

**요청 설정:**
- **Method**: POST
- **URL**: `{{base_url}}/oauth/token`

**Body (form-data):**
```
grant_type: authorization_code
code: {{authorization_code}}
client_id: {{client_id}}
client_secret: {{client_secret}}
redirect_uri: {{redirect_uri}}
code_verifier: {{code_verifier}}
```

**응답 처리 (Tests):**
```javascript
pm.test("Status code is 200", function() {
    pm.response.to.have.status(200);
});

pm.test("Token response structure", function() {
    const response = pm.response.json();
    pm.expect(response).to.have.property('access_token');
    pm.expect(response).to.have.property('refresh_token');
    pm.expect(response).to.have.property('token_type');
    pm.expect(response.token_type).to.equal('Bearer');
});

// 토큰 저장
const response = pm.response.json();
pm.environment.set('access_token', response.access_token);
pm.environment.set('refresh_token', response.refresh_token);
```

**성공 응답:**
```json
{
  "access_token": "eyJhbGc...",
  "refresh_token": "eyJhbGc...",
  "token_type": "Bearer",
  "expires_in": 86400000,
  "scope": "user:email user:profile"
}
```

---

## 🛠️ curl을 사용한 테스트

### 1단계: Code Verifier & Challenge 생성

```bash
#!/bin/bash

# Code Verifier 생성 (128자)
CODE_VERIFIER=$(head -c 96 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=')
echo "Code Verifier: $CODE_VERIFIER"

# Code Challenge 생성 (SHA-256 + Base64URL)
CODE_CHALLENGE=$(echo -n "$CODE_VERIFIER" | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=')
echo "Code Challenge: $CODE_CHALLENGE"

# State 생성
STATE=$(uuidgen)
echo "State: $STATE"

# 환경 변수 저장
export CODE_VERIFIER
export CODE_CHALLENGE
export STATE
```

### 2단계: Authorization Request

```bash
curl -X GET "http://localhost:8080/oauth/authorize" \
  -G \
  --data-urlencode "client_id=client_001" \
  --data-urlencode "redirect_uri=http://localhost:3000/callback" \
  --data-urlencode "response_type=code" \
  --data-urlencode "state=$STATE" \
  --data-urlencode "code_challenge=$CODE_CHALLENGE" \
  --data-urlencode "code_challenge_method=S256" \
  -v
```

### 3단계: Login (Authorization Code 획득)

```bash
# 사용자 정보
EMAIL="test@hyfata.kr"
PASSWORD="password123"

# Login 요청
curl -X POST "http://localhost:8080/oauth/login" \
  -d "email=$EMAIL" \
  -d "password=$PASSWORD" \
  -d "client_id=client_001" \
  -d "redirect_uri=http://localhost:3000/callback" \
  -d "state=$STATE" \
  -d "code_challenge=$CODE_CHALLENGE" \
  -d "code_challenge_method=S256" \
  -v

# 응답에서 Location 헤더의 code 추출
# Location: http://localhost:3000/callback?code=xxx&state=xxx

AUTHORIZATION_CODE="<code_from_response>"
echo "Authorization Code: $AUTHORIZATION_CODE"
```

### 4단계: Token Exchange (PKCE 검증)

```bash
curl -X POST "http://localhost:8080/oauth/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "code=$AUTHORIZATION_CODE" \
  -d "client_id=client_001" \
  -d "client_secret=secret_001" \
  -d "redirect_uri=http://localhost:3000/callback" \
  -d "code_verifier=$CODE_VERIFIER" \
  -v
```

**성공 응답:**
```json
{
  "access_token": "eyJhbGc...",
  "refresh_token": "eyJhbGc...",
  "token_type": "Bearer",
  "expires_in": 86400000,
  "scope": "user:email user:profile"
}
```

---

## ✅ 테스트 시나리오

### 시나리오 1: 정상적인 PKCE 플로우

**테스트:**
1. Authorization Request (올바른 code_challenge)
2. Login (code_challenge 동일)
3. Token Exchange (올바른 code_verifier)

**예상 결과:** ✅ 토큰 발급 성공

### 시나리오 2: code_verifier 불일치

**테스트:**
1. Authorization Request (code_challenge A)
2. Token Exchange (다른 code_verifier B)

**예상 결과:** ❌ 400 Bad Request
```json
{
  "error": "invalid_grant",
  "error_description": "code_verifier verification failed"
}
```

### 시나리오 3: code_verifier 누락

**테스트:**
1. Authorization Request (code_challenge 포함)
2. Token Exchange (code_verifier 없음)

**예상 결과:** ❌ 400 Bad Request
```json
{
  "error": "invalid_grant",
  "error_description": "code_verifier is required for PKCE flow"
}
```

### 시나리오 4: 잘못된 code_verifier 형식

**테스트:**
1. Authorization Request (code_challenge 포함)
2. Token Exchange (유효하지 않은 code_verifier)

**예상 결과:** ❌ 400 Bad Request
```json
{
  "error": "invalid_grant",
  "error_description": "Invalid code_verifier format"
}
```

### 시나리오 5: PKCE 없는 기존 플로우 (호환성)

**테스트:**
1. Authorization Request (code_challenge 없음)
2. Login (code_challenge 없음)
3. Token Exchange (code_verifier 없음)

**예상 결과:** ✅ 토큰 발급 성공 (역호환성)

---

## 🧪 자동화된 테스트 (Postman Collection Runner)

### Collection Runner 사용

1. Postman → **Collections** 탭
2. **PKCE_Postman_Collection** 선택
3. **Runner** 클릭
4. **Run** 클릭

### 테스트 실행 결과

```
PKCE Authorization Flow
├─ 1. Generate Code Challenge
│  ├─ Status: 200 ✓
│  └─ Code Challenge generated ✓
├─ 2. Authorization Request
│  ├─ Status: 200 ✓
│  └─ Login page returned ✓
├─ 3. Login & Get Authorization Code
│  ├─ Status: 302 ✓
│  └─ Authorization Code extracted ✓
└─ 4. Token Exchange (PKCE)
   ├─ Status: 200 ✓
   ├─ Access Token: ✓
   ├─ Refresh Token: ✓
   └─ Token Type: Bearer ✓

Passed: 8/8 ✓
```

---

## 📊 검증 체크리스트

### PKCE 구현 검증

- [ ] **code_challenge 생성**: SHA-256 + Base64URL 인코딩 확인
- [ ] **code_verifier 저장**: Authorization Code와 함께 저장 확인
- [ ] **code_verifier 검증**: Token Exchange 시 검증 확인
- [ ] **에러 처리**: 불일치 시 400 Bad Request 반환
- [ ] **호환성**: PKCE 없는 요청도 작동 확인

### 보안 검증

- [ ] **code_challenge 길이**: 최소 43자 확인
- [ ] **code_verifier 길이**: 43-128자 범위 확인
- [ ] **Base64URL 인코딩**: '+', '/', '=' 문자 확인
- [ ] **일회용 Authorization Code**: 재사용 불가 확인
- [ ] **State 파라미터**: CSRF 방지 확인

---

## 🚨 문제 해결

### 문제 1: "code_verifier is required for PKCE flow"

**원인:** Authorization Request에서 code_challenge를 보냈지만, Token Exchange에서 code_verifier를 보내지 않음

**해결:**
```bash
# code_verifier 필수
curl ... -d "code_verifier=$CODE_VERIFIER"
```

### 문제 2: "code_verifier verification failed"

**원인:** code_verifier가 code_challenge와 일치하지 않음

**해결:**
- Authorization Request의 code_challenge와 동일한 code_verifier 사용 확인
- code_verifier 생성 코드 확인 (임의로 생성되므로 매번 새로 생성하면 안 됨)

### 문제 3: "Invalid code_verifier format"

**원인:** code_verifier가 유효한 형식이 아님

**해결:**
- 길이 확인: 43-128자
- 허용 문자만 사용: `ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~`

### 문제 4: Authorization Code 만료

**원인:** Authorization Code 유효시간(10분) 초과

**해결:**
- Token Exchange를 빠르게 진행
- 테스트 시 타이머 설정

---

## 📚 참고 자료

- [PKCE_IMPLEMENTATION.md](../PKCE_IMPLEMENTATION.md) - PKCE 구현 상세 가이드
- [RFC 7636 - PKCE](https://tools.ietf.org/html/rfc7636)
- [TESTING_OAUTH2.md](./TESTING_OAUTH2.md) - OAuth 2.0 기본 테스트
- [POSTMAN_TESTING_GUIDE.md](./POSTMAN_TESTING_GUIDE.md) - Postman 일반 가이드

---

## 💡 팁

1. **Postman 자동화**: Pre-request Script로 code_challenge 자동 생성
2. **환경 변수**: 클라이언트 ID/Secret을 환경 변수로 관리
3. **Collection Runner**: 전체 플로우 자동화 테스트
4. **curl 스크립트**: 배포 환경에서 CI/CD 테스트용
5. **로그 확인**: `./gradlew bootRun` 출력에서 "PKCE" 로그 검색

---

**작성일**: 2025-11-20
**테스트 대상**: Hyfata REST API v1.0
**상태**: ✅ PKCE 구현 완료
