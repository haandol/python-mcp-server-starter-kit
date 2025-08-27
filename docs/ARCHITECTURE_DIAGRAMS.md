# MCP 서버 아키텍처 다이어그램

이 문서는 MCP 서버의 아키텍처와 데이터 플로우를 시각적으로 보여줍니다.

## 1. 전체 시스템 아키텍처

```mermaid
graph TB
    subgraph "MCP Client"
        Client[MCP Client<br/>Claude, etc.]
    end

    subgraph "MCP Server"
        Server[FastMCP Server<br/>server.py]

        subgraph "Tools (Actions)"
            ToolController[Tool Controller]
            ToolService[Tool Service]
            ToolAdapter[Tool Adapter]
        end

        subgraph "Resources (Data)"
            ResourceController[Resource Controller]
            ResourceService[Resource Service]
            ResourceAdapter[Resource Adapter]
        end

        subgraph "Shared Components"
            DI[DI Container]
            Config[Config]
            Utils[Utils]
        end
    end

    subgraph "External Systems"
        OpenSearch[(OpenSearch<br/>AWS)]
    end

    Client -.->|MCP Protocol| Server
    Server --> ToolController
    Server --> ResourceController

    ToolController --> ToolService
    ToolService --> ToolAdapter
    ToolAdapter --> OpenSearch

    ResourceController --> ResourceService
    ResourceService --> ResourceAdapter
    ResourceAdapter --> OpenSearch

    DI -.->|Inject| ToolController
    DI -.->|Inject| ResourceController
    Config -.->|Configure| DI
    Utils -.->|Support| ToolAdapter
    Utils -.->|Support| ResourceAdapter
```

## 2. Vertical Sliced Architecture

```mermaid
graph LR
    subgraph "Search Products Slice"
        direction TB
        SPC[ProductSearchController]
        SPS[ProductSearchService]
        SPA[OpenSearchAdapter]

        SPC --> SPS
        SPS --> SPA
    end

    subgraph "Product Resource Slice"
        direction TB
        PRC[ProductResourceController]
        PRS[ProductResourceService]
        PRA[ProductResourceAdapter]

        PRC --> PRS
        PRS --> PRA
    end

    subgraph "Future Feature Slice"
        direction TB
        FFC[FeatureController]
        FFS[FeatureService]
        FFA[FeatureAdapter]

        FFC --> FFS
        FFS --> FFA
    end

    subgraph "Shared Layer"
        direction TB
        DIC[DI Container]
        CFG[Config]
        UTL[Utils]
    end

    DIC -.->|Manages| SPC
    DIC -.->|Manages| PRC
    DIC -.->|Manages| FFC

    CFG -.->|Configures| DIC
    UTL -.->|Supports| SPA
    UTL -.->|Supports| PRA
    UTL -.->|Supports| FFA
```

## 3. 데이터 플로우 - Tool 요청 처리

```mermaid
sequenceDiagram
    participant Client as MCP Client
    participant Server as FastMCP Server
    participant Controller as ProductSearchController
    participant Service as ProductSearchService
    participant Adapter as OpenSearchAdapter
    participant OpenSearch as AWS OpenSearch

    Client->>Server: search_products(name, category)
    Server->>Controller: search_products()

    Controller->>Controller: 로깅 시작
    Controller->>Service: search_products(name, category1, category2)

    Service->>Service: 입력 검증
    Service->>Adapter: search(name, category1, category2, limit)

    Adapter->>Adapter: 쿼리 빌드
    Adapter->>OpenSearch: Search 실행
    OpenSearch-->>Adapter: 검색 결과

    Adapter-->>Service: List[Dict[str, Any]]
    Service-->>Controller: List[Dict[str, Any]]

    Controller->>Controller: MCPResponse 생성
    Controller-->>Server: MCPResponse[List[Dict]]
    Server-->>Client: JSON Response
```

## 4. 데이터 플로우 - Resource 요청 처리

```mermaid
sequenceDiagram
    participant Client as MCP Client
    participant Server as FastMCP Server
    participant Controller as ProductResourceController
    participant Service as ProductResourceService
    participant Adapter as ProductResourceAdapter
    participant OpenSearch as AWS OpenSearch

    Client->>Server: GET product-search://PRODUCT_123
    Server->>Controller: get_product_by_id("PRODUCT_123")

    Controller->>Controller: 로깅 시작
    Controller->>Service: get_product_by_id("PRODUCT_123")

    Service->>Adapter: get_by_id("PRODUCT_123")

    Adapter->>OpenSearch: get(index, id)
    OpenSearch-->>Adapter: 상품 데이터 or None

    Adapter-->>Service: Optional[Dict[str, Any]]
    Service-->>Controller: Optional[Dict[str, Any]]

    Controller->>Controller: MCPResponse 생성
    Controller-->>Server: MCPResponse[Optional[Dict]]
    Server-->>Client: JSON Response
```

## 5. 의존성 주입 구조

```mermaid
graph TB
    subgraph "DI Container"
        Container[DIContainer]
    end

    subgraph "Singletons"
        OSClient[OpenSearchClient]
        Config[ServerConfig]
    end

    subgraph "Search Products Slice"
        SPC[ProductSearchController]
        SPS[ProductSearchService]
        SPA[OpenSearchAdapter]
    end

    subgraph "Product Resource Slice"
        PRC[ProductResourceController]
        PRS[ProductResourceService]
        PRA[ProductResourceAdapter]
    end

    Container -->|Creates & Manages| OSClient
    Container -->|Uses| Config

    Container -->|Property| SPC
    SPC -->|Constructor| SPS
    SPS -->|Constructor| SPA
    SPA -->|Constructor| OSClient

    Container -->|Property| PRC
    PRC -->|Constructor| PRS
    PRS -->|Constructor| PRA
    PRA -->|Constructor| OSClient

    Config -.->|Configures| OSClient
    Config -.->|Configures| SPA
    Config -.->|Configures| PRA
```

## 6. 에러 처리 플로우

```mermaid
graph TD
    Start[요청 시작] --> Controller{Controller}

    Controller -->|Success| Service{Service}
    Controller -->|Exception| ErrorResponse1[MCPResponse.error_response]

    Service -->|Success| Adapter{Adapter}
    Service -->|Validation Error| EmptyResult[빈 결과 반환]
    Service -->|Exception| ErrorResponse2[Exception 전파]

    Adapter -->|Success| ExternalSystem[외부 시스템 호출]
    Adapter -->|Exception| ErrorResponse3[Exception 전파]

    ExternalSystem -->|Success| SuccessResponse[MCPResponse.success_response]
    ExternalSystem -->|Error| ErrorResponse4[Exception 전파]

    ErrorResponse1 --> Client[클라이언트 응답]
    ErrorResponse2 --> ErrorResponse1
    ErrorResponse3 --> ErrorResponse2
    ErrorResponse4 --> ErrorResponse3
    EmptyResult --> SuccessResponse
    SuccessResponse --> Client

    style ErrorResponse1 fill:#ffcccc
    style ErrorResponse2 fill:#ffcccc
    style ErrorResponse3 fill:#ffcccc
    style ErrorResponse4 fill:#ffcccc
    style SuccessResponse fill:#ccffcc
```

## 7. 서버 시작 플로우

```mermaid
graph TD
    Start[서버 시작] --> LoadEnv[환경변수 로드<br/>.env]
    LoadEnv --> CreateMCP[FastMCP 인스턴스 생성]
    CreateMCP --> CreateContainer[DIContainer 생성]

    CreateContainer --> RegisterRoutes[라우트 등록<br/>/ping]
    RegisterRoutes --> RegisterTools[Tools 등록]
    RegisterTools --> RegisterResources[Resources 등록]

    RegisterResources --> CheckTransport{Transport 모드}

    CheckTransport -->|stdio| StdioMode[STDIO 모드 실행]
    CheckTransport -->|streamable-http| HttpMode[HTTP 모드 실행<br/>Host:Port]

    StdioMode --> Running[서버 실행 중]
    HttpMode --> Running

    Running --> HandleRequests[MCP 요청 처리]

    style Start fill:#e1f5fe
    style Running fill:#ccffcc
    style HandleRequests fill:#ccffcc
```

## 8. 새로운 기능 추가 플로우

```mermaid
graph LR
    subgraph "1. 새 Vertical Slice 생성"
        CreateDir[디렉토리 생성<br/>tools/new_feature/]
        CreateFiles[파일 생성<br/>controller.py<br/>service.py<br/>adapter.py<br/>__init__.py]

        CreateDir --> CreateFiles
    end

    subgraph "2. 구현"
        ImplAdapter[Adapter 구현<br/>외부 시스템 연동]
        ImplService[Service 구현<br/>비즈니스 로직]
        ImplController[Controller 구현<br/>MCP 인터페이스]

        ImplAdapter --> ImplService
        ImplService --> ImplController
    end

    subgraph "3. 등록"
        UpdateDI[DI Container에<br/>의존성 추가]
        UpdateServer[server.py에<br/>Tool 등록]

        UpdateDI --> UpdateServer
    end

    CreateFiles --> ImplAdapter
    ImplController --> UpdateDI
    UpdateServer --> Complete[새 기능 완성<br/>기존 코드 무수정]

    style Complete fill:#ccffcc
```

## 관련 문서

- [구현 가이드](IMPLEMENTATION_GUIDE.md) - 단계별 구현 방법
- [MCP 서버 특성](MCP_SERVER.md) - Tool과 Resource 베스트 프랙티스
- [테스트 가이드](TESTING_GUIDE.md) - 테스트 전략 및 구현
- [환경 설정](CONFIG_ENVIRONMENT.md) - 배포 및 운영 가이드
