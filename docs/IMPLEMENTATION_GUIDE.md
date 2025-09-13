# MCP 서버 구현 가이드

이 문서는 FastMCP 라이브러리를 사용하여 Model Context Protocol (MCP) 서버를 Vertical Sliced Architecture로 구현하는 단계별 가이드입니다.

개발 과정은 tool_spec.json을 먼저 작성하고, 해당 스펙에 맞춰서 코드를 구현하는 순서로 진행합니다.

## 필수 라이브러리

이 구현 가이드는 다음 핵심 라이브러리들을 기반으로 합니다:

- **FastMCP**: MCP 서버 구현을 위한 핵심 프레임워크
- **structlog**: 구조화된 로깅을 위한 라이브러리
- **pytest**: 테스트 프레임워크
- **pytest-asyncio**: 비동기 테스트 지원
- **python-dotenv**: 환경 변수 관리

## 1. 프로젝트 구조

### 기본 구조

```
src/
├── server.py                    # 메인 서버
├── interfaces/                  # 공통 인터페이스
├── tools/                      # MCP Tools (액션)
│   └── feature_name/           # Vertical Slice
├── resources/                  # MCP Resources (데이터)
│   └── resource_name/          # Vertical Slice
├── di/container.py             # 의존성 주입
├── config/server.py            # 설정
└── utils/                      # 공통 유틸리티
```

### Vertical Slice 구조

각 기능은 독립적인 완전한 스택을 가집니다:

- **Controller**: MCP 인터페이스
- **Service**: 비즈니스 로직
- **Adapter**: 외부 시스템 연동

## 2. 단계별 구현

### Step 1: 프로젝트 초기화

```bash
mkdir your-mcp-server && cd your-mcp-server
mkdir -p src/{interfaces,tools,resources,di,config,utils}
```

#### 필수 의존성 설치

`pyproject.toml`에 다음 의존성들을 추가합니다:

```toml
[project]
dependencies = [
    "fastmcp>=0.1.0",
    "structlog>=23.1.0",
    "python-dotenv>=1.0.0",
    # 기타 프로젝트별 의존성들...
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "pytest-asyncio>=0.21.0",
    # 기타 개발 의존성들...
]
```

### Step 2: Tool Specification 작성

**모든 개발은 tool_spec.json 작성부터 시작합니다.**

#### `tool_spec.json` 작성

```json
{
  "tools": [
    {
      "name": "search_products",
      "description": "CAP Retails에서 상품을 검색합니다. 상품명과 카테고리를 기반으로 최대 3개의 상품을 반환합니다. 모든 매개변수는 영어 키워드만 지원합니다.",
      "inputSchema": {
        "type": "object",
        "properties": {
          "name": {
            "type": "string",
            "description": "검색할 상품명 키워드 (영어만 지원)",
            "minLength": 1,
            "maxLength": 100
          },
          "category1": {
            "type": "string",
            "description": "1차 카테고리 (영어만 지원)",
            "enum": ["HOBBIES", "BAGS", "GAMES"]
          },
          "category2": {
            "type": "string",
            "description": "2차 카테고리 (영어만 지원)",
            "enum": ["Collectible Figures & Memorabilia", "Model Building Kits"]
          }
        },
        "required": ["name"]
      }
    }
  ]
}
```

#### Tool Spec 검증 체크리스트

- [ ] 도구 이름이 명확하고 설명적인가?
- [ ] 설명에 제한사항과 예상 결과가 포함되어 있는가?
- [ ] 필수 매개변수가 required 배열에 포함되어 있는가?
- [ ] enum 값들이 실제 비즈니스 로직과 일치하는가?
- [ ] 타입과 제약 조건이 적절히 설정되어 있는가?

자세한 tool_spec.json 작성 가이드는 [Tool Specification 가이드](TOOL_SPEC_GUIDE.md)를 참조하세요.

### Step 3: 기본 인터페이스 정의

#### `src/interfaces/mcp.py` - MCP 응답 표준화

```python
from typing import Optional, Generic, TypeVar
from pydantic import BaseModel

T = TypeVar("T")

class MCPResponse(BaseModel, Generic[T]):
    success: bool
    data: Optional[T] = None
    error: Optional[str] = None

    @classmethod
    def success_response(cls, data: T) -> "MCPResponse[T]":
        return cls(success=True, data=data)

    @classmethod
    def error_response(cls, error: str) -> "MCPResponse[T]":
        return cls(success=False, data=None, error=error)
```

#### `src/interfaces/product.py` - 도메인 모델 정의 (실제 예시)

```python
import enum
from typing import TypedDict, Optional

class ProductDoc(TypedDict):
    id: str
    name: str
    price: float
    rating: float
    category1: Optional[str]
    category2: Optional[str]
    description: str

class PrimaryCategoryEnum(str, enum.Enum):
    """1차 카테고리"""
    HOBBIES = "Hobbies"
    BAGS = "Bags"
    GAMES = "Games"
    # ... 더 많은 카테고리

class SecondaryCategoryEnum(str, enum.Enum):
    """2차 카테고리"""
    COLLECTIBLE_FIGURES = "Collectible Figures & Memorabilia"
    MODEL_BUILDING_KITS = "Model Building Kits"
    # ... 더 많은 하위 카테고리
```

### Step 4: Tool 구현 (Vertical Slice - tool_spec.json 기반)

#### `src/tools/search_products/adapter.py` - OpenSearch 연동

```python
from typing import List, Dict, Any, Optional
from opensearchpy import Search
from opensearchpy.helpers.query import Q
from interfaces.product import PrimaryCategoryEnum, SecondaryCategoryEnum
from utils.opensearch_client import OpenSearchClient
from utils.logger import logger

class OpenSearchAdapter:
    def __init__(self, opensearch_client: OpenSearchClient, index_name: str):
        self.opensearch_client = opensearch_client
        self.index_name = index_name

    def search(
        self,
        name: str,
        category1: Optional[PrimaryCategoryEnum],
        category2: Optional[SecondaryCategoryEnum],
        limit: int = 3,
    ) -> List[Dict[str, Any]]:
        logger.info("opensearch 검색 실행", index=self.index_name, name=name)

        try:
            s = Search(using=self.opensearch_client.client, index=self.index_name)
            s = s.query("bool", must=[Q("match", name=name)])

            if category1:
                s = s.query("match", category1=category1.value)
            if category2:
                s = s.query("match", category2=category2.value)

            result = s[:limit].execute()
            return [hit.to_dict() for hit in result]
        except Exception as e:
            logger.error("opensearch 검색 중 오류", error=str(e))
            raise
```

#### `src/tools/search_products/service.py` - 비즈니스 로직

```python
from typing import List, Dict, Any, Optional
from .adapter import OpenSearchAdapter
from interfaces.product import PrimaryCategoryEnum, SecondaryCategoryEnum
from utils.logger import logger

class ProductSearchService:
    def __init__(self, opensearch_adapter: OpenSearchAdapter):
        self.opensearch_adapter = opensearch_adapter

    def search_products(
        self,
        name: str,
        category1: Optional[PrimaryCategoryEnum] = None,
        category2: Optional[SecondaryCategoryEnum] = None,
    ) -> List[Dict[str, Any]]:
        logger.info("상품 검색 서비스 처리", name=name)

        # 입력 검증
        if not name or not name.strip():
            logger.warning("빈 검색어로 인한 검색 요청 거부")
            return []

        # 검색 실행
        return self.opensearch_adapter.search(name.strip(), category1, category2)
```

#### `src/tools/search_products/controller.py` - MCP 인터페이스 (tool_spec.json 기반)

**중요**: 함수 시그니처는 tool_spec.json의 inputSchema와 정확히 일치해야 합니다.

```python
from typing import List, Dict, Any, Optional
from .service import ProductSearchService
from interfaces.product import PrimaryCategoryEnum, SecondaryCategoryEnum
from interfaces.mcp import MCPResponse
from utils.logger import logger

class ProductSearchController:
    def __init__(self, service: ProductSearchService):
        self.service = service

    def search_products(
        self,
        name: str,  # tool_spec.json의 required 필드
        category1: Optional[str] = None,  # tool_spec.json의 enum과 일치
        category2: Optional[str] = None,  # tool_spec.json의 enum과 일치
    ) -> MCPResponse[List[Dict[str, Any]]]:
        """
        CAP Retails에서 상품을 검색합니다.

        이 함수는 tool_spec.json의 search_products 도구 스펙을 구현합니다.
        - 최대 3개의 상품 반환
        - 영어 키워드만 지원
        - name은 필수, category1/category2는 선택사항

        Args:
            name (str): 검색할 상품명 (영어만 지원, 1-100자)
            category1 (Optional[str]): 1차 카테고리 (enum 값)
            category2 (Optional[str]): 2차 카테고리 (enum 값)

        Returns:
            MCPResponse: 표준화된 MCP 응답
        """
        logger.info("상품 검색 요청 처리 시작", name=name)

        # tool_spec.json의 제약 조건 검증
        if not name or len(name.strip()) < 1:
            return MCPResponse.error_response(error="검색어는 필수입니다 (최소 1자)")

        if len(name) > 100:
            return MCPResponse.error_response(error="검색어는 최대 100자까지 가능합니다")

        try:
            # Enum 변환 (tool_spec.json의 enum 값을 Python Enum으로)
            category1_enum = PrimaryCategoryEnum(category1) if category1 else None
            category2_enum = SecondaryCategoryEnum(category2) if category2 else None

            products = self.service.search_products(name.strip(), category1_enum, category2_enum)
            return MCPResponse.success_response(data=products)
        except ValueError as e:
            return MCPResponse.error_response(error=f"유효하지 않은 카테고리: {str(e)}")
        except Exception as e:
            logger.error("상품 검색 요청 처리 중 오류", error=str(e))
            return MCPResponse.error_response(error=str(e))
```

#### `src/tools/search_products/__init__.py` - 모듈 내보내기

```python
from .controller import ProductSearchController
from .service import ProductSearchService
from .adapter import OpenSearchAdapter

__all__ = ["ProductSearchController", "ProductSearchService", "OpenSearchAdapter"]
```

### Step 5: Resource 구현 (Vertical Slice - tool_spec.json 기반)

#### `src/resources/products/controller.py`

```python
from typing import Dict, Any, Optional
from .service import ProductResourceService
from interfaces.mcp import MCPResponse
from utils.logger import logger

class ProductResourceController:
    def __init__(self, service: ProductResourceService):
        self.service = service

    def get_product_by_id(self, product_id: str) -> MCPResponse[Optional[Dict[str, Any]]]:
        """상품 ID로 개별 상품 정보 조회"""
        logger.info("상품 ID로 개별 상품 조회 요청", product_id=product_id)

        try:
            product = self.service.get_product_by_id(product_id)
            if product:
                return MCPResponse.success_response(data=product)
            else:
                return MCPResponse.error_response(error="Product not found")
        except Exception as e:
            logger.error("상품 조회 오류", error=str(e))
            return MCPResponse.error_response(error=str(e))
```

### Step 6: 의존성 주입 컨테이너 (실제 구현)

#### `src/di/container.py`

```python
from typing import Optional
from tools.search_products import ProductSearchController, ProductSearchService, OpenSearchAdapter
from resources.products import ProductResourceController, ProductResourceService, ProductResourceAdapter
from utils.opensearch_client import OpenSearchClient
from config.server import server_config

class DIContainer:
    def __init__(self):
        # 싱글톤 인스턴스들
        self._opensearch_client: Optional[OpenSearchClient] = None
        self._opensearch_adapter: Optional[OpenSearchAdapter] = None
        self._product_search_service: Optional[ProductSearchService] = None
        self._product_search_controller: Optional[ProductSearchController] = None
        self._product_resource_adapter: Optional[ProductResourceAdapter] = None
        self._product_resource_service: Optional[ProductResourceService] = None
        self._product_resource_controller: Optional[ProductResourceController] = None

    @property
    def opensearch_client(self) -> OpenSearchClient:
        if self._opensearch_client is None:
            self._opensearch_client = OpenSearchClient(
                opensearch_host=server_config.oss_host,
                aws_profile=server_config.aws_profile,
                environment=server_config.environment,
            )
        return self._opensearch_client

    @property
    def product_search_controller(self) -> ProductSearchController:
        if self._product_search_controller is None:
            # Vertical Slice 내 의존성 체인 구성
            adapter = OpenSearchAdapter(
                opensearch_client=self.opensearch_client,
                index_name=server_config.oss_product_index,
            )
            service = ProductSearchService(adapter)
            self._product_search_controller = ProductSearchController(service)
        return self._product_search_controller

    @property
    def product_resource_controller(self) -> ProductResourceController:
        if self._product_resource_controller is None:
            # 또 다른 Vertical Slice의 의존성 체인
            adapter = ProductResourceAdapter(
                opensearch_client=self.opensearch_client,
                index_name=server_config.oss_product_index,
            )
            service = ProductResourceService(adapter)
            self._product_resource_controller = ProductResourceController(service)
        return self._product_resource_controller
```

### Step 7: 서버 설정 (실제 구현)

#### `src/config/server.py`

```python
import os
from dataclasses import dataclass

@dataclass
class ServerConfig:
    oss_host: str
    oss_product_index: str
    aws_profile: str
    environment: str

server_config = ServerConfig(
    oss_host=os.getenv("OPENSEARCH_HOST", ""),
    oss_product_index=os.getenv("OPENSEARCH_PRODUCT_INDEX", "products"),
    aws_profile=os.getenv("AWS_PROFILE", ""),
    environment=os.getenv("ENVIRONMENT", "local")
)
```

### Step 8: 메인 서버 파일 (tool_spec.json 검증 포함)

#### `src/server.py`

```python
import os
from dotenv import load_dotenv
load_dotenv()

from fastmcp import FastMCP
from starlette.requests import Request
from starlette.responses import JSONResponse, Response
from di.container import DIContainer
from utils.logger import logger

async def health_check(_: Request) -> Response:
    return JSONResponse({"status": "ok"})

def register_tools(mcp_instance: FastMCP, container: DIContainer):
    """Tools 등록 - 각 Vertical Slice의 Controller 등록"""
    logger.info("상품 검색 서버 툴 등록 시작...")

    # search_products Vertical Slice의 Tool 등록
    mcp_instance.tool()(container.product_search_controller.search_products)

    logger.info("상품 검색 서버 툴 등록 완료")

def register_resources(mcp_instance: FastMCP, container: DIContainer):
    """Resources 등록 - 각 Vertical Slice의 Resource 등록"""
    logger.info("상품 검색 서버 리소스 등록 시작...")

    # products Vertical Slice의 Resource 등록
    mcp_instance.resource(
        "product-search://{product_id}",
        mime_type="application/json",
    )(container.product_resource_controller.get_product_by_id)

    logger.info("상품 검색 서버 리소스 등록 완료")

if __name__ == "__main__":
    TRANSPORT = os.getenv("MCP_TRANSPORT", "stdio")
    HOST = os.getenv("MCP_HOST", "0.0.0.0")
    PORT = int(os.getenv("MCP_PORT", "9001"))

    # FastMCP 인스턴스 생성
    if TRANSPORT == "stdio":
        mcp = FastMCP("ProductSearchServer", stateless_http=True)
    elif TRANSPORT == "streamable-http":
        mcp = FastMCP("ProductSearchServer", host=HOST, port=PORT, stateless_http=True)
    else:
        raise ValueError(f"Unknown transport: {TRANSPORT}")

    # 의존성 주입 컨테이너 생성
    container = DIContainer()

    # 등록
    mcp.custom_route(path="/ping", methods=["GET"], name="health_check")(health_check)
    register_tools(mcp, container)
    register_resources(mcp, container)

    # 서버 실행
    logger.info("상품 검색 서버 실행 중...")
    mcp.run(transport=TRANSPORT)
```

## 3. 도구 설계 원칙 및 체크리스트

### 도구 설계 핵심 원칙

효과적인 MCP 도구를 만들기 위한 핵심 원칙들입니다:

#### 1. 적합한 도구 선택
- [ ] 단순 API 호출만 감싸는 도구는 피한다
- [ ] 실제 **업무 흐름**을 해결하는 고임팩트 도구 위주로 만든다
- [ ] 여러 작은 기능 대신 **의미 있는 작업 단위**로 묶는다

#### 2. 네임스페이싱 & 구조화
- [ ] 서비스/리소스 단위로 도구 이름을 구분한다
- [ ] 접두사/접미사로 유사 기능을 일관되게 표시한다
- [ ] 에이전트가 혼란 없이 **올바른 도구를 선택**할 수 있게 한다

#### 3. 반환값 설계
- [ ] 후속 행동에 필요한 **맥락 정보**를 포함한다
- [ ] 단순 ID 대신 사람이 이해할 수 있는 **이름·URL·타입** 등을 제공한다
- [ ] 상세 응답 vs 간결 응답을 선택할 수 있게 한다

#### 4. 토큰 효율성
- [ ] 불필요하게 긴 응답을 줄이고, **pagination / 필터링**을 지원한다
- [ ] 기본값을 문맥 낭비 없이 합리적으로 설정한다
- [ ] 에러 메시지는 **원인 + 해결책**을 담는다

#### 5. 명세 & 설명 품질
- [ ] 도구 설명이 **명확하고 구체적**인가?
- [ ] 파라미터 이름이 의미를 잘 드러내는가? (예: `user_id`)
- [ ] 출력 구조가 일관되고 파싱하기 쉬운가? (JSON 등)
- [ ] 설명 텍스트가 에이전트 문맥에 들어가도 효율적인가?

## 4. 구현 체크리스트

### Tool Specification

- [ ] `tool_spec.json` - 도구 스펙 정의
- [ ] 스펙 검증 - 비즈니스 요구사항과 일치 확인
- [ ] 제약 조건 정의 - 입력 검증 규칙 명시
- [ ] 에러 케이스 정의 - 예상 실패 시나리오 문서화
- [ ] 도구 이름이 명확하고 설명적인가?
- [ ] 설명에 제한사항과 예상 결과가 포함되어 있는가?
- [ ] 필수 매개변수가 required 배열에 포함되어 있는가?
- [ ] enum 값들이 실제 비즈니스 로직과 일치하는가?
- [ ] 타입과 제약 조건이 적절히 설정되어 있는가?

### 핵심 구현 (tool_spec.json 기반)

- [ ] `interfaces/mcp.py` - 표준 응답 형식
- [ ] `interfaces/product.py` - 도메인 모델 (tool_spec.json enum과 일치)
- [ ] Tool Vertical Slice (tool_spec.json 스펙 구현)
- [ ] Resource Vertical Slice (필요시)
- [ ] `di/container.py` - 의존성 주입
- [ ] `server.py` - 메인 서버

### 스펙 일치성 검증

- [ ] 함수 시그니처와 inputSchema 일치
- [ ] Python Enum과 JSON enum 값 일치
- [ ] 입력 검증 로직과 제약 조건 일치
- [ ] 에러 메시지와 스펙 설명 일치

### 환경 설정

- [ ] `.env` 파일
- [ ] `pyproject.toml` 의존성 (FastMCP, structlog, pytest, pytest-asyncio, python-dotenv 포함)

## 5. 새로운 기능 추가 (Tool Spec First)

새로운 기능 추가는 반드시 다음 순서를 따릅니다:

### 1단계: Tool Specification 작성

```json
{
  "tools": [
    {
      "name": "new_feature_tool",
      "description": "새로운 기능에 대한 명확한 설명과 제한사항",
      "inputSchema": {
        "type": "object",
        "properties": {
          "param1": {
            "type": "string",
            "description": "매개변수 설명"
          }
        },
        "required": ["param1"]
      }
    }
  ]
}
```

### 2단계: 스펙 검증

- [ ] 비즈니스 요구사항과 일치하는가?
- [ ] 기존 도구와 중복되지 않는가?
- [ ] 제약 조건이 적절한가?
- [ ] 에러 케이스가 고려되었는가?

### 3단계: 코드 구현

```bash
mkdir -p src/tools/new_feature
# tool_spec.json 기반으로 controller.py, service.py, adapter.py, __init__.py 생성
```

### 4단계: 등록 및 테스트

DIContainer와 server.py에 등록 후 tool_spec.json과 일치성 검증.

## 6. 서버 실행

FastMCP 기반 서버는 다음과 같이 실행할 수 있습니다:

```bash
# 의존성 설치
uv add fastmcp structlog python-dotenv
uv add --dev pytest pytest-asyncio

# 로컬 실행 (STDIO 모드 - 기본)
cp env/local.env .env
uv run python src/server.py

# HTTP 모드로 실행
MCP_TRANSPORT=streamable-http uv run python src/server.py

# 테스트 실행
uv run pytest
```

## 관련 문서

- [Tool Specification 가이드](TOOL_SPEC_GUIDE.md) - tool_spec.json 작성 가이드 (필수)
- [아키텍처 다이어그램](ARCHITECTURE_DIAGRAMS.md) - 시스템 구조 시각화
- [MCP 서버 특성](MCP_SERVER.md) - Tool과 Resource 베스트 프랙티스
- [테스트 가이드](TESTING_GUIDE.md) - 테스트 전략 및 구현
- [환경 설정](CONFIG_ENVIRONMENT.md) - 배포 및 운영 가이드
