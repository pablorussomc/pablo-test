# Medplum Helm Chart - Codebase Analysis & Improvement Recommendations

## Overview

This repository contains a **Helm chart for Medplum**, a healthcare platform designed for deployment on Kubernetes. The chart is currently optimized for **Google Cloud Platform (GCP)** with plans to support AWS and Azure in the future.

### Repository Structure

```
charts/medplum/
├── Chart.yaml                    # Chart metadata (v0.1.2, app v1.16.0)
├── values.yaml                   # Configuration values
├── .helmignore                   # Helm ignore patterns
└── templates/                    # Kubernetes resource templates
    ├── _helpers.tpl              # Template helpers
    ├── deployment.yaml           # Main application deployment
    ├── service.yaml              # Service configuration
    ├── ingress.yaml              # Ingress configuration (GCP-specific)
    ├── hpa.yaml                  # Horizontal Pod Autoscaler
    ├── serviceaccount.yaml       # Service account (GCP-specific)
    ├── backendconfig.yaml        # GCP BackendConfig
    ├── frontendconfig.yaml       # GCP FrontendConfig
    └── managedcertificate.yaml   # GCP ManagedCertificate
```

## Current State Analysis

### What I See

#### 1. **Healthcare Platform Deployment**
- **Purpose**: Deploys Medplum server, a healthcare data platform
- **Runtime**: Node.js application with OpenTelemetry instrumentation
- **Port**: Runs on port 8103 with `/healthcheck` endpoint
- **Architecture**: Designed for cloud-native deployment with autoscaling

#### 2. **GCP-Only Architecture**
- **Cloud Provider**: Exclusively supports Google Cloud Platform
- **GCP Services Used**:
  - Google Kubernetes Engine (GKE)
  - Cloud Load Balancing with BackendConfig/FrontendConfig
  - Managed SSL certificates
  - Workload Identity for service accounts
  - Cloud Armor security policies

#### 3. **Template Structure (9 Files)**
- **Core Resources**: Deployment, Service, HPA
- **GCP-Specific**: Ingress, ServiceAccount, BackendConfig, FrontendConfig, ManagedCertificate
- **Helpers**: Basic template functions for naming and labeling

#### 4. **Configuration Approach**
- **Values Structure**: Basic configuration with GCP-specific settings
- **Conditional Logic**: Heavy use of GCP provider checks
- **Placeholder Values**: Uses bracket notation `[MY_PROJECT_ID]` for required values

## Critical Issues Identified

### 🚨 Performance Issues

#### 1. **Resource Management Problems**
```yaml
# Current deployment.yaml - PROBLEMATIC
resources:
  limits:
    memory: "512Mi"    # Hardcoded memory limit
  requests:
    memory: "256Mi"    # Hardcoded memory request
# Missing: CPU limits and requests entirely
```

**Issues:**
- **No CPU resource limits or requests** - Can cause resource contention
- **Hardcoded memory values** - Not configurable per environment
- **Production risk** - Using `latest` image tag instead of versioned releases

#### 2. **HPA Configuration Gaps**
```yaml
# Current hpa.yaml - INCOMPLETE
metrics:
  {{- if .Values.deployment.autoscaling.targetCPUUtilizationPercentage }}
  # CPU metrics only if explicitly configured
  {{- end }}
  {{- if .Values.deployment.autoscaling.targetMemoryUtilizationPercentage }}
  # Memory metrics only if explicitly configured  
  {{- end }}
```

**Issues:**
- **No default thresholds** - HPA may not have any metrics configured
- **Missing validation** - Could deploy HPA with zero metrics
- **Suboptimal scaling** - No sensible defaults for CPU/memory utilization

### 🔧 Code Quality Issues

#### 1. **Hardcoded Values**
```yaml
# service.yaml - HARDCODED
annotations:
  cloud.google.com/backend-config: '{"default": "medplum-backendconfig"}'

# backendconfig.yaml - HARDCODED  
metadata:
  name: medplum-backendconfig  # Should be configurable

# frontendconfig.yaml - HARDCODED
spec:
  sslPolicy: "medplum-ssl-policy"  # Should be configurable
```

#### 2. **Repetitive Conditional Logic**
```yaml
# Pattern repeated across 5 templates
{{- if and (eq .Values.global.cloudProvider "gcp") (eq .Values.ingress.deploy true) }}
# Template content
{{- end }}
```

#### 3. **Missing Input Validation**
- No validation for required GCP project ID
- No validation for service account configuration
- No validation for domain configuration
- No clear error messages for missing values

### 📚 Simplicity Issues

#### 1. **Poor Documentation**
```yaml
# values.yaml - UNCLEAR
global:
  gcp:
    projectId: [MY_PROJECT_ID]  # Unclear placeholder format
    secretId: [MY_CONFIG_SECRET_ID]  # No explanation of purpose
```

#### 2. **Complex Template Logic**
- Redundant GCP provider checks across multiple templates
- No centralized cloud provider validation
- Inconsistent conditional patterns

#### 3. **Configuration Complexity**
- Placeholder values not clearly documented
- No examples or sensible defaults
- Missing comments explaining configuration options

## Detailed Improvement Recommendations

### 🚀 Performance Improvements

#### 1. **Resource Configuration Enhancement**
```yaml
# Recommended deployment.yaml changes
resources:
  limits:
    cpu: {{ .Values.resources.limits.cpu | default "500m" }}
    memory: {{ .Values.resources.limits.memory | default "512Mi" }}
  requests:
    cpu: {{ .Values.resources.requests.cpu | default "250m" }}
    memory: {{ .Values.resources.requests.memory | default "256Mi" }}
```

#### 2. **Image Tag Best Practices**
```yaml
# Change from:
image: "{{ .Values.deployment.image.repository }}:{{ .Values.deployment.image.tag | default .Chart.AppVersion }}"
# Current uses 'latest' by default

# To:
image: "{{ .Values.deployment.image.repository }}:{{ .Values.deployment.image.tag | default .Chart.AppVersion }}"
# And update values.yaml to use Chart.AppVersion instead of 'latest'
```

#### 3. **HPA Default Configuration**
```yaml
# Recommended hpa.yaml improvements
metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ .Values.deployment.autoscaling.targetCPUUtilizationPercentage | default 80 }}
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: {{ .Values.deployment.autoscaling.targetMemoryUtilizationPercentage | default 70 }}
```

### 🛠️ Code Quality Improvements

#### 1. **Centralized Cloud Provider Validation**
```yaml
# Add to _helpers.tpl
{{- define "medplum.isGCP" -}}
{{- eq .Values.global.cloudProvider "gcp" -}}
{{- end }}

{{- define "medplum.requireGCP" -}}
{{- if not (include "medplum.isGCP" .) -}}
{{- fail "This resource requires cloudProvider to be set to 'gcp'" -}}
{{- end -}}
{{- end }}
```

#### 2. **Configurable Hardcoded Values**
```yaml
# Enhanced values.yaml structure
gcp:
  backendConfig:
    name: "medplum-backendconfig"
  securityPolicy:
    name: "ingress-security-policy"  
  sslPolicy:
    name: "medplum-ssl-policy"
```

#### 3. **Input Validation Helpers**
```yaml
# Add validation helpers to _helpers.tpl
{{- define "medplum.validateGCPConfig" -}}
{{- if eq .Values.global.cloudProvider "gcp" -}}
  {{- if not .Values.global.gcp.projectId -}}
    {{- fail "GCP project ID is required when using GCP cloud provider" -}}
  {{- end -}}
  {{- if not .Values.serviceAccount.annotations -}}
    {{- fail "Service account annotations are required for GCP Workload Identity" -}}
  {{- end -}}
{{- end -}}
{{- end }}
```

### 📖 Simplicity Improvements

#### 1. **Enhanced Documentation**
```yaml
# Improved values.yaml with comprehensive comments
global:
  # Cloud provider configuration - currently only 'gcp' is supported
  # Roadmap includes 'aws' and 'azure' support
  cloudProvider: gcp
  
  gcp:
    # Your Google Cloud Platform project ID where resources will be created
    # Example: "my-healthcare-project-123456"
    projectId: ""
    
    # Secret Manager secret ID containing Medplum configuration
    # This secret should contain your Medplum server configuration
    secretId: ""
```

#### 2. **Simplified Template Logic**
```yaml
# Replace repetitive conditions with helper
{{- if include "medplum.shouldDeployGCPIngress" . }}
# Template content
{{- end }}

# Helper definition
{{- define "medplum.shouldDeployGCPIngress" -}}
{{- and (include "medplum.isGCP" .) .Values.ingress.deploy -}}
{{- end }}
```

## Priority Implementation Order

### Phase 1: Critical Performance Fixes
1. **Add CPU resource limits and requests**
2. **Make memory limits configurable**
3. **Fix image tag to use Chart.AppVersion**
4. **Add default HPA thresholds**

### Phase 2: Code Quality Improvements  
1. **Create cloud provider validation helpers**
2. **Make hardcoded values configurable**
3. **Add input validation with clear error messages**

### Phase 3: Simplicity Enhancements
1. **Add comprehensive documentation to values.yaml**
2. **Simplify template conditional logic**
3. **Provide clear configuration examples**

## Future Roadmap Recommendations

### Multi-Cloud Support
- Abstract cloud-specific resources into separate template files
- Create cloud provider abstraction layer
- Implement feature flags for cloud-specific functionality

### Security Enhancements
- Add Pod Security Standards compliance
- Implement network policies
- Add secret management best practices
- Security context hardening

### Monitoring & Observability
- Add ServiceMonitor for Prometheus
- Implement distributed tracing configuration
- Add logging configuration options
- Health check improvements

### Operational Excellence
- Add backup and disaster recovery configurations
- Implement blue-green deployment support
- Add database migration job templates
- Enhance troubleshooting documentation

## Conclusion

The Medplum Helm chart provides a solid foundation for deploying a healthcare platform on Kubernetes, but requires significant improvements in **performance configuration**, **code quality**, and **simplicity**. The current GCP-only approach is acceptable for the initial release, but the architecture should be prepared for multi-cloud expansion.

**Immediate Priority**: Address the performance issues (missing CPU limits, hardcoded resources, HPA configuration) as these pose the highest risk to production deployments.

**Medium Priority**: Improve code quality through better validation, configurability, and template organization.

**Long-term Priority**: Enhance documentation and prepare for multi-cloud support to increase adoption and maintainability.
