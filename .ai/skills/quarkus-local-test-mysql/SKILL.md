# Quarkus Local Test with Local MySQL

## Purpose

Run `@QuarkusTest` suites for `dalogin-quarkus`, `mbooks-quarkus`, and `mbook-quarkus` on this Mac
against the locally installed MySQL, without Minikube, containers, or the Apache reverse proxy.
Establish that MySQL is up before running anything, and stop and ask the user when it is not.

## Use When

- You need to run or debug a Quarkus test locally, for example `LoginFlowTest` in `dalogin-quarkus`.
- You need a fast backend check during a refactor and do not want a cluster round-trip.
- A test fails with a bind, connection, or proxy error and you need the local-environment cause.
- You are validating a persistence change that must talk to the real `login_` or `book` schema.

## Do Not Use When

- You need deployed-environment smoke coverage (use `api-smoke-restassured`).
- You need cluster behavior, ingress, or service-name resolution (use `k8s-deploy-verify`).
- The task is frontend-only with no backend test execution.

## Inputs

- Required: module directory (`dalogin-quarkus`, `mbooks-quarkus`, or `mbook-quarkus`).
- Required: test class, or test method selector, to run.
- Required: `k8infra/settings-local.xml` for Maven dependency resolution.
- Optional: whether the downstream `mbook` service is needed by the chosen test.

## Outputs

- A pass/fail result for the selected test.
- When MySQL is down: an explicit prompt to the user, and no test run.
- Failure localization pointing at the specific local cause (port, proxy, schema, or datasource).

## Local Environment (verified on this machine)

MySQL is **not** a Homebrew package. It is the Oracle macOS installation:

| Fact | Value |
| --- | --- |
| Install root | `/usr/local/mysql` |
| Client binary | `/usr/local/mysql/bin/mysql` |
| Runs as user | `_mysql` |
| Unix socket | `/tmp/mysql.sock` |
| TCP | `*:3306` |
| Managed by | macOS System Settings pane or `mysql.server`, **not** `brew services` |

Homebrew *does* manage `httpd`, which is started and owns ports `8080` and `80`. Do not confuse the
two: `brew services list` shows `httpd` but will never show `mysql`.

Schemas and ports:

| Module | Schema | Dev port | Notes |
| --- | --- | --- | --- |
| `dalogin-quarkus` | `login_` | *(unset → 8080)* | Collides with Apache; see Pitfall 2 |
| `mbook-quarkus` | `login_` | `8888` | Downstream for some dalogin tests |
| `mbooks-quarkus` | `book` | `9000` (dev override) | Defaults to 8080 if not overridden |

Datasource credentials live in each module's `src/main/resources/application.properties`. Read them
from there; never restate them in code, docs, or commands.

## Constraints

- **Never start or restart MySQL automatically.** If it is not running, stop and prompt the user.
  MySQL here is a shared machine-level service that may hold other work; starting it is the user's
  decision.
- Never fall back to Dev Services, Testcontainers, or a container MySQL to work around a down
  database. A silent container swap produces a green test against the wrong data.
- Never modify `application.properties` to make a test pass. Pass overrides on the command line.
- Always build with `-s k8infra/settings-local.xml`. The default `~/.m2/settings.xml` points at a
  corporate Nexus that is unreachable off VPN.
- Never delete `_remote.repositories` markers or `.lastUpdated` files to force offline resolution.
  Use the settings file instead; editing resolver internals corrupts the shared local repository.
- Do not require Apache, `mbook`, or `mbooks` for a test that does not need them.

## Workflow

### 1. Check MySQL before anything else

`lsof` is unreliable here: MySQL runs as `_mysql`, so `lsof -iTCP:3306` prints **nothing even when
MySQL is running**. Use a TCP probe:

```bash
nc -z -G 2 127.0.0.1 3306 && echo "mysql UP" || echo "mysql DOWN"
```

Confirm it actually answers queries, not just that the port is open:

```bash
/usr/local/mysql/bin/mysql -u sqluser -p"$(grep -m1 'quarkus.datasource.password' \
  dalogin-quarkus/src/main/resources/application.properties | cut -d= -f2)" \
  -e "SELECT 1;" >/dev/null 2>&1 && echo "mysql ANSWERS" || echo "mysql NOT ANSWERING"
```

### 2. If MySQL is not running, stop and prompt the user

Do not start it. Ask, and wait:

> MySQL is not running on `127.0.0.1:3306`. It is the Oracle install at `/usr/local/mysql`, not a
> Homebrew service, so I will not start it for you. Start it via System Settings → MySQL → Start,
> or with `sudo /usr/local/mysql/support-files/mysql.server start`, then tell me to continue.

Offer the choices: start it yourself and retry, skip the DB-dependent tests, or cancel. Resume only
after the user confirms.

### 3. Confirm the schema the test needs

```bash
/usr/local/mysql/bin/mysql -u sqluser -p<from-properties> -e "SHOW DATABASES;"
```

Expect `login_` and `book`. For `dalogin` login tests, confirm the fixture user exists and the
stored procedures are loaded — the suite calls them, so an empty schema fails confusingly. On a
healthy machine this returns `GI` and `24`:

```bash
/usr/local/mysql/bin/mysql -u sqluser -p<from-properties> login_ \
  -e "SELECT user FROM logins WHERE user='GI';"
/usr/local/mysql/bin/mysql -u sqluser -p<from-properties> -N \
  -e "SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema='login_';"
```

Note the table is `logins`, not `users` — `login_.users` does not exist.

### 4. Run the test with the project settings file and a free port

```bash
cd dalogin-quarkus
./mvnw -s ../k8infra/settings-local.xml test \
  -Dtest='LoginFlowTest#loginSuccess+loginBadHmac+loginWrongPassword' \
  -Dquarkus.http.test-port=0
```

Both flags are mandatory on this machine: `-s ../k8infra/settings-local.xml` for dependency
resolution (Pitfall 7) and `-Dquarkus.http.test-port=0` for the port (Pitfall 1).

Verified result of exactly this command:

```
Tests run: 3, Failures: 0, Errors: 0, Skipped: 0, Time elapsed: 2.927 s
```

Read the outcome from the report rather than scrolling the console — the suite logs heavily at
DEBUG, and `-q` does not suppress application logging:

```bash
cat target/surefire-reports/com.dalogin.servlets.LoginFlowTest.txt
```

### 5. Interpret the failure against the pitfalls below before touching application code

## Local Pitfalls (each verified on this machine)

**1. Port 8081 is occupied — the Quarkus default test port.**
Something owned by another user listens on `*:8081` and does not speak HTTP. `lsof` cannot see it.
A `@QuarkusTest` that binds the default test port fails before any test body runs. Always pass
`-Dquarkus.http.test-port=0` to get an ephemeral port, the same fix
`simple-service-webapp-quarkus/src/test/resources/application.properties` already hardcodes.

**2. `dalogin-quarkus` dev mode collides with Apache on 8080.**
`dalogin-quarkus/src/main/resources/application.properties` sets `quarkus.http.root-path=/login` but
no `quarkus.http.port`, so dev mode defaults to `8080` — which Homebrew `httpd` already owns. Run
dev mode on another port instead of stopping Apache:

```bash
./mvnw quarkus:dev -Dquarkus.http.port=9100
```

This affects `quarkus:dev` only. Tests are unaffected once step 4's `test-port=0` is used.

**3. There is no `%test` profile in any module.**
Tests run against the **real local development database**, not a throwaway one. `LoginFlowTest`
writes sessions, devices, and tokens into `login_`. Treat local data as mutable during a test run,
and never point a test at a schema whose contents matter.

**4. Do not blanket-disable the proxy for a Maven run.**
`http_proxy` / `https_proxy` are exported by the login shell. It is tempting to run `proxy_off`, but
Maven needs network access to resolve dependencies, and unsetting the proxy changes which of Nexus
or Maven Central is reachable. Scope the bypass to the traffic that needs it: use
`curl --noproxy '*'` for localhost probes, and control Maven with `-s ../k8infra/settings-local.xml`
rather than by editing environment variables.

**5. `brew services` does not list MySQL.**
Only `httpd` (and stopped `colima`/`podman`/`unbound`) appear. Absence of `mysql` there says
nothing about whether MySQL is running. Use the TCP probe in step 1.

**6. `LoginFlowTest#loginThenRetrieveUser` needs `mbook` on 8888.**
The rest of the class does not. When only the login path matters, select the DB-only methods:

```bash
./mvnw -s ../k8infra/settings-local.xml test -Dquarkus.http.test-port=0 \
  -Dtest='LoginFlowTest#loginSuccess+loginBadHmac+loginWrongPassword'
```

**7. The default Maven settings point at an unreachable corporate Nexus.**
Without `-s`, resolution fails with `nexus.devspace-dev.lhsystems.int: nodename nor servname
provided` when off VPN, or `Cannot access ... in offline mode` with `-o`. Artifacts already cached
in `~/.m2` are still refused, because their `_remote.repositories` markers bind them to the `central`
repository id. The fix is `-s ../k8infra/settings-local.xml`, which maps `central` straight to
`repo1.maven.org`. Do **not** work around this by deleting `_remote.repositories` or `.lastUpdated`
files.

**8. `-q` does not silence the application.**
`dalogin-quarkus` logs its listeners and connection acquisitions at DEBUG/INFO, so a passing run
still prints hundreds of lines and the summary scrolls away. Read
`target/surefire-reports/com.dalogin.servlets.LoginFlowTest.txt` for the verdict.

## Validation Checklist

- [ ] MySQL reachability was probed with `nc`/`netstat`, not `lsof`.
- [ ] MySQL was confirmed to answer a query, not merely hold the port open.
- [ ] If MySQL was down, the user was prompted and nothing was auto-started.
- [ ] No container, Dev Services, or Testcontainers fallback was used.
- [ ] The required schema and fixtures were confirmed before running.
- [ ] `-s ../k8infra/settings-local.xml` was passed.
- [ ] `-Dquarkus.http.test-port=0` was passed.
- [ ] The verdict was read from the surefire report, not the console tail.
- [ ] No `_remote.repositories` or `.lastUpdated` file was deleted.
- [ ] `mbook`/`mbooks`/Apache were started only if the selected test actually needs them.
- [ ] No `application.properties` file was edited to make the test pass.
