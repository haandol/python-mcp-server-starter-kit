# MCP 서버 테스트 가이드

이 문서는 MCP 서버의 테스트 전략과 구현 방법을 설명합니다.

**중요**: 테스트는 **tool_spec.json 스펙 준수**를 최우선으로 검증하며, 스펙과 구현의 일치성을 보장합니다.

## 1. 테스트 전략

### 테스트 피라미드 (Tool Spec First)

- **스펙 준수 테스트**: tool_spec.json과 구현의 일치성 검증 (최우선)
- **단위 테스트**: 개별 컴포넌트 (Controller, Service, Adapter)
- **통합 테스트**: Vertical Slice 전체 플로우
- **E2E 테스트**: MCP 클라이언트와의 실제 통신

### Tool Spec 기반 테스트 원칙

1. **스펙 우선**: 모든 테스트는 tool_spec.json 기준으로 작성
2. **제약 조건 검증**: inputSchema의 모든 제약 조건 테스트
3. **에러 케이스**: 스펙에 정의된 실패 시나리오 검증
4. **타입 일치성**: 함수 시그니처와 스펙의 정확한 일치 확인

### 테스트 환경 설정

```bash
# 테스트 의존성 설치
pip install pytest pytest-asyncio pytest-mock

# 테스트 실행
pytest tests/
```

## 2. 단위 테스트

### 2.1 Tool Spec 준수 테스트 (최우선)

#### tool_spec.json 제약 조건 테스트

````python
import pytest
from unittest.mock import Mock
from tools.search_products.controller import ProductSearchController
from interfaces.mcp import MCPResponse

class TestToolSpecCompliance:
    """tool_spec.json 스펙 준수 테스트"""

    def test_required_parameter_name(self):
        """tool_spec.json required 필드 검증"""
        controller = ProductSearchController(Mock())

        # name이 없는 경우 (required 위반)
        result = controller.search_products("")
        assert result.success is False
        assert "필수" in result.error

    def test_name_length_constraints(self):
        """tool_spec.json minLength/maxLength 검증"""
        controller = ProductSearchController(Mock())

        # minLength: 1 위반
        result = controller.search_products("")
        assert result.success is False

        # maxLength: 100 위반
        long_name = "a" * 101
        result = controller.search_products(long_name)
        assert result.success is False
        assert "100자" in result.error

    def test_category_enum_validation(self):
        """tool_spec.json enum 값 검증"""
        controller = ProductSearchController(Mock())

        # 유효하지 않은 enum 값
        result = controller.search_products("test", category1="INVALID_CATEGORY")
        assert result.success is False
        assert "유효하지 않은" in result.error

        # 유효한 enum 값
        mock_service = Mock()
        mock_service.search_products.return_value = []
        controller = ProductSearchController(mock_service)

        result = controller.search_products("test", category1="HOBBIES")
        assert result.success is True

### 2.2 Controller 테스트

#### 성공 케이스 테스트 (tool_spec.json 기반)

```python
def test_search_products_success_with_spec_compliance():
    """tool_spec.json 스펙을 준수하는 성공 케이스"""
    # Given
    mock_service = Mock()
    mock_service.search_products.return_value = [
        {"id": "1", "name": "test product", "price": 29.99}
    ]
    controller = ProductSearchController(mock_service)

    # When - tool_spec.json의 유효한 입력값 사용
    result = controller.search_products(
        name="test",  # required, 1-100자
        category1="HOBBIES"  # optional, enum 값
    )

    # Then - tool_spec.json 스펙 준수 검증
    assert result.success is True
    assert len(result.data) == 1
    assert result.data[0]["name"] == "test product"

    # 서비스 호출 시 enum 변환 확인
    mock_service.search_products.assert_called_once()
    call_args = mock_service.search_products.call_args[0]
    assert call_args[0] == "test"  # name
    assert str(call_args[1]) == "PrimaryCategoryEnum.HOBBIES"  # enum 변환됨
````

#### 에러 케이스 테스트 (tool_spec.json 기반)

```python
class TestToolSpecErrorCases:
    """tool_spec.json 기반 에러 케이스 테스트"""

    def test_missing_required_parameter(self):
        """required 필드 누락 테스트"""
        controller = ProductSearchController(Mock())

        # name 필드 누락 (tool_spec.json required)
        result = controller.search_products("")
        assert result.success is False
        assert "필수" in result.error

    def test_invalid_parameter_length(self):
        """길이 제약 조건 위반 테스트"""
        controller = ProductSearchController(Mock())

        # maxLength 위반
        result = controller.search_products("a" * 101)
        assert result.success is False
        assert "100자" in result.error

    def test_invalid_enum_value(self):
        """enum 값 위반 테스트"""
        controller = ProductSearchController(Mock())

        # 유효하지 않은 category1 값
        result = controller.search_products("test", category1="INVALID")
        assert result.success is False
        assert "유효하지 않은 카테고리" in result.error

    def test_service_exception_handling(self):
        """서비스 레이어 예외 처리 테스트"""
        mock_service = Mock()
        mock_service.search_products.side_effect = Exception("Service error")
        controller = ProductSearchController(mock_service)

        # 유효한 입력값이지만 서비스에서 예외 발생
        result = controller.search_products("test", category1="HOBBIES")

        assert result.success is False
        assert "Service error" in result.error
```

### 2.2 Service 테스트

#### 비즈니스 로직 테스트

```python
from tools.search_products.service import ProductSearchService
from interfaces.product import PrimaryCategoryEnum

def test_search_products_with_category():
    # Given
    mock_adapter = Mock()
    mock_adapter.search.return_value = [{"id": "1", "name": "test"}]
    service = ProductSearchService(mock_adapter)

    # When
    result = service.search_products("test", PrimaryCategoryEnum.HOBBIES)

    # Then
    assert len(result) == 1
    mock_adapter.search.assert_called_once_with(
        "test", PrimaryCategoryEnum.HOBBIES, None
    )

def test_search_products_empty_name():
    # Given
    mock_adapter = Mock()
    service = ProductSearchService(mock_adapter)

    # When
    result = service.search_products("")

    # Then
    assert result == []
    mock_adapter.search.assert_not_called()
```

### 2.3 Adapter 테스트

#### 외부 시스템 연동 테스트

```python
from unittest.mock import Mock, patch
from tools.search_products.adapter import OpenSearchAdapter

@patch('tools.search_products.adapter.Search')
def test_opensearch_adapter_search(mock_search_class):
    # Given
    mock_search = Mock()
    mock_search_class.return_value = mock_search
    mock_search.query.return_value = mock_search
    mock_search.__getitem__.return_value = mock_search

    mock_result = Mock()
    mock_hit = Mock()
    mock_hit.to_dict.return_value = {"id": "1", "name": "test"}
    mock_result.__iter__.return_value = [mock_hit]
    mock_search.execute.return_value = mock_result

    mock_client = Mock()
    adapter = OpenSearchAdapter(mock_client, "test_index")

    # When
    result = adapter.search("test", None, None)

    # Then
    assert len(result) == 1
    assert result[0]["name"] == "test"
    mock_search.query.assert_called()
```

## 3. 통합 테스트

### 3.1 Vertical Slice 통합 테스트

#### 전체 플로우 테스트

```python
import pytest
from unittest.mock import Mock, patch
from di.container import DIContainer

@patch('utils.opensearch_client.OpenSearchClient')
def test_product_search_integration(mock_opensearch_client):
    # Given
    mock_client = Mock()
    mock_opensearch_client.return_value = mock_client

    # OpenSearch 응답 모킹
    mock_search_result = Mock()
    mock_hit = Mock()
    mock_hit.to_dict.return_value = {
        "id": "PRODUCT_123",
        "name": "Test Product",
        "price": 29.99
    }
    mock_search_result.__iter__.return_value = [mock_hit]

    with patch('opensearchpy.Search') as mock_search_class:
        mock_search = Mock()
        mock_search_class.return_value = mock_search
        mock_search.query.return_value = mock_search
        mock_search.__getitem__.return_value = mock_search
        mock_search.execute.return_value = mock_search_result

        # DIContainer를 통한 통합 테스트
        container = DIContainer()
        controller = container.product_search_controller

        # When
        result = controller.search_products("test")

        # Then
        assert result.success is True
        assert len(result.data) == 1
        assert result.data[0]["name"] == "Test Product"
```

### 3.2 Resource 통합 테스트

```python
@patch('utils.opensearch_client.OpenSearchClient')
def test_product_resource_integration(mock_opensearch_client):
    # Given
    mock_client = Mock()
    mock_opensearch_client.return_value = mock_client

    # OpenSearch get 응답 모킹
    mock_client.client.get.return_value = {
        "_source": {
            "id": "PRODUCT_123",
            "name": "Test Product",
            "price": 29.99
        }
    }

    container = DIContainer()
    controller = container.product_resource_controller

    # When
    result = controller.get_product_by_id("PRODUCT_123")

    # Then
    assert result.success is True
    assert result.data["name"] == "Test Product"
```

## 4. E2E 테스트

### 4.1 MCP 서버 E2E 테스트

#### FastMCP 서버 테스트

```python
import pytest
import asyncio
from mcp.server.fastmcp import FastMCP
from di.container import DIContainer

@pytest.fixture
def mcp_server():
    """테스트용 MCP 서버 인스턴스"""
    mcp = FastMCP("TestServer", stateless_http=True)
    container = DIContainer()

    # Tools 등록
    mcp.tool()(container.product_search_controller.search_products)

    # Resources 등록
    mcp.resource(
        "product-search://{product_id}",
        mime_type="application/json",
    )(container.product_resource_controller.get_product_by_id)

    return mcp

@pytest.mark.asyncio
async def test_mcp_tool_call(mcp_server):
    """MCP Tool 호출 E2E 테스트"""
    # Given
    tool_name = "search_products"
    arguments = {"name": "test"}

    # When
    # 실제 MCP 프로토콜을 통한 Tool 호출 시뮬레이션
    # (실제 구현은 MCP 클라이언트 라이브러리 사용)

    # Then
    # 응답 검증
    pass
```

### 4.2 HTTP 전송 모드 테스트

#### HTTP API 테스트

```python
import requests
import pytest
from multiprocessing import Process
import time
import os

def start_server():
    """테스트용 HTTP 서버 시작"""
    os.environ["MCP_TRANSPORT"] = "streamable-http"
    os.environ["MCP_PORT"] = "9999"

    from server import main
    main()

@pytest.fixture(scope="module")
def http_server():
    """HTTP 서버 픽스처"""
    server_process = Process(target=start_server)
    server_process.start()
    time.sleep(2)  # 서버 시작 대기

    yield "http://localhost:9999"

    server_process.terminate()
    server_process.join()

def test_health_check(http_server):
    """헬스 체크 엔드포인트 테스트"""
    response = requests.get(f"{http_server}/ping")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"

def test_tool_call_http(http_server):
    """HTTP를 통한 Tool 호출 테스트"""
    payload = {
        "name": "test product",
        "category1": "HOBBIES"
    }

    response = requests.post(
        f"{http_server}/tools/search_products",
        json=payload,
        headers={"Content-Type": "application/json"}
    )

    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
```

## 5. 테스트 데이터 관리

### 5.1 픽스처 활용 (Tool Spec 기반)

#### tool_spec.json 기반 테스트 데이터

```python
# conftest.py
import pytest
import json
from unittest.mock import Mock
from pathlib import Path

@pytest.fixture
def tool_spec():
    """tool_spec.json 로드"""
    spec_path = Path(__file__).parent.parent / "tool_spec.json"
    with open(spec_path) as f:
        return json.load(f)

@pytest.fixture
def valid_search_params(tool_spec):
    """tool_spec.json 기반 유효한 매개변수"""
    search_tool = next(t for t in tool_spec["tools"] if t["name"] == "search_products")

    return {
        "name": "test product",  # required, 1-100자
        "category1": search_tool["inputSchema"]["properties"]["category1"]["enum"][0],  # 첫 번째 enum 값
        "category2": None  # optional
    }

@pytest.fixture
def invalid_search_params():
    """tool_spec.json 제약 조건 위반 매개변수들"""
    return {
        "empty_name": {"name": "", "category1": "HOBBIES"},
        "long_name": {"name": "a" * 101, "category1": "HOBBIES"},
        "invalid_category": {"name": "test", "category1": "INVALID_CATEGORY"},
        "wrong_type": {"name": 123, "category1": "HOBBIES"}  # 타입 오류
    }

@pytest.fixture
def sample_product():
    """tool_spec.json enum 값을 사용하는 샘플 상품 데이터"""
    return {
        "id": "PRODUCT_123",
        "name": "Test Product",
        "price": 29.99,
        "rating": 4.5,
        "category1": "HOBBIES",  # tool_spec.json enum 값
        "category2": "Collectible Figures & Memorabilia",  # tool_spec.json enum 값
        "description": "Test product description"
    }

@pytest.fixture
def spec_compliant_search_results(sample_product):
    """tool_spec.json 스펙을 준수하는 검색 결과 (최대 3개)"""
    return [
        sample_product,
        {
            "id": "PRODUCT_456",
            "name": "Another Product",
            "price": 19.99,
            "rating": 3.8,
            "category1": "GAMES",  # tool_spec.json enum 값
            "description": "Another test product"
        },
        {
            "id": "PRODUCT_789",
            "name": "Third Product",
            "price": 39.99,
            "rating": 4.2,
            "category1": "BAGS",  # tool_spec.json enum 값
            "description": "Third test product"
        }
    ]  # 최대 3개 (tool_spec.json description에 명시)
```

### 5.2 테스트 환경 설정 (Tool Spec 검증 포함)

#### 테스트용 환경 변수 및 스펙 검증

```python
# tests/conftest.py
import os
import json
import pytest
from pathlib import Path

@pytest.fixture(autouse=True)
def setup_test_env():
    """테스트 환경 변수 설정"""
    os.environ["ENVIRONMENT"] = "test"
    os.environ["OPENSEARCH_HOST"] = "localhost:9200"
    os.environ["LOG_LEVEL"] = "DEBUG"

    yield

    # 테스트 후 정리
    test_vars = ["ENVIRONMENT", "OPENSEARCH_HOST", "LOG_LEVEL"]
    for var in test_vars:
        if var in os.environ:
            del os.environ[var]

@pytest.fixture(autouse=True)
def validate_tool_spec_exists():
    """tool_spec.json 파일 존재 여부 검증"""
    spec_path = Path(__file__).parent.parent / "tool_spec.json"
    if not spec_path.exists():
        pytest.fail("tool_spec.json 파일이 존재하지 않습니다. Tool Spec First 개발 원칙을 따라주세요.")

@pytest.fixture
def tool_spec_validator():
    """tool_spec.json 스키마 검증 헬퍼"""
    def validate_spec(spec_data):
        """tool_spec.json 기본 구조 검증"""
        assert "tools" in spec_data, "tools 필드가 필요합니다"
        assert isinstance(spec_data["tools"], list), "tools는 배열이어야 합니다"

        for tool in spec_data["tools"]:
            assert "name" in tool, "각 도구는 name 필드가 필요합니다"
            assert "description" in tool, "각 도구는 description 필드가 필요합니다"
            assert "inputSchema" in tool, "각 도구는 inputSchema 필드가 필요합니다"

            schema = tool["inputSchema"]
            assert schema["type"] == "object", "inputSchema type은 object여야 합니다"
            assert "properties" in schema, "inputSchema에는 properties가 필요합니다"

    return validate_spec
```

## 6. 성능 테스트

### 6.1 부하 테스트

#### 동시 요청 테스트

```python
import asyncio
import aiohttp
import pytest
import time

@pytest.mark.asyncio
async def test_concurrent_requests():
    """동시 요청 처리 성능 테스트"""
    async def make_request(session, url):
        async with session.post(url, json={"name": "test"}) as response:
            return await response.json()

    url = "http://localhost:9999/tools/search_products"

    start_time = time.time()

    async with aiohttp.ClientSession() as session:
        tasks = [make_request(session, url) for _ in range(100)]
        results = await asyncio.gather(*tasks)

    end_time = time.time()
    duration = end_time - start_time

    # 성능 검증
    assert duration < 10.0  # 100개 요청이 10초 이내 완료
    assert all(result["success"] for result in results)
```

### 6.2 메모리 사용량 테스트

```python
import psutil
import pytest

def test_memory_usage():
    """메모리 사용량 테스트"""
    process = psutil.Process()
    initial_memory = process.memory_info().rss

    # 대량 데이터 처리 시뮬레이션
    from di.container import DIContainer
    container = DIContainer()
    controller = container.product_search_controller

    # 여러 번 검색 실행
    for i in range(1000):
        result = controller.search_products(f"test_{i}")

    final_memory = process.memory_info().rss
    memory_increase = final_memory - initial_memory

    # 메모리 증가량이 100MB 이하인지 확인
    assert memory_increase < 100 * 1024 * 1024
```

## 7. 테스트 실행 및 리포팅

### 7.1 테스트 실행 명령어

```bash
# 모든 테스트 실행
pytest

# 특정 테스트 파일 실행
pytest tests/test_controllers.py

# 커버리지 포함 실행
pytest --cov=src --cov-report=html

# 병렬 실행
pytest -n auto

# 특정 마커만 실행
pytest -m "not slow"
```

### 7.2 테스트 설정

#### pytest.ini

```ini
[tool:pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
markers =
    slow: marks tests as slow
    integration: marks tests as integration tests
    e2e: marks tests as end-to-end tests
addopts =
    --strict-markers
    --disable-warnings
    -v
```

#### 커버리지 설정

```ini
# .coveragerc
[run]
source = src
omit =
    */tests/*
    */venv/*
    */__pycache__/*

[report]
exclude_lines =
    pragma: no cover
    def __repr__
    raise AssertionError
    raise NotImplementedError
```

## 8. Tool Spec 검증 자동화

### 8.1 스펙-구현 일치성 자동 검증

#### tool_spec.json과 함수 시그니처 일치성 테스트

````python
import json
import inspect
from pathlib import Path
from tools.search_products.controller import ProductSearchController

def test_function_signature_matches_tool_spec():
    """함수 시그니처가 tool_spec.json과 일치하는지 검증"""
    # tool_spec.json 로드
    spec_path = Path(__file__).parent.parent / "tool_spec.json"
    with open(spec_path) as f:
        spec = json.load(f)

    # search_products 도구 스펙 찾기
    search_tool = next(t for t in spec["tools"] if t["name"] == "search_products")

    # 함수 시그니처 검사
    controller = ProductSearchController(None)
    sig = inspect.signature(controller.search_products)

    # required 매개변수 검증
    required_params = search_tool["inputSchema"]["required"]
    for param_name in required_params:
        assert param_name in sig.parameters, f"필수 매개변수 {param_name}이 함수에 없습니다"
        param = sig.parameters[param_name]
        assert param.default == inspect.Parameter.empty, f"{param_name}은 필수 매개변수이므로 기본값이 없어야 합니다"

    # 선택적 매개변수 검증
    all_params = search_tool["inputSchema"]["properties"].keys()
    for param_name in all_params:
        if param_name not in required_params:
            assert param_name in sig.parameters, f"선택적 매개변수 {param_name}이 함수에 없습니다"
            param = sig.parameters[param_name]
            assert param.default is not inspect.Parameter.empty, f"{param_name}은 선택적 매개변수이므로 기본값이 있어야 합니다"

### 8.2 스펙 기반 자동 테스트 생성

#### 동적 테스트 케이스 생성

```python
import pytest
import json
from pathlib import Path

def load_tool_spec():
    """tool_spec.json 로드"""
    spec_path = Path(__file__).parent.parent / "tool_spec.json"
    with open(spec_path) as f:
        return json.load(f)

def generate_test_cases_from_spec():
    """tool_spec.json에서 테스트 케이스 자동 생성"""
    spec = load_tool_spec()
    test_cases = []

    for tool in spec["tools"]:
        schema = tool["inputSchema"]
        properties = schema["properties"]
        required = schema.get("required", [])

        # 유효한 케이스 생성
        valid_case = {}
        for prop_name, prop_schema in properties.items():
            if prop_schema["type"] == "string":
                if "enum" in prop_schema:
                    valid_case[prop_name] = prop_schema["enum"][0]
                else:
                    valid_case[prop_name] = "test_value"

        test_cases.append(("valid", tool["name"], valid_case))

        # 필수 필드 누락 케이스 생성
        for req_field in required:
            invalid_case = valid_case.copy()
            del invalid_case[req_field]
            test_cases.append(("missing_required", tool["name"], invalid_case))

    return test_cases

@pytest.mark.parametrize("case_type,tool_name,params", generate_test_cases_from_spec())
def test_auto_generated_from_spec(case_type, tool_name, params):
    """tool_spec.json에서 자동 생성된 테스트 케이스"""
    if tool_name == "search_products":
        from tools.search_products.controller import ProductSearchController
        controller = ProductSearchController(Mock())

        if case_type == "valid":
            result = controller.search_products(**params)
            # 유효한 입력에 대해서는 서비스 호출까지는 성공해야 함
            # (실제 결과는 모킹된 서비스에 따라 달라짐)
        elif case_type == "missing_required":
            with pytest.raises((TypeError, ValueError)):
                controller.search_products(**params)
````

## 9. CI/CD 통합

### 9.1 GitHub Actions 예시 (Tool Spec 검증 포함)

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  validate-tool-spec:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Validate tool_spec.json exists
        run: |
          if [ ! -f "tool_spec.json" ]; then
            echo "❌ tool_spec.json 파일이 없습니다. Tool Spec First 개발 원칙을 따라주세요."
            exit 1
          fi
          echo "✅ tool_spec.json 파일이 존재합니다."

      - name: Validate JSON syntax
        run: |
          python -m json.tool tool_spec.json > /dev/null
          echo "✅ tool_spec.json JSON 문법이 올바릅니다."

      - name: Validate tool spec schema
        run: |
          python -c "
          import json
          with open('tool_spec.json') as f:
              spec = json.load(f)
          assert 'tools' in spec, 'tools 필드가 필요합니다'
          for tool in spec['tools']:
              assert 'name' in tool, 'name 필드가 필요합니다'
              assert 'description' in tool, 'description 필드가 필요합니다'
              assert 'inputSchema' in tool, 'inputSchema 필드가 필요합니다'
          print('✅ tool_spec.json 스키마가 올바릅니다.')
          "

  test:
    runs-on: ubuntu-latest
    needs: validate-tool-spec

    services:
      opensearch:
        image: opensearchproject/opensearch:2.11.0
        env:
          discovery.type: single-node
          DISABLE_SECURITY_PLUGIN: true
        ports:
          - 9200:9200

    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: "3.11"

      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install pytest pytest-cov jsonschema

      - name: Run tool spec compliance tests
        run: |
          pytest tests/test_tool_spec_compliance.py -v
          echo "✅ Tool Spec 준수 테스트 통과"

      - name: Run unit tests
        run: |
          pytest tests/test_unit/ --cov=src --cov-report=xml

      - name: Run integration tests
        run: |
          pytest tests/test_integration/ -v

      - name: Validate spec-implementation consistency
        run: |
          pytest tests/test_spec_consistency.py -v
          echo "✅ 스펙-구현 일치성 검증 완료"

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.xml
```

## 관련 문서

- [Tool Specification 가이드](TOOL_SPEC_GUIDE.md) - tool_spec.json 작성 가이드 (테스트 기준)
- [아키텍처 다이어그램](ARCHITECTURE_DIAGRAMS.md) - 시스템 구조 시각화
- [구현 가이드](IMPLEMENTATION_GUIDE.md) - 단계별 구현 방법
- [MCP 서버 특성](MCP_SERVER.md) - Tool과 Resource 베스트 프랙티스
- [환경 설정](CONFIG_ENVIRONMENT.md) - 배포 및 운영 가이드
