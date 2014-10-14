{% set cfg = opts['ms_project'] %}
{% import "makina-states/services/http/nginx/init.sls" as nginx with context %}
{% import "makina-states/services/php/init.sls" as php with context %}
include:
  - makina-states.services.php.phpfpm_with_nginx
{% set data = cfg.data %}
# the fcgi sock is meaned to be at docroot/../var/fcgi/fpm.sock;

# incondentionnaly reboot nginx & fpm upon deployments
echo reboot:
  cmd.run:
    - watch_in:
      - mc_proxy: nginx-pre-restart-hook
      - mc_proxy: nginx-pre-hardrestart-hook
      - mc_proxy: makina-php-pre-restart

{{nginx.virtualhost(data.domain,
                    data.www_dir,
                    vh_top_source=data.nginx_top,
                    vh_content_source=data.nginx_vhost,
                    cfg=cfg) }}

{{php.fpm_pool(cfg.data.domain,
               cfg.data.www_dir,
               cfg=cfg,
               **cfg.data.fpm_pool)}}
