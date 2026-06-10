#  Observability: SLO/SLI, OpenTelemetry & Multi-Window Burn Rate Alerts

> **Nguồn tham khảo chính:**
> - [Google SRE Book — Chapter 4: Service Level Objectives](https://sre.google/sre-book/service-level-objectives/)
> - [SRE Workbook — Chapter 2: Implementing SLOs](https://sre.google/workbook/implementing-slos/)
> - [SRE Workbook — Chapter 5: Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/)
> - [OpenTelemetry Concepts & Instrumentation](https://opentelemetry.io/docs/concepts/)
> - [Prometheus Docs](https://prometheus.io/docs) · [Grafana Docs](https://grafana.com/docs/grafana/latest) · [Loki Docs](https://grafana.com/docs/loki/latest)

---

## 1. Tổng Quan Về Observability

Observability là khả năng hiểu được trạng thái bên trong của hệ thống thông qua các tín hiệu đầu ra. OpenTelemetry phân loại các tín hiệu này thành các **signals** độc lập, mỗi signal là một tập hợp chức năng riêng biệt với vòng đời và mức độ ổn định riêng.

Các signals hiện tại theo OTel spec: **Traces**, **Metrics**, **Logs**, **Baggage**, và **Profiles** (đang nổi lên như signal thứ tư/năm).

```txt
Application / Service
      │
      ├─── Metrics ────────► OTel Collector ──► Prometheus ──► Grafana
      │
      ├─── Logs ───────────► OTel Collector ──► Loki ────────► Grafana
      │
      └─── Traces ─────────► OTel Collector ──► Jaeger / Tempo
```

---

## 2. SLI, SLO, SLA — Nền Tảng Của Độ Tin Cậy

*(Google SRE Book, Chapter 4)*

### 2.1. Định nghĩa

| Khái niệm | Tên đầy đủ | Định nghĩa (theo SRE Book) |
|---|---|---|
| **SLI** | Service Level Indicator | Một phép đo định lượng cụ thể về chất lượng dịch vụ đang cung cấp |
| **SLO** | Service Level Objective | Giá trị mục tiêu hoặc dải giá trị cho một SLI: `SLI ≤ target` hoặc `lower ≤ SLI ≤ upper` |
| **SLA** | Service Level Agreement | Hợp đồng tường minh hoặc ngầm định với người dùng, kèm hậu quả nếu SLO không đạt |

> 💡 **Cách phân biệt SLO và SLA (theo SRE Book):** Hỏi *"Điều gì xảy ra nếu SLO không được đáp ứng?"* — Nếu không có hậu quả tường minh, gần như chắc chắn đó là SLO, không phải SLA.

### 2.2. SLI — Những gì thực sự quan trọng

SRE Book phân loại SLI theo loại hệ thống:

- **User-facing serving systems** (web, API) — quan tâm đến: **availability**, **latency**, **throughput**
- **Storage systems** — quan tâm đến: **latency**, **availability**, **durability**
- **Big data / pipeline systems** — quan tâm đến: **throughput**, **end-to-end latency**

SRE Workbook khuyến nghị mô hình SLI theo tỷ lệ (ratio):

```
SLI = số good events / tổng số events
```

Ví dụ cụ thể từ Workbook:
- Số HTTP request thành công / tổng số HTTP request
- Số gRPC call hoàn thành trong < 100ms / tổng số gRPC request
- Số "good user minutes" / tổng số user minutes

Dạng tỷ lệ này có lợi vì: SLI luôn nằm trong khoảng 0%–100%, dễ tính error budget, và tooling có thể chuẩn hóa theo cùng một input (numerator, denominator, threshold).

### 2.3. Error Budget — Ngân Sách Lỗi

```
Error Budget = 100% − SLO target
Ví dụ: SLO = 99.9% → Error Budget = 0.1% = 43.8 phút/tháng
```

SRE Workbook nhấn mạnh rằng error budget chỉ hoạt động đúng khi:

- Tất cả stakeholders đã đồng ý SLO là phù hợp với sản phẩm.
- Team chịu trách nhiệm xác nhận SLO có thể đạt được trong điều kiện bình thường.
- Tổ chức cam kết dùng error budget để đưa ra quyết định, được hình thức hóa thành **error budget policy**.
- Có quy trình để liên tục cải tiến SLO.

Nếu không có đủ bốn điều kiện này, SLO chỉ là một KPI báo cáo, không phải công cụ ra quyết định.

> ⚠️ **Từ SRE Book:** 100% availability là sai mục tiêu. Nguồn gây outage lớn nhất chính là thay đổi (deploy tính năng mới, patch bảo mật, scaling). SLO 100% đồng nghĩa với không bao giờ được cải tiến hệ thống.

---

## 3. SLI Methodology

### 3.1. Availability SLI

```
Availability = good requests / total requests
             = 1 − error rate
```

**Prometheus query:**
```promql
sum(rate(http_requests_total{status!~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))
```

**Bảng ngưỡng SLO phổ biến (từ SRE Book Appendix A):**

| SLO | Downtime/tháng | Downtime/năm |
|---|---|---|
| 99% | 7.20 giờ | 3.65 ngày |
| 99.9% | 43.8 phút | 8.77 giờ |
| 99.95% | 21.9 phút | 4.38 giờ |
| 99.99% | 4.38 phút | 52.6 phút |
| 99.999% | 26.3 giây | 5.26 phút |

### 3.2. Latency SLI

```
Latency SLI = requests hoàn thành trong < threshold / tổng requests
```

**Prometheus query:**
```promql
sum(rate(http_request_duration_seconds_bucket{le="0.3"}[5m]))
/
sum(rate(http_request_duration_seconds_count[5m]))
```

> ⚠️ **Từ SRE Book:** Không dùng *mean latency* làm SLI vì mean bị outlier kéo lệch và che giấu tail latency. Dùng **percentile** (P95, P99) để phản ánh trải nghiệm của đa số người dùng thực tế.

### 3.3. SLI Specification vs SLI Implementation

*(SRE Workbook, Chapter 2)*

Một **SLI specification** (đặc tả) có thể có nhiều **SLI implementation** (triển khai) khác nhau:

- Specification: *"Tỷ lệ homepage request load trong < 100ms"*
- Implementation A: Đo từ server log — bỏ sót request không đến được backend.
- Implementation B: Đo từ prober chạy browser trong VM — bắt lỗi network nhưng bỏ sót lỗi subset user.
- Implementation C: Đo từ JavaScript trên homepage, report về telemetry service — chính xác nhất nhưng cần infrastructure riêng.

Lần đầu triển khai không cần phải hoàn hảo — quan trọng là có measurement và feedback loop để cải tiến liên tục.

---

## 4. OpenTelemetry (OTel) — Chuẩn Hóa Observability

*(opentelemetry.io/docs/concepts/)*

### 4.1. OTel là gì?

OpenTelemetry là CNCF project, ra đời từ việc hợp nhất OpenTracing và OpenCensus — hai project giải quyết cùng một vấn đề: thiếu chuẩn chung để instrument code và gửi telemetry data đến observability backend.

Mục tiêu cốt lõi: **instrument một lần, thay đổi backend bằng config** — không cần viết lại code khi đổi từ Jaeger sang Tempo, hay từ Prometheus sang Datadog.

OTel client được tổ chức xung quanh **signals**. Mỗi signal là một tập hợp chức năng độc lập với lifecycle riêng. Signals hiện tại: Traces, Metrics, Logs, Baggage, Profiles.

### 4.2. Kiến trúc OTel

```txt
┌──────────────────────────────────────────────┐
│              Application Code                │
│                                              │
│   OTel SDK                                   │
│   ┌─────────┐  ┌─────────┐  ┌─────────────┐  │
│   │ Metrics │  │  Logs   │  │   Traces    │  │
│   └────┬────┘  └────┬────┘  └──────┬──────┘  │
└────────┼────────────┼──────────────┼──────────┘
         └────────────┴──────────────┘
                      │  OTLP (gRPC / HTTP)
                      ▼
         ┌────────────────────────┐
         │     OTel Collector     │
         │  Receiver → Processor  │
         │       → Exporter       │
         └────────────────────────┘
                      │
           ┌──────────┼──────────┐
           ▼          ▼          ▼
       Prometheus   Jaeger /   Loki
       (metrics)    Tempo     (logs)
                   (traces)
```

### 4.3. Hai kiểu Instrumentation

Theo OTel docs, có hai cách chính để instrument:

**Zero-code (auto-instrumentation)** — không cần sửa code:
- Tự động patch thư viện phổ biến (HTTP client, DB driver, gRPC...).
- Cung cấp thông tin về *edges* của application — những gì xảy ra ở ranh giới.
- Phù hợp khi bắt đầu, hoặc khi không thể sửa application.

**Code-based (manual instrumentation)** — dùng OTel API/SDK:
- Cho phép insight sâu hơn, telemetry phong phú hơn từ chính application.
- Bổ sung cho zero-code, không thay thế.
- Phù hợp với business logic phức tạp, cần độ chi tiết cao.

> Lưu ý quan trọng từ OTel spec: **Instrumentation authors MUST NOT directly reference any SDK package** — chỉ dùng API. SDK là concern của người deploy, không phải người viết library.

**Ví dụ Python (manual trace):**
```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

provider = TracerProvider()
exporter = OTLPSpanExporter(endpoint="http://otel-collector:4317")
provider.add_span_processor(BatchSpanProcessor(exporter))
trace.set_tracer_provider(provider)

tracer = trace.get_tracer("my-service")

with tracer.start_as_current_span("process-order") as span:
    span.set_attribute("order.id", order_id)
    span.set_attribute("order.amount", amount)
    process(order_id)
```

### 4.4. OTel Collector

Collector là **proxy/aggregator độc lập** nhận data từ SDK và forward tới backend. Không bắt buộc về mặt kỹ thuật (SDK có thể export thẳng), nhưng là best practice trong production:

- Tách application khỏi backend — đổi backend không cần redeploy app.
- Batching, retry — tránh mất data khi backend tạm thời lỗi.
- Sampling & filtering — giảm noise và chi phí lưu trữ.
- Enrichment — tự động thêm metadata (cluster, region...) vào mọi span.

**Collector pipeline config:**
```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 5s
    send_batch_size: 1000
  memory_limiter:
    limit_mib: 512

exporters:
  prometheus:
    endpoint: "0.0.0.0:8889"
  loki:
    endpoint: http://loki:3100/loki/api/v1/push
  otlp/jaeger:
    endpoint: jaeger:4317

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp/jaeger]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [prometheus]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [loki]
```

---

## 5. Stack: Prometheus + Grafana + Loki

### 5.1. Prometheus

Time-series database chuyên biệt cho metrics, hoạt động theo mô hình **pull** (scrape từ target).

**Bốn metric types:**
- `Counter` — Chỉ tăng. Dùng cho: số request, số lỗi. Ví dụ: `http_requests_total`
- `Gauge` — Tăng/giảm tự do. Dùng cho: memory, active connections. Ví dụ: `go_goroutines`
- `Histogram` — Phân phối vào buckets. Dùng cho: latency, request size. Ví dụ: `http_request_duration_seconds`
- `Summary` — Tính percentile phía client (ít dùng hơn Histogram vì khó aggregate across instances).

**prometheus.yml cơ bản:**
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['otel-collector:8889']

rule_files:
  - "rules/*.yaml"

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']
```

### 5.2. Grafana

Platform visualization kết nối nhiều data source (Prometheus, Loki, Tempo...).

**SLO Dashboard — các panel cần có:**
```
┌─────────────────────────────────────────────────────┐
│  Availability (30d) [Stat]  │  Error Budget [Gauge]  │
├─────────────────────────────────────────────────────┤
│  Burn Rate (1h) [Time series]                        │
├─────────────────────────────────────────────────────┤
│  Request Rate & Error Rate [Time series]             │
├─────────────────────────────────────────────────────┤
│  Latency P50 / P95 / P99 [Time series]               │
└─────────────────────────────────────────────────────┘
```

### 5.3. Loki

Log aggregation theo triết lý *"like Prometheus, but for logs"* — lưu trữ theo label thay vì full-text index.

**So sánh Loki vs Elasticsearch:**

| Tiêu chí | Loki | Elasticsearch |
|---|---|---|
| Index | Chỉ label/metadata | Full-text |
| Chi phí lưu trữ | Thấp | Cao |
| Query language | LogQL | Lucene/KQL |
| Full-text search | Hạn chế | Mạnh |
| Tích hợp native | Grafana | Kibana |

**LogQL cơ bản:**
```logql
# Lọc log theo label
{namespace="production", app="api-service"} |= "ERROR"

# Metric query — đếm lỗi theo pod
sum(rate({app="api-service"} |= "ERROR" [1m])) by (pod)

# Parse JSON và lọc theo field
{app="api-service"} | json | status_code >= 500
```

---

## 6. Multi-Window Burn Rate Alert

*(SRE Workbook, Chapter 5 — Alerting on SLOs)*

### 6.1. Bốn tiêu chí đánh giá một alerting strategy

Workbook định nghĩa bốn tiêu chí để đánh giá chiến lược alert:

- **Precision** — Tỷ lệ alert thực sự tương ứng với sự kiện quan trọng (significant event).
- **Recall** — Tỷ lệ sự kiện quan trọng thực sự được phát hiện.
- **Detection time** — Thời gian để gửi notification. Chậm = mất nhiều error budget.
- **Reset time** — Thời gian alert còn firing sau khi vấn đề đã được giải quyết.

### 6.2. Burn Rate là gì?

Burn rate đo **tốc độ tiêu thụ error budget so với tốc độ bình thường** (burn rate = 1).

Từ SRE Workbook Table 5-4:

| Burn rate | Error rate (với SLO 99.9%) | Thời gian hết budget |
|---|---|---|
| 1 | 0.1% | 30 ngày |
| 2 | 0.2% | 15 ngày |
| 10 | 1% | 3 ngày |
| 1,000 | 100% | 43 phút |

### 6.3. Sáu cách Alert — Tiến Trình Từ Đơn Giản Đến Tối Ưu

Workbook trình bày 6 approach theo thứ tự tăng dần độ phức tạp. Ba cách đầu là *nonviable attempts*, ba cách sau là *viable strategies*. Approach 6 là **được khuyến nghị nhất**.

**Approach 1–3 (nonviable — chỉ cần biết lý do tại sao không dùng):**

| Approach | Vấn đề cốt lõi |
|---|---|
| 1: Alert khi error rate > SLO threshold (window 10m) | Precision thấp — 144 alerts/ngày vẫn có thể meet SLO |
| 2: Tăng alert window lên 36h | Reset time rất tệ — alert còn firing 36h sau khi fix xong |
| 3: Dùng `for:` duration thay vì window dài | Recall tệ — spike 100% lỗi mỗi 10 phút có thể không bao giờ trigger |

**Approach 4: Alert on burn rate (viable, nhưng còn hạn chế):**

```yaml
- alert: HighErrorRate
  expr: job:slo_errors_per_request:ratio_rate1h{job="myjob"} > 36 * 0.001
```

Burn rate 36 = tiêu 5% budget trong 1 giờ. Tốt hơn về precision và detection time, nhưng recall vẫn thấp (burn rate 35x không alert nhưng hết budget trong 20.5 giờ).

**Approach 5: Multiple burn rates (viable, gần tối ưu):**

Từ Workbook Table 5-6 — các thông số được Google khuyến nghị:

| Budget consumed | Time window | Burn rate | Notification |
|---|---|---|---|
| 2% | 1 giờ | 14.4 | Page (on-call) |
| 5% | 6 giờ | 6 | Page (on-call) |
| 10% | 3 ngày | 1 | Ticket |

```yaml
expr: (
  job:slo_errors_per_request:ratio_rate1h{job="myjob"} > (14.4 * 0.001)
  or
  job:slo_errors_per_request:ratio_rate6h{job="myjob"} > (6 * 0.001)
)
severity: page

expr: job:slo_errors_per_request:ratio_rate3d{job="myjob"} > 0.001
severity: ticket
```

**Approach 6: Multiwindow, multi-burn-rate (tối ưu nhất — được khuyến nghị):**

### 6.4. Approach 6 Chi Tiết — Multiwindow

Vấn đề của Approach 5: reset time vẫn dài. Alert vẫn firing ngay cả khi error rate đã về bình thường, vì long window (1h, 6h) chứa data cũ.

**Giải pháp:** Thêm một short window để xác nhận budget *vẫn đang* bị burn tại thời điểm hiện tại. Workbook khuyến nghị:

> *"A good guideline is to make the short window 1/12 the duration of the long window."*

```
Short window = Long window / 12

Long window 1h  → Short window = 5m
Long window 6h  → Short window = 30m
```

**Alert chỉ fire khi CẢ HAI window đều vượt ngưỡng** — long window xác nhận burn rate đủ cao, short window xác nhận vấn đề vẫn đang xảy ra (không phải data cũ).

#### Tầng 1 — Fast Burn (Critical / Page on-call)

```
2% error budget consumed in 1h → burn rate 14.4x
Short window: 5m (= 1h / 12)
```

```yaml
- alert: AvailabilityFastBurn
  expr: |
    (
      job:slo_errors_per_request:ratio_rate1h{job="myjob"} > (14.4 * 0.001)
    )
    and
    (
      job:slo_errors_per_request:ratio_rate5m{job="myjob"} > (14.4 * 0.001)
    )
  labels:
    severity: page
    slo: availability
  annotations:
    summary: "Fast burn — 2% error budget at risk within 1h"
    description: >
      Burn rate >14.4x on both 1h and 5m windows.
      At this rate, 2% of monthly error budget will be consumed within 1 hour.
```

#### Tầng 2 — Slow Burn (Warning / Ticket)

```
5% error budget consumed in 6h → burn rate 6x
Short window: 30m (= 6h / 12)
```

```yaml
- alert: AvailabilitySlowBurn
  expr: |
    (
      job:slo_errors_per_request:ratio_rate6h{job="myjob"} > (6 * 0.001)
    )
    and
    (
      job:slo_errors_per_request:ratio_rate30m{job="myjob"} > (6 * 0.001)
    )
  labels:
    severity: ticket
    slo: availability
  annotations:
    summary: "Slow burn — 5% error budget at risk within 6h"
    description: >
      Burn rate >6x on both 6h and 30m windows.
      At this rate, 5% of monthly error budget will be consumed within 6 hours.
```

### 6.5. Bảng Tóm Tắt Multi-Window

| Tier | Budget | Long window | Short window | Burn rate | Notification |
|---|---|---|---|---|---|
| **Fast (Critical)** | 2% / 1h | 1 giờ | 5 phút | 14.4x | Page on-call |
| **Slow (Warning)** | 5% / 6h | 6 giờ | 30 phút | 6x | Ticket |
| **Ticket** | 10% / 3d | 3 ngày | — | 1x | Ticket (no short window needed) |

### 6.6. Latency SLO — Áp Dụng Tương Tự

```yaml
- alert: LatencyFastBurn
  expr: |
    (
      sum(rate(http_request_duration_seconds_bucket{le="0.3"}[1h]))
      / sum(rate(http_request_duration_seconds_count[1h]))
    ) < (1 - 14.4 * 0.001)
    and
    (
      sum(rate(http_request_duration_seconds_bucket{le="0.3"}[5m]))
      / sum(rate(http_request_duration_seconds_count[5m]))
    ) < (1 - 14.4 * 0.001)
  labels:
    severity: page
    slo: latency
```

---

## 7. Bảng So Sánh Các Khái Niệm Dễ Nhầm Lẫn

| Tiêu chí | Khái niệm A | Khái niệm B | Điểm khác biệt |
|---|---|---|---|
| **SLI vs SLO** | SLI: con số đo thực tế | SLO: ngưỡng mục tiêu | SLI là "thermometer", SLO là "desired temperature" |
| **SLO vs SLA** | SLO: mục tiêu nội bộ, không có hậu quả tường minh | SLA: hợp đồng kèm penalty | Hỏi: *"Điều gì xảy ra nếu không đạt?"* |
| **Long window vs Short window** | Long window: xác nhận burn rate đủ cao | Short window: xác nhận vẫn đang burn | Cả hai cùng vi phạm → alert; chỉ long window → có thể là data cũ |
| **Precision vs Recall** | Precision: tỷ lệ alert là thật | Recall: tỷ lệ sự cố được phát hiện | Trade-off cốt lõi khi thiết kế alert |
| **OTel SDK vs Collector** | SDK: instrument app, emit signal | Collector: route, batch, enrich | SDK bắt buộc; Collector best practice cho production |
| **Auto vs Manual instrumentation** | Auto: zero-code, edges của app | Manual: insight sâu vào business logic | Dùng kết hợp cả hai |
| **Prometheus vs Loki** | Prometheus: metrics (số), pull model | Loki: logs (text + label), push model | Khác data model và query language |

---

## 8. Tóm Tắt Nhanh (Quick Reference)

**OTel Stack:**

| Thành phần | Vai trò | Giao thức |
|---|---|---|
| OTel SDK | Instrument app, emit signals | OTLP (gRPC/HTTP) |
| OTel Collector | Route, batch, enrich, sample | OTLP in → multi-protocol out |
| Prometheus | Lưu metrics, evaluate alert rules | PromQL, pull scrape |
| Grafana | Visualize metrics + logs + traces | Multi-datasource |
| Loki | Lưu logs với label index | LogQL, push API |
| Alertmanager | Route & dedup alerts | Webhook, PagerDuty, Slack |

**Multi-Window Burn Rate (SLO 99.9% / 30 ngày):**

| Tier | Budget at risk | Long window | Short window | Burn rate | Action |
|---|---|---|---|---|---|
| **Critical** | 2% trong 1h | 1h | 5m | 14.4x | Page on-call |
| **Warning** | 5% trong 6h | 6h | 30m | 6x | Ticket |
| **Ticket** | 10% trong 3d | 3d | — | 1x | Ticket |

**Burn rate formula:**

```
Burn rate = error_rate_current / (1 − SLO)
Time to exhaustion = SLO_window / burn_rate
Budget consumed = burn_rate × (window_size / SLO_window)
```

---

*Nguồn: Google SRE Book Ch.4, SRE Workbook Ch.2 & Ch.5, opentelemetry.io/docs/concepts — W9 Day D2.*