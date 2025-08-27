# MCP 서버 베스트 프랙티스

이 문서는 MCP Tool과 Resource 구현에 대한 베스트 프랙티스를 설명합니다.

**중요**: 모든 Tool 개발은 **tool_spec.json 작성부터 시작**하여 스펙에 맞춰 코드를 구현하는 순서로 진행합니다.

## 1. MCP 개요

**Model Context Protocol (MCP)**는 AI 모델과 외부 시스템 간의 표준화된 통신 프로토콜입니다.

### MCP 서버 구성 요소

- **Tools**: AI가 실행할 수 있는 액션 (검색, 계산, API 호출)
- **Resources**: AI가 참조할 수 있는 데이터 (문서, 레코드)
- **Prompts**: 재사용 가능한 프롬프트 템플릿 (선택사항)

### 전송 방식

- **STDIO**: 프로덕션 환경, 낮은 지연시간
- **HTTP**: 개발 환경, 디버깅 용이

## 2. Tools vs Resources

### 2.1 Tools (액션)

**Tools는 AI가 실행할 수 있는 함수입니다.**

#### 언제 Tool을 사용하나?

- 데이터를 **검색**할 때
- 외부 API를 **호출**할 때
- **계산**을 수행할 때
- **상태를 변경**할 때

#### Tool 구현 예시

```python
@mcp.tool()
def search_products(
    name: str,
    category: Optional[CategoryEnum] = None
) -> MCPResponse[List[Dict[str, Any]]]:
    """상품을 검색합니다."""
    try:
        results = service.search(name, category)
        return MCPResponse.success_response(data=results)
    except Exception as e:
        return MCPResponse.error_response(error=str(e))
```

### 2.2 Resources (데이터)

**Resources는 AI가 참조할 수 있는 정적 또는 동적 데이터입니다.**

#### 언제 Resource를 사용하나?

- **개별 레코드**를 조회할 때
- **문서 내용**을 제공할 때
- **설정 정보**를 제공할 때
- **메타데이터**를 제공할 때

#### Resource 구현 예시

```python
@mcp.resource("product-search://{product_id}", mime_type="application/json")
def get_product_by_id(product_id: str) -> MCPResponse[Optional[Dict[str, Any]]]:
    """개별 상품 정보를 조회합니다."""
    try:
        product = service.get_by_id(product_id)
        if product:
            return MCPResponse.success_response(data=product)
        else:
            return MCPResponse.error_response(error="Product not found")
    except Exception as e:
        return MCPResponse.error_response(error=str(e))
```

### 2.3 Tools vs Resources 비교

| 구분          | Tools                | Resources          |
| ------------- | -------------------- | ------------------ |
| **목적**      | 액션 실행            | 데이터 제공        |
| **호출 방식** | 함수 호출            | URI 기반 조회      |
| **매개변수**  | 복잡한 매개변수 가능 | 단순한 식별자      |
| **응답**      | 동적 결과            | 정적/반정적 데이터 |
| **캐싱**      | 일반적으로 캐싱 안함 | 캐싱 가능          |
| **예시**      | 검색, 계산, API 호출 | 문서, 레코드, 설정 |

## 3. Tool 구현 베스트 프랙티스

### 3.1 함수 설계 원칙 (Tool Spec First)

#### tool_spec.json 기반 함수 설계

**1단계: tool_spec.json 작성**

```json
{
  "name": "search_products",
  "description": "CAP Retails에서 상품을 검색합니다. 영어 키워드만 지원하며 최대 3개 결과를 반환합니다.",
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
```

**2단계: 스펙 기반 함수 구현**

```python
def search_products(name: str, category: Optional[str] = None):
    """
    CAP Retails에서 상품을 검색합니다.

    이 함수는 tool_spec.json의 search_products 스펙을 구현합니다.
    - 영어 키워드만 지원
    - 최대 3개 결과 반환
    - name은 필수 (1-100자)
    - category는 선택사항 (enum 값)

    Args:
        name (str): 검색할 상품명 키워드 (tool_spec.json required 필드)
        category (Optional[str]): 상품 카테고리 (tool_spec.json enum 값)

    Returns:
        MCPResponse[List[Dict[str, Any]]]: 검색된 상품 목록
    """
```

#### tool_spec.json과 일치하는 타입 힌트

```python
from typing import List, Dict, Any, Optional
from interfaces.product import CategoryEnum
from interfaces.mcp import MCPResponse

def search_products(
    name: str,  # tool_spec.json: "type": "string", required
    category: Optional[str] = None  # tool_spec.json: "enum": [...], optional
) -> MCPResponse[List[Dict[str, Any]]]:
    """
    tool_spec.json 스펙과 정확히 일치하는 시그니처:
    - name: string 타입, 필수 매개변수
    - category: string 타입 (enum), 선택적 매개변수
    """

    # tool_spec.json의 제약 조건 검증
    if len(name) < 1 or len(name) > 100:
        return MCPResponse.error_response(error="name은 1-100자여야 합니다")

    # enum 값 검증 및 변환
    if category and category not in ["HOBBIES", "BAGS", "GAMES"]:
        return MCPResponse.error_response(error="유효하지 않은 카테고리입니다")

    category_enum = CategoryEnum(category) if category else None
    # 비즈니스 로직 실행...
```

### 3.2 에러 처리

#### 표준화된 에러 응답

```python
def search_products(name: str) -> MCPResponse[List[Dict[str, Any]]]:
    try:
        # 입력 검증
        if not name or not name.strip():
            return MCPResponse.error_response(error="검색어는 필수입니다")

        # 비즈니스 로직 실행
        results = service.search(name.strip())
        return MCPResponse.success_response(data=results)

    except ValidationError as e:
        return MCPResponse.error_response(error=f"입력 검증 오류: {str(e)}")
    except ConnectionError as e:
        return MCPResponse.error_response(error=f"외부 시스템 연결 오류: {str(e)}")
    except Exception as e:
        logger.error("예상치 못한 오류", error=str(e), exc_info=True)
        return MCPResponse.error_response(error="내부 서버 오류가 발생했습니다")
```

#### 로깅 전략

```python
def search_products(name: str) -> MCPResponse[List[Dict[str, Any]]]:
    logger.info("상품 검색 요청 시작", name=name)

    try:
        results = service.search(name)
        logger.info("상품 검색 완료", count=len(results))
        return MCPResponse.success_response(data=results)
    except Exception as e:
        logger.error("상품 검색 오류", name=name, error=str(e), exc_info=True)
        return MCPResponse.error_response(error=str(e))
```

### 3.3 입력 검증 (tool_spec.json 기반)

#### tool_spec.json 제약 조건 구현

```python
def search_products(
    name: str,
    category: Optional[str] = None,
    limit: int = 10
) -> MCPResponse[List[Dict[str, Any]]]:
    # tool_spec.json의 required 필드 검증
    if not name or not name.strip():
        return MCPResponse.error_response(error="name은 필수 매개변수입니다")

    # tool_spec.json의 minLength/maxLength 검증
    if len(name.strip()) < 1:  # minLength: 1
        return MCPResponse.error_response(error="name은 최소 1자 이상이어야 합니다")

    if len(name) > 100:  # maxLength: 100
        return MCPResponse.error_response(error="name은 최대 100자까지 가능합니다")

    # tool_spec.json의 enum 값 검증
    if category and category not in ["HOBBIES", "BAGS", "GAMES"]:
        return MCPResponse.error_response(error=f"유효하지 않은 카테고리: {category}")

    # 추가 비즈니스 규칙 (tool_spec.json에 명시된 제한사항)
    if limit > 3:  # tool_spec.json description: "최대 3개 결과 반환"
        limit = 3
```

#### 스펙 일치성 검증 함수

```python
def validate_tool_spec_compliance(name: str, category: Optional[str]) -> Optional[str]:
    """tool_spec.json 스펙 준수 여부를 검증하는 헬퍼 함수"""

    # required 필드 검증
    if not name or not name.strip():
        return "name은 필수 매개변수입니다"

    # 타입 검증
    if not isinstance(name, str):
        return "name은 문자열이어야 합니다"

    # 길이 제약 검증 (tool_spec.json minLength/maxLength)
    if len(name.strip()) < 1:
        return "name은 최소 1자 이상이어야 합니다"
    if len(name) > 100:
        return "name은 최대 100자까지 가능합니다"

    # enum 값 검증
    if category is not None:
        valid_categories = ["HOBBIES", "BAGS", "GAMES"]
        if category not in valid_categories:
            return f"category는 다음 값 중 하나여야 합니다: {valid_categories}"

    return None  # 검증 통과
```

### 3.4 성능 최적화

#### 결과 제한

```python
def search_products(name: str, limit: int = 10) -> MCPResponse[List[Dict[str, Any]]]:
    # 기본값으로 결과 수 제한
    if limit > 100:
        limit = 100

    results = service.search(name, limit=limit)
    return MCPResponse.success_response(data=results)
```

#### 타임아웃 설정

```python
def search_products(name: str) -> MCPResponse[List[Dict[str, Any]]]:
    try:
        # 타임아웃 설정
        results = service.search(name, timeout=30)
        return MCPResponse.success_response(data=results)
    except TimeoutError:
        return MCPResponse.error_response(error="검색 시간이 초과되었습니다")
```

## 4. Resource 구현 베스트 프랙티스

### 4.1 URI 스키마 설계

#### 명확한 URI 패턴

```python
# 좋은 예시
@mcp.resource("product-search://{product_id}", mime_type="application/json")
@mcp.resource("user-profile://{user_id}", mime_type="application/json")
@mcp.resource("document://{doc_id}", mime_type="text/plain")

# 나쁜 예시
@mcp.resource("data://{id}", mime_type="application/json")  # 너무 일반적
@mcp.resource("get_product/{id}", mime_type="application/json")  # 동사 사용
```

#### 계층적 구조

```python
# 계층적 리소스 구조
@mcp.resource("products://{category}/{product_id}", mime_type="application/json")
@mcp.resource("users://{user_id}/orders/{order_id}", mime_type="application/json")
```

### 4.2 MIME 타입 활용

#### 적절한 MIME 타입 선택

```python
# JSON 데이터
@mcp.resource("product://{id}", mime_type="application/json")

# 텍스트 문서
@mcp.resource("document://{id}", mime_type="text/plain")

# 마크다운 문서
@mcp.resource("readme://{project}", mime_type="text/markdown")

# HTML 콘텐츠
@mcp.resource("page://{url}", mime_type="text/html")
```

### 4.3 캐싱 전략

#### 정적 데이터 캐싱

```python
from functools import lru_cache

class ProductResourceService:
    @lru_cache(maxsize=1000)
    def get_product_by_id(self, product_id: str) -> Optional[Dict[str, Any]]:
        """캐싱된 상품 조회"""
        return self.adapter.get_by_id(product_id)
```

#### 캐시 무효화

```python
class ProductResourceService:
    def __init__(self):
        self._cache = {}
        self._cache_ttl = 300  # 5분

    def get_product_by_id(self, product_id: str) -> Optional[Dict[str, Any]]:
        now = time.time()
        cache_key = f"product:{product_id}"

        # 캐시 확인
        if cache_key in self._cache:
            data, timestamp = self._cache[cache_key]
            if now - timestamp < self._cache_ttl:
                return data

        # 캐시 미스 또는 만료
        data = self.adapter.get_by_id(product_id)
        self._cache[cache_key] = (data, now)
        return data
```

## 5. 공통 베스트 프랙티스

### 5.1 응답 형식 표준화

#### MCPResponse 사용

```python
# 성공 응답
return MCPResponse.success_response(data=results)

# 에러 응답
return MCPResponse.error_response(error="오류 메시지")

# 빈 결과
return MCPResponse.success_response(data=[])
```

#### 일관된 데이터 구조

```python
# 상품 데이터 표준 형식
{
    "id": "PRODUCT_123",
    "name": "상품명",
    "price": 29.99,
    "category": "카테고리",
    "description": "상품 설명",
    "metadata": {
        "created_at": "2024-01-01T00:00:00Z",
        "updated_at": "2024-01-01T00:00:00Z"
    }
}
```

### 5.2 로깅 전략

#### 구조화된 로깅

```python
import structlog

logger = structlog.get_logger()

def search_products(name: str) -> MCPResponse:
    logger.info(
        "상품 검색 시작",
        action="search_products",
        name=name,
        timestamp=datetime.utcnow().isoformat()
    )

    try:
        results = service.search(name)
        logger.info(
            "상품 검색 완료",
            action="search_products",
            name=name,
            result_count=len(results),
            duration_ms=duration
        )
        return MCPResponse.success_response(data=results)
    except Exception as e:
        logger.error(
            "상품 검색 오류",
            action="search_products",
            name=name,
            error=str(e),
            exc_info=True
        )
        return MCPResponse.error_response(error=str(e))
```

### 5.3 보안 고려사항

#### 입력 검증 및 새니타이징

```python
import re

def search_products(name: str) -> MCPResponse:
    # SQL 인젝션 방지
    if re.search(r'[;\'"\\]', name):
        return MCPResponse.error_response(error="유효하지 않은 문자가 포함되어 있습니다")

    # XSS 방지
    name = html.escape(name.strip())

    # 길이 제한
    if len(name) > 100:
        return MCPResponse.error_response(error="검색어가 너무 깁니다")
```

## 관련 문서

- [Tool Specification 가이드](TOOL_SPEC_GUIDE.md) - tool_spec.json 작성 가이드 (필수 선행 문서)
- [아키텍처 다이어그램](ARCHITECTURE_DIAGRAMS.md) - 시스템 구조 시각화
- [구현 가이드](IMPLEMENTATION_GUIDE.md) - 단계별 구현 방법
- [테스트 가이드](TESTING_GUIDE.md) - 테스트 전략 및 구현
- [환경 설정](CONFIG_ENVIRONMENT.md) - 배포 및 운영 가이드
