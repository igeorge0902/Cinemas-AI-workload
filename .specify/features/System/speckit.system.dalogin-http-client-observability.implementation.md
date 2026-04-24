# dalogin Outbound HTTP Client Observability — Implementation Draft

## Purpose
Structured logging for all outbound HTTP calls from `dalogin-quarkus` to downstream services,
using a two-layer minimal-intrusion approach: a JAX-RS `ClientResponseFilter` + one-line START
log per `ServiceClient` method.

## Why Not a CDI Interceptor Here

`ServiceClient` is instantiated with `new ServiceClient(...)` in each servlet — it is not a CDI
bean. A CDI `@AroundInvoke` interceptor therefore cannot intercept its methods. The chosen
alternative keeps code changes minimal:

| Layer | What it covers |
|---|---|
| `ClientCallResponseFilter` | Every response (status, latency, URI) — automatic |
| Inline START log per method | Request dispatch event — one line per method |
| `RequestFilter` DEBUG log | Header injection trace — one location |

---

## Full Call Chain

```
Browser/iOS
    │
    ▼
dalogin Servlet (CheckOut, GetAllPurchases, ManagePurchases, …)
    │  builds authAttributes: uuid, token2, TIME_
    ▼
ServiceClient(baseUrl, request, attributes)
    │  registers RequestFilter + ClientCallResponseFilter
    ▼
RequestFilter.filter()
    │  adds X-Token, Ciphertext (or token2 fallback), uuid, TIME_, Cookies
    ▼
JAX-RS HTTP call  →→→  mbook-1 or mbooks-1
    ▼
ClientCallResponseFilter.filter()
    │  captures URI, method, status, latency
    ▼
Response returned to Servlet → written to browser/iOS
```

---

## Servlet → ServiceClient → Downstream Call Map

| Servlet | HTTP | ServiceClient method | Downstream path |
|---|---|---|---|
| `CheckOut` | GET | `clientToken()` | GET `/mbooks-1/rest/book/payment/clientToken` |
| `CheckOut` | POST | `checkOut()` | POST `/mbooks-1/rest/book/payment/fullcheckout2` |
| `GetAllPurchases` | GET | `callGetPurchases()` | GET `/mbooks-1/rest/book/purchases` |
| `ManagePurchases` | GET | `callGetTickets()` | GET `/mbooks-1/rest/book/purchases/tickets` |
| `ManagePurchases` | POST | `managePurchases()` | POST `/mbooks-1/rest/book/managepurchases` |
| `ManagePurchases` | POST | `deletePurchases()` | POST `/mbooks-1/rest/book/deletepurchases` |
| (internal) | GET | `callGetData()` | GET `/mbook-1/rest/user/{user}/{token1}` |
| (internal) | GET | `callGetDevice()` | GET `/mbook-1/rest/device/{uuid}` |

---

## Layer 1: ClientCallResponseFilter (Example)

Registered in `ServiceClient` constructor alongside `RequestFilter`.
Fires automatically for every call — no per-method changes needed.

```java
public class ClientCallResponseFilter implements ClientResponseFilter {

    private static final Logger LOG = Logger.getLogger("LOG-HTTP-CLIENT");

    @Override
    public void filter(ClientRequestContext req, ClientResponseContext res) throws IOException {
        int status  = res.getStatus();
        String uri  = req.getUri().getPath();
        String method = req.getMethod();
        // latency: set as property in ClientCallStartFilter (see below)
        long start  = (long) req.getProperty("call.start");
        long duration = System.currentTimeMillis() - start;

        String msg = "END " + method + " " + uri
                   + " status=" + status
                   + " durationMs=" + duration;

        if (status >= 500) {
            LOG.error(msg);
        } else if (status >= 400) {
            LOG.warn(msg);
        } else {
            LOG.info(msg);
        }
    }
}
```

A companion `ClientCallStartFilter` sets the start timestamp before the call:

```java
public class ClientCallStartFilter implements ClientRequestFilter {
    @Override
    public void filter(ClientRequestContext ctx) throws IOException {
        ctx.setProperty("call.start", System.currentTimeMillis());
    }
}
```

Registration in `ServiceClient` constructor:

```java
target.register(new RequestFilter(request, attributes));
target.register(new ClientCallStartFilter());
target.register(new ClientCallResponseFilter());
```

---

## Layer 2: Inline START log per ServiceClient method (Example)

One line added at the top of each method. No parameter values in the message.

```java
private static final Logger LOG = Logger.getLogger("LOG-HTTP-CLIENT");

public Response clientToken() {
    LOG.info("START GET /rest/book/payment/clientToken");
    purchasesService = target.proxy(Purchases.class);
    return purchasesService.clientToken();
}

public Response checkOut(HttpServletRequest request) {
    LOG.info("START POST /rest/book/payment/fullcheckout2");
    purchasesService = target.proxy(Purchases.class);
    return purchasesService.checkOut(
        request.getParameter("orderId"),
        request.getParameter("seatsToBeReserved"),
        request.getParameter("payment_method_nonce")
    );
}
```

---

## Layer 3: RequestFilter DEBUG header trace (Example)

Only logs header **names** and a boolean for the Ciphertext fallback. No values.

```java
@Override
public void filter(ClientRequestContext requestContext) throws IOException {
    // ... existing header injection code ...

    if (LOG.isDebugEnabled()) {
        String ciphertextFallback = (request.getHeader("Ciphertext") == null) ? "token2-fallback" : "from-request";
        List<String> cookieNames = Arrays.stream(request.getCookies() != null ? request.getCookies() : new Cookie[0])
            .map(Cookie::getName)
            .collect(Collectors.toList());
        LOG.debug("RequestFilter injected: X-Token, Ciphertext[" + ciphertextFallback + "]"
                + " attrs=" + attributes.keySet()
                + " cookies=" + cookieNames);
    }
}
```

---

## Log Output Shape (Structured)

```json
// START (inline in ServiceClient method)
{ "level": "INFO", "category": "LOG-HTTP-CLIENT",
  "source": "ServiceClient.checkOut", "event": "START",
  "method": "POST", "path": "/rest/book/payment/fullcheckout2" }

// END (ClientCallResponseFilter)
{ "level": "INFO", "category": "LOG-HTTP-CLIENT",
  "source": "ClientCallResponseFilter", "event": "END",
  "method": "POST", "path": "/mbooks-1/rest/book/payment/fullcheckout2",
  "status": 200, "durationMs": 342 }

// ERROR (ClientCallResponseFilter on 5xx)
{ "level": "ERROR", "category": "LOG-HTTP-CLIENT",
  "source": "ClientCallResponseFilter", "event": "END",
  "method": "POST", "path": "/mbooks-1/rest/book/payment/fullcheckout2",
  "status": 500, "durationMs": 120 }

// DEBUG (RequestFilter)
{ "level": "DEBUG", "category": "LOG-HTTP-CLIENT",
  "source": "RequestFilter", "event": "HEADERS-INJECTED",
  "headers": ["X-Token", "Ciphertext", "uuid", "token2", "TIME_"],
  "ciphertextSource": "token2-fallback",
  "cookies": ["XSRF-TOKEN", "JSESSIONID"] }
```

> **Security:** token2, Ciphertext, uuid, nonce, and Cookie **values** never appear in any log message.

---

## Log Routing Config (dalogin-quarkus)

```xml
<!-- log4j.xml — add a dedicated appender for LOG-HTTP-CLIENT -->
<appender name="HTTP_CLIENT_FILE" class="org.apache.log4j.RollingFileAppender">
    <param name="File" value="logs/http-client.log"/>
    <param name="MaxFileSize" value="10MB"/>
    <param name="MaxBackupIndex" value="5"/>
    <layout class="org.apache.log4j.PatternLayout">
        <param name="ConversionPattern" value="%d{ISO8601} %-5p [%c] %m%n"/>
    </layout>
</appender>

<logger name="LOG-HTTP-CLIENT" additivity="false">
    <level value="INFO"/>
    <appender-ref ref="HTTP_CLIENT_FILE"/>
</logger>
```

---

## Sensitive Field Masking Rules

| Field | Rule |
|---|---|
| `token2` | Never in any log. Used internally in `RequestFilter` only. |
| `Ciphertext` | Log only whether fallback was used — not the value. |
| `uuid` | Present in `attributes` map — never logged in START/END messages. |
| `payment_method_nonce` | `checkOut()` START log MUST NOT include nonce value. |
| Cookie values | Log cookie names only (not values). |

---

## Validation Checklist
- [ ] All 8 `ServiceClient` methods emit START log (INFO, no param values).
- [ ] `ClientCallResponseFilter` produces END log for every call.
- [ ] 5xx responses produce ERROR log; 4xx produce WARN.
- [ ] `RequestFilter` DEBUG log shows header names and Ciphertext fallback flag, not values.
- [ ] No sensitive value appears in any `http-client.log` entry.
- [ ] `http-client.log` file is separate from all other log streams.

## Open Review Questions
1. Should START logs include the servlet class name as caller (e.g. `"caller": "CheckOut"`) for richer tracing?
2. Should the `ClientCallResponseFilter` also log the servlet session ID (not token) for correlation?
3. Should exception-path logging (SSL errors) in servlets be migrated to `LOG-HTTP-CLIENT` or stay in the servlet's own logger?

