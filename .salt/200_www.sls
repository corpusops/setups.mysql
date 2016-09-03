{% set cfg = opts['ms_project'] %}
{% import "makina-states/services/http/nginx/init.sls" as nginx with context %}
{% import "makina-states/services/php/init.sls" as php with context %}
{% set data = cfg.data %}
{% if not data.get('pma_enabled', True) %}
noop:
  mc_proxy.hook: []
{% else %}
include:
  - makina-states.services.php.phpfpm_with_nginx

{% set nginx_params = data.get('nginx', {}) %}
{% set ssl_key = None %}
{% set ssl_cert = None %}
{% set lssl = cfg.data.get("local_ssl", []) %}
{% if lssl %}
{% set lssl = salt['mc_utils.json_load'](lssl)[0] %}
{% do nginx_params.setdefault('ssl_cert',  lssl[0]) %}
{% do nginx_params.setdefault('ssl_key',  lssl[1]) %}
{% do nginx_params.setdefault('force_reload', True) %}
{% endif %}
{{nginx.virtualhost(cfg=cfg, **nginx_params) }}
{{php.fpm_pool(cfg=cfg, **cfg.data.fpm_pool)}}
{% endif %}
