---
agent: 'Cinemas Testing Engineer'
tools: ['search/codebase', 'refactor', 'test', 'analyze', 'debug', 'java', 'appium']
description: 'Perform maintenance and configuration cleanup for Appium iOS automation framework'
---

# Role
You are an expert test engineer.

# Task: Appium iOS Framework Maintenance and Configuration Cleanup

Please review the entire Appium iOS automation framework and perform a cleanup/refactoring focused only on configuration management and device selection logic.

## Scope

This is a maintenance task.

Goals:

- Simplify and centralize configuration handling.
- Improve CI compatibility.
- Preserve local execution support.
- Remove duplicated or unnecessarily complex property resolution.
- Refactor for maintainability and readability.
- Do NOT add new features.
- Do NOT change test behavior.
- Do NOT redesign the framework architecture.
- Do NOT introduce new dependencies unless absolutely required.

---

## Areas to Review

### DeviceConfiguration.java

Currently this class discovers connected devices.

Refactor it so that:

1. Physical connected devices continue to work exactly as today.
2. Booted iOS simulators are also supported.
3. If multiple booted simulators are present:
    - Select the simulator running the highest iOS version.
    - Keep the selection logic deterministic and easy to understand.
4. Avoid duplicated device-discovery logic.
5. Separate device discovery from property resolution if currently mixed together.
6. Improve naming, structure, and logging where beneficial.

Important:

- Preserve existing execution behavior wherever possible.
- This is a cleanup/refactor, not a redesign.

---

### DriverManager.java

Review capability construction and configuration loading.

Goals:

1. Centralize capability-related configuration.
2. Remove duplicated property lookups.
3. Minimize scattered System.getProperty() usage.
4. Make CI and local execution follow the same configuration flow.
5. Simplify capability creation without changing resulting capabilities.
6. Improve readability and maintainability.

Important:

- Preserve current capability values and behavior.
- Refactor only where it improves clarity and consistency.

---

## Maven / Property Handling Review

Review the property flow between:

- pom.xml
- TestNG XML files
- Java configuration classes

Current surefire configuration:

```xml
<configuration>
    <suiteXmlFiles>
        <suiteXmlFile>${testngXml}</suiteXmlFile>
    </suiteXmlFiles>

    <systemPropertyVariables>
        <sim.device>${sim.device}</sim.device>
        <sim.version>${sim.version}</sim.version>
        <sim.udid>${sim.udid}</sim.udid>

        <appium.host>${appium.host}</appium.host>
        <appium.port>${appium.port}</appium.port>
        <appium.basePath>${appium.basePath}</appium.basePath>
    </systemPropertyVariables>
</configuration>
```

There are also TestNG XML files involved.

Please:

1. Trace the complete configuration flow:
    - Maven properties
    - Surefire systemPropertyVariables
    - TestNG XML parameters
    - Java classes

2. Identify:
    - redundant properties
    - duplicated configuration sources
    - unnecessary property forwarding
    - overlapping Maven/TestNG responsibilities

3. Recommend and implement a cleaner configuration approach that:
    - works in CI
    - works locally
    - keeps backward compatibility where reasonable
    - follows a single clear precedence order

4. Document the final precedence order explicitly, for example:

    1. JVM System Property
    2. TestNG Parameter
    3. Framework Default

   (Use whatever order best matches the framework.)

---

## Deliverables

Provide:

### 1. Findings

Explain:

- current issues discovered
- duplicated configuration paths
- maintainability concerns
- unnecessary complexity

### 2. Refactoring Plan

Describe:

- what was changed
- why it was changed
- why behavior remains equivalent

### 3. Code Changes

Apply only the required refactoring.

### 4. Final Configuration Model

Document:

- supported properties
- precedence order
- CI usage
- local usage

---

## Constraints

- Refactor only.
- No feature development.
- No test redesign.
- No framework migration.
- No changes to test scenarios.
- No changes to reporting.
- No changes to Appium version unless required by compilation.

When multiple options exist, prefer the simplest solution with the smallest behavioral change.
