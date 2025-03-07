{{/* vim: set filetype=mustache: */}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "identity.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Defines extra labels for identity.
*/}}
{{- define "identity.extraLabels" -}}
app.kubernetes.io/component: identity
{{- end -}}

{{/*
Define common labels for identity, combining the match labels and transient labels, which might change on updating
(version depending). These labels shouldn't be used on matchLabels selector, since the selectors are immutable.
*/}}
{{- define "identity.labels" -}}
{{- template "camundaPlatform.labels" . }}
{{ template "identity.extraLabels" . }}
{{- end -}}

{{/*
Defines match labels for identity, which are extended by sub-charts and should be used in matchLabels selectors.
*/}}
{{- define "identity.matchLabels" -}}
{{- template "camundaPlatform.matchLabels" . }}
{{ template "identity.extraLabels" . }}
{{- end -}}

{{/*
[identity] Create the name of the service account to use
*/}}
{{- define "identity.serviceAccountName" -}}
{{- if .Values.serviceAccount.enabled }}
{{- default (include "identity.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
[identity] Create the name of the operate-identity secret
*/}}
{{- define "identity.secretNameOperateIdentity" -}}
{{- $name := .Release.Name -}}
{{- printf "%s-operate-identity-secret" $name | trunc 63 | trimSuffix "-" | quote -}}
{{- end }}

{{/*
[identity] Create the name of the tasklist-identity secret
*/}}
{{- define "identity.secretNameTasklistIdentity" -}}
{{- $name := .Release.Name -}}
{{- printf "%s-tasklist-identity-secret" $name | trunc 63 | trimSuffix "-" | quote -}}
{{- end }}

{{/*
[identity] Create the name of the optimize-identity secret
*/}}
{{- define "identity.secretNameOptimizeIdentity" -}}
{{- $name := .Release.Name -}}
{{- printf "%s-optimize-identity-secret" $name | trunc 63 | trimSuffix "-" | quote -}}
{{- end }}

{{/*
[identity] Create the name of the connectors-identity secret
*/}}
{{- define "identity.secretNameConnectorsIdentity" -}}
{{- $name := .Release.Name -}}
{{- printf "%s-connectors-identity-secret" $name | trunc 63 | trimSuffix "-" | quote -}}
{{- end }}

{{/*
Keycloak helpers
*/}}

{{/*
[identity] Fail in case Keycloak chart is disabled and existing Keycloak URL is not configured.
*/}}
{{- define "identity.keycloak.isConfigured" -}}
{{- $failMessageRaw := `
[identity] To configure Keycloak, you have 3 options:

  - Case 1: If you want to deploy Keycloak chart as it is, then set the following:
    - keycloak.enabled: true

  - Case 2: If you want to customize the Keycloak chart URL, then set the following:
    - keycloak.enabled: true
    - global.identity.keycloak.url.protocol
    - global.identity.keycloak.url.host
    - global.identity.keycloak.url.port

  - Case 3: If you want to use already existing Keycloak, then set the following:
    - keycloak.enabled: false
    - global.identity.keycloak.url.protocol
    - global.identity.keycloak.url.host
    - global.identity.keycloak.url.port
    - global.identity.keycloak.auth.adminUser
    - global.identity.keycloak.auth.existingSecret

For more details, please check Camunda Platform Helm chart documentation.
` -}}
    {{- $failMessage := printf "\n%s" $failMessageRaw | trimSuffix "\n" -}}

    {{- if .Values.global.identity.keycloak.url -}}
        {{- $_ := required $failMessage .Values.global.identity.keycloak.url.protocol -}}
        {{- $_ := required $failMessage .Values.global.identity.keycloak.url.host -}}
        {{- $_ := required $failMessage .Values.global.identity.keycloak.url.port -}}
    {{- end -}}

    {{- if .Values.global.identity.keycloak.auth -}}
        {{- $_ := required $failMessage .Values.global.identity.keycloak.auth.adminUser -}}
        {{- $_ := required $failMessage .Values.global.identity.keycloak.auth.existingSecret -}}
    {{- end -}}
{{- end -}}

{{/*
[identity] Get Keycloak URL protocol based on global value or Keycloak subchart.
*/}}
{{- define "identity.keycloak.protocol" -}}
    {{- if and .Values.global.identity.keycloak.url .Values.global.identity.keycloak.url.protocol -}}
        {{- .Values.global.identity.keycloak.url.protocol -}}
    {{- else -}}
        {{- ternary "https" "http" (.Values.keycloak.auth.tls.enabled) -}}
    {{- end -}}
{{- end -}}

{{/*
[identity] Get Keycloak URL service name based on global value or Keycloak subchart.
This is mainly used to access the external Keycloak service in the global Ingress.
*/}}
{{- define "identity.keycloak.service" -}}
    {{- if and (.Values.global.identity.keycloak.url).host .Values.global.identity.keycloak.internal -}}
        {{- printf "%s-keycloak-custom" .Release.Name | trunc 63 -}}
    {{- else -}}
        {{- include "camundaPlatform.keycloakDefaultHost" . -}}
    {{- end -}}
{{- end -}}

{{/*
[identity] Get Keycloak URL host based on global value or Keycloak subchart.
*/}}
{{- define "identity.keycloak.host" -}}
    {{- if and .Values.global.identity.keycloak.url .Values.global.identity.keycloak.url.host -}}
        {{- .Values.global.identity.keycloak.url.host -}}
    {{- else -}}
        {{- include "camundaPlatform.keycloakDefaultHost" . -}}
    {{- end -}}
{{- end -}}


{{/*
[identity] Get Keycloak URL port based on global value or Keycloak subchart.
*/}}
{{- define "identity.keycloak.port" -}}
    {{- if and .Values.global.identity.keycloak.url .Values.global.identity.keycloak.url.port -}}
        {{- .Values.global.identity.keycloak.url.port -}}
    {{- else -}}
        {{- $keycloakProtocol := (include "identity.keycloak.protocol" .) -}}
        {{- get .Values.keycloak.service.ports $keycloakProtocol -}}
    {{- end -}}
{{- end -}}

{{/*
[identity] Get Keycloak contextPath based on global value.
*/}}
{{- define "identity.keycloak.contextPath" -}}
    {{ .Values.global.identity.keycloak.contextPath | default "/auth" }}
{{- end -}}

{{/*
[identity] Get Keycloak full URL (protocol, host, and port).
*/}}
{{- define "identity.keycloak.url" -}}
    {{- include "identity.keycloak.isConfigured" . -}}
    {{-
      printf "%s://%s:%s%s"
        (include "identity.keycloak.protocol" .)
        (include "identity.keycloak.host" .)
        (include "identity.keycloak.port" .)
        (include "identity.keycloak.contextPath" .)
    -}}
{{- end -}}

{{/*
[identity] Get Keycloak auth admin user. For more details:
*/}}
{{- define "identity.keycloak.authAdminUser" -}}
{{- if .Values.global.identity.keycloak.auth }}
    {{- .Values.global.identity.keycloak.auth.adminUser -}}
{{- else }}
    {{- .Values.keycloak.auth.adminUser -}}
{{- end }}
{{- end -}}

{{/*
[identity] Get name of Keycloak auth existing secret. For more details:
https://docs.bitnami.com/kubernetes/apps/keycloak/configuration/manage-passwords/
*/}}
{{- define "identity.keycloak.authExistingSecret" -}}
{{- if .Values.global.identity.keycloak.auth }}
    {{- .Values.global.identity.keycloak.auth.existingSecret -}}
{{- else if .Values.keycloak.auth.existingSecret }}
    {{- .Values.keycloak.auth.existingSecret }}
{{- else -}}
    {{ .Release.Name }}-keycloak
{{- end }}
{{- end -}}

{{/*
[identity] Get Keycloak auth existing secret key.
*/}}
{{- define "identity.keycloak.authExistingSecretKey" -}}
{{- if .Values.global.identity.keycloak.auth }}
    {{- .Values.global.identity.keycloak.auth.existingSecretKey -}}
{{- else if .Values.keycloak.auth.passwordSecretKey }}
    {{- .Values.keycloak.auth.passwordSecretKey }}
{{- else -}}
    admin-password
{{- end }}
{{- end -}}
