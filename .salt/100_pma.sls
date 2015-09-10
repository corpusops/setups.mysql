{% set cfg = opts['ms_project'] %}
{% set scfg = salt['mc_utils.json_dump'](cfg)%}
{% set php = salt['mc_php.settings']() %}
{% set data = cfg.data %}
{% set pma_ver=data.pma_ver %}

{% set rpw = salt['mc_mysql.settings']().root_passwd %}

prepreqs-{{cfg.name}}:
  pkg.installed:
    - pkgs:
      - unzip
      - xsltproc
      - curl
      - {{ php.packages.mysql }}
      - {{ php.packages.gd }}
      - {{ php.packages.cli }}
      - {{ php.packages.curl }}
      - {{ php.packages.ldap }}
      - {{ php.packages.dev }}
      - {{ php.packages.json }}
      - sqlite3
      - libsqlite3-dev
      - mysql-client
      - apache2-utils
      - autoconf
      - automake
      - build-essential
      - bzip2
      - gettext
      - git
      - groff
      - libbz2-dev
      - libcurl4-openssl-dev
      - libdb-dev
      - libgdbm-dev
      - libreadline-dev
      - libfreetype6-dev
      - libsigc++-2.0-dev
      - libsqlite0-dev
      - libsqlite3-dev
      - libtiff5
      - libtiff5-dev
      - libwebp5
      - libwebp-dev
      - libssl-dev
      - libtool
      - libxml2-dev
      - libxslt1-dev
      - libopenjpeg-dev
      - libopenjpeg2
      - m4
      - man-db
      - pkg-config
      - poppler-utils
      - python-dev
      - python-imaging
      - python-setuptools
      - zlib1g-dev

{{cfg.name}}-pmadownload:
  cmd.run:
    - user: root
    - cwd: {{ cfg.project_root}}
    - onlyif: test ! -e e{{cfg.project_root}}/phpMyAdmin-{{pma_ver}}-all-languages
#            wget -c "http://downloads.sourceforge.net/project/phpmyadmin/phpMyAdmin/{{pma_ver}}/phpMyAdmin-{{pma_ver}}-all-languages.zip?r=http%3A%2F%2Fwww.phpmyadmin.net%2Fhome_page%2Findex.php&ts=1413296402&use_mirror=freefr" -O "pma{{pma_ver}}.zip"
    - name: |
            set -ex
            wget -c "https://files.phpmyadmin.net/phpMyAdmin/{{pma_ver}}/phpMyAdmin-{{pma_ver}}-all-languages.zip?r=http%3A%2F%2Fwww.phpmyadmin.net%2Fhome_page%2Findex.php&ts=1413296402&use_mirror=freefr" -O "pma{{pma_ver}}.zip"
            unzip -o -qq pma{{pma_ver}}.zip
            chown -Rf {{cfg.user}}:{{cfg.group}} $PWD/phpMyAdmin-{{pma_ver}}-all-languages
            rm -f www
            ln -vs $PWD/phpMyAdmin-{{pma_ver}}-all-languages www

{{cfg.name}}-htaccess:
  file.managed:
    - name: {{data.htaccess}}
    - source: ''
    - user: www-data
    - group: www-data
    - mode: 770

{% set httpusers = {} %}

{% for dbext in data.databases %}
{%  for db, dbdata in dbext.items() %}
{%    do httpusers.update({dbdata.user: dbdata.password}) %}
{%  endfor %}
{% endfor %}

{% for userdict in data.get('users', {}) %}
{%  for user, data  in userdict.items() %}
{%    set data = data.copy() %}
{%    set pw = data.pop('password', '') %}
{%    do httpusers.update({user: pw}) %}
{%  endfor %}
{% endfor %}

{% do httpusers.update({'phpmyadmin': salt['mc_utils.generate_stored_password'](cfg.name+'.pmauser')}) %}

{% if data.get('http_users', {}) %}
{% for userrow in data.http_users %}
{%  for user, pw in userrow.items() %}
{%    do httpusers.update({user: pw}) %}
{%  endfor %}
{% endfor %}
{% endif %}

{% for user, passwd in httpusers.items() %}
{{cfg.name}}-{{user}}-htaccess:
  webutil.user_exists:
    - name: {{user}}
    - password: {{passwd}}
    - htpasswd_file: {{data.htaccess}}
    - options: m
    - force: true
    - watch:
      - file: {{cfg.name}}-htaccess
{% endfor %}


{{cfg.name}}-dirs:
  file.directory:
    - makedirs: true
    - user: {{cfg.user}}
    - group: {{cfg.group}}
    - mode: 770
    - watch:
      - pkg: prepreqs-{{cfg.name}}
    - names:
      - {{cfg.project_root}}/lib
      - {{cfg.project_root}}/bin
      - {{cfg.data_root}}/var
      - {{cfg.data_root}}/var/log
      - {{cfg.data_root}}/var/tmp
      - {{cfg.data_root}}/var/run
      - {{cfg.data_root}}/var/private

{{cfg.name}}-pma-sym:
  file.symlink:
    - name: {{cfg.project_root}}/www
    - target: {{cfg.project_root}}/phpMyAdmin-{{pma_ver}}-all-languages
    - user: {{cfg.user}}
    - group: {{cfg.group}}
    - watch:
      - file: {{cfg.name}}-dirs

{% for d in ['lib', 'bin', 'www'] %}
{{cfg.name}}-dirs{{d}}:
  file.symlink:
    - target: {{cfg.project_root}}/{{d}}
    - name: {{cfg.data_root}}/{{d}}
    - user: {{cfg.user}}
    - group: {{cfg.group}}
    - watch:
      - file: {{cfg.name}}-dirs
{% endfor %}

{% for d in ['var'] %}
{{cfg.name}}-l-dirs{{d}}:
  file.symlink:
    - name: {{cfg.project_root}}/{{d}}
    - target: {{cfg.data_root}}/{{d}}
    - user: {{cfg.user}}
    - group: {{cfg.group}}
    - watch:
      - file: {{cfg.name}}-dirs
{% endfor %}

{% for d in ['log', 'private', 'tmp'] %}
{{cfg.name}}-l-var-dirs{{d}}:
  file.symlink:
    - name: {{cfg.project_root}}/{{d}}
    - target: {{cfg.data_root}}/var/{{d}}
    - user: {{cfg.user}}
    - group: {{cfg.group}}
    - watch:
      - file: {{cfg.name}}-dirs
{% endfor %}
{% for i in ['config.inc.php'] %}
config-{{i}}:
  file.managed:
    - source: salt://makina-projects/{{cfg.name}}/files/{{i}}
    - name: {{cfg.project_root}}/www/{{i}}
    - template: jinja
    - mode: 750
    - user: {{cfg.user}}
    - group: {{cfg.group}}
    - defaults:
        cfg: |
             {{scfg}}
    - require:
      - cmd: {{cfg.name}}-pmadownload
{% endfor %}

loadtables:
  cmd.run:
    - name: mysql -u phpmyadmin --password="{{salt['mc_utils.generate_stored_password'](cfg.name+'.pmauser')}}"< {{cfg.project_root}}/www/sql/create_tables.sql
    - require:
      - cmd: {{cfg.name}}-pmadownload


