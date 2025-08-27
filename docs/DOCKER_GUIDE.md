# Docker 가이드

이 문서는 MCP 서버를 Docker 컨테이너로 실행하는 방법을 설명합니다.

## 개요

이 프로젝트는 Python 3.13 기반의 MCP (Model Context Protocol) 서버를 Docker 컨테이너로 패키징합니다. UV 패키지 매니저를 사용하여 의존성을 관리하고, streamable-http 전송 방식으로 통신합니다.

## 사전 요구사항

- Docker 설치 (Docker Desktop 또는 Docker Engine)
- 프로젝트 루트에 `env/dev.env` 파일 존재

## Docker 이미지 빌드

### 기본 빌드

```bash
docker build -t mcp-server .
```

### 태그와 함께 빌드

```bash
docker build -t mcp-server:latest .
docker build -t mcp-server:v1.0.0 .
```

## 컨테이너 실행

### 기본 실행

```bash
docker run -p 9001:9001 mcp-server
```

### 백그라운드 실행

```bash
docker run -d -p 9001:9001 --name mcp-server-container mcp-server
```

### 환경 변수 오버라이드

```bash
docker run -p 9001:9001 \
  -e MCP_HOST=0.0.0.0 \
  -e MCP_PORT=9001 \
  -e MCP_TRANSPORT=streamable-http \
  mcp-server
```

### 볼륨 마운트 (개발용)

```bash
docker run -p 9001:9001 \
  -v $(pwd)/src:/app \
  -v $(pwd)/env/dev.env:/app/.env \
  mcp-server
```

## Docker Compose 사용

`docker-compose.yml` 파일을 생성하여 더 쉽게 관리할 수 있습니다:

```yaml
version: "3.8"

services:
  mcp-server:
    build: .
    ports:
      - "9001:9001"
    environment:
      - MCP_HOST=0.0.0.0
      - MCP_PORT=9001
      - MCP_TRANSPORT=streamable-http
    volumes:
      - ./env/dev.env:/app/.env
    restart: unless-stopped
```

실행:

```bash
docker-compose up -d
```

## 환경 변수

컨테이너에서 사용되는 주요 환경 변수:

| 변수명                    | 기본값            | 설명                            |
| ------------------------- | ----------------- | ------------------------------- |
| `MCP_TRANSPORT`           | `streamable-http` | MCP 전송 프로토콜               |
| `MCP_HOST`                | `0.0.0.0`         | 서버 바인딩 호스트              |
| `MCP_PORT`                | `9001`            | 서버 포트                       |
| `PYTHONDONTWRITEBYTECODE` | `1`               | Python 바이트코드 생성 비활성화 |
| `PYTHONUNBUFFERED`        | `1`               | Python 출력 버퍼링 비활성화     |

## 컨테이너 관리

### 실행 중인 컨테이너 확인

```bash
docker ps
```

### 컨테이너 로그 확인

```bash
docker logs mcp-server-container
docker logs -f mcp-server-container  # 실시간 로그
```

### 컨테이너 중지

```bash
docker stop mcp-server-container
```

### 컨테이너 제거

```bash
docker rm mcp-server-container
```

### 이미지 제거

```bash
docker rmi mcp-server
```

## 개발 워크플로우

### 1. 코드 변경 후 재빌드

```bash
docker build -t mcp-server .
docker stop mcp-server-container
docker rm mcp-server-container
docker run -d -p 9001:9001 --name mcp-server-container mcp-server
```

### 2. 개발용 볼륨 마운트 사용

```bash
docker run -p 9001:9001 \
  -v $(pwd)/src:/app \
  --name mcp-server-dev \
  mcp-server
```

## 헬스 체크

컨테이너가 정상적으로 실행되는지 확인:

```bash
# HTTP 요청으로 확인
curl http://localhost:9001/health

# 컨테이너 내부에서 확인
docker exec mcp-server-container curl http://localhost:9001/health
```

## 트러블슈팅

### 포트 충돌

```bash
# 다른 포트 사용
docker run -p 9002:9001 mcp-server
```

### 환경 파일 누락

```bash
# 환경 파일 생성 확인
ls -la env/dev.env

# 컨테이너 내부 확인
docker exec mcp-server-container ls -la /app/.env
```

### 의존성 문제

```bash
# 캐시 없이 재빌드
docker build --no-cache -t mcp-server .
```

## 프로덕션 배포

### 멀티 스테이지 빌드 (선택사항)

더 작은 이미지 크기를 위해 Dockerfile을 수정할 수 있습니다.

### 보안 고려사항

- 프로덕션에서는 루트 사용자 대신 전용 사용자 사용 권장
- 민감한 환경 변수는 Docker secrets 또는 외부 설정 관리 도구 사용
- 이미지 스캔을 통한 보안 취약점 점검

### 모니터링

- 컨테이너 리소스 사용량 모니터링
- 로그 수집 및 분석 시스템 구축
- 헬스 체크 엔드포인트 구현
