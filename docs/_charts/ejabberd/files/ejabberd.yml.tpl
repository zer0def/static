hosts:
- localhost

default_db: sql
new_sql_schema: true
sql_type: {{ .Values.sql.type }}
{{- if eq .Values.sql.type "sqlite" }}
sql_database: /home/ejabberd/database/db.sqlite
{{- else }}
{{- range $k, $v := (omit .Values.sql "type") }}
sql_{{ $k }}: {{ $v }}
{{- end }}
{{- end }}

auth_method: sql
auth_password_format: scram
auth_scram_hash: sha512

loglevel: info

## If you already have certificates, list them here
# certfiles:
# - /etc/letsencrypt/live/domain.tld/fullchain.pem
# - /etc/letsencrypt/live/domain.tld/privkey.pem

listen:
{{- if .Values.service.c2s.enabled }}
- port: {{ .Values.service.c2s.port }}
  ip: "::"
  module: ejabberd_c2s
  max_stanza_size: 262144
  shaper: c2s_shaper
  access: c2s
  starttls_required: true
{{- end }}
{{- if .Values.service.s2s.enabled }}
- port: {{ .Values.service.s2s.port }}
  ip: "::"
  module: ejabberd_s2s_in
  max_stanza_size: 524288
{{- end }}
{{- if index (default (dict) (index .Values.service "http-upload")) "enabled" }}
- port: {{ index (default (dict) (index .Values.service "http-upload")) "port" }}
  ip: "::"
  module: ejabberd_http
  tls: true
  request_handlers:
    /admin: ejabberd_web_admin
    /api: mod_http_api
    /bosh: mod_bosh
    /captcha: ejabberd_captcha
    /upload: mod_http_upload
    /ws: ejabberd_http_ws
{{- end }}
{{- if .Values.service.http.enabled }}
- port: {{ .Values.service.http.port }}
  ip: "::"
  module: ejabberd_http
  request_handlers:
    /admin: ejabberd_web_admin
    /.well-known/acme-challenge: ejabberd_acme
{{- end }}
{{/*
{{- if .Values.service.stun.enabled }}
- port: {{ .Values.service.stun.port }}
  ip: "::"
  transport: udp
  module: ejabberd_stun
  use_turn: true
  ## The server's public IPv4 address:
  # turn_ipv4_address: "203.0.113.3"
  ## The server's public IPv6 address:
  # turn_ipv6_address: "2001:db8::3"
{{- end }}
*/}}
{{- if .Values.service.mqtt.enabled }}
- port: {{ .Values.service.mqtt.port }}
  ip: "::"
  module: mod_mqtt
  backlog: 1000
{{- end }}

s2s_use_starttls: optional

acl:
  local:
    user_regexp: ""
  loopback:
    ip:
    - 127.0.0.0/8
    - ::1/128

access_rules:
  local:
    allow: local
  c2s:
    deny: blocked
    allow: all
  announce:
    allow: admin
  configure:
    allow: admin
  muc_create:
    allow: local
  pubsub_createnode:
    allow: local
  trusted_network:
    allow: loopback

api_permissions:
  "console commands":
    from:
    - ejabberd_ctl
    who: all
    what: "*"
  "admin access":
    who:
      access:
        allow:
        - acl: loopback
        - acl: admin
      oauth:
        scope: "ejabberd:admin"
        access:
          allow:
          - acl: loopback
          - acl: admin
    what:
    - "*"
    - "!stop"
    - "!start"
  "public commands":
    who:
      ip: 127.0.0.1/8
    what:
    - status
    - connected_users_number

shaper:
  normal:
    rate: 3000
    burst_size: 20000
  fast: 100000

shaper_rules:
  max_user_sessions: 10
  max_user_offline_messages:
    5000: admin
    100: all
  c2s_shaper:
    none: admin
    normal: all
  s2s_shaper: fast

modules:
  mod_adhoc: {}
  mod_admin_extra: {}
  mod_announce:
    access: announce
  mod_avatar: {}
  mod_blocking: {}
  mod_bosh: {}
  mod_caps: {}
  mod_carboncopy: {}
  mod_client_state: {}
  mod_configure: {}
  mod_disco: {}
  mod_fail2ban: {}
  mod_http_api: {}
  mod_http_upload:
    put_url: https://@HOST@:5443/upload
    custom_headers:
      "Access-Control-Allow-Origin": "https://@HOST@"
      "Access-Control-Allow-Methods": "GET,HEAD,PUT,OPTIONS"
      "Access-Control-Allow-Headers": "Content-Type"
  mod_last: {}
  mod_mam:
    ## Mnesia is limited to 2GB, better to use an SQL backend
    ## For small servers SQLite is a good fit and is very easy
    ## to configure. Uncomment this when you have SQL configured:
    ## db_type: sql
    assume_mam_usage: true
    default: always
  mod_mqtt: {}
  mod_muc:
    access:
    - allow
    access_admin:
    - allow: admin
    access_create: muc_create
    access_persistent: muc_create
    access_mam:
    - allow
    default_room_options:
      mam: true
  mod_muc_admin: {}
  mod_offline:
    access_max_user_messages: max_user_offline_messages
  mod_ping: {}
  mod_privacy: {}
  mod_private: {}
  mod_proxy65:
    access: local
    max_connections: 5
  mod_pubsub:
    access_createnode: pubsub_createnode
    plugins:
    - flat
    - pep
    force_node_config:
      ## Avoid buggy clients to make their bookmarks public
      storage:bookmarks:
        access_model: whitelist
  mod_push: {}
  mod_push_keepalive: {}
  mod_register:
    ## Only accept registration requests from the "trusted"
    ## network (see access_rules section above).
    ## Think twice before enabling registration from any
    ## address. See the Jabber SPAM Manifesto for details:
    ## https://github.com/ge0rg/jabber-spam-fighting-manifesto
    ip_access: trusted_network
  mod_roster:
    versioning: true
  mod_s2s_dialback: {}
  mod_shared_roster: {}
  mod_stream_mgmt:
    resend_on_timeout: if_offline
  mod_stun_disco: {}
  mod_vcard: {}
  mod_vcard_xupdate: {}
  mod_version:
    show_os: false
