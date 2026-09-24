# dalogin Persistence and Servlet Adaptation Model

This is the single implementation model for the combined datasource, CDI, SQLAccess family-split,
and Servlet request/response adaptation. `HelloWorld` is the complete reference slice from HTTP
input through the final persistence bean and back to the HTTP response. The unit of work is the
entire Servlet class: lifecycle methods, every HTTP method, private flow helpers, injected
persistence dependencies, request records, and response helpers.

It keeps `HelloWorld` as an Undertow `@WebServlet`. It does not use JAX-RS `@BeanParam`,
`@RequestScoped`, Bean Validation, custom response annotations, or a generic response framework.

```text
HttpServletRequest
        |
        v
LoginRequest.from(request)       immutable request data and normalization
        |
        v
HelloWorld                       authentication and session orchestration
        |
        v
DeviceSessionManager              final CDI persistence family
        |
        v
<Endpoint>Responses              status, JSON, headers, cookies
        |
        v
ServletResponses                 shared content type and writer lifecycle
        |
        v
HttpServletResponse
```

## Target package

```text
com.dalogin.servlets.HelloWorld
com.dalogin.servlets.requestrecord.LoginRequest
com.dalogin.servlets.responsemap.LoginResponses
com.dalogin.servlets.support.ServletResponses
```

The package name is part of the example, not a requirement. The important boundary is that these
types are HTTP-facing and do not live in the persistence package.

## Servlet-wide application

Apply the model to all 14 classes under `com.dalogin.servlets`.

| Servlet | Request handling | Response helper |
|---|---|---|
| `HelloWorld` | complex: `LoginRequest` | `LoginResponses` |
| `Registration` | complex: registration DTO(s) | `RegistrationResponses` |
| `RegistrationWithoutVoucher` | complex: registration DTO(s) | registration helper where wire-identical |
| `Voucher` | simple `voucher` read; no DTO | `VoucherResponses` |
| `RegActivation` | simple `Ciphertext` read; no DTO | `ActivationResponses` |
| `ChangePassword` | complex: `PasswordResetRequest` | `PasswordResetResponses` |
| `ChangePasswordCode` | complex: confirmation DTO | `PasswordResetResponses` |
| `ChangePasswordNewPassword` | complex: new-password DTO | `PasswordResetResponses` |
| `AdminServlet` | simple optional `JSESSIONID`; no DTO | `AdminResponses` |
| `ManagePurchases` | simple operation-specific reads; no DTO unless inventory disproves | `PurchaseResponses` |
| `GetAllPurchases` | no-input | `PurchaseResponses` |
| `CheckOut` | no-input | `CheckoutResponses` |
| `LoggingOut` | no-input | `LogoutResponses` |
| `ActiveSessionsServlet` | no-input | `ActiveSessionsResponses` |

Do not create empty or single-value DTOs merely to make the table symmetrical. A DTO is justified by
complex request processing: mixed headers/parameters, coordinated validation or HMAC inputs,
multiple normalization/default rules, or type conversion. A simple value passed through unchanged
stays as an explicit Servlet read.

Response handling uses a different threshold. Every response branch goes through a named helper,
even when the response is straightforward, because status, body, content type, redirect, headers,
and cookies form the endpoint's wire contract. Sharing a response helper is allowed only when the
wire contract is genuinely identical.

## 1. Immutable request record

```java
package com.dalogin.servlets.login;

import jakarta.servlet.http.HttpServletRequest;

public record LoginRequest(
        String hmac,
        String contentLength,
        String microTime,
        String password,
        String user,
        String deviceId,
        String ios,
        String userAgent,
        String clientType,
        String encryptedDeviceId
) {
    private static final String HMAC_HEADER = "X-HMAC-HASH";
    private static final String MICRO_TIME_HEADER = "X-MICRO-TIME";
    private static final String CLIENT_TYPE_HEADER = "M";
    private static final String ENCRYPTED_DEVICE_HEADER = "M-Device";

    public static LoginRequest from(HttpServletRequest request) {
        return new LoginRequest(
                trim(request.getHeader(HMAC_HEADER)),
                trim(request.getHeader("Content-Length")),
                trim(request.getHeader(MICRO_TIME_HEADER)),
                trim(request.getParameter("pswrd")),
                trim(request.getParameter("user")),
                trim(request.getParameter("deviceId")),
                request.getParameter("ios"),
                request.getHeader("User-Agent"),
                defaultString(request.getHeader(CLIENT_TYPE_HEADER)),
                request.getHeader(ENCRYPTED_DEVICE_HEADER)
        );
    }

    public boolean hasRequiredValues() {
        return hmac != null
                && contentLength != null
                && microTime != null
                && password != null
                && user != null
                && deviceId != null;
    }

    public long validatedMicroTime() {
        return Long.parseLong(microTime);
    }

    public boolean mobileClient() {
        return ios != null;
    }

    private static String trim(String value) {
        return value == null ? null : value.trim();
    }

    private static String defaultString(String value) {
        return value == null ? "" : value;
    }
}
```

### Why it has this shape

- `from(...)` is the only complex login flow code that knows these Servlet wire names.
- Required values are trimmed once.
- `ios` is deliberately not trimmed or converted to `boolean`: current behavior selects the mobile
  response when the parameter is present, regardless of its text.
- `User-Agent` and `M-Device` remain nullable.
- Missing `M` remains `""`.
- The original code parses `X-MICRO-TIME` as a `long`, although the resulting local variable is
  unused. `validatedMicroTime()` preserves that validation without storing redundant state.
- The DTO does not decide what HTTP response invalid input receives.

Do not inject this record:

```java
// Wrong: mutable/proxied request state for a value that already arrives as a method argument
@RequestScoped
public class LoginRequest {
    @Inject
    HttpServletRequest request;
}
```

Do not add JAX-RS annotations:

```java
// Wrong in an HttpServlet: RESTEasy does not bind this object for doPost(...)
public class LoginRequest {
    @FormParam("user")
    String user;
}
```

## 2. Shared response-writing primitive

```java
package com.dalogin.servlets.support;

import jakarta.servlet.http.HttpServletResponse;
import org.json.JSONObject;

import java.io.IOException;
import java.io.PrintWriter;

public final class ServletResponses {

    private ServletResponses() {
    }

    public static void writeJson(
            HttpServletResponse response,
            int status,
            JSONObject body
    ) throws IOException {
        response.setContentType("application/json");
        response.setCharacterEncoding("utf-8");
        response.setStatus(status);

        try (PrintWriter out = response.getWriter()) {
            out.print(body.toString());
            out.flush();
        }
    }
}
```

This type owns mechanics only. It does not know endpoint payload fields, choose a status, catch an
exception, or inspect a request. Preserve an endpoint's existing `application/json;charset=UTF-8`
form where changing the emitted `Content-Type` header would be observable; the shared primitive may
need an overload accepting the exact content type for those endpoints.

## 3. Explicit endpoint response helper

Use a record when a response operation carries a meaningful group of values:

```java
package com.dalogin.servlets.login;

public record LoginSuccess(
        String contextPath,
        int maxAge,
        String sessionId,
        String token,
        String xsrfToken,
        boolean mobileClient
) {
}
```

Do not create response records for constant bodies such as authentication failure; the named helper
method already represents that contract.

```java
package com.dalogin.servlets.login;

import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletResponse;
import org.json.JSONObject;

import java.io.IOException;

import static com.dalogin.servlets.support.ServletResponses.writeJson;

public final class LoginResponses {

    private LoginResponses() {
    }

    public static void missingRequiredInput(HttpServletResponse response) throws IOException {
        writeJson(
                response,
                HttpServletResponse.SC_BAD_GATEWAY,
                new JSONObject()
                        .put("Success", "false")
                        .put("Message", "Missing required headers or parameters")
        );
    }

    public static void authenticationFailed(HttpServletResponse response) throws IOException {
        writeJson(
                response,
                HttpServletResponse.SC_BAD_GATEWAY,
                new JSONObject()
                        .put("Session creation", "failed")
                        .put("Success", "false")
        );
    }

    public static void sessionPersistenceFailed(HttpServletResponse response) throws IOException {
        writeJson(
                response,
                HttpServletResponse.SC_INTERNAL_SERVER_ERROR,
                new JSONObject()
                        .put("Success", "false")
                        .put("Message", "Session creation failed")
        );
    }

    public static void loginSucceeded(
            HttpServletResponse response,
            LoginSuccess success
    ) throws IOException {
        Cookie cookieXSRF = new Cookie("XSRF-TOKEN", success.xsrfToken());
        cookieXSRF.setSecure(true);
        cookieXSRF.setHttpOnly(true);
        cookieXSRF.setMaxAge(success.maxAge());
        cookieXSRF.setPath(success.contextPath());

        Cookie cookieToken = new Cookie("X-Token", success.token());
        cookieToken.setSecure(true);
        cookieToken.setMaxAge(success.maxAge());

        response.addCookie(cookieXSRF);
        response.addCookie(cookieToken);
        response.addHeader("X-Token", success.token());

        JSONObject body = success.mobileClient()
                ? new JSONObject()
                        .put("success", 1)
                        .put("JSESSIONID", success.sessionId())
                        .put("X-Token", success.token())
                : new JSONObject()
                        .put("Session", "raked")
                        .put("Success", "true")
                        .put("X-Token", success.token());

        writeJson(response, HttpServletResponse.SC_OK, body);
    }

}
```

### Response-helper rules

1. Use named endpoint operations, not `respond(status, fields)`.
2. Preserve JSON value types: mobile `success` is numeric `1`; other `Success` values are strings.
3. Preserve both tokens: `X-Token` is a response header and a cookie.
4. Preserve the existing cookie asymmetry:
   - `XSRF-TOKEN` is secure, HTTP-only, has max age, and has the context path.
   - `X-Token` is secure and has max age; the current code does not set HTTP-only or path.
5. One helper operation writes exactly once. The caller returns afterward.
6. Do not log the token, password, HMAC, or decrypted device identifier.

## 4. Final persistence boundary

`HelloWorld` injects the final family beans, not `SQLAccess`:

```java
@Inject
AccountManager accountManager;

@Inject
DeviceSessionManager deviceSessionManager;
```

The merged device/session family exposes one transaction for the normal login path:

```java
public record SessionTokens(String token, String time) {
}
```

```java
@ApplicationScoped
public class DeviceSessionManager {

    @Inject
    DataSource dataSource;

    public SessionTokens establishLogin(
            String deviceId,
            String user,
            long sessionCreated,
            String sessionId
    ) {
        try (Connection conn = dataSource.getConnection()) {
            conn.setAutoCommit(false);
            try {
                insertDevice(conn, deviceId, user);
                insertSessionCreated(conn, deviceId, sessionCreated, sessionId);
                SessionTokens tokens = getToken2(conn, deviceId);
                conn.commit();
                return tokens;
            } catch (SQLException | RuntimeException e) {
                SqlSupport.rollbackQuietly(conn, e);
                throw new PersistenceOperationException("establishLogin", deviceId, e);
            } finally {
                SqlSupport.restoreAutoCommit(conn);
            }
        } catch (SQLException e) {
            throw new PersistenceOperationException("establishLogin", deviceId, e);
        }
    }

    void insertDevice(Connection conn, String deviceId, String user) throws SQLException {
        try (CallableStatement statement =
                     conn.prepareCall("{call `insert_device_`(?, ?)}")) {
            statement.setString(1, deviceId);
            statement.setString(2, user);
            statement.executeUpdate();
        }
    }

    void insertSessionCreated(
            Connection conn,
            String deviceId,
            long sessionCreated,
            String sessionId
    ) throws SQLException {
        try (CallableStatement statement =
                     conn.prepareCall("{call `insert_sessionCreated`(?, ?, ?)}")) {
            statement.setString(1, deviceId);
            statement.setLong(2, sessionCreated);
            statement.setString(3, sessionId);
            statement.executeUpdate();
        }
    }

    SessionTokens getToken2(Connection conn, String deviceId) throws SQLException {
        try (CallableStatement statement = conn.prepareCall("{call `get_token2`(?)}")) {
            statement.setString(1, deviceId);
            try (ResultSet resultSet = statement.executeQuery()) {
                if (!resultSet.next()) {
                    throw new SQLException("Session token was not created");
                }
                return new SessionTokens(resultSet.getString(1), resultSet.getString(2));
            }
        }
    }
}
```

The operation is atomic: if session insertion or token retrieval fails, the device write is rolled
back too. This resolves the former open device-row disposition question; normal login does not leave
a partially established device/session pair.

Standalone `insertDevice`, `insertSessionCreated`, and `getToken2` forms remain where another
verified caller needs them, and delegate to the same connection-accepting implementations. The
registration-with-voucher transaction continues to pass its own connection into these methods.

### Registration transaction remains cross-family and atomic

`AccountManager.wrapUpRegistration` owns its connection and transaction:

```java
public boolean wrapUpRegistration(
        String voucher,
        String user,
        String password,
        String deviceId,
        long sessionCreated,
        String sessionId
) {
    try (Connection conn = dataSource.getConnection()) {
        conn.setAutoCommit(false);
        try {
            voucherManager.insertVoucher(conn, voucher, user, password);
            deviceSessionManager.insertDevice(conn, deviceId, user);
            deviceSessionManager.insertSessionCreated(conn, deviceId, sessionCreated, sessionId);
            voucherManager.copyToken2(conn, voucher);
            conn.commit();
            return true;
        } catch (SQLException e) {
            SqlSupport.rollbackQuietly(conn, e);
            return false;
        } finally {
            SqlSupport.restoreAutoCommit(conn);
        }
    } catch (SQLException e) {
        SqlSupport.logSQLException(e);
        return false;
    }
}
```

The fixed order is a schema contract:

```text
insert_voucher
    -> insert_device_          (creates device_states through trigger)
    -> insert_sessionCreated   (creates Tokens through Last_seen trigger)
    -> copy_token2             (copies the now-existing token)
```

Connection-accepting methods never acquire, close, commit, or roll back the supplied connection.
Their standalone forms acquire their own connection and delegate to them, so every SQL statement is
written once.

### Persistence resource rules

- Inject `DataSource`; never look it up from `ServletContext`.
- Acquire `Connection` per operation and close it with try-with-resources.
- Close every statement and `ResultSet` explicitly.
- Never hold a `Connection` as a bean field.
- Every method that disables auto-commit commits or rolls back explicitly and restores connection
  state without masking the primary failure.
- No `DBConnectionManager`, `DriverManager`, static `SQLAccess` facade, or lifecycle close remains.

## 5. `HelloWorld.doPost` after adaptation

```java
@Override
public void doPost(HttpServletRequest request, HttpServletResponse response)
        throws ServletException, IOException {
    String method = request.getMethod();
    String uri = request.getRequestURI();
    log.debugf(
            "HTTP request started: servlet=%s, method=%s, uri=%s",
            getServletName(),
            method,
            uri
    );

    try {
        HttpSession oldSession = request.getSession(false);
        if (oldSession != null) {
            oldSession.invalidate();
        }

        LoginRequest login = LoginRequest.from(request);
        if (!login.hasRequiredValues()) {
            LoginResponses.missingRequiredInput(response);
            return;
        }

        // Preserve the current numeric validation. The value itself is not otherwise used.
        login.validatedMicroTime();

        String hmacHash = hmac512.getLoginHmac512(
                login.user(),
                login.password(),
                login.deviceId(),
                login.microTime(),
                login.contentLength()
        );
        log.debug("Handshake validation executed for login flow");

        String deviceId = decryptDeviceId(login.deviceId(), login.encryptedDeviceId());
        String passwordHash = accountManager.getHash(login.password(), login.user());

        if (!login.password().equals(passwordHash) || !login.hmac().equals(hmacHash)) {
            LoginResponses.authenticationFailed(response);
            return;
        }

        createSession(
                request,
                response,
                login.user(),
                deviceId,
                login.mobileClient(),
                login.userAgent(),
                login.clientType()
        );
    } finally {
        log.debugf(
                "HTTP request completed: method=%s, uri=%s, status=%d",
                method,
                uri,
                response.getStatus()
        );
    }
}
```

The decryption block becomes a named method without changing its best-effort behavior:

```java
private String decryptDeviceId(String fallbackDeviceId, String encryptedDeviceId) {
    try {
        String decrypted = cryptoService.decrypt(SALT, IV, PASSPHRASE, encryptedDeviceId);
        log.debug("Encrypted device identifier was processed");
        return decrypted;
    } catch (Exception e) {
        log.debug("No encrypted device identifier provided for decryption");
        return fallbackDeviceId;
    }
}
```

## 6. Pending session, database success, then publication

`insertSessionCreated` requires the Servlet session ID and creation time. Therefore the
`HttpSession` object cannot literally be created after the database insert. The required ordering is:

```text
create pending HttpSession (needed for ID/time)
        |
        v
atomically insert/update device + session + tokens
        |
        +-- failure -> rollback DB, invalidate pending HttpSession, return 5xx
        |
        v
publish user/device attributes -> listener exposes active session
        |
        v
write cookies/header/success response
```

The `createSession` method receives values, not the entire DTO:

```java
private void createSession(
        HttpServletRequest request,
        HttpServletResponse response,
        String user,
        String deviceId,
        boolean mobileClient,
        String userAgent,
        String clientType
) throws IOException {
    HttpSession session = request.getSession(true);
    session.setMaxInactiveInterval(30 * 60);

    SessionTokens tokens;
    try {
        tokens = deviceSessionManager.establishLogin(
                deviceId,
                user,
                session.getCreationTime(),
                session.getId()
        );
    } catch (PersistenceOperationException e) {
        session.invalidate();
        log.errorf(e, "Session persistence failed for deviceId=%s", deviceId);
        LoginResponses.sessionPersistenceFailed(response);
        return;
    }

    String xsrfToken;
    try {
        xsrfToken = cryptoService.encrypt(SALT, IV, tokens.time(), tokens.token());
    } catch (Exception e) {
        session.invalidate();
        throw new IOException("Failed to prepare the login response", e);
    }

    String actualToken = xsrfToken.endsWith("=")
            ? xsrfToken.substring(0, xsrfToken.length() - 1)
            : xsrfToken.trim();

    // Publication happens only after the database transaction and token preparation succeeded.
    synchronized (session) {
        session.setAttribute("user", user);
        session.setAttribute("deviceId", deviceId);
        session.removeAttribute("pswrd");
        session.setAttribute("XSRF-TOKEN", actualToken);
        session.setAttribute("TIME_", tokens.time());
    }

    LoginResponses.loginSucceeded(
            response,
            new LoginSuccess(
                    request.getServletContext().getContextPath(),
                    session.getMaxInactiveInterval(),
                    session.getId(),
                    tokens.token(),
                    actualToken,
                    mobileClient
            )
    );
}
```

The old 100 ms `getToken2` retry disappears. The query runs on the same transaction connection after
the trigger-producing insert, so it sees its own writes. Empty token data is a hard persistence
failure, not an asynchronous commit race.

`userAgent` and `clientType` remain parameters only if the complete final flow uses them. Unlike
wire-contract changes, compiler-proven removal of dead locals is allowed in this combined adaptation.

Apply the same publication rule to both registration paths:

- `RegistrationWithoutVoucher` creates a pending session, completes `createUser`, then calls atomic
  `establishLogin`; it publishes attributes only after both required persistence stages succeed.
- `Registration` creates a pending session for the ID/time required by `wrapUpRegistration`, calls
  that existing atomic transaction, and publishes attributes only after it returns success.
- Both invalidate the pending session on failure.

`RegActivation` currently creates a session only to obtain `ServletContext` for SQLAccess. After CDI
injection it calls the activation family directly and does not create that unnecessary session.

## 7. Imports removed from `HelloWorld`

After every response branch delegates:

```java
// remove

import org.json.JSONObject;

// add
import com.dalogin.servlets.requestrecord.LoginRequest;
import com.dalogin.servlets.responsemap.LoginResponses;
import com.dalogin.servlets.responsemap.LoginSuccess;
import com.dalogin.crypto.CryptoService;
import com.dalogin.persistence.AccountManager;
import com.dalogin.persistence.DeviceSessionManager;
import com.dalogin.persistence.PersistenceOperationException;
import com.dalogin.persistence.SessionTokens;
```

Remove `SQLAccess`, `ServletContext`, `JSONObject`, `PrintWriter`, and collection imports once the
final code no longer uses them.

## 8. Focused REST Assured coverage

Existing `loginSuccess`, `loginBadHmac`, and `loginWrongPassword` remain the primary regression
gate. Add only the contract gaps needed for this extraction.

### Missing required value

```java
@Test
void loginMissingUser() {
    given()
            .contentType(ContentType.URLENC)
            .header("X-HMAC-HASH", "unused")
            .header("X-MICRO-TIME", String.valueOf(System.currentTimeMillis()))
            .formParam("pswrd", PASS_HASH)
            .formParam("deviceId", DEVICE_ID)
        .when()
            .post("/HelloWorld")
        .then()
            .statusCode(502)
            .contentType(ContentType.JSON)
            .body("Success", equalTo("false"))
            .body("Message", equalTo("Missing required headers or parameters"));
}
```

REST Assured supplies `Content-Length` for the encoded body. Do not manually calculate a length for
this missing-field test because HMAC validation is never reached.

### Authentication-failure payload

Extend the existing bad-HMAC assertion:

```java
.then()
    .statusCode(502)
    .contentType(ContentType.JSON)
    .body("Session creation", equalTo("failed"))
    .body("Success", equalTo("false"));
```

### Successful mobile response and cookies

Extend `loginSuccess`:

```java
.then()
    .statusCode(200)
    .body("success", equalTo(1))
    .body("JSESSIONID", not(emptyOrNullString()))
    .body("X-Token", not(emptyOrNullString()))
    .header("X-Token", not(emptyOrNullString()))
    .cookie("XSRF-TOKEN", not(emptyOrNullString()))
    .cookie("X-Token", not(emptyOrNullString()));
```

Cookie flag/path/max-age verification may require inspecting the `Set-Cookie` headers because the
REST Assured cookie-value accessor does not expose every attribute.

### Malformed micro-time

Before implementation, record the current endpoint response for a non-numeric `X-MICRO-TIME`.
`LoginRequest.validatedMicroTime()` must preserve that outcome. Do not silently accept malformed
values merely because the parsed `long` local is unused.

## 9. Applying the reference slice to another Servlet

For each Servlet:

1. Inventory the whole class: every `doGet`/`doPost`, `init`, `destroy`, private flow helper,
   `getParameter`, `getHeader`, session read, request attribute, response branch, redirect, cookie,
   header, content type, status, and JSON value type.
2. Classify the request as complex, simple pass-through, or no-input. Create an immutable DTO only
   for a complex request contract. A Servlet with distinct complex POST and GET contracts may have
   distinct DTOs; do not create a bag containing unrelated fields.
3. Create or reuse an endpoint response helper only after comparing wire contracts field by field.
4. Replace complex request parsing and all response construction in the same edit as SQLAccess
   caller injection. Keep classified simple reads direct.
5. Do not move orchestration, database calls, client calls, session mutation, crypto, or logging
   into either the DTO or response helper.
6. Do not "correct" existing status codes, error strings, JSON capitalization, or writer behavior
   beyond the explicitly approved login-persistence failure response.
7. Remove empty `init()` and no-op `destroy()` overrides. Preserve non-empty initialization such as
   `AesUtil` setup through the injected thread-safe service below.
8. Inject final family access beans into the Servlet. Never inject `DataSource` or acquire a
   `Connection` in the Servlet; those belong in persistence beans.

### Lifecycle replacement

Do not inject or retain the current `AesUtil` as an application/request-shared object. It stores a
mutable `Cipher`, and `Cipher` is not thread-safe. Replace the seven Servlet `init()` methods and the
same filter pattern with a stateless service that creates cryptographic state per operation:

```java
@ApplicationScoped
public class CryptoService {
    private static final int KEY_SIZE = 128;
    private static final int ITERATION_COUNT = 1000;

    public String encrypt(String salt, String iv, String passphrase, String plaintext) {
        return new AesUtil(KEY_SIZE, ITERATION_COUNT)
                .encrypt(salt, iv, passphrase, plaintext);
    }

    public String decrypt(String salt, String iv, String passphrase, String ciphertext) {
        return new AesUtil(KEY_SIZE, ITERATION_COUNT)
                .decrypt(salt, iv, passphrase, ciphertext);
    }
}
```

```java
@Inject
CryptoService cryptoService;
```

This preserves the algorithm and wire format while ensuring each operation owns its `Cipher`.
After injection, remove the now-unnecessary `init()` and all no-op `destroy()` overrides. A future
optimization may refactor `AesUtil` itself to create a local `Cipher`, but must prove concurrent
safety before sharing an instance.

Example request record for the password-reset family:

```java
public record PasswordResetRequest(
        String hmac,
        String contentLength,
        String microTime,
        String email,
        String deviceId,
        String ios,
        String userAgent,
        String clientType,
        String encryptedDeviceId
) {
    public static PasswordResetRequest from(HttpServletRequest request) {
        // Same explicit wire-name mapping and normalization rules as LoginRequest.
    }
}
```

This may be shared by `ChangePassword`, `ChangePasswordCode`, and
`ChangePasswordNewPassword` only for their common fields. Endpoint-specific fields such as `cC` and
`pass` belong in a more specific or composed record, not nullable fields that every endpoint carries.

## 10. Combined SQLAccess migration

Implement the Servlet DTO/helper extraction in the same source pass as:

1. datasource legacy removal,
2. CDI datasource injection,
3. SQLAccess family split and caller migration.

For each Servlet, make its complete edit once: inject the final family beans, replace legacy static
SQLAccess calls, parse through its DTO, and delegate response construction. Do not first migrate the
Servlet to an intermediate monolithic injected SQLAccess bean and revisit it later.

The repository is allowed to be uncompilable during this pass. Compile only after all production
callers, DTOs, helpers, filters/listeners, and persistence families are in their final shape. Then
resolve compiler errors and run the targeted login tests. This avoids reviewable intermediate
facades and duplicated call-site churn.

## 11. Verification checklist

Use this checklist for the complete adaptation, not only the `HelloWorld` reference slice.

### Persistence and dependency boundaries

- [ ] Legacy `DriverManager`, hardcoded credentials, datasource fallback, and dead connection test
      code are gone.
- [ ] `SQLAccess` and `DBConnectionManager` are gone; no compatibility facade or static forwarder
      replaced them.
- [ ] Every persistence operation belongs to its final login/registration, voucher,
      device/session/token, or password-reset family.
- [ ] Servlets, filters, and listeners inject only final family access beans; only persistence beans
      inject `DataSource`.
- [ ] No Servlet, filter, listener, DTO, or response helper acquires or stores a `Connection`.
- [ ] Connections, statements, and result sets are closed explicitly with try-with-resources.
- [ ] SQL text, parameter order, result mapping, and required procedure/trigger ordering are
      unchanged.
- [ ] Connection-accepting methods never acquire, close, commit, or roll back the supplied
      connection.
- [ ] Transaction owners commit, roll back on failure, and restore connection state without masking
      the primary failure.
- [ ] No duplicated SQL remains between standalone and transaction-participant forms.

### Whole-Servlet coverage

- [ ] All 14 Servlet classes retain their existing names, URL mappings, and supported HTTP methods.
- [ ] All 26 `doGet`/`doPost` handlers are accounted for in the migration inventory.
- [ ] Every relevant private request, response, session, crypto, downstream-client, and persistence
      helper was reviewed with its owning Servlet.
- [ ] No Servlet was left half-migrated because only its primary POST or SQLAccess path was changed.
- [ ] All ten Servlet `init()` and ten no-op `destroy()` overrides are gone.
- [ ] Behavior formerly performed by a non-empty lifecycle method remains available through an
      injected service or an equivalently safe final design.

### Request records

- [ ] Every request flow is classified as complex, simple pass-through, or no-input with a recorded
      reason.
- [ ] Every complex request flow maps its inputs through an immutable Java record.
- [ ] Record factories are the only code in a complex flow that knows header/parameter wire names.
- [ ] Required values, trimming, defaults, presence semantics, and type conversion match the
      endpoint baseline.
- [ ] Simple pass-through reads remain explicit; no empty, single-value, or ceremonial records were
      created.
- [ ] GET and POST contracts use separate records when their fields or validation differ materially.
- [ ] Request records contain no CDI, session, response, SQL, crypto, client-call, or logging logic.

### Response records and helpers

- [ ] Every terminal response branch delegates to a named endpoint response helper.
- [ ] Nontrivial structured response inputs use records; constant responses remain named helper
      operations without ceremonial records.
- [ ] `ServletResponses` contains writer/content-type/status mechanics only and no endpoint policy.
- [ ] Endpoint helpers are shared only where the full wire contracts are identical.
- [ ] No Servlet directly constructs `JSONObject` or owns a `PrintWriter`, except an explicitly
      documented non-JSON streaming case.
- [ ] Every terminal response is written once and the handler returns afterward.
- [ ] Statuses, content types, encodings, redirects, JSON names/types, headers, cookie names,
      security flags, paths, and max ages match the baseline except for explicitly approved failure
      corrections.

### Session and transaction integrity

- [ ] Session-establishing flows create only a pending `HttpSession` before persistence.
- [ ] `user`, `deviceId`, token, and active-session attributes are published only after the required
      persistence transaction commits.
- [ ] Normal login and registration-without-voucher use atomic `establishLogin`.
- [ ] Registration-with-voucher retains atomic `wrapUpRegistration` and its fixed procedure order.
- [ ] A persistence or token-read failure rolls back database work, invalidates the pending session,
      logs the failed operation without secrets, and returns 5xx.
- [ ] No Servlet creates an `HttpSession` solely to obtain `ServletContext` or datasource access.
- [ ] The obsolete 100 ms token retry and asynchronous-commit explanation are gone.

### Crypto and concurrency

- [ ] Seven Servlet crypto paths and `ChangePswFilter` inject stateless `CryptoService`.
- [ ] No request-shared object contains a mutable `Cipher`.
- [ ] Key size, iteration count, salts, IVs, passphrases, algorithms, and ciphertext format are
      unchanged.
- [ ] Concurrent encrypt/decrypt coverage passes without cross-request corruption.
- [ ] Passwords, HMACs, tokens, confirmation codes, vouchers, and decrypted device identifiers are
      not newly logged or exposed in errors.

### Build and verification

- [ ] The first compile occurs only after datasource removal, final family extraction, all caller
      migrations, record/helper creation, lifecycle cleanup, and legacy deletion are complete.
- [ ] Compiler-reported missed callers/imports/signatures are resolved with no shim introduced.
- [ ] Static searches find no legacy datasource lookup, static SQLAccess call, direct complex-request
      parsing, or direct Servlet JSON writer.
- [ ] Targeted `LoginFlowTest` cases pass using the local-test skill's Maven settings and random port.
- [ ] Automated failure coverage proves rollback, pending-session invalidation, and 5xx behavior.
- [ ] Owner verification covers registration, voucher, activation, password reset, logout, admin,
      active sessions, checkout, purchases, and iOS/web response compatibility.
