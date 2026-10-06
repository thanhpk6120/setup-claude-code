<!-- HOWTO: HƯỚNG DẪN KHỞI TẠO DỰ ÁN MỚI TỪ TEMPLATE
1. Copy file này ra thư mục gốc của dự án mới và đổi tên thành `AGENTS.md`.
2. Tìm và thay thế tất cả các placeholder dạng `{{PLACEHOLDER_NAME}}` bằng thông tin thực tế của dự án.
3. Xóa bỏ toàn bộ các block comment <!-- HOWTO --> này trước khi commit.
-->

> ⚠️ **TEMPLATE / BẢN MẪU:** File này là tài liệu mẫu dùng để tạo `AGENTS.md` cho các dự án mới.
> Không sử dụng trực tiếp file này làm hướng dẫn agent khi chưa điền thông tin cụ thể.

---

# AGENTS.md — Root Project Agent Guide

## 0. File metadata [REQUIRED]

```yaml
project: {{PROJECT_NAME}}
doc_version: 1.0.0
updated_at: {{YYYY-MM-DD}}
owner: {{PROJECT_OWNER}}
docs_repo: {{DOCS_GIT_REPO_URL}}
ticket_prefix: {{TICKET_PREFIX}}
language_for_ai_replies: {{Vietnamese | English}}
```

---

## 1. Project overview [REQUIRED]

**{{PROJECT_NAME}}** là {{Mô tả ngắn gọn về hệ thống / mục tiêu dự án}}.

**Business goal:** {{Mục tiêu kinh doanh chính của hệ thống}}.

**Main capabilities:**
- {{Năng lực 1}}
- {{Năng lực 2}}
- {{Năng lực 3}}
- {{Năng lực 4}}

**Customer / stakeholders:** {{Danh sách khách hàng, người dùng cuối, đội ngũ vận hành, bên liên quan}}.

**Out of scope for this workspace:** {{Những hệ thống, module hoặc dịch vụ bên ngoài nằm ngoài phạm vi workspace này}}.

---

## 2. Session start protocol [REQUIRED]

Đọc theo đúng thứ tự này **trước khi** lập kế hoạch, viết code, kiểm thử hoặc review:

1. Chạy `git pull` bên trong thư mục `docs/`.
2. File này (`AGENTS.md`).
3. `docs/README.md` — quy trình spec-driven workflow.
4. `docs/ARCHITECTURE.md` — kiến trúc hệ thống, cổng mạng, giao tiếp liên service.
5. `docs/specs/<domain>.md` — đặc tả nghiệp vụ liên quan đến task.
6. `docs/rules/<rule>.md` — quy tắc làm việc tương ứng với loại task.
7. `docs/DESIGN.md` — nếu task có thay đổi UI/UX.
8. `docs/features/<TICKET-ID>/` — nếu task gắn với ticket cụ thể.

**Không viết code trước khi hoàn thành các bước 1–6.**

---

## 3. Workspace layout [REQUIRED]

<!-- HOWTO: Liệt kê cấu trúc thư mục workspace và các service thực tế kèm công nghệ/port -->
```text
{{WORKSPACE_ROOT}}/                  ← parent folder (workspace root, NOT a git repo)
├── AGENTS.md                        ← file hướng dẫn agent gốc
├── docs/                            ← docs repo (git riêng) — nguồn chân lý (source of truth)
│   ├── README.md                    ← workflow đặc tả
│   ├── ARCHITECTURE.md              ← kiến trúc tổng thể
│   ├── DESIGN.md                    ← thiết kế UI/UX
│   ├── COMMANDS.md                  ← catalog lệnh tắt
│   ├── specs/                       ← đặc tả nghiệp vụ từng domain
│   ├── rules/                       ← quy tắc vận hành AI agent
│   ├── features/                    ← theo dõi theo ticket ({{TICKET_PREFIX}}-XXXX)
│   └── skills/                      ← domain skills
├── {{service-1-dir}}/               ← {{Tech Stack & Port / Role}}
├── {{service-2-dir}}/               ← {{Tech Stack & Port / Role}}
└── {{service-3-dir}}/               ← {{Tech Stack & Port / Role}}
```

**Naming rule [REQUIRED]:** Tên thư mục cục bộ là **tên canonical** dùng xuyên suốt trong tài liệu, plan, task và report. Không gọi service bằng tên git repo hay title trong README. Khi có xung đột, **mã nguồn thực tế thắng** và phải ghi nhận vào `docs/ARCHITECTURE.md`.

---

## 4. Service registry [REQUIRED]

### 4.1 Canonical Service Tags (`{{SERVICE_TAGS}}`)
`{{service-key-1}}`, `{{service-key-2}}`, `{{service-key-3}}`

### 4.2 Service Registry Table
| service-key (canonical) | Repo path | Git repository | Role | Runtime / port | Datastore |
|---|---|---|---|---|---|
| `{{service-key-1}}` | `./{{service-key-1}}` | `{{GIT_URL_SERVICE_1}}` | {{Mô tả vai trò service 1}} | {{Runtime / Framework / Port}} | {{Datastore}} |
| `{{service-key-2}}` | `./{{service-key-2}}` | `{{GIT_URL_SERVICE_2}}` | {{Mô tả vai trò service 2}} | {{Runtime / Framework / Port}} | {{Datastore}} |
| `{{service-key-3}}` | `./{{service-key-3}}` | `{{GIT_URL_SERVICE_3}}` | {{Mô tả vai trò service 3}} | {{Runtime / Framework / Port}} | {{Datastore}} |
| `docs` | `./docs` | `{{DOCS_GIT_REPO_URL}}` | Documentation source of truth | Markdown | — |

**Hạ tầng dùng chung:**
- Cơ sở dữ liệu: {{Databases, ví dụ: PostgreSQL, MongoDB, MySQL}}
- Lưu trữ file/đối tượng: {{Object Storage, ví dụ: MinIO, AWS S3}}
- Hàng đợi / Message broker: {{Message Broker, ví dụ: Kafka, RabbitMQ, SQS}}
- Cache: {{Cache, ví dụ: Redis, Caffeine}}
- Tích hợp chuyên biệt: {{Chuyên biệt, ví dụ: HSM, Gateway, Identity Provider}}

### 4.3 Quy tắc định vị service [REQUIRED]
1. Service mục tiêu phải được **chỉ định rõ ràng** theo thứ tự ưu tiên: `plan.md` front-matter `service:` → cột `Service` trong `tasks.md` → chỉ thị trực tiếp từ người dùng.
2. Tuyệt đối không đoán service bằng grep/glob.
3. Chỉ thao tác trên các file thuộc `Repo path` được ánh xạ từ bảng trên.
4. Nếu chưa xác định được service hoặc task liên quan nhiều repo mà chưa được khai báo: **DỪNG LẠI VÀ HỎI**.

---

## 5. Tech stack [REQUIRED]

| Service | Framework / version | Language / version | Auth | Build & run |
|---|---|---|---|---|
| `{{service-key-1}}` | {{Framework / Version}} | {{Language / Version}} | {{Auth Mechanism}} | `{{BUILD_CMD}}` / `{{RUN_CMD}}` |
| `{{service-key-2}}` | {{Framework / Version}} | {{Language / Version}} | {{Auth Mechanism}} | `{{BUILD_CMD}}` / `{{RUN_CMD}}` |
| `{{service-key-3}}` | {{Framework / Version}} | {{Language / Version}} | {{Auth Mechanism}} | `{{BUILD_CMD}}` / `{{RUN_CMD}}` |

---

## 6. Source-of-truth map [REQUIRED]

| Vấn đề cần tìm / thay đổi | Tài liệu cần đọc trước |
|---|---|
| Kiến trúc, dịch vụ, tích hợp ngoại vi | `docs/ARCHITECTURE.md` |
| Đặc tả chi tiết nghiệp vụ domain A | `docs/specs/{{domain-a}}.md` |
| Đặc tả chi tiết nghiệp vụ domain B | `docs/specs/{{domain-b}}.md` |
| Giao diện, UI component, theme | `docs/DESIGN.md` |
| Ticket hoặc tính năng cụ thể | `docs/features/<TICKET-ID>/` |
| Quy tắc vận hành của Agent | `docs/rules/*.md` |
| Hướng dẫn thực thi kỹ năng Agent | `docs/skills/<skill-name>/SKILL.md` |

---

## 7. Business domain map

| # | Domain | Backend module / service | Frontend feature | Spec file |
|---|---|---|---|---|
| 1 | {{Tên nghiệp vụ 1}} | `{{backend-service-1}}` | `{{frontend-service-1}}` | `docs/specs/{{domain-1}}.md` |
| 2 | {{Tên nghiệp vụ 2}} | `{{backend-service-2}}` | `{{frontend-service-2}}` | `docs/specs/{{domain-2}}.md` |
| 3 | {{Tên nghiệp vụ 3}} | `{{backend-service-3}}` | `{{frontend-service-3}}` | `docs/specs/{{domain-3}}.md` |

---

## 8. Feature workflow [REQUIRED]

### 8.1 Feature folder model

Mỗi hạng mục công việc được quản lý tại `docs/features/<TICKET-ID>/` (ví dụ `{{TICKET_PREFIX}}-1024/`):

| File | Owner | Nội dung |
|---|---|---|
| `expect.md` | BA | Yêu cầu nghiệp vụ, actors, tiêu chí nghiệm thu (acceptance criteria), out-of-scope |
| `plan.md` | DEV + AI | Thiết kế kỹ thuật; bắt buộc duyệt Gate 1 trước khi viết code |
| `tasks.md` | DEV + AI | Danh sách checklist công việc theo service, có cột `Service` và trạng thái |
| `testcase.md` | AI | Kịch bản kiểm thử sinh từ `expect.md` |
| `impact.md` | AI + DEV | Phạm vi ảnh hưởng, rủi ro, danh sách kiểm tra an toàn |
| `report.md` | AI | Danh sách file thay đổi thực tế và kết quả kiểm thử thực tế |
| `deploy.md` | DEV | Hướng dẫn cấu hình/DB/deployment nếu có thay đổi hạ tầng |

### 8.2 Lifecycle and gates

```text
draft ──► plan-review ──► approved ──► in_progress ──► testing ──► done
                                              │
                                              └──► blocked / cancelled
```

- **Gate 1 — Plan review:** `plan.md` phải được DEV tự kiểm tra và TechLead duyệt trước khi code.
- **Gate 2 — Docs update review:** Thay đổi tại `docs/specs/` và `docs/ARCHITECTURE.md` phải được TechLead duyệt trước khi merge.

### 8.3 Front matter của tasks.md

```md
---
feature: {{TICKET_PREFIX}}-0000
service: {{service-key}}
status: in_progress
owner: AI
updated_at: {{YYYY-MM-DD}}
---
```

---

## 9. Rule index [REQUIRED]

| Rule file | Khi nào chạy | Input | Output |
|---|---|---|---|
| `docs/rules/init-docs.md` | Khởi tạo hoặc đồng bộ lại toàn bộ docs | Mã nguồn toàn bộ các service | `ARCHITECTURE.md`, `DESIGN.md`, `specs/*.md` |
| `docs/rules/create-plan.md` | Đã có `expect.md` | `expect.md` + base docs | `plan.md`, `tasks.md` |
| `docs/rules/implement-task.md` | Plan đã duyệt (Gate 1) | `tasks.md` | Code + `report.md` + `deploy.md` + docs diff |
| `docs/rules/create-testcase.md` | Sau plan, trước khi code | `expect.md` | `testcase.md` |

---

## 10. Service quick rules [REQUIRED]

### 10.1 Layer Read Order (`{{LAYER_READ_ORDER}}`)
<!-- HOWTO: Khai báo thứ tự đọc code theo từng loại framework/techstack có trong dự án -->
- **Spring Boot (Java):** `controller` / `grpc` → `service` → `repository`/`dao` → `entity`/`model` → `dto` → `config`
- **Node.js / Express / NestJS:** `controller` / `resolver` → `service` → `repository` / `entity` → `dto` / `interface` → `config`
- **React (TypeScript/JavaScript):** `router` → `view`/`page` → `component` → `store`/`slice`/`thunk` → `api service`
- **Angular (TypeScript):** `routing-module` → `page`/`component` → `service` → `model`
- **Vue (TypeScript/JavaScript):** `router` → `views`/`pages` → `components` → `stores`/`pinia` → `api`

### 10.2 Service Quick Matrix & Verification Commands (`{{VERIFY_COMMANDS}}`)

| Service | Thứ tự đọc source code (`{{LAYER_READ_ORDER}}`) | Lệnh xác thực (`{{VERIFY_COMMANDS}}`) | Ràng buộc kỹ thuật |
|---|---|---|---|
| `{{service-key-1}}` | `{{controller}}` → `{{service}}` → `{{repository}}` → `{{model}}` → `{{config}}` | `{{mvn clean test / npm test}}` | {{Ràng buộc kiến trúc, security, không code logic ở controller}} |
| `{{service-key-2}}` | `{{router}}` → `{{views}}` → `{{components}}` → `{{store}}` → `{{api}}` | `{{npm run build / npm test}}` | {{Quy chuẩn UI/UX, xử lý state/error bắt buộc}} |
| `{{service-key-3}}` | `{{grpc/service}}` → `{{worker}}` → `{{client}}` → `{{config}}` | `{{mvn clean test / pytest / go test}}` | {{Ràng buộc về hiệu năng, timeout, transaction}} |

### 10.3 Deploy & release commands (`{{DEPLOY_COMMANDS}}`)

| Service | Build artifact / Image | Kịch bản / Lệnh deploy | Rollback | Hiện trạng CI/CD |
|---|---|---|---|---|
| `{{service-key-1}}` | `{{BUILD_PACKAGE_CMD}}` | `{{DEPLOY_SCRIPT_OR_K8S}}` | `{{ROLLBACK_CMD}}` | {{CI/CD status, ví dụ: GitLab CI / Jenkins / K8s}} |
| `{{service-key-2}}` | `{{BUILD_PACKAGE_CMD}}` | `{{DEPLOY_SCRIPT_OR_K8S}}` | `{{ROLLBACK_CMD}}` | {{CI/CD status}} |
| `{{service-key-3}}` | `{{BUILD_PACKAGE_CMD}}` | `{{DEPLOY_SCRIPT_OR_K8S}}` | `{{ROLLBACK_CMD}}` | {{CI/CD status}} |

*Ghi chú:* Xem catalog lệnh chi tiết tại `docs/COMMANDS.md`.
---
## 11. Agent working rules [REQUIRED]

### 11.1 Project Configuration Defaults
- **DB docs path (`{{DB_DOCS_PATH}}`):** `docs/database/` (nếu có, snapshot, migration Liquibase/Flyway/SQL script tại repo tương ứng).
- **Impact tool (`{{IMPACT_TOOL}}`):** `none` (hoặc tên công cụ phân tích impact nếu có; mặc định sử dụng git diff và source tracing theo `{{LAYER_READ_ORDER}}`).
- **I18N requirement (`{{I18N_REQUIRED}}`):** `{{false | true}}` (mặc định ngôn ngữ chính, chỉ bật `true` nếu hệ thống yêu cầu đa ngôn ngữ bắt buộc).
- **Integration surfaces (`{{INTEGRATION_SURFACES}}`):**
  - {{Giao tiếp RPC/Protobuf, ví dụ: gRPC Protobuf contracts tại `*/src/main/resources/proto/*.proto`}}
  - {{REST APIs, ví dụ: REST API endpoints / OpenAPI specs}}
  - {{Message Broker events / topic schema}}
  - {{Giao thức tích hợp bên thứ ba / External integrations}}
- **Status vocabulary (`{{STATUS_VOCABULARY}}`):** `draft` → `plan-review` → `approved` → `in_progress` → `testing` → `done` (`blocked` / `cancelled`)
- **Task format (`{{TASK_FORMAT}}`):** `checklist`

### 11.2 Phạm vi và an toàn
- Không triển khai bất kỳ tính năng nào ngoài phạm vi đã được duyệt trong `expect.md` / `plan.md` / `tasks.md`.
- Cập nhật liên tục trạng thái trong `tasks.md` khi tiến hành công việc.
- `report.md` phải phản ánh file thay đổi thực tế và kết quả test thực tế (`{{REPORT_EVIDENCE}}`).
- Tuyệt đối không commit hoặc ghi secrets, API keys, password, certificate private key vào code hoặc tài liệu.
- Không chỉnh sửa file build artifact (`dist/`, `target/`, `node_modules/`, `build/`).
- **Dependency policy (`{{DEPENDENCY_POLICY}}`):** {{Quy định thêm thư viện mới, ví dụ: Không tự ý thêm dependency mới nếu chưa được phê duyệt tại Gate 1}}.
- **Forbidden changes (`{{FORBIDDEN_CHANGES}}`):** {{Các thay đổi bắt buộc phải dừng lại xin phê duyệt lại, ví dụ: Thay đổi API/Protobuf public contract, DB schema, RBAC/Security}}.
- **Deploy triggers (`{{DEPLOY_TRIGGERS}}`):** {{Các loại thay đổi bắt buộc tạo deploy.md, ví dụ: DB migration, cấu hình/env, dependency mới, scheduled job, contract}}.
- **Mockable integrations (`{{MOCKABLE_INTEGRATIONS}}`):** {{Danh sách dịch vụ được phép mock ở local, ví dụ: Gateway, Payment, Third-party APIs}}.

### 11.3 Quy chuẩn code (`{{CODE_STYLE_RULES}}`)
- Tuân thủ cấu trúc phân tầng: Controller/Handler → Service/Business Engine → Repository/Client Adapter.
- Thứ tự implement files trong task (`{{IMPLEMENT_ORDER}}`):
  - Backend: Entity/Migration/DTO → Repository → Service → Controller/gRPC Handler → Config/Test
  - Frontend: Types/Models → API Service → Store/State → Components → Pages/Routes
- Không đặt logic xử lý nghiệp vụ tại tầng Controller/View.
- Mọi file tạo mới phải ở định dạng **UTF-8 without BOM**.
- Phản hồi và comment code bằng **{{Vietnamese | English}}**.

### 11.4 Common impact zones (`{{COMMON_IMPACT_ZONES}}`)

| Thay đổi (Change X) | Ảnh hưởng tới (Affects Y) | Mức độ rủi ro | Hành động bắt buộc |
|---|---|---|---|
| {{Thay đổi giao tiếp API/Protobuf/RPC}} | {{Tất cả client và service phụ thuộc}} | **CAO (HIGH)** | {{Cập nhật đồng bộ client SDK/contract, kiểm tra tương thích ngược}} |
| {{Thay đổi schema/cấu trúc dữ liệu core}} | {{Báo cáo, luồng xử lý giao dịch chính}} | **CAO (HIGH)** | {{Tạo migration script, đánh giá dữ liệu cũ}} |
| {{Thay đổi cấu hình auth/security}} | {{Luồng đăng nhập và xác thực người dùng}} | **CAO (HIGH)** | {{Test kỹ lưỡng các scenario phân quyền và token}} |
---

## 12. Project skills [OPTIONAL]

| Tình huống | Kỹ năng (`docs/skills/`) |
|---|---|
| Khởi tạo hoặc cập nhật tài liệu toàn hệ thống | `docs/skills/init-docs/SKILL.md` |
| Tạo kế hoạch kỹ thuật cho ticket mới | `docs/skills/create-plan/SKILL.md` |
| Thực thi task và viết mã nguồn | `docs/skills/implement-task/SKILL.md` |
| Tạo kịch bản kiểm thử từ yêu cầu | `docs/skills/create-testcase/SKILL.md` |

---

## 13. Git rules [REQUIRED] (`{{BRANCH_RULE}}`, `{{COMMIT_RULE}}`)

### 13.1 Branch convention (`{{BRANCH_RULE}}`)
- Tên branch: `feature/{{TICKET_PREFIX}}-<TICKET-NUMBER>-<slug>` hoặc `feature/{{TICKET_PREFIX}}-<TICKET-NUMBER>` (ví dụ: `feature/{{TICKET_PREFIX}}-1024-user-auth` hoặc `feature/{{TICKET_PREFIX}}-1024`) — **đồng nhất trên tất cả các repo tham gia**.
- Kiểm tra branch trước khi làm việc: `git status`.
- Tuyệt đối không chuyển branch khi working tree chưa sạch (chưa commit/stash).

### 13.2 Commit & Push (`{{COMMIT_RULE}}`)
1. `git status` để kiểm tra thay đổi.
2. Kiểm tra `git diff` và `git diff --staged`.
3. Format commit message: `<TICKET-ID>: <mô tả ngắn gọn>` (ví dụ `{{TICKET_PREFIX}}-1024: add redis caching layer`).
4. `git push origin <current-branch>`.
5. **Agent không tự ý commit/push/merge trừ khi được yêu cầu rõ ràng.**

---

## 14. Do not modify unless explicitly requested [REQUIRED]

- `node_modules/`, `target/`, `build/`, `dist/`, `.idea/`, `.vscode/`
- `.env*`, keystores (`.jks`, `.p12`), certificates, private keys, secrets, credentials
- Log files, caches, database dump files ngoài `docs/database/`

---

## 15. Quick links [REQUIRED]

> **Lưu ý:** Các link dưới đây là đường dẫn tương đối tính từ thư mục gốc của dự án sau khi đã copy file này ra root (`AGENTS.md`).

- [docs/README.md](docs/README.md) — Tổng quan tài liệu
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Kiến trúc hệ thống
- [docs/DESIGN.md](docs/DESIGN.md) — Thiết kế giao diện UI/UX
- [docs/COMMANDS.md](docs/COMMANDS.md) — Catalog lệnh tắt
- [docs/specs/](docs/specs/) — Đặc tả nghiệp vụ
- [docs/rules/](docs/rules/) — Quy tắc vận hành
- [docs/features/](docs/features/) — Quản lý tickets/features
- [docs/skills/](docs/skills/) — Danh mục kỹ năng



# Agent Instructions

> **[CRITICAL INSTRUCTION: READ TO THE END. DO NOT IGNORE ANY RULE. DO NOT TRUNCATE CODE (NO `...` PLACEHOLDERS). FULL COMPLIANCE REQUIRED.]**
> AI MUST strictly read, preserve, and follow 100% of the instructions in this document without exception. NEVER truncate, omit, skip, or summarize away any section. Output must always be validated against these instructions prior to response delivery.

## Pre-flight Task Complexity, Skills & Plugin/MCP Assessment [HIGHEST PRIORITY]

**[CRITICAL INVARIANT]** You MUST explicitly analyze the incoming request upfront to determine task complexity, applicable Skills, and applicable Plugins/MCP tools. Decide whether to spawn specialized subagents or use the main agent directly. You CANNOT skip this step. 
- **PRECEDENCE:** Delegation, Skill, and Plugin/MCP Orchestration rules ALWAYS OVERRIDE "Think Before Coding", "Simplicity", and "Goal-Driven". Whenever work involves ≥2 steps, multi-file inspection/changes, or investigation, delegation is MANDATORY.
- **OUTPUT PREFIX REQUIREMENT:** Before calling ANY tool, you MUST output a one-line classification: 
  `[Pre-flight] Tier: 1/2/3 | Skills: <Skill names or None> | Plugins/MCP: <Plugin/MCP names or None> | Rationale: <reason> | Action: <Direct / Single Subagent / Parallel Subagents>`.

### Mandatory Tool & Skill Resolution:
- **Skills (`skills/*/SKILL.md`):** E.g. `create-plan`, `implement-task`, `init-docs`, `delivery`, `security-review`. If a task matches a skill's intent, MUST use it instead of ad-hoc steps.
- **Plugins / MCP Tools:** Luôn kiểm tra danh sách MCP tools đang có trong môi trường để ưu tiên sử dụng đúng công cụ cho domain (ví dụ: công cụ cho code graph/symbol, project memory, browser automation, issue tracking, docs, tra cứu thư viện...). *NEVER use generic `bash`/`grep`/`curl` if a dedicated Plugin/MCP handles the domain.*

Before executing actions or calling tool sequences, classify the incoming task and strictly follow the delegation rules:

1. **Tier 1: Trivial / Direct (Handled directly by Main Agent)**
   - **Scope:** Single-file edit under ≤ 30 diff lines; 1-2 CLI lookups (status, env checks); answering questions/explanations without code changes; reading a single known-path file. Single-step only.
   - **Action:** Main Agent executes directly to minimize latency and handoff overhead.

2. **Tier 2: Moderate / Focused Multi-step (Mandatory Single Subagent Delegation)**
   - **Scope:** Touching 2–3 files in the same module/domain; local bug investigation requiring code tracing; writing or updating specific testcases/specs/docs; any task with 2+ steps on a single file.
   - **Action:** Main Agent MUST NOT execute sequentially. Spawn a dedicated subagent (`scout` for code discovery/tracing, `dely-implementer` or `task` for implementation, `docs-*` for documentation lifecycle).

3. **Tier 3: Complex / Long / Broad / Multi-slice (Mandatory Parallel Multi-Agent Delegation)**
   - **Scope:** Multi-file changes (≥ 3 files); cross-module refactors; migrations; Docker/CI/CD/infra; new feature flows (Spec-Driven / Delivery); broad investigations.
   - **Action:** Main Agent acts strictly as **Dispatcher & Integrator**. Decompose the task into independent slices and spawn ≥ 2 concurrent subagents in a single `tasks[]` batch via the `task` tool. Never serialize independent work.

Default behavioral guidelines for all workspaces.

---

## Think Before Coding

- State key assumptions briefly. Mention multiple interpretations; ask only if ambiguity blocks safe execution.
- For minor ambiguity, state the safest assumption and continue.
- Prefer simpler approaches. Push back on unnecessary complexity, risk, or unrelated work.
- For easy/short tasks: implement directly and verify fast. No plan file (ONLY if strictly qualified under Tier 1 above. Delegation rules supersede this).

Create/update a task-tracking `.md` inside the workspace only for large, risky, multi-session, dependent multi-step tasks, or work whose progress must survive context loss. Include task list, status, verification, blockers, final result; update status after each step.

---

## Simplicity & Surgical Changes (Subordinate to Delegation Rules)

Minimum code that solves the request. Touch only what is required. Clean up only your own mess.

- Execute only the request; suggest improvements afterward.
- No unrequested features, abstractions, configurability, or impossible-case error handling.
- Mention unrelated dead code but don't delete it. Remove only code your change made unused.
- If overcomplicated, simplify it.

---

## Goal-Driven Execution (Subordinate to Delegation Rules)

Define success criteria and verify. Do not stop mid-task unless blocked by safety/destructive-risk confirmation, missing permissions, critical missing files, or tool failures. If requirements have minor ambiguities or missing non-critical parameters, choose the safest standard assumption, log it, and proceed to completion. Ask ONLY when the requirement is fundamentally contradictory or blocking safe execution.

---

## Communication

- Don't ask confirmation for obvious non-destructive steps; ask only when ambiguity blocks execution.
- Suggest improvements after completing the request.

---

## Agents, Sub-Agents, and Multi-Agent Orchestration

### Anti-patterns & Hard Invariants
- NEVER have the Main Agent iteratively inspect > 1 file sequentially when exploring or understanding a codebase; delegate to `scout`.
- NEVER have the Main Agent implement multi-file changes directly; ALWAYS partition and delegate to subagents.
- NEVER yield or serialize work when independent chunks can run concurrently in a single `tasks[]` batch.

### Subagent Role Directory
- `scout`: Read-only rapid exploration, codebase mapping, cross-directory search, and handoff summaries.
- `reviewer`: Code review, quality evaluation, architectural consistency, and convention compliance.
- `security-reviewer`: Read-only security audit, vulnerability scanning, and risk assessment.
- `architect`: System architecture design, implementation planning, and module decomposition.
- `plan-reviewer`: Independent review and gate approval of technical plans (`plan.md`).
- `sonic`: High-speed, focused mechanical edits and quick transformations.
- `dely-implementer`: Autonomous coding, TDD, task implementation following design contracts.
- `dely-reviewer`: Independent code review, reproduction of test gates, and counterexample evaluation.
- `docs-reader` / `docs-fact-check` / `docs-reviewer` / `docs-update` / `docs-init`: Full lifecycle management of Spec-Driven documentation.

### Multi-Agent Dynamic Spawning & Concurrency
- **Eager Parallel Decomposition:** When facing multi-file analysis, cross-subsystem investigations, broad reviews, or independent implementation chunks, dynamically spawn multiple subagents in parallel via the `task` tool using a single `tasks[]` batch instead of executing sequentially.
- **Workload Partitioning:** Fan out work across specialized agents based on task domains (e.g., spawn several `scout` agents scoped to different directories/modules, alongside a `reviewer` or `docs-*` agent).
- **Avoid Bottlenecks:** Do not serialize independent exploration or tasks that can be delegated to ≥ 2 concurrent workers. Coordinate shared resources or downstream integration only after parallel batch completion.

### Advisor Role Guidelines
- When acting as **Advisor**: Provide passive analysis, architectural critique, edge-case risks, and suggestions only. NEVER issue mutation tool calls (`write`, `edit`, `bash` state changes). Output purely analytical feedback.

## Workspace

Workspace permissions: Autonomous by default for all task-scoped reads, writes, and edits. No confirmation required for standard code changes. Explicit confirmation is required ONLY for Risky Operations: destructive actions (data loss, force push, dropping tables/branches, hard resets, deleting production assets).

---

## Git Worktrees

Allowed only when requested or for approved parallel chunks. Use the exact task/chunk name. No parallel worktree agents unless requested. Delete each worktree only after completion, verification, and merge; leave none orphaned.

---

## Tools

### MCP Routing & Strict Enforcement (Hard Constraints)
- **Strict OUTPUT PREFIX Verification:** You MUST NEVER issue a tool call without first outputting the `[Pre-flight]` prefix.
- **MCP Route & Priority (Hard Constraints):** BẮT BUỘC ưu tiên dùng các MCP tools chuyên dụng tương ứng với domain của task (ví dụ: dùng MCP tool về code graph thay vì `grep`, dùng MCP tool về browser thay vì `curl`/`wget`, dùng MCP tool về database/memory thay vì tra cứu file thủ công). **CẤM** lạm dụng `bash` (grep, find, awk, curl) hoặc native tools khi trong danh sách công cụ đã có MCP tool phục vụ chức năng đó.
- **Fallback Rule:** Chỉ dùng bash/native tools thay thế khi MCP báo lỗi không khả dụng hoặc user bắt buộc. Lạm dụng bash/grep thay cho MCP là vi phạm nghiêm trọng.

- Use local search/read/terminal and external docs for third-party integrations as needed.
- Don't assume optional tools/services exist; fall back gracefully and report limitations.
- Prefer focused searches/ranges/summaries over entire massive logs or files.

---

## Windows Shell

Prefer PowerShell 7 (`pwsh`); use other shells only when required. Run heavy tasks sequentially in small steps. Set timeouts for long commands; inspect or stop safely if exceeded.

---

## Memorix: Memory and Safety Gate

**Mandatory session bootstrap:** At the start of every new session, initialize Memorix by calling `memorix_session_start` (with `projectRoot` if available) or `memorix_project_context` to load active workspace context. Keep Memorix instructions active across all session turns.

**On-demand usage:** After initialization, use Memorix retrieval/storage tools selectively — for non-trivial coding, debugging, architecture decisions, past context queries, or continuing previous work. Simple single-turn queries do not require full memory searches.

### Memory Autopilot

Default first step for non-trivial coding work (can be done during pre-flight, but does NOT bypass delegation): call `memorix_project_context` with the user's task before progress files, dev-log reads, ad-hoc file reads, or git archaeology. Memorix chooses a task-lensed brief (bugfix, feature, release, onboarding, refactor, docs, test, or general). When continuing prior work, the brief includes a bounded prior-work projection. Treat its "Start here" files as the first workspace files to inspect.

Continuation fallback: when the user asks to continue/resume/take over prior work and MCP cannot be called, run exactly one CLI brief with the user's real task before inspecting files: `memorix resume "<task>" --fallback --brief-json`. For a new task: `memorix context "<task>" --fallback --brief-json`. If that fails, report and proceed normally.

After a successful brief, it is the default retrieval boundary. Use `memorix_context_pack`, `memorix_search`, or `memorix_detail` only when the brief lacks a specific reference or fact needed for the task, or when the user explicitly asks for deeper history.

### When to Search Memory

Use `memorix_graph_context` for explicit memory graph questions or broad graph overview when the autopilot brief is insufficient.

Use `memorix_search` when prior workspace context would help and the brief did not answer the question:
- The user asks about a past decision, bug, or change
- Understanding why something was designed a certain way
- Continuing work from a previous session

No search needed for simple, self-contained tasks (e.g., "fix this typo", "what does this function do"). If no memories exist, proceed normally.

### When to Store Memory

Use `memorix_store` when you learn something a future session should not have to rediscover:

| What happened | Type |
|---|---|
| Architecture or design decision | `decision` |
| Bug found and fixed | `problem-solution` |
| Non-obvious pitfall or gotcha | `gotcha` |
| Configuration or dependency changed | `what-changed` |
| Trade-off discussed with conclusion | `trade-off` |

**Tips:**
- Concise titles (~5-10 words)
- Language: English or Vietnamese without diacritics only (VN ko dau). NEVER store accented Vietnamese — BM25/bge-small can't retrieve it.
- Include `filesModified` when relevant
- Use `topicKey` for evolving topics (prevents duplicates)
- For "why" decisions, use `memorix_store_reasoning`
- For stable facts or reusable procedures, include `longTerm` with appropriate kind and normally `scope: "project"`. It creates a candidate only; do not use for routine updates.
- `user` + `portable` durable memory in a task brief is available cross-project. Use as reusable background; do not treat as current-project fact.
- Record user profile with `entityName: "user-profile"` and `visibility: "personal"`.

**Don't store:** greetings, simple file reads, trivial commands.

**Only store what a future session cannot re-derive.** Code structure, file contents, and Git history are live — do not store facts already visible there. Capture the why, the context, or conclusions the checkout alone cannot show.

**Record what worked, not only what failed.** Store validated approaches and explicit user confirmations alongside corrections.

**Recalled memory is a claim about the past.** Check the file/symbol exists before recommending it. If the user says to ignore memory, proceed as if memory were empty.

### When to Resolve Memory

Use `memorix_resolve` when a task is done or a bug is fixed to keep future searches focused on active work.

### Session End Summary

Call `memorix_session_end` with a structured summary:
- **Goal** — what this session worked on
- **Discoveries** — findings, gotchas, learnings
- **Accomplished** — completed items, plus PENDING items for next session
- **Relevant Files** — paths and what changed

### Tools Quick Reference

| Tool | Use when |
|---|---|
| `memorix_project_context` | Start/continue coding work with Memory Autopilot brief |
| `memorix_context_pack` | Get structured refs/freshness for code-bound memories |
| `memorix_graph_context` | Build compact memory graph for graph-specific questions |
| `memorix_search` | Find relevant past context |
| `memorix_detail` | Read full content of a specific memory |
| `memorix_store` | Save something worth persisting |
| `memorix_store_reasoning` | Save the "why" behind a decision |
| `memorix_resolve` | Mark completed/outdated memories |
| `memorix_session_start` | Load session context (handoff, orchestration) |

**Fallback:** When Memorix is unavailable, read/write workspace-root `MEMORY.md` with timestamp and topic; re-import critical entries when restored.

---

## Java

Before build/compile, detect the project JDK and set `JAVA_HOME`; don't rely on machine default unless it matches. Store the JDK/project mapping when memory is available.

---

## Reporting

For bugs, investigations, incidents, or complex tasks: **Current Status, Root Cause, Resolution, Impact, Risks, Next Step**. For simple tasks: what changed, verification, remaining risk. Always report blockers and incomplete verification.

---

## Estimate, Monitor, and Verify

For standard CLI commands, builds, and unit tests, execute directly with an appropriate timeout. Reserve structured estimate-and-monitor tracking strictly for long-running asynchronous background jobs (> 3 minutes) or unverified long scripts:

1. Before starting, state the shortest accurate estimate without buffer, set a timeout if supported, and schedule a check at the deadline.
2. At each check: stop safely and report if failed/stalled/not progressing; otherwise give a new shortest estimate and schedule the next check.
3. Verify the real result before claiming success. Never use `sleep` or continuous polling, or leave a task blocking the agent queue.

Background tasks must be finite and non-interactive. Commands that stay open or run continuously (servers, watchers, log streams) must run in a separate system terminal, never an agent background task.



# Global Rules

> **[CRITICAL INSTRUCTION: READ TO THE END. DO NOT IGNORE ANY RULE. DO NOT TRUNCATE CODE (NO `...` PLACEHOLDERS). FULL COMPLIANCE REQUIRED.]**
> AI MUST strictly read, preserve, and follow 100% of the rules in this document without exception. NEVER truncate, omit, skip, or summarize away any rule. Output must always be validated against these rules prior to response delivery.
> **QUY TẮC TIÊN QUYẾT Ở ĐẦU (MANDATORY PREREQUISITE):** TẤT CẢ các lệnh xoá file/thư mục BẮT BUỘC phải dùng cách di chuyển nó vào thùng rác (Trash / Recycle Bin), TUYỆT ĐỐI KHÔNG ĐƯỢC xoá luôn/xóa vĩnh viễn.

## 0. PRECEDENCE, DELEGATION, SKILLS & PLUGINS/MCP [MANDATORY PRE-FLIGHT — NEVER SKIP]
- **PRECEDENCE RULE:** Delegation, Skill, and Plugin/MCP Orchestration rules ALWAYS OVERRIDE "Think Before Coding", "Simplicity", and "Goal-Driven". Whenever a task involves ≥2 steps, multi-file scope, or investigation, delegation is MANDATORY. "Simplicity" and "Goal-Driven" apply *within* the subagent's scope, NOT as an excuse for the Main Agent to do everything directly.
- **OUTPUT PREFIX (MANDATORY BEFORE ANY TOOL CALL):** 
  The Main Agent MUST output a reasoning line before calling ANY tool:
  `[Pre-flight] Tier: 1/2/3 | Skills: <Skill name(s) or None> | Plugins/MCP: <Plugin/MCP tool(s) or None> | Rationale: <reason> | Action: <Direct / Single Subagent / Parallel Subagents>`
- **Mandatory Skills Resolution:** Scan and apply matching skills from `skills/*/SKILL.md` (e.g. `create-plan`, `implement-task`, `init-docs`, `delivery`, `security-review`, `sql-*`, `java-*`, `poka-yoke`...). Never invent ad-hoc procedures when an established skill exists.
- **Mandatory Plugins / MCP Tools Resolution:** Route domain-specific requests to specialized MCP tools instead of manual CLI/bash/grep. Luôn ưu tiên dùng các MCP server hiện có trong hệ thống (ví dụ: công cụ chuyên dụng cho code graph, project memory, browser automation, v.v. - tùy thuộc vào danh sách tools đang được cấp) thay vì tự xử lý bằng các lệnh shell cơ bản.
- **Delegation logic:**
  - Prefer delegating to specialized subagents (`scout`, `task`, `reviewer`, `docs-*`, `dely-*`) in parallel batches via the `task` tool whenever work has 2+ steps, multi-file scope, or distinct inspection/implementation slices.
  - Do not sequentially inspect > 1 file or serialize independent tasks in the main agent. Fan out concurrently to minimize latency, ensure accuracy, and save main context window.
  - Main agent acts primarily as Dispatcher & Integrator.

## 1. Global Rules
- Always respond in Vietnamese (except code identifiers, error strings, shell commands, URLs).
- Never commit, branch, or open PRs unless explicitly requested.
- **QUY TẮC TIÊN QUYẾT (MANDATORY):** TẤT CẢ các lệnh xoá file/thư mục BẮT BUỘC phải dùng cách di chuyển nó vào thùng rác, KHÔNG ĐƯỢC xoá luôn. Never permanently delete user files. Clean temporary files only by moving them to the Recycle Bin / Trash.
- Create/update files only in the current workspace; ask before editing outside it.
- Do not stop or downgrade scope/model/agents solely for cost warnings. Continue when technically possible; report platform blocks.
- Disclose failed commands/tests and incomplete verification. Never claim unverified success.
- Do not refactor, reformat, or improve unrelated code. Match project style.
- Every changed line must trace directly to the user's request.
- MANDATORY RULE COMPLIANCE: AI MUST strictly follow ALL rules in AGENTS.md and RULES.md without exception. NEVER skip, omit, or downgrade any rule. ALWAYS verify final output against every applicable rule for compliance before responding.

## 2. MCP Routing & Strict Enforcement
- **Strict OUTPUT PREFIX Verification:** You MUST NEVER issue a tool call without first outputting the `[Pre-flight]` prefix. If you generate a tool call without this prefix, you have violated a core directive.
- **MCP Route & Priority (Hard Constraints):** BẮT BUỘC ưu tiên dùng các MCP tools chuyên dụng tương ứng với domain của task (ví dụ: dùng MCP tool về code graph thay vì `grep`, dùng MCP tool về browser thay vì `curl`/`wget`, dùng MCP tool về database/memory thay vì tra cứu file thủ công). **CẤM** lạm dụng `bash` (grep, find, awk, curl) hoặc native tools khi trong danh sách công cụ đã có MCP tool phục vụ chức năng đó.
- **Fallback Rule:** Chỉ được dùng bash/native tools khi MCP tool tương ứng báo lỗi không khả dụng (connection refused, not configured) HOẶC user rõ ràng yêu cầu dùng bash. Trừ khi đó, lạm dụng bash/grep thay cho MCP là vi phạm nghiêm trọng.
