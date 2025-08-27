# 환경 설정 및 배포 가이드

이 문서는 MCP 서버의 환경 설정, 배포, 운영 가이드입니다.

## 1. 환경 설정

### 1.1 환경별 설정 분리 (env 폴더 구조)

```python
# config/environments.py
import os
from dataclasses import dataclass
from dotenv import load_dotenv

# .env 파일 로드
load_dotenv()

@dataclass
class Config:
    debug: bool = os.getenv("DEBUG", "false").lower() == "true"
    log_level: str = os.getenv("LOG_LEVEL", "INFO")
    opensearch_host: str = os.getenv("OPENSEARCH_HOST", "localhost:9200")
    opensearch_username: str = os.getenv("OPENSEARCH_USERNAME", "")
    opensearch_password: str = os.getenv("OPENSEARCH_PASSWORD", "")
```

### 1.2 환경 파일 구조

```
project_root/
├── env/
│   ├── local.env    # 로컬 개발 환경
│   ├── dev.env      # 개발 서버 환경
│   └── prod.env     # 운영 환경 (선택사항)
├── .env             # 현재 활성화된 환경 (복사됨)
└── .gitignore       # .env 파일은 제외
```

### 1.3 환경 파일 예시

**env/local.env:**

```env
DEBUG=true
LOG_LEVEL=DEBUG
OPENSEARCH_HOST=localhost:9200
OPENSEARCH_USERNAME=
OPENSEARCH_PASSWORD=
```

**env/dev.env:**

```env
DEBUG=false
LOG_LEVEL=INFO
OPENSEARCH_HOST=dev-opensearch:9200
OPENSEARCH_USERNAME=dev_user
OPENSEARCH_PASSWORD=dev_password
```

**env/prod.env:**

```env
DEBUG=false
LOG_LEVEL=WARNING
OPENSEARCH_HOST=prod-opensearch:9200
OPENSEARCH_USERNAME=prod_user
OPENSEARCH_PASSWORD=prod_password
```

### 1.4 환경 설정 방법

```bash
# 로컬 개발 환경 설정
cp env/local.env .env

# 개발 서버 환경 설정
cp env/dev.env .env

# 운영 환경 설정
cp env/prod.env .env
```

### 1.5 사용법

```python
# 애플리케이션에서 설정 사용
from config.environments import Config

config = Config()

# 설정 값 사용
if config.debug:
    print("디버그 모드 활성화")

logger.setLevel(config.log_level)
```

## 2. 배포

### 2.1 Docker 배포

**Dockerfile:**

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# 의존성 설치
COPY requirements.txt .
RUN pip install -r requirements.txt

# 애플리케이션 코드 복사
COPY . .

# 환경 변수 설정
ENV PYTHONPATH=/app

# 포트 노출
EXPOSE 9001

# 애플리케이션 실행
CMD ["python", "main.py"]
```

**docker-compose.yml:**

```yaml
version: "3.8"

services:
  mcp-server:
    build: .
    ports:
      - "9001:9001"
    environment:
      - DEBUG=false
      - LOG_LEVEL=INFO
      - OPENSEARCH_HOST=opensearch:9200
    depends_on:
      - opensearch
    volumes:
      - ./logs:/app/logs

  opensearch:
    image: opensearchproject/opensearch:2.11.0
    environment:
      - discovery.type=single-node
      - DISABLE_SECURITY_PLUGIN=true
    ports:
      - "9200:9200"
    volumes:
      - opensearch_data:/usr/share/opensearch/data

volumes:
  opensearch_data:
```

### 2.2 배포 스크립트

**deploy.sh:**

```bash
#!/bin/bash

# 환경 설정
ENVIRONMENT=${1:-dev}
echo "배포 환경: $ENVIRONMENT"

# 환경 파일 복사
cp env/${ENVIRONMENT}.env .env

# Docker 이미지 빌드
docker build -t mcp-server:latest .

# 기존 컨테이너 중지 및 제거
docker-compose down

# 새 컨테이너 시작
docker-compose up -d

echo "배포 완료: $ENVIRONMENT"
```

## 3. 모니터링

### 3.1 헬스 체크

```python
@mcp.custom_route(path="/health", methods=["GET"])
async def health_check(request: Request) -> Response:
    try:
        # 외부 시스템 연결 확인
        opensearch_status = check_opensearch_connection()

        return JSONResponse({
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "services": {
                "opensearch": opensearch_status
            }
        })
    except Exception as e:
        return JSONResponse(
            {"status": "unhealthy", "error": str(e)},
            status_code=503
        )

def check_opensearch_connection() -> str:
    """OpenSearch 연결 상태 확인"""
    try:
        # OpenSearch 클라이언트로 연결 테스트
        response = opensearch_client.ping()
        return "healthy" if response else "unhealthy"
    except Exception:
        return "unhealthy"
```

### 3.2 메트릭 수집

```python
import time
from functools import wraps

def measure_time(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        start_time = time.time()
        try:
            result = func(*args, **kwargs)
            duration = time.time() - start_time
            logger.info(
                "함수 실행 완료",
                function=func.__name__,
                duration_ms=duration * 1000,
                success=True
            )
            return result
        except Exception as e:
            duration = time.time() - start_time
            logger.error(
                "함수 실행 오류",
                function=func.__name__,
                duration_ms=duration * 1000,
                success=False,
                error=str(e)
            )
            raise
    return wrapper

# 사용 예시
@measure_time
def search_products(name: str) -> MCPResponse:
    return service.search(name)
```

### 3.3 로그 관리

**로그 설정:**

```python
import logging
import structlog
from config.environments import Config

def setup_logging():
    config = Config()

    # 기본 로깅 설정
    logging.basicConfig(
        level=getattr(logging, config.log_level),
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    )

    # structlog 설정
    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer()
        ],
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )
```

## 4. 보안

### 4.1 환경 변수 보안

```bash
# .env 파일 권한 설정
chmod 600 .env

# Git에서 제외
echo ".env" >> .gitignore
echo "env/*.env" >> .gitignore
```

### 4.2 인증 및 권한

```python
# API 키 기반 인증
@mcp.custom_route(path="/protected", methods=["GET"])
async def protected_endpoint(request: Request) -> Response:
    api_key = request.headers.get("X-API-Key")

    if not api_key or api_key != os.getenv("API_KEY"):
        return JSONResponse(
            {"error": "Unauthorized"},
            status_code=401
        )

    return JSONResponse({"message": "Access granted"})
```

## 5. 성능 최적화

### 5.1 연결 풀링

```python
from opensearchpy import OpenSearch
from urllib3.util.retry import Retry

def create_opensearch_client():
    return OpenSearch(
        hosts=[os.getenv("OPENSEARCH_HOST")],
        http_auth=(
            os.getenv("OPENSEARCH_USERNAME"),
            os.getenv("OPENSEARCH_PASSWORD")
        ),
        use_ssl=True,
        verify_certs=True,
        connection_class=RequestsHttpConnection,
        pool_maxsize=20,
        retry_on_timeout=True,
        max_retries=3
    )
```

### 5.2 캐싱 전략

```python
import redis
from functools import wraps

# Redis 클라이언트 설정
redis_client = redis.Redis(
    host=os.getenv("REDIS_HOST", "localhost"),
    port=int(os.getenv("REDIS_PORT", "6379")),
    decode_responses=True
)

def cache_result(ttl: int = 300):
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            # 캐시 키 생성
            cache_key = f"{func.__name__}:{hash(str(args) + str(kwargs))}"

            # 캐시에서 조회
            cached_result = redis_client.get(cache_key)
            if cached_result:
                return json.loads(cached_result)

            # 함수 실행 및 캐시 저장
            result = func(*args, **kwargs)
            redis_client.setex(
                cache_key,
                ttl,
                json.dumps(result, default=str)
            )

            return result
        return wrapper
    return decorator
```

## 6. 트러블슈팅

### 일반적인 문제

- **연결 오류**: OpenSearch 연결 상태 확인
- **메모리 사용량**: 프로세스 모니터링 필요

### 디버깅

```bash
# 헬스 체크
curl http://localhost:9001/health

# HTTP 모드에서 Tool 테스트
curl -X POST http://localhost:9001/tools/search_products \
  -H "Content-Type: application/json" \
  -d '{"name": "test"}'
```

## 관련 문서

- [아키텍처 다이어그램](ARCHITECTURE_DIAGRAMS.md) - 시스템 구조 시각화
- [구현 가이드](IMPLEMENTATION_GUIDE.md) - 단계별 구현 방법
- [MCP 서버 특성](MCP_SERVER.md) - Tool과 Resource 베스트 프랙티스
- [테스트 가이드](TESTING_GUIDE.md) - 테스트 전략 및 구현
