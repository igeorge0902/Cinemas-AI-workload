# Screen news over WebSocket — implementation example

Design-time examples for plan §3–§4 and tasks T00–T09. The corresponding implementation was completed and accepted for T00–T10/T12 on 2026-10-09; actual module sources are authoritative rather than verbatim copies of these illustrative snippets.

The final implementation validates literal JSON booleans without coercion, distinguishes a missing settings row from a stored NULL, and builds outbound WebSocket JSON from the deserialized Kafka event rather than parsing the Base64 Java-serialization transport as JSON. `eventType` on mbook's entity is JPA-transient, not Java-transient; no event/category SQL column was added. The diagnostic Quarkus entry point is named and socket retries are cancellable and generation-guarded.

The standalone RC is `k8infra/mysql_8/screen_news_standalone_rc.sql`, based on the confirmed login dump and the user-accepted older `mysql_8/book.sql` supplement. Three backend compiles and isolated MySQL import/insertion acceptance passed; iOS validation is static-only. See the tasks file's execution acceptance for hashes and evidence. Historical "no execution now" language below describes the original documentation stage, not the subsequent authorized implementation.

The user chose to retain the approved authentication scope and record existing filter/active-session risks. T12 approval is task-compliance approval, not security-hardening approval. T11, working/live database changes and deployment remain deferred.

Prerequisite T00: mbook is first refactored to the mbooks layering. `BookController` and `BookingHandlerImpl` are replaced by `AccountController`/`NewsController`, `AccountService`/`NewsService` and `ApiResponseFactory`. The 5 existing routes are unchanged. The snippets below assume that layering.

## 0. mbook layering refactor (T00) — Quick Engineer example

Contracts unchanged: same statuses, header names/values and JSON shape. Delete `rest/BookController.java` and `service/BookingHandlerImpl.java`.

### `mbook-quarkus/src/main/java/com/jeet/rest/ApiResponseFactory.java`

```java
package com.jeet.rest;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

@ApplicationScoped
public class ApiResponseFactory {

    public Response ok(Object body) {
        return response(Response.Status.OK, body);
    }

    public Response ok(Object body, Response.Status status) {
        return response(status, body);
    }

    public Response error(Response.Status status, Object body) {
        return response(status, body);
    }

    public Response.ResponseBuilder builder(int status, Object body) {
        return json(Response.status(status), body);
    }

    private Response response(Response.Status status, Object body) {
        return json(Response.status(status), body).build();
    }

    private Response.ResponseBuilder json(Response.ResponseBuilder builder, Object body) {
        if (body != null) {
            builder.entity(body);
        }
        return builder.type(MediaType.APPLICATION_JSON);
    }
}
```

### `rest/requestbean/UserParams.java`

```java
package com.jeet.rest.requestbean;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.core.Context;

public class UserParams {

    @Context
    public HttpServletRequest request;

    @PathParam("user")
    public String user;

    @PathParam("token1")
    public String token1;
}
```

### `rest/responserecord/account/UserResponse.java`

```java
package com.jeet.rest.responserecord.account;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.JsonNode;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record UserResponse(
        String uuid,
        String user,
        String email,
        String profilePicture,
        @JsonProperty("Error Details") JsonNode errorDetails
) {
}
```

### `rest/responserecord/account/NameResponse.java`

```java
package com.jeet.rest.responserecord.account;

public record NameResponse(String name) {
}
```

### `rest/responserecord/news/InfoResponse.java`

```java
package com.jeet.rest.responserecord.news;

import com.fasterxml.jackson.annotation.JsonProperty;

public record InfoResponse(@JsonProperty("Info") String info) {
}
```

### `rest/responsemapper/AccountMapper.java`

Parse with `JSONObject` before querying the user. Explicit tree construction retains nested JSON nulls even if application-wide Jackson configuration excludes null map values.

```java
package com.jeet.rest.responsemapper;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.NullNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.jeet.api.Logins;
import com.jeet.rest.responserecord.account.UserResponse;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.json.JSONArray;
import org.json.JSONObject;

@ApplicationScoped
public class AccountMapper {

    @Inject
    ObjectMapper objectMapper;

    public ObjectNode parseErrorDetails(Object attribute) {
        if (attribute == null) {
            return null;
        }
        return toObjectNode(new JSONObject(attribute.toString()));
    }

    public UserResponse toUserResponse(Logins login, JsonNode errorDetails) {
        return new UserResponse(
                login.getUuid(),
                login.getUser(),
                login.getEmail(),
                login.getProfilePicture(),
                errorDetails
        );
    }

    private ObjectNode toObjectNode(JSONObject source) {
        ObjectNode result = JsonNodeFactory.instance.objectNode();
        for (String key : source.keySet()) {
            result.set(key, toNode(source.get(key)));
        }
        return result;
    }

    private JsonNode toNode(Object value) {
        if (value == null || value == JSONObject.NULL) {
            return NullNode.getInstance();
        }
        if (value instanceof JSONObject object) {
            return toObjectNode(object);
        }
        if (value instanceof JSONArray array) {
            ArrayNode result = JsonNodeFactory.instance.arrayNode();
            for (int i = 0; i < array.length(); i++) {
                result.add(toNode(array.get(i)));
            }
            return result;
        }
        return objectMapper.valueToTree(value);
    }
}
```

### `service/AccountService.java`

Mapper is injected into the service and the controller calls the service (mbooks pattern: `MovieMapper` → `MovieService` → `MovieController`). Method names keep the existing `BookingHandlerImpl` names.

```java
package com.jeet.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.jeet.api.Devices;
import com.jeet.api.Logins;
import com.jeet.db.DAO;
import com.jeet.rest.responsemapper.AccountMapper;
import com.jeet.rest.responserecord.account.UserResponse;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

import java.util.List;

@ApplicationScoped
public class AccountService {

    @Inject
    DAO dao;

    @Inject
    AccountMapper accountMapper;

    public ObjectNode parseErrorDetails(Object attribute) {
        return accountMapper.parseErrorDetails(attribute);
    }

    public UserResponse toUserResponse(Logins login, JsonNode errorDetails) {
        return accountMapper.toUserResponse(login, errorDetails);
    }

    public List<Devices> getDevice(String uuid) {
        return dao.getDevices(uuid);
    }

    public Logins getUser(String user) {
        return dao.getUser(user);
    }

    public int getNewUser(String newuser) {
        return dao.getNewUser(newuser);
    }

    public int getNewEmail(String newemail) {
        return dao.getNewEmail(newemail);
    }
}
```

### `service/NewsService.java`

```java
package com.jeet.service;

import com.jeet.broadcasting.eventModel.AddMovie;
import com.jeet.broadcasting.eventModel.EventState;
import com.jeet.db.DAO;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

import java.util.List;

@ApplicationScoped
public class NewsService {

    @Inject
    DAO dao;

    public List<EventState> getNewEventsForUser(String user) {
        return dao.getNewEventsForUser(user);
    }

    @Transactional
    public void saveNewEvent(AddMovie event) {
        dao.saveNewEvent(event);
    }
}
```

### `rest/AccountController.java`

```java
package com.jeet.rest;

import com.fasterxml.jackson.databind.node.ObjectNode;
import com.jeet.api.Devices;
import com.jeet.api.Logins;
import com.jeet.rest.requestbean.UserParams;
import com.jeet.rest.responserecord.account.NameResponse;
import com.jeet.rest.responserecord.account.UserResponse;
import com.jeet.service.AccountService;
import jakarta.enterprise.context.RequestScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.BeanParam;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.GenericEntity;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import java.util.List;

@RequestScoped
@Path("/rest")
@Produces(MediaType.APPLICATION_JSON)
public class AccountController {

    @Inject
    AccountService accountService;

    @Inject
    ApiResponseFactory responses;

    @GET
    @Path("/device/{uuid}")
    public Response getDevice(@PathParam("uuid") String uuid) {
        List<Devices> devices = accountService.getDevice(uuid);

        if (devices == null || devices.isEmpty() || devices.get(0).getId() == 0) {
            return responses.error(
                    Response.Status.NOT_FOUND,
                    "{\"error\":\"Device not found\"}"
            );
        }

        GenericEntity<List<Devices>> entity = new GenericEntity<>(devices) {
        };
        return responses.builder(200, entity)
                .header("Device", devices.get(0).getDevice())
                .build();
    }

    @GET
    @Path("/user/{user}/{token1}")
    public Response getUser(@BeanParam UserParams params) {
        String token2 = params.request.getHeader("X-Token");
        Object attribute = params.request.getAttribute("Error Details");
        ObjectNode errorDetails = accountService.parseErrorDetails(attribute);

        Logins login = accountService.getUser(params.user);

        if (login.getId() == 0) {
            return responses.error(Response.Status.PRECONDITION_FAILED, login);
        }

        UserResponse body = accountService.toUserResponse(login, errorDetails);

        if (attribute != null) {
            Response.ResponseBuilder builder = responses.builder(300, body)
                    .header("User", login.getUuid());
            if (token2 != null) {
                builder.header("X-Token", token2);
            }
            return builder.build();
        }

        return responses.builder(200, body)
                .header("User", login.getUuid())
                .build();
    }

    @GET
    @Path("/newuser/{newuser}")
    public Response getNewUser(@PathParam("newuser") String newuser) {
        int count = accountService.getNewUser(newuser);
        NameResponse body = new NameResponse("My name is...");

        if (count > 0) {
            return responses.error(Response.Status.PRECONDITION_FAILED, body);
        }
        return responses.ok(body);
    }

    @GET
    @Path("/newemail/{newemail}")
    public Response getNewEmail(@PathParam("newemail") String newemail) {
        int count = accountService.getNewEmail(newemail);
        NameResponse body = new NameResponse("My email is...");

        if (count > 0) {
            return responses.error(Response.Status.PRECONDITION_FAILED, body);
        }
        return responses.ok(body);
    }
}
```

### `rest/NewsController.java`

```java
package com.jeet.rest;

import com.jeet.broadcasting.eventModel.EventState;
import com.jeet.rest.responserecord.news.InfoResponse;
import com.jeet.service.NewsService;
import jakarta.enterprise.context.RequestScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import java.util.List;

@RequestScoped
@Path("/rest")
@Produces(MediaType.APPLICATION_JSON)
public class NewsController {

    @Inject
    NewsService news;

    @Inject
    ApiResponseFactory responses;

    @GET
    @Path("/news/{user}")
    public Response getNewEventsForUser(@PathParam("user") String user) {
        List<EventState> events = news.getNewEventsForUser(user);

        if (events == null || events.isEmpty()) {
            return responses.ok(new InfoResponse("No new event"));
        }
        return responses.ok(events);
    }
}
```

### `broadcasting/KafkaMoviesListener.java` — bounded replacements

The field is renamed to `news`; the call becomes `news.saveNewEvent(event)`.

```java
import com.jeet.service.NewsService;
```

```java
@Inject NewsService news;
```

The existing record-processing block remains:

```java
AddMovie event = deserialization.deserializeAddMovie(record.value());
news.saveNewEvent(event);

WebSocketServer.broadcastMessage(record.value());
System.out.println("Sent to WebSocket: " + record.value());
```

**Do not implement T06 gating in T00.** T06 later replaces the broadcast after persistence and introduces the `AccountService`/`NewsSettingsService` recipient lookups.

### `broadcasting/KafkaListener.java` — bounded removals

Remove these two lines; leave all consumer and user-notification broadcast logic unchanged:

```java
import com.jeet.service.BookingHandlerImpl;
```

```java
BookingHandlerImpl bh = new BookingHandlerImpl();
```

### `utils/HibernateTest.java`

Replace the standalone, non-CDI construction with a **named Quarkus application entry point**, not the default application entry point. All four lookups use the injected DAO; DAO transaction annotations and persistence ownership remain unchanged.

```java
package com.jeet.utils;

import com.jeet.api.Devices;
import com.jeet.api.Logins;
import com.jeet.broadcasting.eventModel.EventState;
import com.jeet.db.DAO;
import io.quarkus.runtime.QuarkusApplication;
import io.quarkus.runtime.annotations.QuarkusMain;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManagerFactory;
import org.hibernate.SessionFactory;
import org.hibernate.stat.Statistics;
import org.json.JSONObject;

import java.util.List;

@QuarkusMain(name = "hibernate-test")
public class HibernateTest implements QuarkusApplication {

    @Inject
    DAO dao;

    @Inject
    EntityManagerFactory entityManagerFactory;

    @Override
    public int run(String... args) {
        SessionFactory factory = entityManagerFactory.unwrap(SessionFactory.class);
        Statistics stats = factory.getStatistics();
        stats.setStatisticsEnabled(true);

        List<EventState> events = dao.getNewEventsForUser("GG");
        List<Devices> device = dao.getDevices("65f63602-6ddf-11e5-8441-71caa0c5f788");

        JSONObject json = new JSONObject();
        json.put("device", device);
        System.out.println("hello");

        Logins user = dao.getUser("II");
        if (user.getId() != 0) {
            System.out.println("hello");
        } else {
            System.out.println("no user");
        }

        int newuser_ = dao.getNewEmail("igeorge1982@gmail.com");
        System.out.println(newuser_);

        stats.logSummary();
        stats.getCacheRegionStatistics("movies");
        return 0;
    }
}
```

Finish T00 by deleting `rest/BookController.java` and `service/BookingHandlerImpl.java`. Leave `DAO.java`, filters, WebSocket code, entities and `AesUtil.java` unchanged. Update `mbook-quarkus/README.md:28` to list `AccountController` for account/device routes and `NewsController` for `/rest/news`.

## 1. DB (T01): standalone RC; intermediate migration example

**Final product (USER-CONFIRMED): full standalone schema-and-data SQL dump**, planned new path `k8infra/mysql_8/screen_news_standalone_rc.sql`, owned by Database Engineer. No dump or RC is created now. The user confirms `k8infra/mysql_8/Dump20260524.sql` is the latest working dump and includes events. Record its checksum and preserve a separate untouched byte-for-byte copy, including user dirty content, before generation. The repository dump contents cover `login_` and do not include `book`; canonical `mysql_8/book.sql` is separate schema evidence, not proof of the current `book` data. Do not infer exhaustive dual-schema coverage from the user-confirmed baseline.

Generate the separate RC from the preserved source; never overwrite originals. Preserve complete source schema/seed/data, unrelated objects, triggers/routines, keys, charset/collation, the dual-schema boundary and booking guarantees; embed any identified required supplemental source. RC alone must import into a fresh empty MySQL target without source, migration or previous-schema dependencies. Only approved bounded changes are included; no automatic cleanup or preference hardening.

The following `k8infra/mysql_8/news_settings_unique_logins_id.sql` snippet illustrates the **intermediate migration delta only**, not the final RC or a prerequisite to its import. The existing `04-db-migration-runbook.md` describes separately authorized rollout considerations; its live-schema/preflight wording is not authority for this workflow to access working/live DBs.

```sql
-- Preflight: both queries must return 0 rows
SELECT logins_id, COUNT(*) FROM login_.news_settings GROUP BY logins_id HAVING COUNT(*) > 1;
SELECT id FROM login_.news_settings WHERE logins_id IS NULL;

ALTER TABLE login_.news_settings
  MODIFY logins_id INT NOT NULL,
  ADD UNIQUE KEY UK_NEWS_SETTINGS_LOGINS_ID (logins_id);

-- Reverse
-- ALTER TABLE login_.news_settings DROP INDEX UK_NEWS_SETTINGS_LOGINS_ID, MODIFY logins_id INT NULL;
```

## 2. mbook DAO: setting lookup and upsert (T02, T06)

```java
// DAO.java
@Transactional
public Optional<String> getNewsScreening(int loginsId) {
    return session.createQuery(
            "select n.newsScreening from NewsSettings n where n.user.id = :id", String.class)
        .setParameter("id", loginsId)
        .uniqueResultOptional();
}

@Transactional
public void upsertNewsScreening(Logins user, boolean enabled) {
    NewsSettings ns = session.createQuery(
            "from NewsSettings n where n.user.id = :id", NewsSettings.class)
        .setParameter("id", user.getId())
        .uniqueResult();
    if (ns == null) {
        ns = new NewsSettings();
        ns.setUser(user);               // add a setter; the field is protected today
    }
    ns.newsScreening = enabled ? "yes" : "no";
    session.persist(ns);
}
```

Entity addition (`NewsSettings` currently has no setter; `user` is protected and `newsScreening` is public):

```java
public void setUser(Logins user) {
    this.user = user;
}
```

`DAO.getUser` returns a placeholder with `id == 0` when the user is not found. Treat `id == 0` as "not found".

## 3. mbook `NewsSettingsController` (T02) — new

```java
import jakarta.enterprise.context.RequestScoped;

@Path("/rest/news-settings/screen")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@RequestScoped
public class NewsSettingsController {

    public record ScreenNews(Boolean enabled) {}

    @Inject AccountService accountService;
    @Inject NewsSettingsService newsSettingsService;   // wraps the DAO methods from §2
    @Inject ApiResponseFactory responses;

    @GET
    public Response get(@HeaderParam("user") String user) {
        try {
            Logins l = accountService.getUser(user);
            if (l.getId() == 0) return error(404, "user_not_found");
            String v = newsSettingsService.getNewsScreening(l.getId()).orElse("no");
            return switch (v) {
                case "yes" -> Response.ok(new ScreenNews(true)).build();
                case "no"  -> Response.ok(new ScreenNews(false)).build();
                default    -> error(500, "invalid_news_setting");
            };
        } catch (RuntimeException e) {
            return error(500, "db_error");
        }
    }

    @PUT
    public Response put(@HeaderParam("user") String user, ScreenNews body) {
        if (body == null || body.enabled() == null) return error(400, "invalid_body");
        try {
            Logins l = accountService.getUser(user);
            if (l.getId() == 0) return error(404, "user_not_found");
            newsSettingsService.upsertNewsScreening(l, body.enabled());
            return Response.ok(body).build();
        } catch (RuntimeException e) {
            return error(500, "db_error");
        }
    }

    private static Response error(int status, String code) {
        return Response.status(status).entity(Map.of("error", code)).build();
    }
}
```

### `service/NewsSettingsService.java` — new

```java
package com.jeet.service;

import com.jeet.api.Logins;
import com.jeet.db.DAO;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

import java.util.Optional;

@ApplicationScoped
public class NewsSettingsService {

    @Inject
    DAO dao;

    public Optional<String> getNewsScreening(int loginsId) {
        return dao.getNewsScreening(loginsId);
    }

    public void upsertNewsScreening(Logins user, boolean enabled) {
        dao.upsertNewsScreening(user, enabled);
    }

    public boolean isScreenNewsEnabled(int loginsId) {
        return dao.getNewsScreening(loginsId)
                .filter("yes"::equals)
                .isPresent();
    }
}
```

In `CookieFilter` (line 31) and `CiphertextFilter` (line 20), add `|| path.matches("^/?(rest/)?news-settings/screen$")` to the existing path condition (T03).

## 4. dalogin `AdminServlet` extension (T04)

**Dispatch:** use two exact servlet mappings. For the news route, `getServletPath()` is `/admin/newsSettings/screen` and `getPathInfo()` is null. Do not change the servlet mapping to `/admin/*`.

**Activation rule:** keep `performTask` and `handleActivationRequired` unchanged. When `checkActivation(user)` returns `"S"` on either route, the existing handler calls `AdminResponses.prepareActivationRequired(response, token2.get(0))`, builds the existing attributes and calls `callServiceAndRespond` for the account profile. The response remains **300**, with `Response: S`, `X-Token` and the existing account-profile body. It never calls the news-settings endpoint or mutates preferences, including on PUT. Do not introduce an activation-specific 403.

**AuthFilter already maps `/admin/*`**, not just `/admin`. It covers the new route; no filter edit is needed. Its actual no-session response is **502**. Preserve the existing filter/servlet checks and error paths as-is: add no session/device/user, token/token2 or activation-null guards.

### `dalogin-quarkus/src/main/java/com/dalogin/client/service/NewsSettings.java` — new

```java
package com.dalogin.client.service;

import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

@Path("/rest/news-settings/screen")
@Produces(MediaType.APPLICATION_JSON)
public interface NewsSettings {

    @GET
    Response getNewsScreen();

    @PUT
    @Consumes(MediaType.APPLICATION_JSON)
    Response putNewsScreen(String json);
}
```

### `client/ServiceClient.java` — additions inside the existing class

Add the import:

```java
import com.dalogin.client.service.NewsSettings;
```

Add the methods; no constructor or `RequestFilter` change:

```java
public Response callGetNewsScreen() {
    logOutboundRequest(
            "callGetNewsScreen", "GET", "/rest/news-settings/screen", Map.of()
    );
    NewsSettings newsSettingsService = target.proxy(NewsSettings.class);
    Response response = newsSettingsService.getNewsScreen();
    logOutboundResponse(
            "callGetNewsScreen", "GET", "/rest/news-settings/screen",
            response.getStatus()
    );
    return response;
}

public Response callPutNewsScreen(String json) {
    logOutboundRequest(
            "callPutNewsScreen", "PUT", "/rest/news-settings/screen", Map.of()
    );
    NewsSettings newsSettingsService = target.proxy(NewsSettings.class);
    Response response = newsSettingsService.putNewsScreen(json);
    logOutboundResponse(
            "callPutNewsScreen", "PUT", "/rest/news-settings/screen",
            response.getStatus()
    );
    return response;
}
```

The existing registered `RequestFilter` sends:

| Header | Source |
|---|---|
| `user` | Session attribute `user`, via `buildAttributes` |
| `token2` | `deviceSessionManager.getToken2(deviceId).get(0)`, via attributes |
| `TIME_` | `String.valueOf(session.getCreationTime())`, via attributes |
| `X-Token` | Incoming request header |
| `Ciphertext` | Incoming header; existing fallback to attribute `token2` when missing/empty |
| `Cookie` | Existing forwarding of incoming cookies, including `XSRF-TOKEN` |

PUT additionally sends `Content-Type: application/json`. Neither method accepts client-supplied identity parameters or logs the body/tokens.

### `servlets/AdminServlet.java` — minimal targeted edits

Add the import:

```java
import java.io.StringWriter;
```

Replace the annotation:

```java
@WebServlet(
        urlPatterns = {"/admin", "/admin/newsSettings/screen"},
        name = "AdminServlet"
)
```

Leave `doGet` unchanged. Add the constant and path helper, gate only news-route POST in `doPost`, and add `doPut` for the exact new route. Legacy `/admin` GET/POST still call `processRequest`; legacy PUT keeps superclass handling.

```java
private static final String NEWS_SCREEN_PATH = "/admin/newsSettings/screen";

private boolean isNewsSettingsRequest(HttpServletRequest request) {
    return NEWS_SCREEN_PATH.equals(request.getServletPath())
            && request.getPathInfo() == null;
}

@Override
protected void doPost(HttpServletRequest request, HttpServletResponse response)
        throws ServletException, IOException {
    if (isNewsSettingsRequest(request)) {
        response.setHeader("Allow", "GET, PUT");
        AdminResponses.error(response, 405, "Method not allowed");
        return;
    }
    processRequest(request, response);
}

@Override
protected void doPut(HttpServletRequest request, HttpServletResponse response)
        throws ServletException, IOException {
    if (isNewsSettingsRequest(request)) {
        processRequest(request, response);
        return;
    }
    super.doPut(request, response);
}
```

Do not replace `performTask` or duplicate its forwarding guards. Keep `processRequest`, `performTask`, `handleActivationRequired`, `buildAttributes` and `callServiceAndRespond` unchanged. The existing resolved token still controls entry into `handleLoginForActivedUser`, and is still passed to the legacy account-profile call.

In **`handleLoginForActivedUser` only**, replace its final two lines (attribute construction and account call) with the following. Its existing `getToken2(deviceId)` lookup and exception handling remain untouched; reuse those attributes without another token lookup or validation layer.

```java
Map<String, String> attributes = buildAttributes(session, user, token2.get(0));
if (isNewsSettingsRequest(request)) {
    callNewsSettingsAndRespond(response, request, attributes);
} else {
    callServiceAndRespond(response, request, user, token, attributes);
}
```

Add one method analogous to `callServiceAndRespond`, using the active handler's already-built attributes and the existing `ServiceClient` constructor/registered filters. NewsSettings has no token path parameter; `X-Token` continues to come from the incoming request via `RequestFilter`, not a new header override.

```java
private void callNewsSettingsAndRespond(
        HttpServletResponse response,
        HttpServletRequest request,
        Map<String, String> attributes
) throws IOException, CertificateException, KeyStoreException,
        NoSuchAlgorithmException, KeyManagementException {
    ServiceClient client = new ServiceClient(
            SystemConstants.getServiceUrl() + "/mbook-1",
            request,
            attributes
    );

    int status;
    String responseBody;
    String contentType;

    try {
        Response apiResponse;
        if ("PUT".equals(request.getMethod())) {
            StringWriter body = new StringWriter();
            request.getReader().transferTo(body);
            apiResponse = client.callPutNewsScreen(body.toString());
        } else {
            apiResponse = client.callGetNewsScreen();
        }

        try (Response upstream = apiResponse) {
            status = upstream.getStatus();
            contentType = "application/json";
            if (upstream.getMediaType() != null) {
                contentType = upstream.getMediaType().toString();
            }

            responseBody = "";
            if (upstream.hasEntity()) {
                responseBody = upstream.readEntity(String.class);
            }
        }
    } finally {
        client.close();
    }

    AdminResponses.newsSettingsDownstream(
            response, status, contentType, responseBody
    );
}
```

The raw PUT body—including malformed or empty input—is forwarded for **mbook** to validate. Do not reconstruct it, coerce `enabled`, or extract identity from it.

### `servlets/responsemap/AdminResponses.java` — addition only

Do not change `downstreamBody`: legacy `/admin` deliberately does not relay the downstream status.

```java
public static void newsSettingsDownstream(
        HttpServletResponse response,
        int statusCode,
        String contentType,
        String body
) throws IOException {
    response.setContentType(contentType);
    response.setCharacterEncoding(UTF_8);
    response.setStatus(statusCode);
    writeRaw(response, body);
}
```

### Status mapping

| Case | Gateway result |
|---|---|
| Active news request: any mbook response, including 200/400/403/404/500 | Same status and raw body; upstream content type retained. 403 remains an unrelated mbook filter rejection, not activation |
| Activation `"S"` on news route (GET or PUT) | Existing 300, `Response: S`, `X-Token` and account-profile body via unchanged `handleActivationRequired` → `prepareActivationRequired` → `callServiceAndRespond`; no news forwarding or preference mutation |
| No session rejected by existing AuthFilter | Existing 502/body; unchanged |
| Existing servlet checks/token2 lookup exceptions | Existing `performTask` and handler behavior unchanged; no news-specific checks or error mapping |
| Forwarding exception | Existing `processRequest` logged 502 handler |
| POST on news route | 405 and `Allow: GET, PUT`; no forwarding |
| Existing `/admin` GET/POST | Existing behavior, status, headers and body unchanged |
| Existing `/admin` PUT | Existing superclass handling unchanged |

## 5. mbook `WebSocketServer`: device registry (T06)

```java
@ServerEndpoint("/ws")
public class WebSocketServer {
    private static final ConcurrentHashMap<String, Set<Session>> byDevice = new ConcurrentHashMap<>();

    @OnOpen
    public void onOpen(Session session) throws IOException {
        String deviceId = session.getRequestParameterMap()
            .getOrDefault("deviceId", List.of()).stream().findFirst().orElse("").trim();
        if (deviceId.isEmpty()) {
            session.close(new CloseReason(CloseReason.CloseCodes.VIOLATED_POLICY, "deviceId required"));
            return;
        }
        session.setMaxIdleTimeout(0);
        session.getUserProperties().put("deviceId", deviceId);
        byDevice.computeIfAbsent(deviceId, k -> ConcurrentHashMap.newKeySet()).add(session);
    }

    @OnClose public void onClose(Session s) { remove(s); }
    @OnError public void onError(Session s, Throwable t) { remove(s); }
    @OnMessage public void onPong(PongMessage pong, Session s) { }

    public static Set<String> deviceIds() { return Set.copyOf(byDevice.keySet()); }

    public static void sendToDevice(String deviceId, String message) {
        for (Session s : byDevice.getOrDefault(deviceId, Set.of())) {
            try { s.getBasicRemote().sendText(message); }
            catch (IOException e) { remove(s); }
        }
    }

    // Kept for ios-users-notifications
    public static void broadcastMessage(String message) {
        byDevice.keySet().forEach(d -> sendToDevice(d, message));
    }

    private static void remove(Session s) {
        Object d = s.getUserProperties().get("deviceId");
        if (d == null) return;
        byDevice.computeIfPresent((String) d, (k, set) -> { set.remove(s); return set.isEmpty() ? null : set; });
    }
}
```

## 6. mbook `ActiveSessionResolver` (T05) — new

```java
@ApplicationScoped
public class ActiveSessionResolver {

    @ConfigProperty(name = "active-sessions.url") String url;   // simple-service-webapp /webapi/myresource/admin
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(2)).build();
    private final ObjectMapper mapper = new ObjectMapper();

    /** deviceId -> distinct users; throws on any failure. */
    public Map<String, Set<String>> deviceToUsers() throws IOException, InterruptedException {
        HttpRequest req = HttpRequest.newBuilder(URI.create(url)).timeout(Duration.ofSeconds(2)).GET().build();
        HttpResponse<String> resp = http.send(req, HttpResponse.BodyHandlers.ofString());
        if (resp.statusCode() != 200) throw new IOException("active sessions HTTP " + resp.statusCode());

        Map<String, Set<String>> out = new HashMap<>();
        for (JsonNode n : mapper.readTree(resp.body())) {        // [{id,sessionId,user,deviceId,creationTime}]
            String device = n.path("deviceId").asText(""), user = n.path("user").asText("");
            if (!device.isBlank() && !user.isBlank())
                out.computeIfAbsent(device, k -> new HashSet<>()).add(user);
        }
        return out;
    }
}
```

## 7. mbook `KafkaMoviesListener`: gated delivery (T06)

```java
@Inject NewsService news;
@Inject ActiveSessionResolver resolver;
@Inject AccountService accountService;
@Inject NewsSettingsService newsSettingsService;
@Inject ObjectMapper mapper;
```

The line-62 broadcast is replaced:

```java
for (ConsumerRecord<String, String> record : records) {
    AddMovie event = deserialization.deserializeAddMovie(record.value());
    news.saveNewEvent(event);
    deliverScreenNews(record.value());
}

private void deliverScreenNews(String raw) throws JsonProcessingException {
    Map<String, Set<String>> active;
    try {
        active = resolver.deviceToUsers();
    } catch (Exception e) {
        System.err.println("Screen news skipped, active sessions unavailable: " + e.getMessage());
        return;                                              // lookup failure: no delivery
    }
    String message = enrich(raw);
    for (String deviceId : WebSocketServer.deviceIds()) {
        Set<String> users = active.getOrDefault(deviceId, Set.of());
        if (users.size() != 1) continue;                     // unknown or ambiguous device
        Logins l = accountService.getUser(users.iterator().next());
        if (l.getId() == 0) continue;
        if (newsSettingsService.isScreenNewsEnabled(l.getId()))   // exactly "yes"
            WebSocketServer.sendToDevice(deviceId, message);
    }
}

private String enrich(String raw) throws JsonProcessingException {
    ObjectNode n = (ObjectNode) mapper.readTree(raw);        // wrap in try/catch in real code
    if (!n.hasNonNull("eventType")) n.put("eventType", "created");
    n.put("category", "screening");
    return n.toString();
}
```

## 8. mbooks: events and stopping the broadcast (T07)

```java
// VenueController: add, update and delete all publish only after the commit succeeds
AddMovie snapshot = toEvent(screen);          // for delete, capture before deleting
venueService.deleteScreen(id);                // throws if the commit fails
snapshot.setEventType("deleted");             // "created" | "updated" | "deleted"
producer.send("ios-movies-notifications2", serialize(snapshot));

// mbooks KafkaListener line 47: remove the WebSocketServer.broadcastMessage(...) call for screen news
```

## 9. iOS (T08, T09)

The settings methods below decode `ScreenNews` only after a successful 2xx response. A **300 activation body is an account profile, not `ScreenNews`**. Existing `APIClient.requestData(_:headers:)` handles 300 by throwing `AppError.activationRequired(voucherActive: false)` before decoding; iOS must use its existing activation response handling and must not treat that response as a successful settings read/save. No iOS application-code change is part of this documentation correction.

```swift
// WebSocketManager (BroadCasting/Websocket.swift)
var components = URLComponents(string: URLManager.webSocketURL)!
components.queryItems = [
    URLQueryItem(name: "deviceId", value: currentDeviceId())
]
webSocketTask = session.webSocketTask(with: components.url!)

// LoginGatewayService (Networking/BackendServices.swift) — new methods inside the class (`loginPath` is private there)
struct ScreenNews: Codable { let enabled: Bool }   // new DTO

func getNewsScreen() async throws -> ScreenNews {
    let endpoint = Endpoint(path: loginPath("admin/newsSettings/screen"), method: "GET", query: nil, body: nil, cacheKey: nil, absoluteURL: nil)
    let data = try await apiClient.requestData(endpoint, headers: session)
    return try JSONDecoder().decode(ScreenNews.self, from: data)
}

func putNewsScreen(_ enabled: Bool) async throws -> ScreenNews {
    let payload = try JSONEncoder().encode(ScreenNews(enabled: enabled))
    let endpoint = Endpoint(path: loginPath("admin/newsSettings/screen"), method: "PUT", query: nil, body: payload, cacheKey: nil, absoluteURL: nil)
    let headers = MergedHeaderProvider(base: session, extra: ["Content-Type": "application/json"])
    let data = try await apiClient.requestData(endpoint, headers: headers)
    return try JSONDecoder().decode(ScreenNews.self, from: data)
}

// MenuVC — new additions
@objc private func screenNewsChanged(_ sender: UISwitch) {
    let wanted = sender.isOn
    Task {
        do { _ = try await appServices.loginGateway.putNewsScreen(wanted) }
        catch { await MainActor.run { sender.setOn(!wanted, animated: true) } }   // revert on error
    }
}
```

`Endpoint`, `MergedHeaderProvider(base:extra:)` and `apiClient.requestData(_:headers:)` are the existing APIs (`Networking/Endpoint.swift`, `HeaderProvider.swift`); `loginPath` is the existing private helper in `LoginGatewayService`.

## 10. Validation (T10)

- Before implementation, capture original files as session `files/originals/<repo-relative-path>.txt` (T-preflight), including current uncommitted content. Never overwrite originals; mark new files as `new`. Keep these separate from staged replacements.
- Static dry run: compare originals with final contents, including new/deleted files, against the T00 preservation list and plan §3. Confirm routes, filter regex, headers, JSON keys and the minimal AdminServlet adaptation (activation `"S"` returns existing 300 without subscription mutation).
- Database Engineer statically compares the RC with the confirmed preserved working source and canonical `mysql_8` scripts; record actual final model → table/column → DAO write mappings and checks from T10 (annotation/implicit naming, type/length/nullability, ids/generation/defaults, FKs, uniqueness, String yes/no). In particular T07's `eventType` on mbook's persisted `AddMovie` must align with its final persistence/transient treatment; do not invent a SQL column from the wire DTO. This model/schema check remains required, but the user-reported source-code/event-sending validation does not call for repeat event-sending runtime validation in the RC gate.
- Run `./mvnw -q -DskipTests compile` in `mbook-quarkus`, `mbooks-quarkus` and `dalogin-quarkus`.
- Static inspection must find no `BookingHandlerImpl`/`BookController` references in mbook source. Review iOS statically only; Swift compilation is not covered.
- Application validation remains compile-only; no Java/runtime tests, `swiftc`, `xcodebuild`, application service startup or deployment. Run compiles after all edits, then triage failures.
- Required bounded SQL exception, only after all edits/static model matching and before T12: Database Engineer imports RC alone into a fresh empty isolated disposable MySQL 8 target, verifies all source data/schema objects intact, FK integrity and duplicate/NULL/orphan owner/invalid preference preflight, then records valid model-shaped insertion/update/commit/re-read, generated ids/defaults, trigger behavior and duplicate/NULL/missing-owner rejection. No silent cleanup, unapproved CHECK/defaults or working/live migration. See T10 for full acceptance checks.
- Because source dumps contain `CREATE DATABASE`/`USE`, qualified names and definers, another default schema is not safe isolation. Use a disposable instance with no live connectivity/credentials, or reviewed fully retargeted references with grants confined to disposable schemas. Only SQL-harness MySQL startup is allowed. Real ORM roundtrip is optional when feasible without application startup/Java tests; otherwise matching parameterized SQL and re-read are required, explicitly reported as SQL evidence rather than ORM/API runtime proof.
- T12: Backend Engineer reviews successful compiles, final model alignment and Database Engineer's executed full-import/insertion evidence tied to the final RC checksum. Failures/findings require scoped fixes, RC regeneration/static matching and fresh-target retest when impacted, not target hand repairs; rerun affected compiles and obtain final approval. Static review alone cannot accept the RC.

T11 (optional future scenarios; separate approval, after T10 and T12): run the existing RestAssured login→admin smoke tests (`k8infra/api-smoke-restassured` `LoginApiTest`/`AdminApiTest`), then the manual scenario. The user's report of prior source-code/event-sending validation does not mark T11 complete or make it a repeat T10/RC gate. No k6, no new tests, no news-settings automation.
T11 includes no restore/migration over working/live schemas; rollout requires distinct explicit authorization. This documentation turn executes nothing and leaves telemetry disabled.
