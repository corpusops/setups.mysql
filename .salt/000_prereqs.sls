{% set cfg = opts.ms_project %}
{% set data = cfg.data %}
{% set db = cfg.data.db %}
include:
  - makina-states.services.db.mysql

{%for dsysctl in data.sysctls %}
{%for sysctl, val in dsysctl.items() %}
{% if val is not none %}
{{sysctl}}-{{cfg.name}}:
  sysctl.present:
    - config: /etc/sysctl.d/00_{{cfg.name}}sysctls.conf
    - name: {{sysctl}}
    - value: {{val}}
    - watch_in:
      - mc_proxy: mysql-post-conf-hook
      - service: reload-sysctls-{{cfg.name}}
{% endif %}
{% endfor %}
{% endfor %}
{% if grains['os'] in ['Ubuntu'] %}
reload-sysctls-{{cfg.name}}:
  service.running:
    - name: procps
    - enable: true
    - watch:
      - mc_proxy: mysql-post-conf-hook
{% endif %}

{% import "makina-states/services/db/mysql/init.sls" as macros with context %}
{% for dbext in data.databases %}
{% for db, dbdata in dbext.items() %}
{{ macros.mysql_db(db, user=dbdata.user, password=dbdata.password) }}
{%endfor %}
{%endfor%}

{% set rpw = salt['mc_mysql.settings']().root_passwd %}
{% if not data.get('pma_enabled', True) %}
{{ macros.mysql_db(
  'phpmyadmin', 
  password=salt['mc_utils.generate_stored_password'](cfg.name+'.pmauser')) }}
{% endif %}

{% for userdict in data.get('users', {}) %}
{% for user, data  in userdict.items() %}
{% set data = data.copy() %}
{% set pw = data.pop('password', '') %}
{{macros.mysql_user(user, pw, **data) }}
{% endfor %}
{% endfor %}
