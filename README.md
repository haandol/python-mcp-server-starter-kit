# MCP 서버 스타터킷 - Kiro & Q CLI 개발 가이드

이 프로젝트는 **Agentic IDE**를 활용하여 **Model Context Protocol (MCP) 서버**를 반자동으로 개발할 수 있는 스타터킷 템플릿입니다. **Kiro**나 **q CLI** 같은 AI 개발 도구를 사용해 효율적으로 MCP 서버를 구축할 수 있습니다.

## 🚀 빠른 시작

### 1. 프로젝트 클론 및 설정

```bash
git clone <repository-url>
cd python-mcp-server-starter-kit

uv sync
```

### 2. 환경 설정

```bash
# 로컬 개발 환경 설정
cp env/local.env .env

# 환경 변수 편집
vim .env
```

### 3. 서버 실행

```bash
# STDIO 모드 (기본)
uv run src/server.py

# HTTP 모드 (서버 환경 테스트)
MCP_TRANSPORT=streamable-http uv run src/server.py
```

## 🎯 핵심 개념

### MCP (Model Context Protocol)란?

MCP는 AI 모델과 외부 시스템 간의 표준화된 통신 프로토콜입니다.

- **Tools**: AI가 실행할 수 있는 액션 (검색, 계산, API 호출)
- **Resources**: AI가 참조할 수 있는 데이터 (문서, 레코드)
- ~~**Prompts**: 재사용 가능한 프롬프트 템플릿 (선택사항)~~

### Tool Spec First 개발

0. **PRD.md** 작성 → 프로젝트 요약
1. **tool_spec.json** 작성 → 스펙 정의
2. **코드 구현** → 스펙에 맞춰 개발
3. **테스트** → 스펙 준수 검증

## 🛠️ Kiro / Q CLI로 MCP 서버 개발하기

### 0단계: Context7 설정

[Context7](https://github.com/upstash/context7) 페이지를 방문해서 내가 사용하는 Agentic IDE (Kiro, Q CLI) 에 맞게 context7 mcp 를 설정하기

### 1단계: Product Requirement Document (PRD) 작성

Q CLI 등 편한 LLM 을 활용하여 요구사항 정리문서를 작성하여 `PRD.md` 에 추가

> PRD 를 작성해본 적 없다면, [ALPS Writer](https://github.com/haandol/alps-writer) 활용 추천

### 2단계: Tool Specification 작성

먼저 AI 도구에게 다음과 같이 요청하세요:

```
"#File docs/TOOL_SPEC_GUIDE.md 과 PRD.md 파일을 읽고, tool_spec.json을 작성해줘.
- 상품명으로 검색 (필수)
- 카테고리 필터링 (선택)
- 최대 3개 결과 반환
- 영어 키워드만 지원
- TOOL_SPEC_GUIDE.md의 베스트 프랙티스를 모두 적용해줘"
```

**예상 결과:**

```json
{
  "tools": [
    {
      "name": "search_products",
      "description": "상품을 검색합니다. 영어 키워드만 지원하며 최대 3개 결과를 반환합니다.",
      "inputSchema": {
        "type": "object",
        "properties": {
          "name": {
            "type": "string",
            "description": "검색할 상품명 키워드 (영어만 지원)",
            "minLength": 1,
            "maxLength": 100
          },
          "category": {
            "type": "string",
            "description": "상품 카테고리",
            "enum": ["HOBBIES", "BAGS", "GAMES"]
          }
        },
        "required": ["name"]
      }
    }
  ]
}
```

### 3단계: Vertical Slice 구현

AI 도구에게 다음과 같이 요청하세요:

```
"#File tool_spec.json과 #File docs/IMPLEMENTATION_GUIDE.md를 참조해서 search_products 기능을 구현해줘.
- Controller: MCP 인터페이스 (#File docs/MCP_SERVER.md의 Tool 구현 베스트 프랙티스 적용)
- Service: 비즈니스 로직
- Adapter: OpenSearch 연동
- 입력 검증은 tool_spec.json 제약 조건을 정확히 따라야 함
- IMPLEMENTATION_GUIDE.md의 단계별 구현 방법을 정확히 따라줘"
```

**생성될 파일 구조:**

```bash
src/tools/search_products/
├── controller.py    # MCP 인터페이스
├── service.py       # 비즈니스 로직
├── adapter.py       # OpenSearch 연동
└── __init__.py      # 모듈 내보내기
```

### 4단계: 의존성 주입 설정

AI 도구에게 다음과 같이 요청하세요:

```
"#File docs/IMPLEMENTATION_GUIDE.md의 Step 6, Step 8을 참조해서 DIContainer에 search_products 기능을 등록하고, server.py에서 MCP 도구로 등록하는 코드를 추가해줘.
- 의존성 주입 컨테이너 패턴을 정확히 따라줘
- 싱글톤 인스턴스 관리 방식 적용
- FastMCP 등록 방법 준수"
```

### 5단계: 테스트 작성 (옵셔널)

AI 도구에게 다음과 같이 요청하세요:

```
"#File tool_spec.json과 #File docs/TESTING_GUIDE.md를 참조해서 Tool Spec 준수를 검증하는 테스트를 작성해줘.
- Tool Spec First 테스트 원칙 적용 (TESTING_GUIDE.md 2.1절 참조)
- 필수 매개변수 검증
- 길이 제약 조건 검증 (tool_spec.json minLength/maxLength)
- enum 값 검증 (tool_spec.json enum과 정확히 일치)
- 에러 케이스 테스트 (TESTING_GUIDE.md의 에러 케이스 패턴 적용)
- 스펙-구현 일치성 자동 검증 (8.1절 참조)"
```

## 📁 프로젝트 구조

```
├── src/
│   ├── server.py                    # 메인 서버
│   ├── interfaces/                  # 공통 인터페이스
│   │   ├── mcp.py                  # MCP 응답 표준화
│   │   └── product.py              # 도메인 모델
│   ├── tools/                      # MCP Tools (액션)
│   │   └── search_products/        # Vertical Slice
│   │       ├── controller.py
│   │       ├── service.py
│   │       ├── adapter.py
│   │       └── __init__.py
│   ├── resources/                  # MCP Resources (데이터)
│   │   └── products/               # Vertical Slice
│   ├── di/container.py             # 의존성 주입
│   ├── config/server.py            # 설정
│   └── utils/                      # 공통 유틸리티
├── docs/                           # 상세 문서
├── env/                            # 환경별 설정
├── tool_spec.json                  # Tool 스펙 정의
└── pyproject.toml                  # 프로젝트 설정
```

## 🤖 AI 도구 활용 팁

### Kiro 사용 시

`#` 명령어를 통해 컨텍스트 참조가능 (코드베이스, 파일, 온라인 문서 등)

```
#Folder docs/TOOL_SPEC_GUIDE.md 를 참조해서 ...
```

### Q CLI 사용 시

0. **Q CLI 실행**

```bash
q chat --model claude-4-sonnet
```

1. **컨텍스트 추가**

Q Chat 안에서 입력:

```bash
# docs/ 아래의 파일들을 컨텍스트에 추가
/context add docs/

# 현재 컨텍스트 보기
/context show
```

## 📚 상세 가이드

프로젝트의 `docs/` 폴더에는 다음과 같은 상세 가이드가 있습니다:

### 필수 문서

- **[TOOL_SPEC_GUIDE.md](docs/TOOL_SPEC_GUIDE.md)** - tool_spec.json 작성 가이드 (개발 시작점)
- **[IMPLEMENTATION_GUIDE.md](docs/IMPLEMENTATION_GUIDE.md)** - 단계별 구현 방법
- **[MCP_SERVER.md](docs/MCP_SERVER.md)** - Tool과 Resource 베스트 프랙티스

### 참고 문서

- **[ARCHITECTURE_DIAGRAMS.md](docs/ARCHITECTURE_DIAGRAMS.md)** - 시스템 구조 시각화
- **[TESTING_GUIDE.md](docs/TESTING_GUIDE.md)** - 테스트 전략 및 구현
- **[CONFIG_ENVIRONMENT.md](docs/CONFIG_ENVIRONMENT.md)** - 환경 설정 및 배포
- **[DOCKER_GUIDE.md](docs/DOCKER_GUIDE.md)** - Docker 컨테이너 실행

## 🔧 개발 워크플로우

### 새로운 기능 추가

1. **AI 도구에게 요청**

   ```
   "#Folder docs/를 참조해서 새로운 기능 'user_profile' Tool을 추가하고 싶어.
   - #File docs/TOOL_SPEC_GUIDE.md를 기반으로 tool_spec.json부터 작성
   - #File docs/IMPLEMENTATION_GUIDE.md의 새로운 기능 추가 방법 (4단계) 적용
   - #File docs/MCP_SERVER.md의 Tool 구현 베스트 프랙티스 준수
   - 전체 Vertical Slice를 Tool Spec First 원칙으로 구현해줘"
   ```

2. **생성되는 구조**

   ```
   src/tools/user_profile/
   ├── controller.py
   ├── service.py
   ├── adapter.py
   └── __init__.py
   ```

3. **자동 등록**
   - DIContainer에 의존성 추가
   - server.py에 Tool 등록
   - 기존 코드 수정 없이 확장

### 디버깅 및 테스트

1. **HTTP 모드로 테스트**

   ```bash
   MCP_TRANSPORT=streamable-http python src/server.py
   curl -X POST http://localhost:9001/tools/search_products \
     -H "Content-Type: application/json" \
     -d '{"name": "test"}'
   ```

2. **헬스 체크**
   ```bash
   curl http://localhost:9001/ping
   ```

## 🐳 Docker 실행

```bash
# 이미지 빌드
docker build -t mcp-server .

# 컨테이너 실행
docker run -p 9001:9001 mcp-server

# Docker Compose 사용
docker-compose up -d
```

## 🧪 테스트 실행

```bash
# 모든 테스트 실행
pytest

# Tool Spec 준수 테스트만 실행
pytest tests/test_tool_spec_compliance.py

# 커버리지 포함
pytest --cov=src --cov-report=html
```

## AI 도구 활용 팁

- **항상 관련 docs/ 파일을 컨텍스트로 제공**
  - Tool 개발: `#File docs/TOOL_SPEC_GUIDE.md`, `#File docs/MCP_SERVER.md`
  - 구현: `#File docs/IMPLEMENTATION_GUIDE.md`, `#File docs/ARCHITECTURE_DIAGRAMS.md`
  - 테스트: `#File docs/TESTING_GUIDE.md`
  - 배포: `#File docs/CONFIG_ENVIRONMENT.md`, `#File docs/DOCKER_GUIDE.md`
- **Tool Spec First 원칙 강조** - 반드시 `#File docs/TOOL_SPEC_GUIDE.md` 참조
- **구체적인 요구사항과 제약 조건 명시** - 각 docs 파일의 베스트 프랙티스 인용
- **단계별로 나누어 요청** - 각 단계마다 해당하는 docs 파일 지정
