# CI/CD Architecture for Apache Hop on ROSA

## 1. Purpose

This document captures the CI/CD discussion and proposed
production-ready architecture for the Apache Hop on ROSA platform.

The central design principle is:

> **Build once → validate → promote the same immutable artifact.**

The pipeline separates: - building an artifact, - assessing its
quality, - deciding whether it is eligible to progress, - and releasing
to production.

This avoids rebuilding between environments and provides
reproducibility, auditability, and controlled promotion.

------------------------------------------------------------------------

## 2. The Two Main Questions

### 2.1 What should happen when unit tests fail?

Two competing arguments were considered.

#### Option A --- Stop before building the image

Advantages: - avoids creating artifacts known to be broken; - avoids
unnecessary Artifactory storage; - gives a simple red/green CI pipeline.

Disadvantages: - there may be no exact container image representing the
failed build; - reproducing the problem can become harder; - the source
tree may not perfectly represent the runtime image that would have been
produced.

#### Option B --- Build regardless

Advantages: - creates the exact artifact that can be inspected and used
to reproduce the problem; - supports debugging against the actual
container image; - keeps build reproducibility strong.

Disadvantage: - if every failed build is permanently stored, Artifactory
becomes polluted with unusable artifacts.

### Recommended compromise

**Build the image, but do not treat it as an approved artifact.**

If the mandatory checks fail, the image can be placed into a short-lived
**quarantine/diagnostic repository** and automatically deleted after a
retention period.

This gives both: - reproducibility for debugging; and - a clean
permanent artifact store.

------------------------------------------------------------------------

## 3. Automated Code Review Findings

The same principle applies to automated code review.

A critical finding does not necessarily mean:

> "The image cannot be built."

Instead:

> "The image is not eligible to progress."

Recommended policy:

  Condition                         Build                  Artifact            Promotion
  ------------------------------- ------- ------------------------- --------------------
  Unit tests pass                     Yes                 Validated              Allowed
  Unit test fails                     Yes                Quarantine              Blocked
  No code-review findings             Yes                 Validated              Allowed
  Low finding                         Yes                 Validated              Allowed
  Medium finding                      Yes                 Validated        Review/policy
  High finding                        Yes   Validated or quarantine   Blocked / approval
  Critical finding                    Yes   Validated or quarantine          **Blocked**
  Mandatory scanner unavailable     Maybe                Diagnostic          **Blocked**
  No tests found                      Yes          Policy-dependent      Usually blocked

The exact severity thresholds should be configurable as policy rather
than hard-coded throughout the pipeline.

------------------------------------------------------------------------

# 4. Core Architecture

``` mermaid
flowchart LR
    A[Bitbucket<br/>Commit / PR] --> B[Build & Compile]
    B --> C[Unit Tests]
    C --> D[Build Container Image]

    D --> E[Automated Code Review]
    E --> F[Security / Dependency Checks]
    F --> G[Quality Gate]

    G -->|PASS| H[Validated Artifact Repository]
    G -->|FAIL| I[Quarantine / Diagnostic Repository]

    H --> J[DEV]
    J --> K[TEST]
    K --> L[UAT]
    L --> M[PROD]

    I --> N[Auto-clean after short TTL]
```

## 4.1 Important distinction

The pipeline should distinguish:

``` text
Build
  ≠
Quality Gate
  ≠
Environment Promotion
  ≠
Production Release
```

A build can exist without being eligible for promotion.

------------------------------------------------------------------------

# 5. Recommended Artifact Lifecycle

``` mermaid
flowchart TD
    A[Source Commit] --> B[Build / Compile]
    B --> C[Unit Tests]
    C --> D[Build Image]
    D --> E[Immutable Image Digest]

    E --> F{Quality Gate}

    F -->|PASS| G[hop-validated]
    F -->|FAIL| H[hop-quarantine]

    G --> I[DEV]
    I --> J[TEST]
    J --> K[UAT]
    K --> L[PROD]

    H --> M[Diagnostic / Debugging]
    H --> N[Automatic Cleanup]
```

The **image digest** is the authoritative identity of the artifact.

Example:

``` text
sha256:abc123...
```

Tags are human-friendly labels, but should not be the source of truth
for artifact identity.

------------------------------------------------------------------------

# 6. Artifactory Repository Design

Use two logical repositories rather than relying only on tags.

``` text
Artifactory
│
├── hop-validated/
│   ├── platform/
│   ├── finance/
│   └── policy/
│
└── hop-quarantine/
    ├── platform/
    ├── finance/
    └── policy/
```

## 6.1 Validated repository

Purpose: - contains artifacts that passed the mandatory CI quality
gates; - artifacts can progress through environments; - longer
retention; - immutable artifact identity; - suitable for environment
promotion.

Example:

``` text
hop-validated/platform
    image digest:
    sha256:abc123...
```

## 6.2 Quarantine repository

Purpose: - contains failed or blocked CI artifacts; - supports debugging
and reproduction; - short retention; - automatic cleanup.

Possible failure reasons:

``` text
UNIT_TEST_FAILED
CODE_REVIEW_CRITICAL
SECURITY_SCAN_FAILED
DEPENDENCY_CHECK_FAILED
MIGRATION_VALIDATION_FAILED
OTHER_POLICY_FAILURE
```

A quarantine artifact should also retain useful metadata such as: -
commit SHA; - pipeline/build ID; - failure reason; - test report; -
code-review report; - scan results; - image digest; - timestamps.

------------------------------------------------------------------------

# 7. Why Separate Repositories Instead of Only Tags?

A tag such as:

``` text
stable
quarantine
failed
```

is useful as a human-readable label, but tags can be mutable.

The stronger model is:

``` text
Repository = lifecycle boundary
Digest     = immutable identity
Tag        = human-friendly label
Policy     = promotion authority
```

Therefore:

> **Do not make a `stable` tag the mechanism that authorises production
> deployment.**

Instead, the promotion system should verify the artifact digest and its
quality-gate status.

------------------------------------------------------------------------

# 8. Build Once, Promote the Same Image

The same image digest should be used across all environments.

``` mermaid
flowchart LR
    A[Image<br/>sha256:ABC123] --> B[DEV]
    B --> C[TEST]
    C --> D[UAT]
    D --> E[PROD]

    B -. same digest .-> C
    C -. same digest .-> D
    D -. same digest .-> E
```

There should be **no rebuild between environments**.

Bad pattern:

``` text
Build → DEV
        ↓
      rebuild → TEST
        ↓
      rebuild → PROD
```

Preferred pattern:

``` text
Build once
   ↓
sha256:ABC123
   ↓
DEV → TEST → UAT → PROD
```

This eliminates configuration/build drift caused by rebuilding.

------------------------------------------------------------------------

# 9. Promotion Should Be the Central Quality Decision

Individual tools should produce evidence.

For example:

``` text
Unit Tests
    ↓
PASS / FAIL

Code Review
    ↓
Findings

Security Scan
    ↓
Vulnerabilities

Complexity Analysis
    ↓
Score

Semantic Log Comparison
    ↓
PASS / FAIL

Migration Validation
    ↓
PASS / FAIL
```

A central quality gate consumes these results.

``` mermaid
flowchart TD
    A[Unit Test Results] --> G[Central Quality Gate]
    B[Code Review Findings] --> G
    C[Security Scan] --> G
    D[Dependency Scan] --> G
    E[Migration Validation] --> G
    F[Complexity / Quality Metrics] --> G

    G --> H{Policy Decision}

    H -->|Eligible| I[Promote]
    H -->|Blocked| J[Quarantine / Stop Promotion]
```

This is preferable to having every individual tool independently control
Jenkins.

------------------------------------------------------------------------

# 10. Quality Gate Policy

A configurable policy could look like:

``` text
Unit test failure       → BLOCK
Critical finding        → BLOCK
High finding             → BLOCK
Medium finding           → REVIEW / APPROVAL
Low finding              → ALLOW
Mandatory scanner down   → BLOCK
No tests found           → BLOCK or policy exception
```

The exact thresholds should be centrally managed.

This allows policy to evolve without redesigning the pipeline.

------------------------------------------------------------------------

# 11. Exception Management

A production CI/CD system needs an explicit exception process.

For example:

``` mermaid
flowchart TD
    A[Quality Gate Blocked] --> B[Exception Request]
    B --> C[Provide Reason / Evidence]
    C --> D[Authorised Review]
    D --> E{Approved?}

    E -->|No| F[Remain Blocked]
    E -->|Yes| G[Time-Bound Exception]
    G --> H[Audit Record]
    H --> I[Allow Promotion]
```

An exception should record:

-   finding;
-   severity;
-   reason;
-   impact;
-   requester;
-   approver;
-   approval timestamp;
-   expiry date;
-   affected artifact digest;
-   ticket/reference.

Exceptions should be **time-bound**.

Avoid manual Jenkins configuration changes as a bypass mechanism.

------------------------------------------------------------------------

# 12. Fail-Closed for Critical Controls

For mandatory security or quality checks:

``` text
Scanner works + finding = BLOCK if policy requires it

Scanner unavailable = BLOCK
```

Otherwise the pipeline could effectively say:

> "We could not determine whether this artifact is safe, so deploy it
> anyway."

For critical controls, fail-closed is the safer enterprise policy.

------------------------------------------------------------------------

# 13. Housekeeping and Retention

The separation makes cleanup straightforward.

### Quarantine

Example policy:

``` text
Retention: 1–3 days
Automatic cleanup: Yes
Purpose: diagnostics / reproduction
```

### Validated

Example:

``` text
Retention: 30–90 days
Purpose: environment promotion / rollback
```

### Production

Retention should follow the organisation's production release and
rollback policy.

``` mermaid
flowchart TD
    A[Quarantine Repository] --> B[Scheduled Cleanup]
    B --> C{Older than TTL?}
    C -->|Yes| D[Delete]
    C -->|No| E[Keep]

    F[Validated Repository] --> G[Normal Artifact Retention]
    G --> H[Cleanup according to policy]
```

The exact retention periods should be agreed with
platform/security/governance teams.

------------------------------------------------------------------------

# 14. Production Promotion Flow

``` mermaid
sequenceDiagram
    participant Dev as Developer
    participant BB as Bitbucket
    participant CI as CI Pipeline
    participant AR as Artifactory
    participant QG as Quality Gate
    participant ROSA as ROSA
    participant PROD as Production

    Dev->>BB: Commit / Pull Request
    BB->>CI: Trigger pipeline

    CI->>CI: Build & compile
    CI->>CI: Run unit tests
    CI->>CI: Build container image
    CI->>CI: Run automated code review
    CI->>CI: Run security / dependency checks

    CI->>QG: Submit assessment results

    alt Quality Gate PASS
        QG->>AR: Store in validated repository
        AR->>ROSA: Deploy same image digest to DEV
        ROSA->>ROSA: Test / validation
        ROSA->>ROSA: Promote same digest to TEST
        ROSA->>ROSA: Promote same digest to UAT
        ROSA->>PROD: Promote approved same digest
    else Quality Gate FAIL
        QG->>AR: Store in quarantine repository
        AR->>CI: Mark non-promotable
        CI->>CI: Retain diagnostics temporarily
    end
```

------------------------------------------------------------------------

# 15. Example Image Identity

Suppose CI creates:

``` text
Image:
hop-app

Digest:
sha256:abc123456789...
```

The image should move through the lifecycle as the same immutable
digest:

``` text
sha256:abc123...
      │
      ├── DEV
      ├── TEST
      ├── UAT
      └── PROD
```

A human-friendly tag can exist:

``` text
build-1842
```

or:

``` text
validated
```

but the deployment mechanism should ultimately resolve and verify:

``` text
sha256:abc123...
```

------------------------------------------------------------------------

# 16. Rollback

Rollback becomes simple because previous validated image digests are
known.

``` mermaid
flowchart LR
    A[PROD<br/>sha256:NEW] --> B[Incident]
    B --> C[Select Previous Validated Digest]
    C --> D[sha256:PREVIOUS]
    D --> E[Deploy Previous Image]
```

There is no need to rebuild the previous version.

The deployment system can simply reference a previously validated image
digest.

------------------------------------------------------------------------

# 17. Security and Supply-Chain Enhancements

For a mature enterprise implementation, consider adding:

-   container vulnerability scanning;
-   SBOM generation;
-   dependency scanning;
-   image signing;
-   signature verification before deployment;
-   provenance/attestation;
-   least-privilege service accounts;
-   secrets management;
-   immutable artifact policy;
-   audit logging;
-   environment-specific deployment permissions.

Conceptually:

``` mermaid
flowchart LR
    A[Build] --> B[Image]
    B --> C[Vulnerability Scan]
    C --> D[SBOM]
    D --> E[Sign / Attest]
    E --> F[Quality Gate]
    F --> G[Promote]
    G --> H[Verify Before Deploy]
```

------------------------------------------------------------------------

# 18. Observability and Auditability

The pipeline should retain enough information to answer:

> What exactly is running in PROD?

and:

> Why was this artifact allowed to get there?

Useful records include:

``` text
Application / Project
Commit SHA
Pipeline ID
Build ID
Image digest
Image tag
Unit-test result
Code-review result
Security scan result
Quality-gate decision
Exception / approval
Promotion history
Deployment timestamp
Environment
Deployment result
```

A useful audit chain is:

``` text
Commit
  ↓
Pipeline
  ↓
Image Digest
  ↓
Quality Results
  ↓
Quality Gate
  ↓
DEV
  ↓
TEST
  ↓
UAT
  ↓
PROD
```

------------------------------------------------------------------------

# 19. Relationship to the Hop on ROSA Platform

For the existing Hop on ROSA migration, this pattern fits the
architecture where:

-   Bitbucket contains source and configuration;
-   Jenkins performs CI/CD;
-   container images are built centrally;
-   Artifactory provides artifact storage;
-   ROSA runs the workloads;
-   Control-M can continue triggering runtime workloads;
-   image identity is immutable;
-   deployment uses the approved image rather than rebuilding it.

The same quality-gate concept can later incorporate project-specific
checks such as:

-   Hop migration validation;
-   complexity analysis;
-   semantic log comparison;
-   before/after payload comparison;
-   configuration validation;
-   plugin compatibility checks;
-   migration exception checks.

------------------------------------------------------------------------

# 20. Recommended End-to-End Architecture

``` mermaid
flowchart TB
    subgraph SCM["Source Control"]
        BB[Bitbucket]
    end

    subgraph CI["CI / Assessment"]
        BUILD[Build & Compile]
        TEST[Unit Tests]
        IMAGE[Build Container Image]
        REVIEW[Automated Code Review]
        SEC[Security / Dependency Scan]
        MIG[Hop Migration Validation]
    end

    subgraph ART["Artifactory"]
        VALID[hop-validated<br/>Production-eligible]
        QUAR[hop-quarantine<br/>Short-lived diagnostics]
    end

    subgraph GATE["Quality Governance"]
        QG[Central Quality Gate]
        EX[Exception Management]
    end

    subgraph ROSA["ROSA"]
        DEV[DEV]
        TESTENV[TEST]
        UAT[UAT]
        PROD[PROD]
    end

    BB --> BUILD
    BUILD --> TEST
    TEST --> IMAGE
    IMAGE --> REVIEW
    IMAGE --> SEC
    IMAGE --> MIG

    TEST --> QG
    REVIEW --> QG
    SEC --> QG
    MIG --> QG

    QG -->|PASS| VALID
    QG -->|FAIL| QUAR

    VALID --> DEV
    DEV --> TESTENV
    TESTENV --> UAT
    UAT --> PROD

    QG --> EX
    EX -->|Approved exception| VALID

    QUAR --> CLEAN[Auto-clean / TTL]
```

------------------------------------------------------------------------

# 21. Final Design Principles

### Principle 1 --- Build once

Create the container image once in CI.

### Principle 2 --- Immutable identity

Use the image digest as the authoritative identity.

### Principle 3 --- Validate before progression

Tests, code review, security, and other checks feed a central quality
gate.

### Principle 4 --- Build does not equal promotion

A technically buildable artifact can still be blocked from progressing.

### Principle 5 --- Keep permanent artifact storage clean

Use separate validated and quarantine repositories.

### Principle 6 --- Quarantine is temporary

Failed artifacts exist long enough to diagnose and reproduce failures,
then are automatically cleaned up.

### Principle 7 --- Never rebuild between environments

DEV → TEST → UAT → PROD should use the same image digest.

### Principle 8 --- Production is not a tag

A `stable` or similar tag is a label, not the authoritative
production-approval mechanism.

### Principle 9 --- Exceptions are explicit

Critical findings can only be bypassed through an authorised, auditable,
time-bound exception.

### Principle 10 --- Fail closed for mandatory critical controls

If a mandatory security or quality assessment cannot run, promotion
should be blocked.

------------------------------------------------------------------------

# 22. Recommended One-Line Architecture Statement

> **CI builds an immutable container image once, assesses it through
> automated quality gates, stores failed builds temporarily in
> quarantine, stores validated artifacts separately, and promotes the
> exact same image digest through DEV → TEST → UAT → PROD without
> rebuilding.**

This is the core architecture to take into a production CI/CD design
review.
