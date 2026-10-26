{{- define "common.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "common.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "common.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "common.labels" -}}
app.kubernetes.io/name: {{ include "common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
{{- end -}}

{{/* mysqld 설정. StatefulSet마다 자기 설정만 checksum으로 걸어, 한쪽 설정 변경이 다른 쪽을 재시작하지 않게 한다 */}}
{{- define "mysql.primaryCnf" -}}
[mysqld]
server-id = 1
binlog_format = ROW
gtid_mode = ON
enforce_gtid_consistency = ON
binlog_expire_logs_seconds = {{ .Values.mysqld.binlogExpireSeconds }}
plugin-load-add = mysql_clone.so
{{- end -}}

{{- define "mysql.replicaCnf" -}}
[mysqld]
server-id = 2
relay-log = relay-bin
binlog_format = ROW
gtid_mode = ON
enforce_gtid_consistency = ON
binlog_expire_logs_seconds = {{ .Values.mysqld.binlogExpireSeconds }}
plugin-load-add = mysql_clone.so
# 복제 설정 전에 replica가 혼자 쓰기를 받지 않도록 (설정 Job이 SET PERSIST super_read_only=ON 으로 고정)
read_only = ON
{{- end -}}

{{- define "mysql.replicaSelectorLabels" -}}
app.kubernetes.io/name: {{ include "common.name" . }}-replica
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "common.selectorLabels" -}}
app.kubernetes.io/name: {{ include "common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}