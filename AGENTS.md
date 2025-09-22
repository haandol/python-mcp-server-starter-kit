# AGENTS.md

## Project Overview

이 프로젝트는 **Model Context Protocol (MCP) 서버**를 개발하기 위한 스타터킷입니다. **Tool Spec First** 개발 방법론을 따르며, AI 개발 도구(Kiro, Q CLI 등)와 함께 사용하도록 설계되었습니다.

### 주요 구성 요소

- **MCP Tools**: AI가 실행할 수 있는 액션 (검색, 계산, API 호출)
- **MCP Resources**: AI가 참조할 수 있는 데이터 (문서, 레코드)
- **Vertical Sliced Architecture**: 기능별로 완전한 스택을 가지는 구조

### 프로젝트 구조

```
├── docs/                           # 상세 문서
├── env/                            # 환경별 설정 파일
├── src/                            # 소스 코드 (생성 예정)
│   ├── server.py                   # 메인 서버
│   ├── interfaces/                 # 공통 인터페이스
│   ├── tools/                      # MCP Tools (Vertical Slices)
│   ├── resources/                  # MCP Resources (Vertical Slices)
│   ├── di/container.py             # 의존성 주입
│   └── utils/                      # 공통 유틸리티
├── tool_spec.json                  # Tool 스펙 정의 (생성 예정)
└── pyproject.toml                  # 프로젝트 설정
```

## Setup / Environment

### 필수 요구사항

- Python 3.13+
- UV 패키지 매니저

### 설치 및 설정

```bash
# 프로젝트 클론
git clone <repository-url>
cd python-mcp-server-starter-kit

# 의존성 설치
uv sync

# 환경 설정
cp env/local.env .env
```

### 환경 변수

주요 환경 변수들은 `env/` 폴더의 템플릿 파일들을 참조하세요:

- `env/local.env`: 로컬 개발 환경
- `env/dev.env`: 개발 서버 환경
- `env/prod.env`: 운영 환경

## Build & Run Commands

### 개발 서버 실행

```bash
# STDIO 모드 (기본)
uv run src/server.py

# HTTP 모드 (디버깅용)
MCP_TRANSPORT=streamable-http uv run src/server.py
```

### Docker 실행

```bash
# 이미지 빌드
docker build -t mcp-server .

# 컨테이너 실행
docker run -p 9001:9001 mcp-server

# Docker Compose 사용
docker-compose up -d
```

### 헬스 체크

```bash
# HTTP 모드에서 헬스 체크
curl http://localhost:9001/ping
```

## Testing

### 테스트 실행

```bash
# 모든 테스트 실행
pytest

# Tool Spec 준수 테스트만 실행
pytest tests/test_tool_spec_compliance.py

# 커버리지 포함
pytest --cov=src --cov-report=html
```

### 테스트 전략

- **Tool Spec 준수 테스트**: tool_spec.json과 구현의 일치성 검증 (최우선)
- **단위 테스트**: 개별 컴포넌트 (Controller, Service, Adapter)
- **통합 테스트**: Vertical Slice 전체 플로우
- **E2E 테스트**: MCP 클라이언트와의 실제 통신

## Code Style / Conventions

### 언어 및 도구

- **언어**: Python 3.13+
- **패키지 매니저**: UV
- **프레임워크**: FastMCP
- **로깅**: structlog
- **테스트**: pytest, pytest-asyncio

### 코딩 컨벤션

- **아키텍처**: Vertical Sliced Architecture
- **네이밍**: snake_case (Python 표준)
- **타입 힌트**: 모든 함수에 타입 힌트 필수
- **문서화**: 모든 public 함수에 docstring 작성

### 개발 원칙

1. **Tool Spec First**: 반드시 tool_spec.json 작성 후 코드 구현
2. **스펙 준수**: 함수 시그니처와 tool_spec.json 완전 일치
3. **표준화된 응답**: MCPResponse 클래스 사용
4. **구조화된 로깅**: structlog 활용

## Commit / PR / Release Guidelines

### 커밋 메시지 포맷

```
<type>(<scope>): <description>

예시:
feat(tools): add search_products tool
fix(server): resolve dependency injection issue
docs(guide): update implementation guide
test(spec): add tool spec compliance tests
```

### PR 가이드라인

- PR 제목은 커밋 메시지 포맷 준수
- 변경사항에 대한 명확한 설명 포함
- 관련 문서 업데이트 확인
- 테스트 통과 확인

## Deployment / Operations

### 배포 환경

- **로컬**: STDIO 모드, 개발용
- **개발 서버**: HTTP 모드, 테스트용
- **운영**: Docker 컨테이너, 프로덕션용

### 모니터링

- 헬스 체크 엔드포인트: `/ping`
- 구조화된 로깅을 통한 모니터링
- 메트릭 수집 및 성능 모니터링

## Security Considerations

### 환경 변수 보안

- `.env` 파일은 Git에서 제외
- 민감한 정보는 환경 변수로 관리
- 프로덕션에서는 시크릿 관리 도구 사용

### 입력 검증

- tool_spec.json 제약 조건 엄격 준수
- 모든 사용자 입력에 대한 검증
- SQL 인젝션, XSS 등 보안 취약점 방지

## Agent-specific Instructions

### AI 개발 도구 활용 가이드

#### 필수 참조 문서 순서

1. **[TOOL_SPEC_GUIDE.md](docs/TOOL_SPEC_GUIDE.md)** - 모든 개발의 시작점
2. **[IMPLEMENTATION_GUIDE.md](docs/IMPLEMENTATION_GUIDE.md)** - 단계별 구현 방법
3. **[MCP_SERVER.md](docs/MCP_SERVER.md)** - Tool과 Resource 베스트 프랙티스

#### 개발 워크플로우

1. **PRD.md 작성** → 프로젝트 요구사항 정리
2. **tool_spec.json 작성** → 스펙 정의 (TOOL_SPEC_GUIDE.md 참조)
3. **코드 구현** → 스펙에 맞춰 개발 (IMPLEMENTATION_GUIDE.md 참조)
4. **테스트 작성** → 스펙 준수 검증 (TESTING_GUIDE.md 참조)

#### AI 도구 사용 시 주의사항

- **항상 Tool Spec First 원칙 강조**
- **관련 docs/ 파일을 컨텍스트로 제공**
- **구체적인 요구사항과 제약 조건 명시**
- **단계별로 나누어 요청**

#### 금지된 작업

- tool_spec.json 없이 코드 구현 시작
- 기존 아키텍처 패턴 무시
- 테스트 없는 코드 배포
- 문서 업데이트 없는 기능 추가

#### 권장 자동화 수준

- Tool Spec 작성 지원
- Vertical Slice 코드 생성
- 테스트 케이스 생성
- 문서 업데이트

### Kiro / Q CLI 활용 팁

#### Kiro 사용 시

```
#File docs/TOOL_SPEC_GUIDE.md 를 참조해서 tool_spec.json을 작성해줘
#File docs/IMPLEMENTATION_GUIDE.md 의 Step 4를 참조해서 search_products 기능을 구현해줘
```

#### Q CLI 사용 시

```bash
# 컨텍스트 추가
/context add docs/

# 개발 요청
"docs/TOOL_SPEC_GUIDE.md와 docs/IMPLEMENTATION_GUIDE.md를 참조해서..."
```

## References

### 핵심 문서

- **[README.md](README.md)** - 프로젝트 개요 및 빠른 시작
- **[TOOL_SPEC_GUIDE.md](docs/TOOL_SPEC_GUIDE.md)** - tool_spec.json 작성 가이드 (필수)
- **[IMPLEMENTATION_GUIDE.md](docs/IMPLEMENTATION_GUIDE.md)** - 단계별 구현 방법
- **[MCP_SERVER.md](docs/MCP_SERVER.md)** - Tool과 Resource 베스트 프랙티스

### 참고 문서

- **[ARCHITECTURE_DIAGRAMS.md](docs/ARCHITECTURE_DIAGRAMS.md)** - 시스템 구조 시각화
- **[TESTING_GUIDE.md](docs/TESTING_GUIDE.md)** - 테스트 전략 및 구현
- **[CONFIG_ENVIRONMENT.md](docs/CONFIG_ENVIRONMENT.md)** - 환경 설정 및 배포
- **[DOCKER_GUIDE.md](docs/DOCKER_GUIDE.md)** - Docker 컨테이너 실행

### 외부 리소스

- [MCP 공식 사양서](https://modelcontextprotocol.io/)
- [FastMCP 문서](https://github.com/jlowin/fastmcp)
- [JSON Schema 공식 문서](https://json-schema.org/)
- [Context7](https://github.com/upstash/context7) - AI 도구 컨텍스트 관리

## 새로운 기능 추가 가이드

### AI 도구에게 요청하는 방법

```
"#File docs/TOOL_SPEC_GUIDE.md와 #File docs/IMPLEMENTATION_GUIDE.md를 참조해서 새로운 기능 'user_profile' Tool을 추가하고 싶어.
- tool_spec.json부터 작성 (Tool Spec First 원칙)
- 전체 Vertical Slice 구현 (Controller, Service, Adapter)
- DIContainer와 server.py에 등록
- 베스트 프랙티스 모두 적용"
```

### 생성되는 구조

```
src/tools/user_profile/
├── controller.py    # MCP 인터페이스
├── service.py       # 비즈니스 로직
├── adapter.py       # 외부 시스템 연동
└── __init__.py      # 모듈 내보내기
```
