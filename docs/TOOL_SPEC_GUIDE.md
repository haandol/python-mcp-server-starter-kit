# MCP Tool Specification 가이드

## 개요

Model Context Protocol (MCP)의 tool_spec.json 파일은 MCP 서버가 제공하는 도구들을 정의하는 핵심 문서입니다. 이 가이드는 효과적인 tool_spec.json 파일을 작성하는 방법을 설명합니다.

## 기본 구조

```json
{
  "tools": [
    {
      "name": "tool_name",
      "description": "도구에 대한 명확한 설명",
      "inputSchema": {
        "type": "object",
        "properties": {
          "parameter_name": {
            "type": "string",
            "description": "매개변수 설명"
          }
        },
        "required": ["parameter_name"]
      }
    }
  ]
}
```

## 필수 필드

### 1. name (필수)
- 도구의 고유 식별자
- 소문자, 언더스코어, 하이픈만 사용
- 명확하고 설명적인 이름 사용

```json
{
  "name": "search_files"
}
```

### 2. description (필수)
- 도구의 기능과 목적을 명확히 설명
- 사용자가 언제 이 도구를 사용해야 하는지 명시
- 간결하면서도 충분한 정보 제공

```json
{
  "description": "지정된 디렉토리에서 파일명 패턴으로 파일을 검색합니다. 정규식과 glob 패턴을 지원합니다."
}
```

### 3. inputSchema (필수)
- JSON Schema 형식으로 입력 매개변수 정의
- type은 항상 "object"
- properties에서 각 매개변수 정의
- required 배열로 필수 매개변수 지정

## 매개변수 타입 정의

### 문자열 매개변수
```json
{
  "parameter_name": {
    "type": "string",
    "description": "매개변수 설명",
    "minLength": 1,
    "maxLength": 100
  }
}
```

### 숫자 매개변수
```json
{
  "count": {
    "type": "integer",
    "description": "반환할 결과 수",
    "minimum": 1,
    "maximum": 100,
    "default": 10
  }
}
```

### 불린 매개변수
```json
{
  "recursive": {
    "type": "boolean",
    "description": "하위 디렉토리도 검색할지 여부",
    "default": false
  }
}
```

### 배열 매개변수
```json
{
  "file_types": {
    "type": "array",
    "description": "검색할 파일 확장자 목록",
    "items": {
      "type": "string"
    },
    "minItems": 1
  }
}
```

### 열거형 매개변수
```json
{
  "sort_order": {
    "type": "string",
    "description": "정렬 순서",
    "enum": ["asc", "desc"],
    "default": "asc"
  }
}
```

## 고급 스키마 기능

### 조건부 필드
```json
{
  "inputSchema": {
    "type": "object",
    "properties": {
      "search_type": {
        "type": "string",
        "enum": ["name", "content"]
      },
      "pattern": {
        "type": "string",
        "description": "검색 패턴"
      },
      "case_sensitive": {
        "type": "boolean",
        "description": "대소문자 구분 여부"
      }
    },
    "required": ["search_type", "pattern"],
    "if": {
      "properties": {
        "search_type": {"const": "content"}
      }
    },
    "then": {
      "properties": {
        "case_sensitive": {"default": true}
      }
    }
  }
}
```

### 복합 객체
```json
{
  "filter": {
    "type": "object",
    "properties": {
      "size_min": {"type": "integer"},
      "size_max": {"type": "integer"},
      "modified_after": {"type": "string", "format": "date-time"}
    }
  }
}
```

## 실제 예제

### 현재 프로젝트의 상품 검색 도구
현재 구현된 `item_search` 도구를 기반으로 한 tool_spec.json 예제:

```json
{
  "tools": [
    {
      "name": "item_search",
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
          "category": {
            "type": "string",
            "description": "상품 카테고리 (영어만 지원)",
            "enum": [
              "Apparel", "Accessories", "Footwear", "Personal Care", "Free Items",
              "Sporting Goods", "Home", "Topwear", "Bottomwear", "Watches", "Socks",
              "Shoes", "Belts", "Flip Flops", "Bags", "Innerwear", "Sandal",
              "Shoe Accessories", "Apparel Set", "Headwear", "Mufflers", "Skin Care",
              "Makeup", "Free Gifts", "Ties", "Water Bottle", "Eyes", "Bath and Body",
              "Gloves", "Sports Accessories", "Cufflinks", "Sports Equipment",
              "Stoles", "Hair", "Perfumes", "Home Furnishing", "Umbrellas",
              "Wristbands", "Vouchers"
            ]
          }
        },
        "required": ["name", "category"]
      }
    }
  ]
}
```

### 파일 검색 도구 (일반적인 예제)
```json
{
  "tools": [
    {
      "name": "search_files",
      "description": "지정된 경로에서 파일을 검색합니다. 파일명 패턴, 내용 검색, 파일 크기 등 다양한 조건으로 필터링할 수 있습니다.",
      "inputSchema": {
        "type": "object",
        "properties": {
          "path": {
            "type": "string",
            "description": "검색할 디렉토리 경로",
            "default": "."
          },
          "pattern": {
            "type": "string",
            "description": "검색할 파일명 패턴 (glob 또는 정규식)"
          },
          "search_content": {
            "type": "boolean",
            "description": "파일 내용도 검색할지 여부",
            "default": false
          },
          "max_results": {
            "type": "integer",
            "description": "최대 결과 수",
            "minimum": 1,
            "maximum": 1000,
            "default": 50
          },
          "file_types": {
            "type": "array",
            "description": "검색할 파일 확장자 (예: ['.py', '.js'])",
            "items": {
              "type": "string",
              "pattern": "^\\.[a-zA-Z0-9]+$"
            }
          }
        },
        "required": ["pattern"]
      }
    }
  ]
}
```

## 베스트 프랙티스

### 1. 명확한 네이밍
- 도구 이름은 기능을 명확히 표현
- 동사_명사 형태 권장 (예: search_files, create_directory, item_search)
- 현재 프로젝트의 `item_search`처럼 도메인 특화된 이름 사용

### 2. 상세한 설명
- 도구의 목적과 사용 시나리오 명시
- 제한사항이나 주의사항 포함 (예: "영어 키워드만 지원")
- 예상 결과 형태 설명 (예: "최대 3개의 상품 반환")
- 특정 도메인이나 서비스 명시 (예: "CAP Retails에서만 검색")

### 3. 적절한 기본값
- 자주 사용되는 값을 기본값으로 설정
- 사용자 편의성 향상
- 현재 프로젝트처럼 결과 수 제한이 있는 경우 명시

### 4. 입력 검증
- 적절한 타입과 제약 조건 설정
- minLength, maxLength, minimum, maximum 활용
- 정규식 패턴으로 형식 검증
- enum을 활용한 선택지 제한 (현재 프로젝트의 CategoryEnum처럼)

### 5. 에러 처리 고려
- 필수 매개변수 명확히 지정
- 예상 가능한 에러 상황 문서화
- 실패 시 반환값 명시 (예: 빈 배열 반환)

### 6. 도메인 특화 고려사항
- 비즈니스 로직에 맞는 카테고리나 열거형 정의
- 외부 서비스 의존성 명시
- 언어 제한사항 명확히 표시

## 검증 체크리스트

### 기본 구조 검증
- [ ] 모든 도구에 name, description, inputSchema가 있는가?
- [ ] 도구 이름이 고유하고 명확한가?
- [ ] 설명이 충분히 상세한가?
- [ ] JSON 문법이 올바른가?

### 매개변수 검증
- [ ] 필수 매개변수가 required 배열에 포함되어 있는가?
- [ ] 매개변수 타입이 올바르게 지정되어 있는가?
- [ ] 적절한 제약 조건이 설정되어 있는가?
- [ ] enum 값들이 실제 구현과 일치하는가?

### 도메인 특화 검증
- [ ] 비즈니스 로직에 맞는 카테고리가 정의되어 있는가?
- [ ] 언어 제한사항이 명시되어 있는가?
- [ ] 결과 제한사항이 문서화되어 있는가?
- [ ] 외부 서비스 의존성이 설명되어 있는가?

### 현재 프로젝트 기준 검증
- [ ] CategoryEnum의 모든 값이 enum에 포함되어 있는가?
- [ ] 영어 키워드 제한사항이 명시되어 있는가?
- [ ] OpenSearch 기반 검색임이 설명되어 있는가?
- [ ] 최대 3개 결과 반환 제한이 명시되어 있는가?

## 현재 프로젝트 구조와의 연관성

### FastMCP와의 통합
현재 프로젝트는 FastMCP를 사용하여 MCP 서버를 구현합니다:

```python
# src/server.py에서
from mcp.server.fastmcp import FastMCP

def register_tools(mcp_instance: FastMCP):
    mcp_instance.tool()(item_search)
```

### 도구 구현과 스키마의 일치
Python 함수의 타입 힌트와 tool_spec.json의 스키마가 일치해야 합니다:

```python
# src/tools/item_search.py
def item_search(name: str, category: CategoryEnum) -> List[Dict[str, Any]]:
```

이는 tool_spec.json의 다음 부분과 대응됩니다:
- `name: str` → `"name": {"type": "string"}`
- `category: CategoryEnum` → `"category": {"type": "string", "enum": [...]}`

### 환경 설정 고려사항
tool_spec.json 작성 시 다음 환경 설정들을 고려해야 합니다:
- OpenSearch 호스트 및 인덱스 설정
- AWS 프로필 설정
- 전송 방식 (stdio/http) 설정

## 추가 리소스

- [JSON Schema 공식 문서](https://json-schema.org/)
- [MCP 공식 사양서](https://modelcontextprotocol.io/)
- [FastMCP 문서](https://github.com/jlowin/fastmcp)
- [JSON Schema 검증 도구](https://www.jsonschemavalidator.net/)
- [현재 프로젝트 README](./README.md)